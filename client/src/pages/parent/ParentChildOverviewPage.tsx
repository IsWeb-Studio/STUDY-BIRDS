import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { ApplicationStatusBadge } from "../../components/ApplicationStatusBadge";
import { parentService } from "../../services/parentService";
import type { ParentChildOverview } from "../../types";
import { getErrorMessage } from "../../utils/errors";
import { formatDate } from "../../utils/format";
import { useLanguage } from "../../hooks/useLanguage";

export const ParentChildOverviewPage = () => {
  const { id } = useParams<{ id: string }>();
  const { language } = useLanguage();
  const isArabic = language === "ar";
  const [overview, setOverview] = useState<ParentChildOverview | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!id) return;
    parentService
      .getChildOverview(id)
      .then(setOverview)
      .catch((err) => setError(getErrorMessage(err, isArabic ? "تعذر تحميل بيانات هذا الطالب." : "Unable to load this student's data.")));
  }, [id, isArabic]);

  if (error) {
    return <div className="panel p-6 text-sm text-rose-700">{error}</div>;
  }

  if (!overview) {
    return <div className="panel p-6 text-sm text-slate-500">{isArabic ? "جارٍ التحميل..." : "Loading..."}</div>;
  }

  return (
    <div className="space-y-6">
      <section className="panel p-6">
        <h1 className="text-3xl font-semibold text-slate-900">{overview.student.name}</h1>
        <p className="mt-1 text-sm text-slate-500">{overview.student.email}</p>

        <div className="mt-5 flex flex-wrap gap-3">
          {overview.targetCountries?.length ? (
            <span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-600">
              {isArabic ? "الدول المستهدفة" : "Target countries"}: {overview.targetCountries.join(", ")}
            </span>
          ) : null}
          {overview.intake ? (
            <span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-600">
              {isArabic ? "الفصل الدراسي" : "Intake"}: {overview.intake}
            </span>
          ) : null}
          {overview.journeyStage ? (
            <span className="rounded-full bg-brand-100 px-3 py-1 text-xs font-semibold text-brand-700">
              {isArabic ? "مرحلة الرحلة" : "Journey stage"}: {overview.journeyStage}
            </span>
          ) : null}
        </div>
      </section>

      <section className="panel p-6">
        <h2 className="text-lg font-semibold text-slate-900">{isArabic ? "الطلبات" : "Applications"}</h2>
        <div className="mt-4 space-y-4">
          {overview.applications.length ? (
            overview.applications.map((application) => (
              <div key={application.id} className="rounded-3xl bg-slate-50 p-5">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div>
                    <p className="font-semibold text-slate-900">{application.program?.name || (isArabic ? "برنامج غير محدد" : "Unnamed program")}</p>
                    <p className="text-sm text-slate-500">{application.university?.name}</p>
                    <p className="mt-2 text-xs text-slate-500">
                      {isArabic ? "أُرسل في" : "Submitted"}: {formatDate(application.submittedAt)}
                    </p>
                  </div>
                  <ApplicationStatusBadge status={application.detailedStatus || application.status} />
                </div>
              </div>
            ))
          ) : (
            <p className="text-sm text-slate-500">{isArabic ? "لا توجد طلبات حتى الآن." : "No applications yet."}</p>
          )}
        </div>
      </section>

      <p className="text-center text-xs text-slate-400">
        {isArabic
          ? "هذه نسخة للقراءة فقط. للتواصل بخصوص أي تفاصيل، تواصل مع فريق Study Birds."
          : "This is a read-only view. Contact the Study Birds team for further details."}
      </p>
    </div>
  );
};
