import { PushAnnouncementComposer } from "../../components/admin/PushAnnouncementComposer";
import { useEffect, useMemo, useRef, useState, type FormEvent } from "react";
import { Bell, Search, Send, Users } from "lucide-react";
import { adminService } from "../../services/adminService";
import type { NotificationItem } from "../../types";
import { AdminPagination } from "../../components/admin/AdminPagination";
import { useLanguage } from "../../hooks/useLanguage";
import { getErrorMessage } from "../../utils/errors";
import { formatDate } from "../../utils/format";

const PAGE_SIZE = 8;
type Audience = { activeUsers: number; pushEligibleUsers: number; pushConfigured: boolean; canBroadcast: boolean };
type BroadcastResult = {
  recipientCount: number;
  pushEligibleCount: number;
  pushConfigured: boolean;
  pushReportedRecipientCount: number;
  pushUnconfirmedBatches: number;
};

export const AdminStudentNotificationsPage = () => {
  const { language } = useLanguage();
  const isArabic = language === "ar";
  const [items, setItems] = useState<NotificationItem[]>([]);
  const [query, setQuery] = useState("");
  const [readFilter, setReadFilter] = useState<"all" | "read" | "unread">("all");
  const [page, setPage] = useState(1);
  const [error, setError] = useState("");
  const [title, setTitle] = useState("");
  const [message, setMessage] = useState("");
  const [audience, setAudience] = useState<Audience | null>(null);
  const [audienceError, setAudienceError] = useState("");
  const [sending, setSending] = useState(false);
  const [sendError, setSendError] = useState("");
  const [sendResult, setSendResult] = useState<BroadcastResult | null>(null);
  const idempotencyKey = useRef<string | null>(null);
  const pendingPayload = useRef<string | null>(null);

  const updateDraft = (nextTitle: string, nextMessage: string) => {
    const draftKey = JSON.stringify({ title: nextTitle.trim(), message: nextMessage.trim() });
    if (pendingPayload.current !== null && pendingPayload.current !== draftKey) {
      idempotencyKey.current = null;
      pendingPayload.current = null;
    }
    setTitle(nextTitle);
    setMessage(nextMessage);
  };

  const loadNotifications = () => adminService.getStudentNotifications()
    .then(setItems)
    .catch((issue) => setError(getErrorMessage(issue, isArabic ? "تعذر تحميل الإشعارات." : "Unable to load notifications.")));

  useEffect(() => {
    void loadNotifications();
    adminService.getNotificationAudience().then(setAudience).catch((issue) => {
      setAudience(null);
      setAudienceError(getErrorMessage(issue, isArabic ? "تعذر التحقق من جمهور الإشعار." : "Unable to verify the notification audience."));
    });
  }, [isArabic]);

  const handleBroadcast = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!title.trim() || !message.trim() || !audience || sending) return;
    const prompt = isArabic
      ? `سيُحفظ الإعلان في صندوق الإشعارات لكل ${audience.activeUsers} حساب نشط. وسيُرسل Push للحسابات التي تسمح بإعلانات التطبيق. هل تريد المتابعة؟`
      : `This will save the announcement to the inbox of all ${audience.activeUsers} active accounts and send push to accounts that allow announcements. Continue?`;
    if (!window.confirm(prompt)) return;

    setSending(true);
    setSendError("");
    setSendResult(null);
    try {
      const payload = { title: title.trim(), message: message.trim() };
      const payloadKey = JSON.stringify(payload);
      if (!idempotencyKey.current || pendingPayload.current !== payloadKey) {
        idempotencyKey.current = globalThis.crypto.randomUUID();
        pendingPayload.current = payloadKey;
      }
      const result = await adminService.broadcastNotification(payload, idempotencyKey.current);
      setSendResult(result);
      idempotencyKey.current = null;
      pendingPayload.current = null;
      setTitle("");
      setMessage("");
      setAudience((current) => current ? {
        ...current,
        activeUsers: result.recipientCount,
        pushEligibleUsers: result.pushEligibleCount,
        pushConfigured: result.pushConfigured,
      } : current);
      await loadNotifications();
    } catch (issue) {
      setSendError(getErrorMessage(issue, isArabic ? "تعذر إرسال الإعلان. لم يتم تأكيد إرساله." : "The announcement could not be sent. Delivery was not confirmed."));
    } finally {
      setSending(false);
    }
  };

  const filteredItems = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();
    return items.filter((item) => {
      const matchesRead = readFilter === "all" || (readFilter === "read" ? item.isRead : !item.isRead);
      const matchesQuery = !normalizedQuery ||
        [item.user?.name, item.user?.email, item.title, item.message]
          .filter(Boolean)
          .some((value) => String(value).toLowerCase().includes(normalizedQuery));
      return matchesRead && matchesQuery;
    });
  }, [items, query, readFilter]);

  const totalPages = Math.max(1, Math.ceil(filteredItems.length / PAGE_SIZE));
  const visibleItems = filteredItems.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

  useEffect(() => setPage(1), [query, readFilter]);
  useEffect(() => { if (page > totalPages) setPage(totalPages); }, [page, totalPages]);

  const roleLabel = (role?: string) => {
    const labels: Record<string, { ar: string; en: string }> = {
      student: { ar: "طالب", en: "Student" },
      admin: { ar: "إدارة", en: "Admin" },
      partner: { ar: "وكيل", en: "Agent" },
      parent: { ar: "ولي أمر", en: "Parent" },
      university: { ar: "جامعة", en: "University" },
      employee: { ar: "موظف", en: "Employee" },
    };
    if (!role) return "";
    return labels[role]?.[isArabic ? "ar" : "en"] || role;
  };

  return (
    <div className="space-y-6">
      <PushAnnouncementComposer />
      <section className="panel p-6">
        <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <h1 className="text-3xl font-semibold text-slate-900">{isArabic ? "إشعارات التطبيق" : "App Notifications"}</h1>
            <p className="mt-2 text-sm text-slate-500">{isArabic ? "تابع إشعارات التطبيق وأرسل إعلانًا عامًا إلى جميع الحسابات النشطة." : "Review app notifications and send an announcement to all active accounts."}</p>
          </div>
          <div className="grid gap-3 sm:grid-cols-2">
            <label className="rounded-2xl border border-slate-200 bg-white px-4 py-3">
              <span className="mb-2 block text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">{isArabic ? "بحث" : "Search"}</span>
              <div className="flex items-center gap-2">
                <Search className="h-4 w-4 text-slate-400" />
                <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder={isArabic ? "ابحث بالحساب أو عنوان الإشعار" : "Search by account or title"} className="w-full border-none bg-transparent p-0 outline-none" />
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

      <section className="panel p-6">
        <div className="mb-5 flex items-start gap-3">
          <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-brand-100 text-brand-700"><Send className="h-5 w-5" /></div>
          <div>
            <h2 className="text-xl font-semibold text-slate-900">{isArabic ? "إرسال إعلان عام" : "Send an app-wide announcement"}</h2>
            <p className="mt-1 text-sm leading-6 text-slate-500">{isArabic ? "سيظهر الإعلان داخل التطبيق لكل الحسابات النشطة، ويُرسل Push لمن سمح بإعلانات التطبيق." : "The announcement is saved in every active account's in-app inbox. Push is sent to users who allow app announcements."}</p>
          </div>
        </div>
        {audienceError ? <p role="alert" className="mb-4 rounded-xl bg-rose-50 px-4 py-3 text-sm text-rose-700">{audienceError}{isArabic ? " لن يتاح الإرسال حتى ينجح التحقق." : " Sending remains disabled until the audience can be verified."}</p> : null}
        <div className="mb-5 flex flex-wrap items-center gap-2 rounded-2xl bg-slate-50 px-4 py-3 text-sm text-slate-600">
          <Users className="h-4 w-4 text-brand-600" />
          {audience
            ? (isArabic ? `${audience.activeUsers} حساب نشط · ${audience.pushEligibleUsers} يسمحون بإعلانات Push` : `${audience.activeUsers} active accounts · ${audience.pushEligibleUsers} allow announcement push`)
            : (isArabic ? "جارٍ تحميل عدد الحسابات..." : "Loading account count...")}
          {audience && !audience.pushConfigured ? <span className="font-medium text-amber-700">{isArabic ? "· Push غير مهيأ؛ سيبقى الإعلان داخل صندوق التطبيق" : "· Push is not configured; the announcement will still appear in app inboxes"}</span> : null}
        </div>
        {audience && !audience.canBroadcast ? <p className="mb-4 rounded-xl bg-amber-50 px-4 py-3 text-sm text-amber-800">{isArabic ? "إرسال الإعلان العام متاح لحساب الأدمن فقط." : "Only an admin account can send an app-wide announcement."}</p> : null}
        <form className="space-y-4" onSubmit={handleBroadcast}>
          <label className="block">
            <span className="mb-2 block text-sm font-semibold text-slate-700">{isArabic ? "عنوان الإشعار" : "Notification title"}</span>
            <input value={title} onChange={(event) => updateDraft(event.target.value, message)} maxLength={120} required className="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 outline-none focus:border-brand-400" placeholder={isArabic ? "مثال: منحة دراسية جديدة" : "Example: New scholarship available"} />
            <span className="mt-1 block text-end text-xs text-slate-400">{title.length}/120</span>
          </label>
          <label className="block">
            <span className="mb-2 block text-sm font-semibold text-slate-700">{isArabic ? "نص الإشعار" : "Notification message"}</span>
            <textarea value={message} onChange={(event) => updateDraft(title, event.target.value)} maxLength={500} rows={4} required className="w-full resize-y rounded-xl border border-slate-200 bg-white px-4 py-3 outline-none focus:border-brand-400" placeholder={isArabic ? "اكتب تفاصيل الإعلان باختصار..." : "Write the announcement details..."} />
            <span className="mt-1 block text-end text-xs text-slate-400">{message.length}/500</span>
          </label>
          {sendError ? <p role="alert" className="rounded-xl bg-rose-50 px-4 py-3 text-sm text-rose-700">{sendError}</p> : null}
          {sendResult ? <p role="status" className="rounded-xl bg-emerald-50 px-4 py-3 text-sm text-emerald-800">
            {isArabic ? `تم حفظ الإعلان في ${sendResult.recipientCount} صندوق إشعارات. أكد OneSignal عدد ${sendResult.pushReportedRecipientCount} مستلمًا لإشعار Push.` : `Saved to ${sendResult.recipientCount} inboxes. OneSignal confirmed ${sendResult.pushReportedRecipientCount} push recipients.`}
            {sendResult.pushUnconfirmedBatches ? (isArabic ? ` تعذر تأكيد نتيجة ${sendResult.pushUnconfirmedBatches} دفعات Push؛ تحقق من OneSignal.` : ` The result of ${sendResult.pushUnconfirmedBatches} push batch(es) could not be confirmed; check OneSignal.`) : null}
            {!sendResult.pushConfigured ? (isArabic ? " لم يُرسل Push لأن الخدمة غير مهيأة." : " Push was not sent because the service is not configured.") : null}
          </p> : null}
          <button type="submit" disabled={sending || !audience || !audience.canBroadcast || audience.activeUsers === 0 || !title.trim() || !message.trim()} className="inline-flex min-h-12 items-center gap-2 rounded-xl bg-brand-700 px-5 py-3 font-semibold text-white transition hover:bg-brand-800 disabled:cursor-not-allowed disabled:opacity-50">
            <Send className="h-4 w-4" />
            {sending ? (isArabic ? "جارٍ الإرسال..." : "Sending...") : (isArabic ? "إرسال لجميع المستخدمين" : "Send to all users")}
          </button>
        </form>
      </section>

      <section className="space-y-4">
        {visibleItems.map((item) => (
          <article key={item._id} className={`panel p-6 ${item.isRead ? "" : "ring-1 ring-brand-200"}`}>
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div className="flex min-w-0 flex-1 items-start gap-3">
                <div className={`mt-1 flex h-10 w-10 shrink-0 items-center justify-center rounded-full ${item.isRead ? "bg-slate-100 text-slate-500" : "bg-brand-100 text-brand-700"}`}><Bell className="h-4 w-4" /></div>
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <h2 className="break-words text-lg font-semibold text-slate-900">{item.title}</h2>
                    <span className={`rounded-full px-3 py-1 text-xs font-semibold ${item.isRead ? "bg-slate-100 text-slate-600" : "bg-emerald-100 text-emerald-700"}`}>{item.isRead ? (isArabic ? "مقروء" : "Read") : isArabic ? "جديد" : "New"}</span>
                  </div>
                  <p className="mt-2 text-sm text-slate-500">{item.user?.name || "--"} · {item.user?.email || "--"}{item.user?.role ? ` · ${roleLabel(item.user.role)}` : ""}</p>
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
