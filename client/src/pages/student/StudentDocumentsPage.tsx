import { DocumentPicker } from "../../components/forms/DocumentPicker";
import { DocumentFileLink } from '../../components/DocumentFileLink';
import { StatusExplanation } from '../../components/StatusExplanation';
import { useEffect, useRef, useState } from "react";
import { FileUpload } from "../../components/forms/FileUpload";
import type { DocumentItem } from "../../types";
import { studentService } from "../../services/studentService";
import { EmptyState } from "../../components/EmptyState";
import { useLanguage } from "../../hooks/useLanguage";
import { dt } from "../../utils/dashboardTranslations";
import { getErrorMessage } from "../../utils/errors";


type PendingUpload = { kind: "version" | "translation"; document: DocumentItem };

export const StudentDocumentsPage = () => {
  const { t, language } = useLanguage();
  const isArabic = language === "ar";
  const [documents, setDocuments] = useState<DocumentItem[]>([]);
  const [formError, setFormError] = useState("");
  const [success, setSuccess] = useState("");
  const [busy, setBusy] = useState(false);
  const [openHistory, setOpenHistory] = useState<string | null>(null);
  const pending = useRef<PendingUpload | null>(null);
  const [sourcePickerOpen, setSourcePickerOpen] = useState(false);

  const load = () => studentService
    .getDocuments()
    .then(setDocuments)
    .catch((error) => setFormError(getErrorMessage(error, t("noDocumentsDescription"))));
  useEffect(() => { void load(); }, [t]);

  const handleUpload = async (file: File, type: string) => {
    setFormError(""); setSuccess("");
    try {
      await studentService.uploadDocument(file, type);
      await load();
    } catch (error) {
      setFormError(getErrorMessage(error, dt(language, "profileSaveFailed")));
    }
  };

  // New version or certified translation of an existing document (PRD 29).
  const choose = (kind: PendingUpload["kind"], document: DocumentItem) => {
    pending.current = { kind, document };
    setSourcePickerOpen(true);
  };
  const onPicked = async (file: File | undefined) => {
    const target = pending.current;
    setSourcePickerOpen(false);
    if (!file || !target) return;
    setBusy(true); setFormError(""); setSuccess("");
    try {
      await studentService.uploadDocument(file, "", target.kind === "version" ? { replaces: target.document._id } : { translationOf: target.document._id });
      setSuccess(target.kind === "version"
        ? (isArabic ? "رُفعت النسخة الجديدة، وحُفظت السابقة في سجل النسخ." : "New version uploaded; the previous one is kept in the history.")
        : (isArabic ? "رُفعت الترجمة وستُراجع مع المستند." : "Translation uploaded and will be reviewed."));
      await load();
    } catch (error) {
      setFormError(getErrorMessage(error, isArabic ? "تعذر رفع الملف." : "Unable to upload the file."));
    } finally {
      setBusy(false);
    }
  };

  const documentTypeLabels: Record<string, string> = {
    passport: isArabic ? "صورة جواز السفر" : "Passport Copy",
    "biometric-photo": dt(language, "biometricPhoto"),
    "latest-qualification": isArabic ? "الشهادة الثانوية أو الجامعية" : "High School / University Certificate",
    transcript: dt(language, "transcriptDocument"),
    "english-test": dt(language, "englishTestDocument"),
    resume: dt(language, "resumeDocument"),
    "personal-photos": isArabic ? "صور شخصية" : "Personal Photos",
    "language-certificates": isArabic ? "شهادات اللغة" : "Language Certificates",
    "other-documents": isArabic ? "مستندات أخرى" : "Other Documents",
    "birth-certificate": isArabic ? "شهادة الميلاد" : "Birth certificate",
    "high-school-certificate": isArabic ? "شهادة الثانوية" : "High school certificate",
    "university-degree": isArabic ? "الشهادة الجامعية" : "University degree",
    "recommendation-letter": isArabic ? "خطاب توصية" : "Recommendation letter",
    "personal-statement": isArabic ? "خطاب الدافع" : "Personal statement",
    translation: isArabic ? "ترجمة معتمدة" : "Certified translation",
  };
  const translationLabels: Record<string, [string, string]> = {
    required: ["مطلوبة — ارفع ترجمة معتمدة", "Required — upload a certified translation"],
    uploaded: ["مرفوعة وقيد المراجعة", "Uploaded, under review"],
    approved: ["معتمدة", "Approved"],
    "needs-attention": ["تحتاج تصحيحًا", "Needs attention"],
    "not-required": ["غير مطلوبة", "Not required"],
  };
  const statusLabels: Record<string, string> = {
    pending: dt(language, "uploadedStatusPending"),
    verified: dt(language, "uploadedStatusVerified"),
    rejected: dt(language, "uploadedStatusRejected"),
  };
  const date = (value?: string) => (value ? new Date(value).toLocaleDateString(isArabic ? "ar" : "en") : "—");
  // Current files only; older versions and translations appear inside their document.
  const current = documents.filter((document) => document.isLatest !== false && !document.translationOf);

  return (
    <div className="space-y-6">
      <FileUpload onUpload={handleUpload} />
      {sourcePickerOpen && <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
        <section role="dialog" aria-modal="true" aria-label={isArabic ? "اختيار مصدر المستند" : "Choose document source"} className="w-full max-w-lg space-y-4 rounded-2xl bg-white p-5">
          <h2 className="font-semibold">{isArabic ? "اختيار مصدر المستند" : "Choose document source"}</h2>
          <DocumentPicker disabled={busy} onSelect={file => void onPicked(file)} />
          <button type="button" onClick={() => setSourcePickerOpen(false)} className="min-h-11 px-4 text-sm">{isArabic ? "إلغاء" : "Cancel"}</button>
        </section>
      </div>}
      {formError ? <div role="alert" className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{formError}</div> : null}
      {success ? <div role="status" className="rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-800">{success}</div> : null}
      {current.length ? (
        <div className="panel p-6">
          <h2 className="text-2xl font-semibold">{dt(language, "uploadedFiles")}</h2>
          <p className="mt-2 text-sm text-slate-500">{dt(language, "uploadHistoryHelp")}</p>
          <div className="mt-6 space-y-4">
            {current.map((document) => {
              const translation = document.translation;
              const needsTranslation = translation && ["required", "needs-attention"].includes(translation.status);
              return (
                <div key={document._id} className="rounded-3xl bg-slate-50 p-5">
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div className="min-w-0 flex-1">
                      <p className="break-words font-semibold">{documentTypeLabels[document.type] || document.type}</p>
                      <p className="text-sm text-slate-500 break-words">{document.fileName}</p>
                    </div>
                    <span className={`rounded-full px-3 py-1 text-xs font-semibold ${document.status === "verified" ? "bg-emerald-100 text-emerald-700" : document.status === "rejected" ? "bg-rose-100 text-rose-700" : "bg-amber-100 text-amber-700"}`}>
                      {document.statusInfo ? (isArabic ? document.statusInfo.ar.label : document.statusInfo.en.label) : statusLabels[document.status] || document.status}
                    </span>
                  </div>

                  {/* Details (PRD 29): dates, reviewer, validity, translation. */}
                  <dl className="mt-3 grid gap-2 text-sm sm:grid-cols-2">
                    <div><dt className="inline text-slate-500">{isArabic ? "تاريخ الرفع: " : "Uploaded: "}</dt><dd className="inline">{date(document.createdAt)}</dd></div>
                    <div><dt className="inline text-slate-500">{isArabic ? "المراجِع: " : "Reviewer: "}</dt><dd className="inline">{document.reviewedBy?.name || (isArabic ? "لم يُراجع بعد" : "Not reviewed yet")}</dd></div>
                    <div><dt className="inline text-slate-500">{isArabic ? "صالح حتى: " : "Valid until: "}</dt><dd className="inline">{document.expiresAt ? date(document.expiresAt) : (isArabic ? "غير محدد" : "Not set")}</dd></div>
                    {translation ? <div><dt className="inline text-slate-500">{isArabic ? "الترجمة: " : "Translation: "}</dt><dd className="inline">{translationLabels[translation.status]?.[isArabic ? 0 : 1]}</dd></div> : null}
                  </dl>

                  {document.statusInfo
                    ? <div className="mt-3"><StatusExplanation info={document.statusInfo} /></div>
                    : document.reviewNote ? <p className="mt-3 rounded-2xl bg-white px-4 py-3 text-sm text-slate-600">{document.reviewNote}</p> : null}

                  <div className="mt-3 flex flex-wrap gap-3 text-sm">
                    <DocumentFileLink className="inline-flex font-semibold text-brand-700" path={document.filePath}>
                      {isArabic ? "معاينة الملف" : "Preview file"}
                    </DocumentFileLink>
                    <button type="button" disabled={busy} className="font-semibold text-slate-700 underline disabled:opacity-50" onClick={() => choose("version", document)}>
                      {isArabic ? "رفع نسخة جديدة" : "Upload a new version"}
                    </button>
                    {needsTranslation || translation?.status === "not-required" ? (
                      <button type="button" disabled={busy} className={`font-semibold underline disabled:opacity-50 ${needsTranslation ? "text-amber-800" : "text-slate-700"}`} onClick={() => choose("translation", document)}>
                        {isArabic ? "رفع ترجمة معتمدة" : "Upload certified translation"}
                      </button>
                    ) : null}
                    {document.versions?.length ? (
                      <button type="button" className="font-semibold text-slate-700 underline" onClick={() => setOpenHistory(openHistory === document._id ? null : document._id)}>
                        {isArabic ? `سجل النسخ (${document.versions.length})` : `Version history (${document.versions.length})`}
                      </button>
                    ) : null}
                  </div>

                  {openHistory === document._id && document.versions?.length ? (
                    <ul className="mt-3 space-y-2 rounded-2xl bg-white p-3 text-sm">
                      {document.versions.map((version) => (
                        <li key={version._id} className="flex flex-wrap items-center justify-between gap-2">
                          <span>{version.fileName} · {date(version.createdAt)} · {isArabic ? version.statusInfo.ar.label : version.statusInfo.en.label}</span>
                          <DocumentFileLink className="font-semibold text-brand-700" path={version.filePath}>{isArabic ? "عرض" : "View"}</DocumentFileLink>
                        </li>
                      ))}
                    </ul>
                  ) : null}
                </div>
              );
            })}
          </div>
        </div>
      ) : (
        <EmptyState title={t("noDocuments")} description={dt(language, "noDocumentsYet")} />
      )}
    </div>
  );
};
