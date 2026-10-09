import { useEffect, useState } from "react";
import { Calendar, CheckCircle2, Circle, Clock, RefreshCw } from "lucide-react";
import { Link } from "react-router-dom";
import { EmptyState } from "../../components/EmptyState";
import { useLanguage } from "../../hooks/useLanguage";
import { studentService } from "../../services/studentService";
import type { StudentDashboardOverview } from "../../types";
import { getErrorMessage } from "../../utils/errors";

type Stage = StudentDashboardOverview["progress"]["stages"][number];

function StageIcon({ status }: { status: Stage["status"] }) {
  if (status === "completed") return <CheckCircle2 className="h-6 w-6 text-emerald-500" />;
  if (status === "current") return <Clock className="h-6 w-6 text-orange-500 animate-pulse" />;
  return <Circle className="h-6 w-6 text-slate-300" />;
}

export const StudentJourneyPage = () => {
  const { language } = useLanguage();
  const ar = language === "ar";
  const t = (a: string, b: string) => (ar ? a : b);

  const [overview, setOverview] = useState<StudentDashboardOverview | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  async function load() {
    setLoading(true);
    setError("");
    try {
      const data = await studentService.getOverview();
      setOverview(data);
    } catch (e) {
      setError(getErrorMessage(e, t("تعذر تحميل رحلتك", "Unable to load your journey")));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { void load(); }, []);

  if (loading) {
    return (
      <div className="space-y-4">
        {Array.from({ length: 6 }).map((_, i) => (
          <div key={i} className="panel flex animate-pulse items-start gap-4 p-5">
            <div className="mt-1 h-6 w-6 rounded-full bg-slate-200" />
            <div className="flex-1 space-y-2">
              <div className="h-4 w-40 rounded bg-slate-200" />
              <div className="h-3 w-64 rounded bg-slate-100" />
            </div>
          </div>
        ))}
      </div>
    );
  }

  if (error) return (
    <div className="space-y-4">
      <EmptyState title={t("تعذر التحميل", "Unable to load")} description={error} />
      <div className="flex justify-center"><button onClick={load} className="btn-primary text-sm">{t("إعادة المحاولة", "Retry")}</button></div>
    </div>
  );

  const stages = overview?.progress?.stages ?? [];
  const currentIndex = stages.findIndex((s) => s.status === "current");
  const completedCount = stages.filter((s) => s.status === "completed").length;
  const totalCount = stages.length;
  const progressPct = totalCount > 0 ? Math.round((completedCount / totalCount) * 100) : 0;

  return (
    <div className="space-y-6" dir={ar ? "rtl" : "ltr"}>
      {/* Header */}
      <div className="panel dashboard-page-hero overflow-hidden p-6 sm:p-8">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-slate-900 sm:text-3xl">
              {t("رحلتي الدراسية", "My Study Journey")}
            </h1>
            <p className="mt-1 text-sm text-slate-500">
              {t("تتبع تقدمك في كل مرحلة من مراحل القبول حتى الوصول", "Track your progress through each admission stage until arrival")}
            </p>
          </div>
          <button onClick={load} className="inline-flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50">
            <RefreshCw className="h-4 w-4" />
            {t("تحديث", "Refresh")}
          </button>
        </div>

        {/* Progress bar */}
        {totalCount > 0 && (
          <div className="mt-6">
            <div className="mb-2 flex items-center justify-between text-sm">
              <span className="font-semibold text-slate-700">
                {t(`${completedCount} من ${totalCount} مرحلة مكتملة`, `${completedCount} of ${totalCount} stages complete`)}
              </span>
              <span className="text-slate-500">{progressPct}%</span>
            </div>
            <div className="h-2.5 w-full overflow-hidden rounded-full bg-slate-100">
              <div
                className="h-full rounded-full bg-gradient-to-r from-emerald-500 to-teal-400 transition-all duration-500"
                style={{ width: `${progressPct}%` }}
              />
            </div>
          </div>
        )}
      </div>

      {/* Quick links */}
      <div className="grid gap-3 sm:grid-cols-3">
        <Link to="/student/arrival-services" className="panel flex items-center gap-3 p-4 hover:bg-slate-50 transition-colors">
          <Calendar className="h-5 w-5 text-blue-500 shrink-0" />
          <div>
            <p className="text-sm font-semibold text-slate-800">{t("خدمات الوصول", "Arrival Services")}</p>
            <p className="text-xs text-slate-500">{t("تفاصيل السفر والاستقبال", "Travel & pickup details")}</p>
          </div>
        </Link>
        <Link to="/student/visa" className="panel flex items-center gap-3 p-4 hover:bg-slate-50 transition-colors">
          <CheckCircle2 className="h-5 w-5 text-emerald-500 shrink-0" />
          <div>
            <p className="text-sm font-semibold text-slate-800">{t("مركز التأشيرة", "Visa Center")}</p>
            <p className="text-xs text-slate-500">{t("متطلبات التأشيرة والتأمين", "Visa requirements & insurance")}</p>
          </div>
        </Link>
        <Link to="/student/documents" className="panel flex items-center gap-3 p-4 hover:bg-slate-50 transition-colors">
          <Clock className="h-5 w-5 text-orange-500 shrink-0" />
          <div>
            <p className="text-sm font-semibold text-slate-800">{t("مستنداتي", "My Documents")}</p>
            <p className="text-xs text-slate-500">{t("رفع ومتابعة المستندات", "Upload & track documents")}</p>
          </div>
        </Link>
      </div>

      {/* Timeline */}
      {stages.length === 0 ? (
        <EmptyState
          title={t("لا توجد مراحل بعد", "No stages yet")}
          description={t("ستظهر مراحل رحلتك هنا بعد بدء معالجة ملفك.", "Your journey stages will appear here once your file processing begins.")}
        />
      ) : (
        <div className="panel p-6">
          <h2 className="mb-6 text-base font-semibold text-slate-800">
            {t("مراحل الرحلة", "Journey Stages")}
          </h2>
          <ol className="relative space-y-0">
            {stages.map((stage, i) => {
              const isLast = i === stages.length - 1;
              const isCurrent = stage.status === "current";
              const isDone = stage.status === "completed";

              return (
                <li key={stage.key} className="relative flex gap-4 pb-8 last:pb-0">
                  {/* Vertical line */}
                  {!isLast && (
                    <div
                      className={`absolute top-7 ${ar ? "right-[11px]" : "left-[11px]"} bottom-0 w-0.5 ${isDone ? "bg-emerald-300" : "bg-slate-200"}`}
                    />
                  )}

                  {/* Icon */}
                  <div className="relative z-10 shrink-0 mt-0.5">
                    <StageIcon status={stage.status} />
                  </div>

                  {/* Content */}
                  <div className={`flex-1 rounded-xl border p-4 ${isCurrent ? "border-orange-200 bg-orange-50" : isDone ? "border-emerald-100 bg-emerald-50/50" : "border-slate-100 bg-white"}`}>
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <p className={`text-sm font-semibold ${isCurrent ? "text-orange-700" : isDone ? "text-emerald-700" : "text-slate-500"}`}>
                        {ar ? stage.titleAr : stage.titleEn}
                      </p>
                      <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold ${isCurrent ? "bg-orange-100 text-orange-700" : isDone ? "bg-emerald-100 text-emerald-700" : "bg-slate-100 text-slate-500"}`}>
                        {isCurrent ? t("جارية الآن", "In progress") : isDone ? t("مكتملة", "Completed") : t("قادمة", "Upcoming")}
                      </span>
                    </div>
                    {(ar ? stage.descriptionAr : stage.descriptionEn) && (
                      <p className={`mt-1 text-xs ${isCurrent ? "text-orange-600" : isDone ? "text-emerald-600" : "text-slate-400"}`}>
                        {ar ? stage.descriptionAr : stage.descriptionEn}
                      </p>
                    )}
                  </div>
                </li>
              );
            })}
          </ol>
        </div>
      )}

      {/* Active stage highlight */}
      {currentIndex >= 0 && stages[currentIndex] && (
        <div className="panel border-l-4 border-orange-400 bg-orange-50 p-5">
          <p className="text-xs font-semibold uppercase tracking-wide text-orange-600">{t("المرحلة الحالية", "Current Stage")}</p>
          <p className="mt-1 text-lg font-bold text-orange-800">
            {ar ? stages[currentIndex].titleAr : stages[currentIndex].titleEn}
          </p>
          {(ar ? stages[currentIndex].descriptionAr : stages[currentIndex].descriptionEn) && (
            <p className="mt-1 text-sm text-orange-700">
              {ar ? stages[currentIndex].descriptionAr : stages[currentIndex].descriptionEn}
            </p>
          )}
        </div>
      )}
    </div>
  );
};
