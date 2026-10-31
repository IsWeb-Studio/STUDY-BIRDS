import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { HeartHandshake, UserPlus } from "lucide-react";
import { parentService } from "../../services/parentService";
import type { ParentLinkItem, User } from "../../types";
import { getErrorMessage } from "../../utils/errors";
import { formatDate } from "../../utils/format";
import { useLanguage } from "../../hooks/useLanguage";

export const ParentDashboardPage = () => {
  const { language } = useLanguage();
  const isArabic = language === "ar";
  const [children, setChildren] = useState<User[]>([]);
  const [requests, setRequests] = useState<ParentLinkItem[]>([]);
  const [form, setForm] = useState({ studentEmail: "", relationship: "", note: "" });
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState("");

  const loadData = async () => {
    const [childrenData, requestsData] = await Promise.all([
      parentService.getChildren(),
      parentService.getLinkRequests(),
    ]);
    setChildren(childrenData);
    setRequests(requestsData);
  };

  useEffect(() => {
    loadData().catch((error) => setFormError(getErrorMessage(error, isArabic ? "تعذر تحميل بياناتك." : "Unable to load your data.")));
  }, [isArabic]);

  const handleSubmitRequest = async () => {
    if (!form.studentEmail) {
      setFormError(isArabic ? "برجاء إدخال البريد الإلكتروني للطالب." : "Please enter the student's email.");
      return;
    }

    setSubmitting(true);
    setFormError("");
    try {
      const created = await parentService.createLinkRequest(form);
      setRequests((current) => [created, ...current]);
      setForm({ studentEmail: "", relationship: "", note: "" });
    } catch (error) {
      setFormError(getErrorMessage(error, isArabic ? "تعذر إرسال الطلب." : "Unable to submit the request."));
    } finally {
      setSubmitting(false);
    }
  };

  const pendingOrRejected = requests.filter((request) => request.status !== "approved");

  return (
    <div className="space-y-6">
      <section className="panel p-6">
        <div className="flex items-center gap-3">
          <div className="rounded-2xl bg-slate-100 p-3 text-slate-700">
            <HeartHandshake className="h-5 w-5" />
          </div>
          <div>
            <h1 className="text-3xl font-semibold text-slate-900">{isArabic ? "أبنائي" : "My Children"}</h1>
            <p className="mt-1 text-sm text-slate-500">
              {isArabic
                ? "تابع رحلة أبنائك الدراسية بعد موافقة الإدارة على ربط حسابك بحسابهم."
                : "Follow your children's study journey once Study Birds approves the link to their account."}
            </p>
          </div>
        </div>

        {formError ? <div className="mt-4 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{formError}</div> : null}
      </section>

      <section className="panel p-6">
        <h2 className="text-lg font-semibold text-slate-900">{isArabic ? "ربط حساب طالب جديد" : "Link a new student account"}</h2>
        <div className="mt-4 grid gap-3 md:grid-cols-3 md:items-end">
          <label className="block">
            <span className="mb-2 block text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">
              {isArabic ? "البريد الإلكتروني للطالب" : "Student's email"}
            </span>
            <input
              type="email"
              value={form.studentEmail}
              onChange={(event) => setForm((current) => ({ ...current, studentEmail: event.target.value }))}
              className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
            />
          </label>
          <label className="block">
            <span className="mb-2 block text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">
              {isArabic ? "صلة القرابة" : "Relationship"}
            </span>
            <input
              value={form.relationship}
              onChange={(event) => setForm((current) => ({ ...current, relationship: event.target.value }))}
              placeholder={isArabic ? "مثال: الأب" : "e.g. Father"}
              className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
            />
          </label>
          <button
            type="button"
            disabled={submitting}
            onClick={handleSubmitRequest}
            className="flex items-center justify-center gap-2 rounded-2xl bg-slate-950 px-4 py-3 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-60"
          >
            <UserPlus className="h-4 w-4" />
            {submitting ? (isArabic ? "جارٍ الإرسال..." : "Sending...") : isArabic ? "إرسال طلب الربط" : "Send link request"}
          </button>
        </div>

        {pendingOrRejected.length > 0 ? (
          <div className="mt-5 space-y-2">
            {pendingOrRejected.map((request) => (
              <div key={request._id} className="flex items-center justify-between rounded-2xl bg-slate-50 px-4 py-3 text-sm">
                <span className="text-slate-700">{request.student?.email}</span>
                <span
                  className={`rounded-full px-3 py-1 text-xs font-semibold ${
                    request.status === "pending" ? "bg-amber-100 text-amber-700" : "bg-rose-100 text-rose-700"
                  }`}
                >
                  {request.status === "pending" ? (isArabic ? "قيد المراجعة" : "Pending review") : isArabic ? "مرفوض" : "Rejected"}
                </span>
              </div>
            ))}
          </div>
        ) : null}
      </section>

      <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        {children.length ? (
          children.map((child) => (
            <Link
              key={child._id}
              to={`/parent/children/${child._id}`}
              className="panel block p-5 transition hover:-translate-y-0.5 hover:shadow-lg"
            >
              <p className="text-lg font-semibold text-slate-900">{child.name}</p>
              <p className="mt-1 text-sm text-slate-500">{child.email}</p>
              <p className="mt-4 text-xs font-semibold uppercase tracking-[0.2em] text-brand-700">
                {isArabic ? "عرض التفاصيل ←" : "View details →"}
              </p>
            </Link>
          ))
        ) : (
          <div className="panel p-8 text-sm text-slate-500 md:col-span-3">
            {isArabic
              ? "لا يوجد لديك أبناء مرتبطين بعد. أرسل طلب ربط بالأعلى وانتظر موافقة الإدارة."
              : "No linked children yet. Send a link request above and wait for admin approval."}
          </div>
        )}
      </section>

      {requests.find((r) => r.status === "approved" && r.reviewedAt) ? (
        <p className="text-center text-xs text-slate-400">
          {isArabic ? "آخر تحديث" : "Last update"}: {formatDate(requests[0]?.reviewedAt)}
        </p>
      ) : null}
    </div>
  );
};
