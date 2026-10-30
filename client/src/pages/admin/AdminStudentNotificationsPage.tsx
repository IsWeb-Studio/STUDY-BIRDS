import { useEffect, useMemo, useState } from "react";
import { Bell, Search } from "lucide-react";
import { PushAnnouncementComposer } from '../../components/admin/PushAnnouncementComposer';
import { adminService } from "../../services/adminService";
import type { NotificationItem } from "../../types";
import { AdminPagination } from "../../components/admin/AdminPagination";
import { useLanguage } from "../../hooks/useLanguage";
import { getErrorMessage } from "../../utils/errors";
import { formatDate } from "../../utils/format";

const PAGE_SIZE = 8;

export const AdminStudentNotificationsPage = () => {
  const { language } = useLanguage();
  const isArabic = language === "ar";
  const [items, setItems] = useState<NotificationItem[]>([]);
  const [query, setQuery] = useState("");
  const [readFilter, setReadFilter] = useState<"all" | "read" | "unread">("all");
  const [page, setPage] = useState(1);
  const [error, setError] = useState("");

  useEffect(() => {
    adminService
      .getStudentNotifications()
      .then((data) => setItems(data.filter((item) => item.user?.role === "student")))
      .catch((issue) => setError(getErrorMessage(issue, isArabic ? "تعذر تحميل إشعارات الطلاب." : "Unable to load student notifications.")));
  }, [isArabic]);

  const filteredItems = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();
    return items.filter((item) => {
      const matchesRead = readFilter === "all" || (readFilter === "read" ? item.isRead : !item.isRead);
      const matchesQuery =
        !normalizedQuery ||
        [item.user?.name, item.user?.email, item.title, item.message]
          .filter(Boolean)
          .some((value) => String(value).toLowerCase().includes(normalizedQuery));
      return matchesRead && matchesQuery;
    });
  }, [items, query, readFilter]);

  const totalPages = Math.max(1, Math.ceil(filteredItems.length / PAGE_SIZE));
  const visibleItems = filteredItems.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

  useEffect(() => setPage(1), [query, readFilter]);
  useEffect(() => {
    if (page > totalPages) setPage(totalPages);
  }, [page, totalPages]);

  return (
    <div className="space-y-6">
      <PushAnnouncementComposer />
      <section className="panel p-6">
        <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <h1 className="text-3xl font-semibold text-slate-900">{isArabic ? "إشعارات الطلاب" : "Student Notifications"}</h1>
            <p className="mt-2 text-sm text-slate-500">{isArabic ? "متابعة كل التنبيهات المرسلة للطلاب من مكان واحد." : "Track all notifications sent to students from one place."}</p>
          </div>
          <div className="grid gap-3 sm:grid-cols-2">
            <label className="rounded-2xl border border-slate-200 bg-white px-4 py-3">
              <span className="mb-2 block text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">{isArabic ? "بحث" : "Search"}</span>
              <div className="flex items-center gap-2">
                <Search className="h-4 w-4 text-slate-400" />
                <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder={isArabic ? "ابحث بالطالب أو عنوان الإشعار" : "Search by student or title"} className="w-full border-none bg-transparent p-0 outline-none" />
              </div>
            </label>
            <label className="rounded-2xl border border-slate-200 bg-white px-4 py-3">
              <span className="mb-2 block text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">{isArabic ? "القراءة" : "Read State"}</span>
              <select value={readFilter} onChange={(event) => setReadFilter(event.target.value as "all" | "read" | "unread")} className="w-full border-none bg-transparent p-0 outline-none">
                <option value="all">{isArabic ? "الكل" : "All"}</option>
                <option value="unread">{isArabic ? "غير مقروء" : "Unread"}</option>
                <option value="read">{isArabic ? "مقروء" : "Read"}</option>
              </select>
            </label>
          </div>
        </div>
        {error ? <div className="mt-5 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div> : null}
      </section>

      <section className="space-y-4">
        {visibleItems.map((item) => (
          <article key={item._id} className={`panel p-6 ${item.isRead ? "" : "ring-1 ring-brand-200"}`}>
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div className="flex min-w-0 flex-1 items-start gap-3">
                <div className={`mt-1 flex h-10 w-10 shrink-0 items-center justify-center rounded-full ${item.isRead ? "bg-slate-100 text-slate-500" : "bg-brand-100 text-brand-700"}`}>
                  <Bell className="h-4 w-4" />
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <h2 className="break-words text-lg font-semibold text-slate-900">{item.title}</h2>
                    <span className={`rounded-full px-3 py-1 text-xs font-semibold ${item.isRead ? "bg-slate-100 text-slate-600" : "bg-emerald-100 text-emerald-700"}`}>
                      {item.isRead ? (isArabic ? "مقروء" : "Read") : isArabic ? "جديد" : "New"}
                    </span>
                  </div>
                  <p className="mt-2 text-sm text-slate-500">{item.user?.name || "--"} • {item.user?.email || "--"}</p>
                  <p className="mt-3 break-words text-sm leading-7 text-slate-600">{item.message}</p>
                  <p className="mt-3 text-xs text-slate-500">{formatDate(item.createdAt)}</p>
                </div>
              </div>
            </div>
          </article>
        ))}

        {filteredItems.length === 0 ? <div className="panel px-6 py-12 text-center text-sm text-slate-500">{isArabic ? "لا توجد إشعارات مطابقة." : "No matching notifications found."}</div> : null}

        <AdminPagination page={page} totalPages={totalPages} totalItems={filteredItems.length} pageSize={PAGE_SIZE} isArabic={isArabic} onPageChange={setPage} />
      </section>
    </div>
  );
};
