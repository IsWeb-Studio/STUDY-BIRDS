import { VoiceReply } from "../../components/VoiceReply";
import { DocumentFileLink } from "../../components/DocumentFileLink";
import { useEffect, useState } from "react";
import { EmptyState } from "../../components/EmptyState";
import { DOCUMENT_UPLOAD_ACCEPT, DOCUMENT_UPLOAD_HINT_AR, DOCUMENT_UPLOAD_HINT_EN } from "../../constants/upload";
import { partnerService } from "../../services/partnerService";
import type { SupportTicketItem } from "../../types";
import { useLanguage } from "../../hooks/useLanguage";
import { getErrorMessage } from "../../utils/errors";

export const PartnerSupportTicketsPage = () => {
  const { language } = useLanguage();
  const isArabic = language === "ar";
  const [tickets, setTickets] = useState<SupportTicketItem[]>([]);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [form, setForm] = useState({ subject: "", message: "", category: "student-application" });
  const [file, setFile] = useState<File | null>(null);

  const loadTickets = () =>
    partnerService
      .getTickets()
      .then(setTickets)
      .catch((issue) =>
        setError(getErrorMessage(issue, isArabic ? "تعذر تحميل التذاكر." : "Unable to load support tickets."))
      );

  useEffect(() => {
    loadTickets();
  }, [isArabic]);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setSubmitting(true);
    setError("");
    setSuccess("");
    try {
      await partnerService.createTicket({ ...form, file });
      setForm({ subject: "", message: "", category: "student-application" });
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
        <p className="mt-2 text-sm text-slate-500">{isArabic ? "افتح تذكرة جديدة وتابع ردود الإدارة." : "Open a new ticket and track admin replies."}</p>
        {success ? <div className="mt-5 rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{success}</div> : null}
        {error ? <div className="mt-5 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div> : null}
        <form onSubmit={handleSubmit} className="mt-6 grid gap-4 rounded-[2rem] border border-slate-200 bg-slate-50 p-5 md:grid-cols-2">
          <label>
            <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "العنوان" : "Subject"}</span>
            <input value={form.subject} onChange={(event) => setForm((current) => ({ ...current, subject: event.target.value }))} className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 outline-none focus:ring" />
          </label>
          <label>
            <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "نوع المشكلة" : "Category"}</span>
            <select value={form.category} onChange={(event) => setForm((current) => ({ ...current, category: event.target.value }))} className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 outline-none focus:ring">
              <option value="student-application">{isArabic ? "طلب طالب" : "Student Application"}</option>
              <option value="commission">{isArabic ? "العمولات" : "Commission"}</option>
              <option value="technical-issue">{isArabic ? "مشكلة تقنية" : "Technical Issue"}</option>
              <option value="other">{isArabic ? "أخرى" : "Other"}</option>
            </select>
          </label>
          <label className="md:col-span-2">
            <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "الرسالة" : "Message"}</span>
            <textarea value={form.message} onChange={(event) => setForm((current) => ({ ...current, message: event.target.value }))} rows={4} className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 outline-none focus:ring" />
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

      {tickets.length ? (
        <div className="space-y-4">
          {tickets.map((ticket) => (
            <article key={ticket._id} className="panel p-6">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <h2 className="text-xl font-semibold text-slate-900">{ticket.subject}</h2>
                  <p className="mt-1 text-sm text-slate-500">{ticket.category}</p>
                </div>
                <span className="rounded-full bg-slate-100 px-4 py-2 text-xs font-semibold text-slate-700">{ticket.status}</span>
              </div>
              <p className="mt-4 text-sm leading-7 text-slate-600">{ticket.message}</p>
              {ticket.attachment?.filePath && <DocumentFileLink path={ticket.attachment.filePath} className="mt-3 inline-flex min-h-11 items-center rounded-lg border border-slate-200 px-4 text-sm font-semibold text-orange-700">{ticket.attachment.fileName || (isArabic ? "فتح المرفق" : "Open attachment")}</DocumentFileLink>}
              {ticket.replies?.length ? (
                <div className="mt-5 space-y-3 rounded-3xl bg-slate-50 p-4">
                  {ticket.replies.map((reply, index) => (
                    <div key={`${ticket._id}-${index}`} className="rounded-2xl bg-white px-4 py-3">
                      <div className="text-xs font-semibold uppercase tracking-[0.16em] text-slate-400">{reply.fromRole}</div>
                      <div className="mt-2 text-sm text-slate-700">{reply.audioPath ? <VoiceReply path={reply.audioPath} /> : reply.message}</div>
                    </div>
                  ))}
                </div>
              ) : null}
            </article>
          ))}
        </div>
      ) : (
        <EmptyState title={isArabic ? "لا توجد تذاكر بعد" : "No support tickets yet"} description={isArabic ? "عند فتح أول تذكرة ستظهر هنا." : "Your support tickets will appear here."} />
      )}
    </div>
  );
};
