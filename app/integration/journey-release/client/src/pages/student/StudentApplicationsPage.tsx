import { DocumentFileLink } from '../../components/DocumentFileLink';
import { StudentPostAdmission } from '../../components/StudentPostAdmission';
import { ApplicationDocumentUpdates } from '../../components/ApplicationDocumentUpdates';
import { useEffect, useState } from "react";
import { ApplicationStatusBadge } from "../../components/ApplicationStatusBadge";
import { EmptyState } from "../../components/EmptyState";
import { useLanguage } from "../../hooks/useLanguage";
import { studentService } from "../../services/studentService";
import type { Application } from "../../types";
import { dt } from "../../utils/dashboardTranslations";
import { getErrorMessage } from "../../utils/errors";
import { formatDate } from "../../utils/format";

export const StudentApplicationsPage = () => {
  const { t, language } = useLanguage();
  const [applications, setApplications] = useState<Application[]>([]);
  const [formError, setFormError] = useState("");
  const [editingId, setEditingId] = useState<string>();

  useEffect(() => {
    studentService.getApplications().then(setApplications).catch((error) => setFormError(getErrorMessage(error, dt(language, "applicationFailed"))));
  }, [language]);

  const documentTypeLabels: Record<string, string> = {
    passport: dt(language, "passportFile"),
    "biometric-photo": dt(language, "biometricPhoto"),
    "latest-qualification": dt(language, "latestQualification"),
    transcript: dt(language, "transcriptDocument"),
    "english-test": dt(language, "englishTestDocument"),
    resume: dt(language, "resumeDocument"),
  };

  return (
    <div className="panel p-6">
      <h1 className="text-3xl font-semibold text-slate-900">{t("myApplications")}</h1>
      {formError ? <div className="mt-5 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{formError}</div> : null}

      <div className="mt-6 space-y-4">
        {applications.length ? (
          applications.map((application) => {
            const timeline = [...(application.statusTimeline || [])].reverse();

            return (
              <div key={application._id} className="rounded-3xl bg-slate-50 p-5">
                <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
                  <div>
                    <p className="font-semibold text-slate-900">{application.program?.title}</p>
                    <p className="text-sm text-slate-500">{application.program?.university?.name}</p>
                    <p className="mt-2 text-xs text-slate-500">
                      {dt(language, "submitted")}: {formatDate(application.submittedAt || application.createdAt)}
                    </p>
                  </div>
                  <ApplicationStatusBadge status={application.status} />
                </div>

                {application.notes ? (
                  <div className="mt-4 rounded-2xl bg-white px-4 py-3 text-sm text-slate-600">
                    <span className="font-semibold text-slate-800">{dt(language, "studentNotesLabel")}:</span> {application.notes}
                  </div>
                ) : null}

                <div className="mt-4 grid gap-4 lg:grid-cols-2">
                  <div className="rounded-2xl bg-white p-4">
                    <h2 className="text-sm font-semibold uppercase tracking-[0.2em] text-slate-500">{dt(language, "applicantProfile")}</h2>
                    <div className="mt-4 space-y-2 text-sm text-slate-600">
                      <p><span className="font-semibold text-slate-800">{t("currentEducation")}:</span> {application.applicantProfile?.currentEducation || dt(language, "notAvailable")}</p>
                      <p><span className="font-semibold text-slate-800">{t("gpa")}:</span> {application.applicantProfile?.gpa || dt(language, "notAvailable")}</p>
                      <p><span className="font-semibold text-slate-800">{t("preferredIntake")}:</span> {application.applicantProfile?.intake || dt(language, "notAvailable")}</p>
                      <p><span className="font-semibold text-slate-800">{dt(language, "englishExam")}:</span> {application.applicantProfile?.englishTest?.exam || dt(language, "notAvailable")}</p>
                      <p><span className="font-semibold text-slate-800">{dt(language, "englishScore")}:</span> {application.applicantProfile?.englishTest?.score || dt(language, "notAvailable")}</p>
                    </div>
                  </div>

                  <div className="rounded-2xl bg-white p-4">
                    <h2 className="text-sm font-semibold uppercase tracking-[0.2em] text-slate-500">{dt(language, "documentsShared")}</h2>
                    <div className="mt-4 space-y-3">
                      {application.documents?.length ? (
                        application.documents.map((document) => (
                          <div key={document._id} className="flex items-center justify-between gap-3 rounded-2xl bg-slate-50 px-4 py-3 text-sm">
                            <div>
                              <p className="font-medium text-slate-900">{documentTypeLabels[document.type] || document.type}</p>
                              <p className="text-xs text-slate-500">{document.fileName}</p>
                            </div>
                            <DocumentFileLink className="font-semibold text-brand-700" path={document.filePath}>
                              {dt(language, "viewFile")}
                            </DocumentFileLink>
                          </div>
                        ))
                      ) : (
                        <p className="text-sm text-slate-500">{dt(language, "notAvailable")}</p>
                      )}
                    </div>
                  </div>
                </div>

                <StudentPostAdmission applicationId={application._id} />
                <div className="mt-4 rounded-2xl bg-white p-4">
                  <button onClick={() => setEditingId(editingId === application._id ? undefined : application._id)} aria-expanded={editingId === application._id} className="min-h-11 font-semibold">{language === 'ar' ? 'استكمال مستندات الطلب' : 'Update application documents'}</button>
                  {editingId === application._id && <ApplicationDocumentUpdates applicationId={application._id} onUpdated={() => { studentService.getApplications().then(setApplications).catch(() => setFormError(language === 'ar' ? 'تم الإرفاق؛ تعذر تحديث القائمة.' : 'Attached; unable to refresh the list.')); }} />}
                </div>

                <div className="mt-4 rounded-2xl bg-white p-4">
                  <h2 className="text-sm font-semibold uppercase tracking-[0.2em] text-slate-500">{dt(language, "statusTimelineLabel")}</h2>
                  <div className="mt-4 space-y-3">
                    {timeline.length ? (
                      timeline.map((item, index) => (
                        <div key={`${application._id}-${item.status}-${item.changedAt || index}`} className="rounded-2xl bg-slate-50 px-4 py-3 text-sm">
                          <div className="flex flex-wrap items-center justify-between gap-3">
                            <ApplicationStatusBadge status={item.status} />
                            <span className="text-xs text-slate-500">{formatDate(item.changedAt)}</span>
                          </div>
                          {item.note ? <p className="mt-3 text-slate-600">{item.note}</p> : null}
                        </div>
                      ))
                    ) : (
                      <p className="text-sm text-slate-500">{dt(language, "noStatusTimeline")}</p>
                    )}
                  </div>
                </div>
              </div>
            );
          })
        ) : (
          <EmptyState title={t("myApplications")} description={dt(language, "noApplicationsYet")} />
        )}
      </div>
    </div>
  );
};
