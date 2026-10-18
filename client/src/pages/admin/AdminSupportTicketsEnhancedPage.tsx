import { DocumentFileLink } from "../../components/DocumentFileLink";
import { useEffect, useMemo, useState } from "react";
import { Search, Send } from "lucide-react";
import { adminService } from "../../services/adminService";
import type { SupportTicketItem } from "../../types";
import { useLanguage } from "../../hooks/useLanguage";
import { getErrorMessage } from "../../utils/errors";
import { AdminPagination } from "../../components/admin/AdminPagination";
import { AdminToastViewport } from "../../components/admin/AdminToastViewport";
import { useAdminToasts } from "../../hooks/useAdminToasts";
import { formatDate } from "../../utils/format";

const PAGE_SIZE = 5;

export const AdminSupportTicketsEnhancedPage = () => {
  const { language } = useLanguage();
  const isArabic = language === "ar";
  const [items, setItems] = useState<SupportTicketItem[]>([]);
  const [replies, setReplies] = useState<Record<string, string>>({});
  const [statuses, setStatuses] = useState<Record<string, SupportTicketItem["status"]>>({});
  const [filter, setFilter] = useState<SupportTicketItem["status"] | "all">("all");
  const [query, setQuery] = useState("");
  const [page, setPage] = useState(1);
  const [sendingId, setSendingId] = useState("");
  const [error, setError] = useState("");
  const { toasts, pushToast, dismissToast } = useAdminToasts();

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

  const filteredItems = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();
    return items.filter((item) => {
      const matchesStatus = filter === "all" || item.status === filter;
      const matchesQuery =
        !normalizedQuery ||
        [item.subject, item.message, item.user?.name || item.agent?.name || "", item.user?.email || item.agent?.email || "", item.category].join(" ").toLowerCase().includes(normalizedQuery);
      return matchesStatus && matchesQuery;
    });
  }, [filter, items, query]);

  const totalPages = Math.max(1, Math.ceil(filteredItems.length / PAGE_SIZE));
  const visibleItems = useMemo(() => filteredItems.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE), [filteredItems, page]);

  useEffect(() => {
    setPage(1);
  }, [filter, query]);

  useEffect(() => {
    if (page > totalPages) {
      setPage(totalPages);
    }
  }, [page, totalPages]);

  const handleReply = async (id: string) => {
    if (!replies[id]?.trim()) {
      const message = isArabic ? "اكتب الرد أولًا." : "Write a reply first.";
      setError(message);
      pushToast(message, "error");
      return;
    }

    setSendingId(id);
    setError("");

    try {
      const updated = await adminService.replySupportTicket(id, {
        message: replies[id],
        status: statuses[id] || "answered",
      });
      setItems((current) => current.map((item) => (item._id === id ? updated : item)));
      setReplies((current) => ({ ...current, [id]: "" }));
      pushToast(isArabic ? "تم إرسال الرد." : "Reply sent successfully.", "success");
    } catch (issue) {
      const message = getErrorMessage(issue, isArabic ? "تعذر إرسال الرد." : "Unable to send reply.");
      setError(message);
      pushToast(message, "error");
    } finally {
      setSendingId("");
    }
  };

  return (
    <div className="space-y-6">
      <section className="panel p-6">
        <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <h1 className="text-3xl font-semibold text-slate-900">{isArabic ? "تذاكر دعم الوكلاء" : "Support Tickets"}</h1>
            <p className="mt-2 text-sm text-slate-500">{isArabic ? "تابع تذاكر الدعم ورد عليها مباشرة." : "Follow partner support tickets and respond directly."}</p>
          </div>
          <div className="grid gap-3 sm:grid-cols-2">
            <label className="rounded-2xl border border-slate-200 bg-white px-4 py-3">
              <span className="mb-2 block text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">{isArabic ? "بحث" : "Search"}</span>
              <div className="flex items-center gap-2">
                <Search className="h-4 w-4 text-slate-400" />
                <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder={isArabic ? "ابحث بعنوان التذكرة أو الوكيل" : "Search by subject or agent"} className="w-full border-none p-0 outline-none" />
              </div>
            </label>
            <label className="rounded-2xl border border-slate-200 bg-white px-4 py-3">
              <span className="mb-2 block text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">{isArabic ? "الحالة" : "Status"}</span>
              <select value={filter} onChange={(event) => setFilter(event.target.value as SupportTicketItem["status"] | "all")} className="w-full border-none bg-transparent p-0 outline-none">
                <option value="all">{isArabic ? "كل الحالات" : "All statuses"}</option>
                <option value="open">{isArabic ? "مفتوحة" : "Open"}</option>
                <option value="in-progress">{isArabic ? "قيد التنفيذ" : "In Progress"}</option>
                <option value="answered">{isArabic ? "تم الرد" : "Answered"}</option>
                <option value="closed">{isArabic ? "مغلقة" : "Closed"}</option>
              </select>
            </label>
          </div>
        </div>
        {error ? <div className="mt-5 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div> : null}
      </section>

      <div className="space-y-4">
        {visibleItems.map((item) => (
          <article key={item._id} className="panel p-6">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <h2 className="text-xl font-semibold text-slate-900">{item.subject}</h2>
                <p className="mt-1 text-sm text-slate-500">{item.user?.name || item.agent?.name || "--"} • {item.user?.email || item.agent?.email || "--"}</p>
              </div>
              <div className="text-right">
                <span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-700">{item.status}</span>
                <p className="mt-2 text-xs text-slate-400">{formatDate(item.updatedAt || item.createdAt)}</p>
              </div>
            </div>
            <p className="mt-4 text-sm leading-7 text-slate-600">{item.message}</p>
              {item.attachment?.filePath && <DocumentFileLink path={item.attachment.filePath} className="mt-3 inline-flex min-h-11 items-center rounded-lg border border-slate-200 px-4 text-sm font-semibold text-orange-700">{item.attachment.fileName || (isArabic ? "فتح المرفق" : "Open attachment")}</DocumentFileLink>}
            {item.replies?.length ? (
              <div className="mt-5 space-y-3 rounded-3xl bg-slate-50 p-4">
                {item.replies.map((reply) => (
                  <div key={reply._id || `${item._id}-${reply.createdAt}`} className="rounded-2xl bg-white px-4 py-3">
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <div className="text-xs font-semibold uppercase tracking-[0.16em] text-slate-400">{reply.displayName || reply.user?.name || reply.fromRole}</div>
                      <div className="text-xs text-slate-400">{formatDate(reply.createdAt)}</div>
                    </div>
                    <div className="mt-2 text-sm text-slate-700">{reply.message}</div>
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
                <button type="button" disabled={sendingId === item._id} onClick={() => handleReply(item._id)} className="inline-flex w-full items-center justify-center gap-2 rounded-2xl bg-slate-950 px-4 py-3 text-sm font-semibold text-white disabled:opacity-60">
                  <Send className="h-4 w-4" />
                  {sendingId === item._id ? (isArabic ? "جارٍ الإرسال..." : "Sending...") : isArabic ? "إرسال الرد" : "Send Reply"}
                </button>
              </div>
            </div>
          </article>
        ))}
        {filteredItems.length === 0 ? <div className="panel px-6 py-12 text-center text-sm text-slate-500">{isArabic ? "لا توجد تذاكر مطابقة." : "No support tickets match your filters."}</div> : null}
      </div>

      <AdminPagination page={page} totalPages={totalPages} totalItems={filteredItems.length} pageSize={PAGE_SIZE} isArabic={isArabic} onPageChange={setPage} />
      <AdminToastViewport items={toasts} onDismiss={dismissToast} />
    </div>
  );
};
