import { DocumentFileLink } from "../../components/DocumentFileLink";
import { StaffReadReceipt } from "../../components/admin/StaffReadReceipt";
import { useState } from "react";
import { useSupportFeed } from "../../hooks/useSupportFeed";
import { supportConversation } from "../../utils/supportConversation";
import { formatDate } from "../../utils/format";
import { Send } from "lucide-react";
import { adminService } from "../../services/adminService";
import type { SupportTicketItem } from "../../types";
import { useLanguage } from "../../hooks/useLanguage";
import { getErrorMessage } from "../../utils/errors";

export const AdminSupportTicketsPage = () => {
  const { language } = useLanguage();
  const isArabic = language === "ar";
  const { items, error, setError, loading, refresh } = useSupportFeed(adminService.getSupportTickets, isArabic ? "تعذر تحميل التذاكر." : "Unable to load support tickets.");
  const [sending, setSending] = useState(false);
  const [replies, setReplies] = useState<Record<string, string>>({});
  const [statuses, setStatuses] = useState<Record<string, SupportTicketItem["status"]>>({});
  const handleReply = async (id: string) => {
    if (sending || !replies[id]?.trim()) return;
    setSending(true); setError("");
    try {
      await adminService.replySupportTicket(id, { message: replies[id].trim(), status: statuses[id] || "answered" });
      setReplies(current => ({...current, [id]: ""}));
      setStatuses(current => { const next = {...current}; delete next[id]; return next; });
      await refresh();
    } catch (issue) { setError(getErrorMessage(issue, isArabic ? "تعذر إرسال الرد." : "Unable to send reply.")); }
    finally { setSending(false); }
  };

  return (
    <div className="space-y-6">
      <section className="panel p-6">
        <h1 className="text-3xl font-semibold text-slate-900">{isArabic ? "تذاكر الدعم" : "Support Tickets"}</h1>
        <p className="mt-2 text-sm text-slate-500">{isArabic ? "تابع تذاكر الدعم ورد عليها مباشرة." : "Follow student and partner support tickets and respond directly."}</p>
        {error ? <div className="mt-5 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div> : null}
      </section>

      <div className="space-y-4">
        {loading && <p role="status">{isArabic ? "جارٍ تحميل التذاكر..." : "Loading tickets..."}</p>}
        {items.map((item) => (
          <article id={`ticket-${item._id}`} key={item._id} className="panel p-6">
            <StaffReadReceipt resource="support" record={item} />
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <h2 className="text-xl font-semibold text-slate-900">{item.subject}</h2>
                <p className="mt-1 text-sm text-slate-500">{item.user?.name || item.agent?.name || "--"} • {item.user?.email || item.agent?.email || "--"}</p>
              </div>
              <span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-700">{isArabic ? {open:"مفتوحة", "in-progress":"قيد المتابعة", answered:"تم الرد", closed:"مغلقة"}[item.status] : item.status}</span>
            </div>
            <p className="mt-4 text-sm leading-7 text-slate-600">{item.message}</p>
              {item.attachment?.filePath && <DocumentFileLink path={item.attachment.filePath} className="mt-3 inline-flex min-h-11 items-center rounded-lg border border-slate-200 px-4 text-sm font-semibold text-orange-700">{item.attachment.fileName || (isArabic ? "فتح المرفق" : "Open attachment")}</DocumentFileLink>}
            {supportConversation(item).length ? (
              <div className="mt-5 space-y-3 rounded-3xl bg-slate-50 p-4">
                {supportConversation(item).map((reply, index) => (
                  <div key={`${item._id}-${index}`} className="rounded-2xl bg-white px-4 py-3">
                    <div className="text-xs font-semibold uppercase tracking-[0.16em] text-slate-400">{reply.displayName || reply.user?.name || (reply.fromRole === "admin" ? (isArabic ? "فريق الدعم" : "Support team") : item.user?.name || item.agent?.name || (isArabic ? "الطالب" : "Student"))}{reply.source === "crm" ? " · CRM" : ""}{reply.createdAt ? ` · ${formatDate(reply.createdAt)}` : ""}</div>
                    <div className="mt-2 text-sm text-slate-700">{reply.message}</div>
                  </div>
                ))}
              </div>
            ) : null}
            <div className="mt-5 grid gap-4 md:grid-cols-[1fr_220px]">
              <textarea disabled={sending} maxLength={10000} value={replies[item._id] || ""} onChange={(event) => setReplies((current) => ({ ...current, [item._id]: event.target.value }))} rows={4} placeholder={isArabic ? "اكتب رد الإدارة هنا" : "Write the admin reply here"} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
              <div className="space-y-3">
                <select value={statuses[item._id] || item.status} onChange={(event) => setStatuses((current) => ({ ...current, [item._id]: event.target.value as SupportTicketItem["status"] }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring">
                  <option value="open">{isArabic ? "مفتوحة" : "Open"}</option>
                  <option value="in-progress">{isArabic ? "قيد التنفيذ" : "In Progress"}</option>
                  <option value="answered">{isArabic ? "تم الرد" : "Answered"}</option>
                  <option value="closed">{isArabic ? "مغلقة" : "Closed"}</option>
                </select>
                <button disabled={sending || !replies[item._id]?.trim()} type="button" onClick={() => handleReply(item._id)} className="inline-flex w-full items-center justify-center gap-2 rounded-2xl bg-slate-950 px-4 py-3 text-sm font-semibold text-white">
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
