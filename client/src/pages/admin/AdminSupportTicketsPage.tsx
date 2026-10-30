import { VoiceReply } from "../../components/VoiceReply";
import { DocumentFileLink } from "../../components/DocumentFileLink";
import { useEffect, useState } from "react";
import { Send } from "lucide-react";
import { adminService } from "../../services/adminService";
import type { SupportTicketItem } from "../../types";
import { useLanguage } from "../../hooks/useLanguage";
import { getErrorMessage } from "../../utils/errors";

export const AdminSupportTicketsPage = () => {
  const { language } = useLanguage();
  const isArabic = language === "ar";
  const [items, setItems] = useState<SupportTicketItem[]>([]);
  const [replies, setReplies] = useState<Record<string, string>>({});
  const [statuses, setStatuses] = useState<Record<string, SupportTicketItem["status"]>>({});
  const [error, setError] = useState("");

  useEffect(() => {
    adminService
      .getSupportTickets()
      .then((data) => {
        setItems(data);
        setReplies(data.reduce<Record<string, string>>((acc, item) => ({ ...acc, [item._id]: "" }), {}));
        setStatuses(data.reduce<Record<string, SupportTicketItem["status"]>>((acc, item) => ({ ...acc, [item._id]: item.status }), {}));
      })
      .catch((issue) => setError(getErrorMessage(issue, isArabic ? "تعذر تحميل التذاكر." : "Unable to load support tickets.")));
  }, [isArabic]);

  const handleReply = async (id: string) => {
    const updated = await adminService.replySupportTicket(id, {
      message: replies[id] || "",
      status: statuses[id] || "answered",
    });
    setItems((current) => current.map((item) => (item._id === id ? updated : item)));
    setReplies((current) => ({ ...current, [id]: "" }));
  };

  return (
    <div className="space-y-6">
      <section className="panel p-6">
        <h1 className="text-3xl font-semibold text-slate-900">{isArabic ? "تذاكر دعم الوكلاء" : "Support Tickets"}</h1>
        <p className="mt-2 text-sm text-slate-500">{isArabic ? "تابع تذاكر الدعم ورد عليها مباشرة." : "Follow partner support tickets and respond directly."}</p>
        {error ? <div className="mt-5 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div> : null}
      </section>

      <div className="space-y-4">
        {items.map((item) => (
          <article key={item._id} className="panel p-6">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <h2 className="text-xl font-semibold text-slate-900">{item.subject}</h2>
                <p className="mt-1 text-sm text-slate-500">{item.agent?.name || "--"} • {item.agent?.email || "--"}</p>
              </div>
              <span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-700">{item.status}</span>
            </div>
            <p className="mt-4 text-sm leading-7 text-slate-600">{item.message}</p>
              {item.attachment?.filePath && <DocumentFileLink path={item.attachment.filePath} className="mt-3 inline-flex min-h-11 items-center rounded-lg border border-slate-200 px-4 text-sm font-semibold text-orange-700">{item.attachment.fileName || (isArabic ? "فتح المرفق" : "Open attachment")}</DocumentFileLink>}
            {item.replies?.length ? (
              <div className="mt-5 space-y-3 rounded-3xl bg-slate-50 p-4">
                {item.replies.map((reply, index) => (
                  <div key={`${item._id}-${index}`} className="rounded-2xl bg-white px-4 py-3">
                    <div className="text-xs font-semibold uppercase tracking-[0.16em] text-slate-400">{reply.fromRole}</div>
                    <div className="mt-2 text-sm text-slate-700">{reply.audioPath ? <VoiceReply path={reply.audioPath} /> : reply.message}</div>
                  </div>
                ))}
              </div>
            ) : null}
            <div className="mt-5 grid gap-4 md:grid-cols-[1fr_220px]">
              <textarea value={replies[item._id] || ""} onChange={(event) => setReplies((current) => ({ ...current, [item._id]: event.target.value }))} rows={4} placeholder={isArabic ? "اكتب رد الإدارة هنا" : "Write the admin reply here"} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
              <div className="space-y-3">
                <select value={statuses[item._id] || item.status} onChange={(event) => setStatuses((current) => ({ ...current, [item._id]: event.target.value as SupportTicketItem["status"] }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring">
                  <option value="open">{isArabic ? "مفتوحة" : "Open"}</option>
                  <option value="in-progress">{isArabic ? "قيد التنفيذ" : "In Progress"}</option>
                  <option value="answered">{isArabic ? "تم الرد" : "Answered"}</option>
                  <option value="closed">{isArabic ? "مغلقة" : "Closed"}</option>
                </select>
                <button type="button" onClick={() => handleReply(item._id)} className="inline-flex w-full items-center justify-center gap-2 rounded-2xl bg-slate-950 px-4 py-3 text-sm font-semibold text-white">
                  <Send className="h-4 w-4" />
                  {isArabic ? "إرسال الرد" : "Send Reply"}
                </button>
              </div>
            </div>
          </article>
        ))}
      </div>
    </div>
  );
};
