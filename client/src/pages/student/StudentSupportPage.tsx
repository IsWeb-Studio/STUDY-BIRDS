import { DocumentFileLink } from "../../components/DocumentFileLink";
import { useState } from "react";
import { EmptyState } from "../../components/EmptyState";
import { DOCUMENT_UPLOAD_ACCEPT, DOCUMENT_UPLOAD_HINT_AR, DOCUMENT_UPLOAD_HINT_EN } from "../../constants/upload";
import { useLanguage } from "../../hooks/useLanguage";
import { studentService } from "../../services/studentService";
import { useSupportFeed } from "../../hooks/useSupportFeed";
import { supportConversation } from "../../utils/supportConversation";
import { getErrorMessage } from "../../utils/errors";
import { formatDate } from "../../utils/format";

export const StudentSupportPage = () => {
  const { language } = useLanguage();
  const isArabic = language === "ar";
  const { items: tickets, error, setError, loading, refresh: loadTickets } = useSupportFeed(studentService.getSupportTickets, isArabic ? "تعذر تحميل تذاكر الدعم." : "Unable to load support tickets.");
  const [replyDrafts, setReplyDrafts] = useState<Record<string, string>>({});
  const [replyBusy, setReplyBusy] = useState(false);
  const [success, setSuccess] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [file, setFile] = useState<File | null>(null);
  const [form, setForm] = useState({
    subject: "",
    message: "",
    category: "documents",
  });

  const sendReply = async (event: React.FormEvent, id: string) => {
    event.preventDefault();
    if (replyBusy || !replyDrafts[id]?.trim()) return;
    setReplyBusy(true); setError(""); setSuccess("");
    try {
      await studentService.replySupportTicket(id, replyDrafts[id].trim());
      setReplyDrafts(current => ({ ...current, [id]: "" }));
      setSuccess(isArabic ? "تم إرسال ردك." : "Your reply was sent.");
      await loadTickets();
    } catch (issue) { setError(getErrorMessage(issue, isArabic ? "تعذر إرسال الرد." : "Unable to send reply.")); }
    finally { setReplyBusy(false); }
  };

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    if (submitting) return;
    setSubmitting(true);
    setError("");
    setSuccess("");

    try {
      await studentService.createSupportTicket({ ...form, file });
      setForm({ subject: "", message: "", category: "documents" });
      setFile(null);
      setSuccess(isArabic ? "تم فتح التذكرة بنجاح." : "Support ticket opened successfully.");
      await loadTickets();
    } catch (issue) {
      setError(getErrorMessage(issue, isArabic ? "تعذر فتح التذكرة." : "Unable to open support ticket."));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="space-y-6">
      <section className="panel p-6">
        <h1 className="text-3xl font-semibold text-slate-900">{isArabic ? "تذاكر الدعم" : "Support Tickets"}</h1>
        <p className="mt-2 text-sm text-slate-500">{isArabic ? "افتح تذكرة جديدة وتابع ردود مستشار القبول أو الإدارة." : "Open a new ticket and follow replies from the admission consultant or admin."}</p>
        {success ? <div className="mt-5 rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{success}</div> : null}
        {error ? <div className="mt-5 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div> : null}

        <form onSubmit={handleSubmit} className="mt-6 grid gap-4 rounded-[2rem] border border-slate-200 bg-slate-50 p-5 md:grid-cols-2">
          <label>
            <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "عنوان المشكلة" : "Issue Subject"}</span>
            <input required maxLength={200} value={form.subject} onChange={(event) => setForm((current) => ({ ...current, subject: event.target.value }))} className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 outline-none focus:ring" />
          </label>
          <label>
            <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "نوع المشكلة" : "Category"}</span>
            <select value={form.category} onChange={(event) => setForm((current) => ({ ...current, category: event.target.value }))} className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 outline-none focus:ring">
              <option value="documents">{isArabic ? "المستندات" : "Documents"}</option>
              <option value="application-status">{isArabic ? "حالة الطلب" : "Application Status"}</option>
              <option value="payment">{isArabic ? "الدفع" : "Payment"}</option>
              <option value="arrival-services">{isArabic ? "خدمات الوصول" : "Arrival Services"}</option>
              <option value="technical-issue">{isArabic ? "مشكلة في التطبيق" : "App issue"}</option>
              <option value="other">{isArabic ? "أخرى" : "Other"}</option>
            </select>
          </label>
          <label className="md:col-span-2">
            <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "الرسالة" : "Message"}</span>
            <textarea value={form.message} onChange={(event) => setForm((current) => ({ ...current, message: event.target.value }))} required maxLength={10000} rows={5} className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 outline-none focus:ring" />
          </label>
          <label className="md:col-span-2">
            <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "مرفق اختياري" : "Optional Attachment"}</span>
            <input type="file" accept={DOCUMENT_UPLOAD_ACCEPT} className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm outline-none focus:ring" onChange={(event) => setFile(event.target.files?.[0] || null)} />
            <p className="mt-2 text-xs text-slate-500">{isArabic ? DOCUMENT_UPLOAD_HINT_AR : DOCUMENT_UPLOAD_HINT_EN}</p>
          </label>
          <button type="submit" disabled={submitting} className="w-fit rounded-full bg-brand-900 px-6 py-3 font-semibold text-white">
            {submitting ? (isArabic ? "جارٍ الإرسال..." : "Submitting...") : isArabic ? "فتح تذكرة جديدة" : "Open New Ticket"}
          </button>
        </form>
      </section>

      {loading ? <p role="status">{isArabic ? "جارٍ تحميل التذاكر..." : "Loading tickets..."}</p> : tickets.length ? (
        <div className="space-y-4">
          {tickets.map((ticket) => (
            <article id={`ticket-${ticket._id}`} key={ticket._id} className="panel p-6">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <h2 className="text-xl font-semibold text-slate-900">{ticket.subject}</h2>
                  <p className="mt-1 text-sm text-slate-500">{ticket.category} • {formatDate(ticket.createdAt)}</p>
                </div>
                <span className="rounded-full bg-slate-100 px-4 py-2 text-xs font-semibold text-slate-700">{isArabic ? {open:"مفتوحة", "in-progress":"قيد المتابعة", answered:"تم الرد", closed:"مغلقة"}[ticket.status] : ticket.status}</span>
              </div>
              <p className="mt-4 text-sm leading-7 text-slate-600">{ticket.message}</p>
              {ticket.assignedTo?.name && <p className="mt-2 text-sm text-slate-500">{isArabic ? "الموظف المسؤول: " : "Assigned to: "}{ticket.assignedTo.name}</p>}
              {ticket.attachment?.filePath && <DocumentFileLink path={ticket.attachment.filePath} className="mt-3 inline-flex min-h-11 items-center rounded-lg border border-slate-200 px-4 text-sm font-semibold text-orange-700">{ticket.attachment.fileName || (isArabic ? "فتح المرفق" : "Open attachment")}</DocumentFileLink>}
              {supportConversation(ticket).length ? (
                <div className="mt-5 space-y-3 rounded-3xl bg-slate-50 p-4">
                  {supportConversation(ticket).map((reply, index) => (
                    <div key={`${ticket._id}-${index}`} className="rounded-2xl bg-white px-4 py-3">
                      <div className="text-xs font-semibold uppercase tracking-[0.16em] text-slate-400">{reply.fromRole === "student" ? (isArabic ? "أنت" : "You") : reply.displayName || reply.user?.name || (isArabic ? "فريق الدعم" : "Support team")}{reply.source === "crm" ? " · CRM" : ""}{reply.createdAt ? ` · ${formatDate(reply.createdAt)}` : ""}</div>
                      <div className="mt-2 text-sm text-slate-700">{reply.message}</div>
                    </div>
                  ))}
                </div>
              ) : null}
              {ticket.status !== "closed" ? <form onSubmit={event => sendReply(event, ticket._id)} className="mt-4 space-y-3">
                <label className="block"><span className="mb-2 block text-sm font-medium">{isArabic ? "رد على التذكرة" : "Reply to ticket"}</span>
                  <textarea required maxLength={10000} rows={3} disabled={replyBusy} value={replyDrafts[ticket._id] || ""} onChange={event => setReplyDrafts(current => ({...current, [ticket._id]: event.target.value}))} className="w-full rounded-2xl border border-slate-200 px-4 py-3" />
                </label>
                <button type="submit" disabled={replyBusy || !replyDrafts[ticket._id]?.trim()} className="rounded-full bg-brand-900 px-5 py-3 font-semibold text-white disabled:opacity-50">{isArabic ? "إرسال الرد" : "Send reply"}</button>
              </form> : <p className="mt-4 text-sm text-slate-500">{isArabic ? "هذه التذكرة مغلقة." : "This ticket is closed."}</p>}
            </article>
          ))}
        </div>
      ) : (
        <EmptyState title={isArabic ? "لا توجد تذاكر بعد" : "No support tickets yet"} description={isArabic ? "عند فتح أول تذكرة ستظهر هنا." : "Your support tickets will appear here once you open one."} />
      )}
    </div>
  );
};
