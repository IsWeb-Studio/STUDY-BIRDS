import { useEffect, useState } from "react";
import { ArrowLeft, BadgeCheck, BriefcaseBusiness, Mail, MessageCircleMore } from "lucide-react";
import { Link } from "react-router-dom";
import { Seo } from "../components/seo/Seo";
import { useAuth } from "../hooks/useAuth";
import { useLanguage } from "../hooks/useLanguage";
import { useSiteSettings } from "../hooks/useSiteSettings";
import { studentService } from "../services/studentService";
import { SITE_NAME, seoText } from "../seo/site";
import type { AgencyRequest } from "../types";
import { getErrorMessage } from "../utils/errors";

export const BecomeAgentPage = () => {
  const { language } = useLanguage();
  const { user } = useAuth();
  const siteSettings = useSiteSettings();
  const [agencyRequest, setAgencyRequest] = useState<AgencyRequest | null>(null);
  const [requestLoading, setRequestLoading] = useState(false);
  const [requestError, setRequestError] = useState("");
  const [requestMessage, setRequestMessage] = useState("");

  const isArabic = language === "ar";

  const benefits = isArabic
    ? [
        "وسّع دورك من طالب إلى وكيل يساعد طلابًا آخرين في رحلتهم الدراسية.",
        "استفد من منصة منظمة لمتابعة البرامج والجامعات والتواصل بشكل أوضح.",
        "ابدأ طلب الانضمام كوكيل مباشرة عبر فريق Study Birds.",
      ]
    : [
        "Grow from student to agent and support other students in their study journey.",
        "Use an organized platform to follow programs, universities, and communication more clearly.",
        "Start your onboarding request directly with the Study Birds team.",
      ];

  useEffect(() => {
    if (user?.role !== "student") {
      return;
    }

    studentService
      .getAgencyRequest()
      .then(setAgencyRequest)
      .catch(() => undefined);
  }, [user?.role]);

  const statusLabel =
    agencyRequest?.status === "approved"
      ? isArabic
        ? "تم قبول طلبك"
        : "Your request was approved"
      : agencyRequest?.status === "rejected"
        ? isArabic
          ? "تم رفض الطلب"
          : "Your request was rejected"
        : agencyRequest?.status === "pending"
          ? isArabic
            ? "طلبك قيد المراجعة"
            : "Your request is pending"
          : "";

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

  return (
    <div className="space-y-8">
      <Seo
        title={seoText(language, `Become an Agent | ${SITE_NAME}`, `كن وكيلاً | ${SITE_NAME}`)}
        description={seoText(
          language,
          `Learn how students can become agents with ${SITE_NAME} and start the onboarding process.`,
          `تعرّف على طريقة التحول من طالب إلى وكيل مع ${SITE_NAME} وابدأ خطوات الانضمام.`
        )}
      />

      <section className="panel overflow-hidden p-8 sm:p-10">
        <div className="max-w-3xl">
          <div className="inline-flex items-center gap-2 rounded-full bg-brand-50 px-4 py-2 text-sm font-semibold text-brand-700">
            <BriefcaseBusiness className="h-4 w-4" />
            {isArabic ? "فرصة جديدة داخل Study Birds" : "A new role inside Study Birds"}
          </div>
          <h1 className="mt-5 text-4xl font-semibold text-slate-900 sm:text-5xl">
            {isArabic ? "كن وكيلاً مع Study Birds" : `Become an Agent with ${SITE_NAME}`}
          </h1>
          <p className="mt-5 text-lg leading-8 text-slate-600">
            {isArabic
              ? "إذا كنت طالبًا وتريد تطوير دورك، يمكنك بدء طريقك كوكيل ومساعدة طلاب آخرين في الوصول إلى البرامج والجامعات المناسبة لهم."
              : "If you are a student and want to grow your role, you can start your path as an agent and support other students in finding the right programs and universities."}
          </p>

          {statusLabel ? (
            <div className="mt-6 rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm font-medium text-slate-700">
              {statusLabel}
            </div>
          ) : null}
          {requestMessage ? <div className="mt-4 rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{requestMessage}</div> : null}
          {requestError ? <div className="mt-4 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{requestError}</div> : null}

          <div className="mt-8 flex flex-wrap gap-3">
            {!user ? (
              <Link to="/login" className="inline-flex items-center gap-2 rounded-full bg-brand-900 px-6 py-3 font-semibold text-white">
                {isArabic ? "سجل الدخول لتقديم الطلب" : "Sign in to request"}
                <ArrowLeft className="h-4 w-4" />
              </Link>
            ) : user.role === "student" ? (
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
            ) : (
              <Link to="/partner/dashboard" className="inline-flex items-center gap-2 rounded-full bg-brand-900 px-6 py-3 font-semibold text-white">
                {isArabic ? "افتح لوحة الوكيل" : "Open partner profile"}
                <ArrowLeft className="h-4 w-4" />
              </Link>
            )}
            {siteSettings.whatsappUrl ? (
              <a
                href={siteSettings.whatsappUrl}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-2 rounded-full border border-slate-200 px-6 py-3 font-semibold text-slate-700"
              >
                <MessageCircleMore className="h-4 w-4" />
                {isArabic ? "تواصل عبر واتساب" : "Contact on WhatsApp"}
              </a>
            ) : null}
            {siteSettings.contactEmail ? (
              <a
                href={`mailto:${siteSettings.contactEmail}`}
                className="inline-flex items-center gap-2 rounded-full border border-slate-200 px-6 py-3 font-semibold text-slate-700"
              >
                <Mail className="h-4 w-4" />
                {isArabic ? "راسلنا بالبريد" : "Email us"}
              </a>
            ) : null}
          </div>
        </div>
      </section>

      <section className="grid gap-4 md:grid-cols-3">
        {benefits.map((benefit) => (
          <article key={benefit} className="panel p-6">
            <BadgeCheck className="h-8 w-8 text-brand-700" />
            <p className="mt-4 text-base leading-7 text-slate-700">{benefit}</p>
          </article>
        ))}
      </section>
    </div>
  );
};
