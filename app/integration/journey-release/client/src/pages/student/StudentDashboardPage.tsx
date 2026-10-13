import { useEffect, useState } from "react";
import { Bell, CheckCircle2, CircleAlert, CreditCard, FileText, GraduationCap, Sparkles } from "lucide-react";
import { Link } from "react-router-dom";
import { ApplicationStatusBadge } from "../../components/ApplicationStatusBadge";
import { EmptyState } from "../../components/EmptyState";
import { useLanguage } from "../../hooks/useLanguage";
import { studentService } from "../../services/studentService";
import type { StudentDashboardOverview } from "../../types";
import { getErrorMessage } from "../../utils/errors";
import { formatDate } from "../../utils/format";

const stageLabels = (language: "ar" | "en", titleAr: string, titleEn: string) => (language === "ar" ? titleAr : titleEn);
const stageDescriptions = (language: "ar" | "en", descriptionAr: string, descriptionEn: string) => (language === "ar" ? descriptionAr : descriptionEn);

export const StudentDashboardPage = () => {
  const { language } = useLanguage();
  const isArabic = language === "ar";
  const [overview, setOverview] = useState<StudentDashboardOverview | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    studentService
      .getOverview()
      .then(setOverview)
      .catch((issue) => setError(getErrorMessage(issue, isArabic ? "تعذر تحميل لوحة الطالب." : "Unable to load the student dashboard.")));
  }, [isArabic]);

  if (error) {
    return <EmptyState title={isArabic ? "تعذر التحميل" : "Unable to load"} description={error} />;
  }

  if (!overview) {
    return <div className="panel flex min-h-[320px] items-center justify-center p-8 text-sm text-slate-500">{isArabic ? "جارٍ تحميل لوحة الطالب..." : "Loading student dashboard..."}</div>;
  }

  const stats = [
    {
      label: isArabic ? "الطلبات الحالية" : "Current Applications",
      value: overview.stats.currentApplications,
      icon: GraduationCap,
      tone: "from-sky-100 to-white text-sky-700",
    },
    {
      label: isArabic ? "المستندات المقبولة" : "Accepted Documents",
      value: overview.stats.acceptedDocuments,
      icon: CheckCircle2,
      tone: "from-emerald-100 to-white text-emerald-700",
    },
    {
      label: isArabic ? "مطلوب إعادة رفعها" : "Needs Re-upload",
      value: overview.stats.rejectedDocuments,
      icon: CircleAlert,
      tone: "from-amber-100 to-white text-amber-700",
    },
    {
      label: isArabic ? "المدفوعات المستحقة" : "Pending Payments",
      value: overview.stats.pendingPayments,
      icon: CreditCard,
      tone: "from-rose-100 to-white text-rose-700",
    },
    {
      label: isArabic ? "إشعارات غير مقروءة" : "Unread Notifications",
      value: overview.stats.unreadNotifications,
      icon: Bell,
      tone: "from-violet-100 to-white text-violet-700",
    },
  ];

  return (
    <div className="space-y-6">
      <section className="panel overflow-hidden p-0">
        <div className="bg-slate-950 px-6 py-7 text-white sm:px-8">
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div className="max-w-3xl">
              <div className="inline-flex items-center gap-2 rounded-full bg-white/10 px-3 py-1 text-xs font-semibold text-slate-200">
                <Sparkles className="h-3.5 w-3.5" />
                {isArabic ? "Student Dashboard" : "Student Dashboard"}
              </div>
              <h1 className="mt-4 text-3xl font-semibold sm:text-4xl">{isArabic ? `مرحباً ${overview.profile?.user?.name || ""}` : `Welcome ${overview.profile?.user?.name || ""}`}</h1>
              <p className="mt-3 max-w-2xl text-sm leading-7 text-slate-300">
                {isArabic
                  ? "مرحباً بك في لوحة تحكم Study Birds، تتبع حالة قبولك الجامعي، أدر مستنداتك، وابدأ رحلتك التعليمية معنا."
                  : "Welcome to the Study Birds dashboard. Track your university admission progress, manage documents, and continue your study journey with us."}
              </p>
            </div>
            <div className="min-w-[220px] rounded-3xl border border-white/10 bg-white/5 p-4">
              <p className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">{isArabic ? "آخر إشعار" : "Latest Notification"}</p>
              <p className="mt-3 font-semibold text-white">{overview.latestNotification?.title || (isArabic ? "لا يوجد إشعار جديد" : "No new notifications")}</p>
              <p className="mt-2 text-sm text-slate-300">{overview.latestNotification?.message || (isArabic ? "سيظهر آخر تحديث مهم هنا." : "The latest important update will appear here.")}</p>
            </div>
          </div>
        </div>
      </section>

      {overview.nextAction && (
        <section className="panel border border-orange-100 p-6" aria-label={isArabic ? "الخطوة التالية" : "Next action"}>
          <p className="text-sm text-slate-500">{overview.nextAction.waiting ? (isArabic ? "متابعة الفريق" : "Team follow-up") : (isArabic ? "الخطوة التالية" : "Next action")}</p>
          <h2 className="mt-2 text-xl font-semibold text-slate-900">{isArabic ? overview.nextAction.titleAr : overview.nextAction.titleEn}</h2>
          <p className="mt-2 text-sm leading-7 text-slate-600">{isArabic ? overview.nextAction.descriptionAr : overview.nextAction.descriptionEn}</p>
          {overview.nextAction.dueDate && <p className="mt-2 text-sm">{isArabic ? "الاستحقاق: " : "Due: "}{formatDate(overview.nextAction.dueDate)}</p>}
          <Link className="mt-4 inline-flex min-h-12 items-center rounded-xl bg-orange-500 px-5 font-semibold text-white" to={overview.nextAction.destination === 'journey' ? `/student/applications#journey-${overview.nextAction.entityId}` : ({ payments: "/student/financials", documents: "/student/documents", applications: "/student/applications", support: "/student/support", catalog: "/programs" } as Record<string, string>)[overview.nextAction.destination] || "/student/applications"}>
            {isArabic ? "عرض التفاصيل" : "View details"}
          </Link>
        </section>
      )}

      <section className="panel p-6">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h2 className="text-2xl font-semibold text-slate-900">{isArabic ? "مراحل الرحلة الدراسية" : "Admission Journey"}</h2>
            <p className="mt-2 text-sm text-slate-500">{isArabic ? "تابع مرحلتك الحالية بوضوح واعرف الخطوة التالية." : "Track your current stage clearly and see what comes next."}</p>
          </div>
          <span className="rounded-full bg-brand-50 px-4 py-2 text-sm font-semibold text-brand-700">
            {overview.progress.stages.find((stage) => stage.status === "current")
              ? stageLabels(language, overview.progress.stages.find((stage) => stage.status === "current")!.titleAr, overview.progress.stages.find((stage) => stage.status === "current")!.titleEn)
              : isArabic
                ? "قيد المتابعة"
                : "In progress"}
          </span>
        </div>
        <div className="mt-6 grid gap-4 xl:grid-cols-6">
          {overview.progress.stages.map((stage, index) => (
            <div
              key={stage.key}
              className={`rounded-3xl border p-4 ${stage.status === "current" ? "border-brand-300 bg-brand-50" : stage.status === "completed" ? "border-emerald-200 bg-emerald-50/70" : "border-slate-200 bg-slate-50"}`}
            >
              <div className="flex items-center justify-between gap-3">
                <span className={`flex h-9 w-9 items-center justify-center rounded-full text-sm font-semibold ${stage.status === "current" ? "bg-brand-700 text-white" : stage.status === "completed" ? "bg-emerald-600 text-white" : "bg-white text-slate-500"}`}>
                  {index + 1}
                </span>
                <span className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-400">
                  {stage.status === "completed" ? (isArabic ? "مكتمل" : "Completed") : stage.status === "current" ? (isArabic ? "حالي" : "Current") : isArabic ? "قادم" : "Upcoming"}
                </span>
              </div>
              <h3 className="mt-4 text-base font-semibold text-slate-900">{stageLabels(language, stage.titleAr, stage.titleEn)}</h3>
              <p className="mt-2 text-sm leading-6 text-slate-600">{stageDescriptions(language, stage.descriptionAr, stage.descriptionEn)}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="grid gap-4 sm:grid-cols-2 xl:grid-cols-5">
        {stats.map((item) => {
          const Icon = item.icon;
          return (
            <article key={item.label} className={`rounded-3xl border border-slate-200 bg-gradient-to-br ${item.tone} p-5 shadow-sm`}>
              <div className="flex items-center justify-between gap-3">
                <p className="text-sm font-semibold text-slate-700">{item.label}</p>
                <Icon className="h-5 w-5" />
              </div>
              <p className="mt-4 text-3xl font-semibold text-slate-900">{item.value}</p>
            </article>
          );
        })}
      </section>

      <div className="grid gap-6 xl:grid-cols-[1.15fr_0.85fr]">
        <section className="panel p-6">
          <div className="flex items-center justify-between gap-3">
            <div>
              <h2 className="text-2xl font-semibold text-slate-900">{isArabic ? "أحدث الطلبات" : "Recent Applications"}</h2>
              <p className="mt-2 text-sm text-slate-500">{isArabic ? "راجع حالة طلباتك وملاحظات القبول بسرعة." : "Review your application progress and admission notes quickly."}</p>
            </div>
            <Link to="/student/applications" className="text-sm font-semibold text-brand-700">
              {isArabic ? "عرض الكل" : "View all"}
            </Link>
          </div>
          <div className="mt-6 space-y-4">
            {overview.recentApplications.length ? (
              overview.recentApplications.map((application) => (
                <article key={application._id} className="rounded-3xl bg-slate-50 p-5">
                  <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
                    <div>
                      <p className="font-semibold text-slate-900">{application.program?.university?.name || (isArabic ? "جامعة غير محددة" : "Unknown university")}</p>
                      <p className="mt-1 text-sm text-slate-500">{application.program?.title || (isArabic ? "تخصص غير محدد" : "Unknown program")}</p>
                      <p className="mt-2 text-xs text-slate-500">{isArabic ? "آخر تحديث:" : "Updated:"} {formatDate(application.createdAt)}</p>
                    </div>
                    <ApplicationStatusBadge status={application.status} />
                  </div>
                  {application.notes ? <p className="mt-4 rounded-2xl bg-white px-4 py-3 text-sm text-slate-600">{application.notes}</p> : null}
                </article>
              ))
            ) : (
              <EmptyState title={isArabic ? "لا توجد طلبات بعد" : "No applications yet"} description={isArabic ? "عند بدء التقديم ستظهر طلباتك هنا." : "Your applications will appear here once you start applying."} />
            )}
          </div>
        </section>

        <section className="space-y-6">
          <div className="panel p-6">
            <div className="flex items-center justify-between gap-3">
              <div>
                <h2 className="text-2xl font-semibold text-slate-900">{isArabic ? "أحدث المستندات" : "Recent Documents"}</h2>
                <p className="mt-2 text-sm text-slate-500">{isArabic ? "تابع آخر الملفات التي رفعتها وحالتها الحالية." : "Keep an eye on your latest uploaded files and their status."}</p>
              </div>
              <Link to="/student/documents" className="text-sm font-semibold text-brand-700">
                {isArabic ? "المستندات" : "Documents"}
              </Link>
            </div>
            <div className="mt-6 space-y-3">
              {overview.recentDocuments.length ? (
                overview.recentDocuments.map((document) => (
                  <div key={document._id} className="rounded-2xl bg-slate-50 px-4 py-3">
                    <div className="flex flex-wrap items-center justify-between gap-3">
                      <div className="min-w-0 flex-1">
                        <p className="break-words font-semibold text-slate-900">{document.fileName}</p>
                        <p className="mt-1 text-xs text-slate-500">{formatDate(document.createdAt)}</p>
                      </div>
                      <span className={`rounded-full px-3 py-1 text-xs font-semibold ${document.status === "verified" ? "bg-emerald-100 text-emerald-700" : document.status === "rejected" ? "bg-rose-100 text-rose-700" : "bg-amber-100 text-amber-700"}`}>
                        {document.status}
                      </span>
                    </div>
                    {document.reviewNote ? <p className="mt-3 text-sm text-slate-600">{document.reviewNote}</p> : null}
                  </div>
                ))
              ) : (
                <div className="rounded-2xl bg-slate-50 px-4 py-6 text-sm text-slate-500">{isArabic ? "لم يتم رفع مستندات بعد." : "No documents uploaded yet."}</div>
              )}
            </div>
          </div>

          <div className="panel p-6">
            <h2 className="text-2xl font-semibold text-slate-900">{isArabic ? "اختصارات سريعة" : "Quick Actions"}</h2>
            <div className="mt-5 grid gap-3 sm:grid-cols-2">
              <Link to="/student/profile" className="rounded-2xl border border-slate-200 px-4 py-4 text-sm font-semibold text-slate-700 hover:bg-slate-50">
                {isArabic ? "تحديث الملف الشخصي" : "Update Profile"}
              </Link>
              <Link to="/student/documents" className="rounded-2xl border border-slate-200 px-4 py-4 text-sm font-semibold text-slate-700 hover:bg-slate-50">
                {isArabic ? "رفع مستند جديد" : "Upload Document"}
              </Link>
              <Link to="/student/support" className="rounded-2xl border border-slate-200 px-4 py-4 text-sm font-semibold text-slate-700 hover:bg-slate-50">
                {isArabic ? "طلب دعم" : "Open Support Ticket"}
              </Link>
              <Link to="/student/notifications" className="rounded-2xl border border-slate-200 px-4 py-4 text-sm font-semibold text-slate-700 hover:bg-slate-50">
                {isArabic ? "مركز الإشعارات" : "Notifications Center"}
              </Link>
            </div>
          </div>
        </section>
      </div>
    </div>
  );
};
