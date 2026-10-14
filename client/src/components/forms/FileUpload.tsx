import { DocumentPicker } from "./DocumentPicker";
import { useState, type FormEvent } from "react";
import { useLanguage } from "../../hooks/useLanguage";
import { DOCUMENT_UPLOAD_HINT_AR, DOCUMENT_UPLOAD_HINT_EN } from "../../constants/upload";
import { dt } from "../../utils/dashboardTranslations";

export const FileUpload = ({
  onUpload,
}: {
  onUpload: (file: File, type: string) => Promise<void>;
}) => {
  const { language, t } = useLanguage();
  const [type, setType] = useState("passport");
  const [file, setFile] = useState<File | null>(null);

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    if (!file) return;
    await onUpload(file, type);
    setFile(null);
  };

  return (
    <form onSubmit={handleSubmit} className="panel space-y-4 p-6">
      <select value={type} onChange={(event) => setType(event.target.value)} className="w-full rounded-2xl border border-slate-200 px-4 py-3">
        <option value="passport">{language === "ar" ? "صورة جواز السفر" : "Passport Copy"}</option>
        <option value="latest-qualification">{language === "ar" ? "الشهادة الثانوية أو الجامعية" : "High School / University Certificate"}</option>
        <option value="transcript">{language === "ar" ? "بيان الدرجات" : "Transcript"}</option>
        <option value="personal-photos">{language === "ar" ? "صور شخصية" : "Personal Photos"}</option>
        <option value="language-certificates">{language === "ar" ? "شهادات اللغة" : "Language Certificates"}</option>
        <option value="english-test">{dt(language, "englishTestDocument")}</option>
        <option value="resume">{dt(language, "resumeDocument")}</option>
        <option value="other-documents">{language === "ar" ? "مستندات أخرى" : "Other Documents"}</option>
        <option value="biometric-photo">{dt(language, "biometricPhoto")}</option>
        <option value="birth-certificate">{language === "ar" ? "شهادة الميلاد" : "Birth certificate"}</option>
        <option value="high-school-certificate">{language === "ar" ? "شهادة الثانوية" : "High school certificate"}</option>
        <option value="university-degree">{language === "ar" ? "الشهادة الجامعية" : "University degree"}</option>
        <option value="recommendation-letter">{language === "ar" ? "خطاب توصية" : "Recommendation letter"}</option>
        <option value="personal-statement">{language === "ar" ? "خطاب الدافع" : "Personal statement"}</option>
      </select>
      <DocumentPicker selectedName={file?.name || ""} onSelect={setFile} />
      <p className="text-xs text-slate-500">{language === "ar" ? DOCUMENT_UPLOAD_HINT_AR : DOCUMENT_UPLOAD_HINT_EN}</p>
      <button type="submit" disabled={!file} className="rounded-full bg-brand-900 px-5 py-3 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:bg-slate-300">
        {t("uploadDocument")}
      </button>
    </form>
  );
};
