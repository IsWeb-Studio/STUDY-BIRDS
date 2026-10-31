import { useEffect, useState } from "react";
import { ArrowLeft, BadgeCheck, Mail, MessageCircleMore } from "lucide-react";
import { Link } from "react-router-dom";
import { useLanguage } from "../../hooks/useLanguage";
import { useSiteSettings } from "../../hooks/useSiteSettings";
import { studentService } from "../../services/studentService";
import type { AgencyRequest } from "../../types";
import { getErrorMessage } from "../../utils/errors";

export const StudentBecomeAgentPage = () => {
  const { language } = useLanguage();
  const siteSettings = useSiteSettings();
  const isArabic = language === "ar";
  const [agencyRequest, setAgencyRequest] = useState<AgencyRequest | null>(null);
  const [requestLoading, setRequestLoading] = useState(false);
  const [requestError, setRequestError] = useState("");
  const [requestMessage, setRequestMessage] = useState("");

  const steps = isArabic
    ? [
        "حدّث ملفك الشخصي وبياناتك الأكاديمية داخل لوحة الطالب.",
        "تواصل مع فريق Study Birds لطلب التحول إلى وكيل.",
        "بعد المراجعة، يتم توجيهك للخطوات التالية للانضمام كوكيل.",
      ]
    : [
        "Update your profile and academic details from your dashboard.",
        "Contact the Study Birds team to request becoming an agent.",
        "After review, you will be guided through the next onboarding steps.",
      ];

  useEffect(() => {
    studentService
      .getAgencyRequest()
      .then(setAgencyRequest)
      .catch(() => undefined);
  }, []);

  const handleAgencyRequest = async () => {
    setRequestLoading(true);
    setRequestError("");
    setRequestMessage("");

    try {
      const createdRequest = await studentService.createAgencyRequest();
      setAgencyRequest(createdRequest);
      setRequestMessage(isArabic ? "تم إرسال طلب الوكالة بنجاح." : "Agency request submitted successfully.");
    } catch (error) {
      setRequestError(getErrorMessage(error, isArabic ? "تعذر إرسال طلب الوكالة." : "Unable to submit agency request."));
    } finally {
      setRequestLoading(false);
    }
  };

  const statusLabel =
    agencyRequest?.status === "approved"
      ? isArabic
        ? "تم قبول طلبك وأصبح بإمكانك العمل كوكيل."
        : "Your request was approved and you can now work as an agent."
      : agencyRequest?.status === "rejected"
        ? isArabic
          ? "تم رفض طلبك حاليًا."
          : "Your request was rejected for now."
        : agencyRequest?.status === "pending"
          ? isArabic
            ? "طلبك قيد المراجعة الآن."
            : "Your request is currently under review."
          : "";

  return (
    <div className="space-y-6">
      <section className="panel p-8">
        <div className="max-w-3xl">
          <p className="text-sm font-semibold uppercase tracking-[0.3em] text-brand-700">
            {isArabic ? "قسم جديد في لوحة الطالب" : "New dashboard section"}
          </p>
          <h1 className="mt-3 text-3xl font-semibold text-slate-900">{isArabic ? "كن وكيلاً" : "Become an Agent"}</h1>
          <p className="mt-4 text-base leading-7 text-slate-600">
            {isArabic
              ? "إذا رغبت في أن تصبح وكيلاً مع Study Birds، ابدأ من هنا. هذا القسم يوضح لك الطريقة الأسرع لبدء الطلب والتواصل مع الفريق."
              : "If you want to become an agent with Study Birds, start here. This section gives you the fastest way to begin and contact the team."}
          </p>

          {statusLabel ? (
            <div className="mt-6 rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm font-medium text-slate-700">
              {statusLabel}
            </div>
          ) : null}
          {requestMessage ? <div className="mt-4 rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{requestMessage}</div> : null}
          {requestError ? <div className="mt-4 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{requestError}</div> : null}

          <div className="mt-6 flex flex-wrap gap-3">
            <button
              type="button"
              onClick={handleAgencyRequest}
              disabled={requestLoading || agencyRequest?.status === "pending" || agencyRequest?.status === "approved"}
              className="inline-flex items-center gap-2 rounded-full bg-brand-900 px-6 py-3 font-semibold text-white disabled:cursor-not-allowed disabled:opacity-60"
            >
              {requestLoading
                ? isArabic
                  ? "جارٍ الإرسال..."
                  : "Submitting..."
                : agencyRequest?.status === "pending"
                  ? isArabic
                    ? "الطلب قيد المراجعة"
                    : "Request pending"
                  : agencyRequest?.status === "approved"
                    ? isArabic
                      ? "تم قبول الطلب"
                      : "Request approved"
                    : isArabic
                      ? "طلب وكالة"
                      : "Request agency"}
              <ArrowLeft className="h-4 w-4" />
            </button>
            <Link to="/become-agent" className="inline-flex items-center gap-2 rounded-full border border-slate-200 px-6 py-3 font-semibold text-slate-700">
              {isArabic ? "اعرف التفاصيل" : "View details"}
            </Link>
            {siteSettings.whatsappUrl ? (
              <a
                href={siteSettings.whatsappUrl}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-2 rounded-full border border-slate-200 px-6 py-3 font-semibold text-slate-700"
              >
                <MessageCircleMore className="h-4 w-4" />
                {isArabic ? "ابدأ عبر واتساب" : "Start on WhatsApp"}
              </a>
            ) : null}
            {siteSettings.contactEmail ? (
              <a
                href={`mailto:${siteSettings.contactEmail}`}
                className="inline-flex items-center gap-2 rounded-full border border-slate-200 px-6 py-3 font-semibold text-slate-700"
              >
                <Mail className="h-4 w-4" />
                {isArabic ? "إرسال بريد" : "Send email"}
              </a>
            ) : null}
          </div>
        </div>
      </section>

      <section className="grid gap-4">
        {steps.map((step, index) => (
          <article key={step} className="panel flex items-start gap-4 p-6">
            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-brand-50 text-sm font-bold text-brand-700">
              {index + 1}
            </div>
            <div>
              <div className="flex items-center gap-2">
                <BadgeCheck className="h-4 w-4 text-brand-700" />
                <h2 className="text-lg font-semibold text-slate-900">{isArabic ? `الخطوة ${index + 1}` : `Step ${index + 1}`}</h2>
              </div>
              <p className="mt-2 text-sm leading-7 text-slate-600">{step}</p>
            </div>
          </article>
        ))}
      </section>
    </div>
  );
};
