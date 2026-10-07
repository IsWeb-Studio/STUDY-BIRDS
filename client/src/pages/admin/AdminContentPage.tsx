import { useEffect, useState, type FormEvent } from "react";
import { Globe2, GraduationCap, PencilLine, Plus, Trash2 } from "lucide-react";
import { ArticleContentFields } from "../../components/admin/ArticleContentFields";
import { useLanguage } from "../../hooks/useLanguage";
import { getApiAssetUrl } from "../../lib/api";
import { adminService } from "../../services/adminService";
import type { Country, StudyField } from "../../types";
import { createEmptyArticleBodies, createEmptyArticleHeadings, normalizeArticleBodies, normalizeArticleHeadings } from "../../constants/articleContent";
import { getErrorMessage } from "../../utils/errors";
import { dt } from "../../utils/dashboardTranslations";

const emptyCountryForm = {
  name: "",
  code: "",
  description: "",
  visaNotes: "",
  heroImage: "",
  universityCount: "0",
  specialtyCount: "0",
  averageTuition: "0",
  articleTitle: "",
  articleTitleColor: "#0f172a",
  articleHeadingColor: "#0f172a",
  articleBodyColor: "#475569",
  articleHeadings: createEmptyArticleHeadings(),
  articleBodies: createEmptyArticleBodies(),
  featured: false,
  processingDays: "0",
  visaFeeUsd: "0",
  languageRequirements: [] as string[],
  visaNotesList: [] as string[],
  visaRequirements: [] as { docKey: string; label: string }[],
};

const emptyStudyFieldForm = {
  name: "",
  description: "",
  image: "",
  featured: true,
  sortOrder: "0",
};

const appendArticleItem = (items: string[]) => [...items, ""];
const removeArticleItem = (items: string[], index: number) => (items.length > 1 ? items.filter((_, itemIndex) => itemIndex !== index) : items);

export const AdminContentPage = () => {
  const { language, t } = useLanguage();
  const [countries, setCountries] = useState<Country[]>([]);
  const [studyFields, setStudyFields] = useState<StudyField[]>([]);
  const [studyFieldForm, setStudyFieldForm] = useState(emptyStudyFieldForm);
  const [countryForm, setCountryForm] = useState(emptyCountryForm);
  const [editingStudyFieldId, setEditingStudyFieldId] = useState<string | null>(null);
  const [editingCountryId, setEditingCountryId] = useState<string | null>(null);
  const [formError, setFormError] = useState("");
  const [uploadingCountryImage, setUploadingCountryImage] = useState(false);
  const [uploadingStudyFieldImage, setUploadingStudyFieldImage] = useState(false);

  const loadData = async () => {
    const [countriesData, studyFieldsData] = await Promise.all([adminService.getCountries(), adminService.getStudyFields()]);
    setCountries(countriesData);
    setStudyFields(studyFieldsData);
  };

  useEffect(() => {
    loadData().catch((error) => setFormError(getErrorMessage(error, dt(language, "loadContentFailed"))));
  }, [language]);

  const resetCountryForm = () => {
    setEditingCountryId(null);
    setCountryForm(emptyCountryForm);
  };

  const resetStudyFieldForm = () => {
    setEditingStudyFieldId(null);
    setStudyFieldForm(emptyStudyFieldForm);
  };

  const submitCountry = async (event: FormEvent) => {
    event.preventDefault();
    setFormError("");

    try {
      const payload = {
        ...countryForm,
        universityCount: Number(countryForm.universityCount || 0),
        specialtyCount: Number(countryForm.specialtyCount || 0),
        averageTuition: Number(countryForm.averageTuition || 0),
        processingDays: Number(countryForm.processingDays || 0),
        visaFeeUsd: Number(countryForm.visaFeeUsd || 0),
        languageRequirements: countryForm.languageRequirements.filter(Boolean),
        visaNotesList: countryForm.visaNotesList.filter(Boolean),
        visaRequirements: countryForm.visaRequirements.filter((r) => r.docKey && r.label),
        articleTitle: countryForm.articleTitle.trim(),
        articleTitleColor: countryForm.articleTitleColor || "#0f172a",
        articleHeadingColor: countryForm.articleHeadingColor || "#0f172a",
        articleBodyColor: countryForm.articleBodyColor || "#475569",
        articleHeadings: countryForm.articleHeadings.map((item) => item.trim()).filter(Boolean),
        articleBodies: countryForm.articleBodies.map((item) => item.trim()).filter(Boolean),
      };

      if (editingCountryId) {
        await adminService.updateCountry(editingCountryId, payload);
      } else {
        await adminService.createCountry(payload);
      }

      resetCountryForm();
      await loadData();
    } catch (error) {
      setFormError(getErrorMessage(error, dt(language, "saveContentFailed")));
    }
  };

  const handleCountryImageUpload = async (fileList: FileList | null) => {
    if (!fileList?.length) return;
    setFormError("");
    setUploadingCountryImage(true);

    try {
      const imageUrl = await adminService.uploadCountryImage(fileList[0]);
      setCountryForm((current) => ({ ...current, heroImage: imageUrl }));
    } catch (error) {
      setFormError(getErrorMessage(error, dt(language, "imageUploadFailed")));
    } finally {
      setUploadingCountryImage(false);
    }
  };

  const submitStudyField = async (event: FormEvent) => {
    event.preventDefault();
    setFormError("");

    const payload = {
      name: studyFieldForm.name,
      description: studyFieldForm.description || "",
      image: studyFieldForm.image || "",
      featured: studyFieldForm.featured,
      sortOrder: Number(studyFieldForm.sortOrder || 0),
    };

    try {
      if (editingStudyFieldId) {
        await adminService.updateStudyField(editingStudyFieldId, payload);
      } else {
        await adminService.createStudyField(payload);
      }

      resetStudyFieldForm();
      await loadData();
    } catch (error) {
      setFormError(getErrorMessage(error, dt(language, "saveContentFailed")));
    }
  };

  const handleStudyFieldImageUpload = async (fileList: FileList | null) => {
    if (!fileList?.length) return;
    setFormError("");
    setUploadingStudyFieldImage(true);

    try {
      const imageUrl = await adminService.uploadStudyFieldImage(fileList[0]);
      setStudyFieldForm((current) => ({ ...current, image: imageUrl }));
    } catch (error) {
      setFormError(getErrorMessage(error, dt(language, "imageUploadFailed")));
    } finally {
      setUploadingStudyFieldImage(false);
    }
  };

  return (
    <div className="space-y-6">
      {formError ? <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{formError}</div> : null}

      <div className="grid gap-6">
        <section className="panel p-7">
          <div className="flex items-center gap-3">
            <div className="rounded-2xl bg-slate-100 p-3 text-slate-700">
              <Globe2 className="h-5 w-5" />
            </div>
            <div>
              <h1 className="text-2xl font-semibold text-slate-900">{dt(language, "countriesContent")}</h1>
              <p className="mt-1 text-sm text-slate-500">{dt(language, "countriesHelp")}</p>
            </div>
          </div>
          <form onSubmit={submitCountry} className="mt-6 space-y-4">
            <div className="grid gap-4 md:grid-cols-2">
              <label className="block">
                <span className="mb-2 block text-sm font-medium text-slate-700">{t("country")}</span>
                <input value={countryForm.name} onChange={(event) => setCountryForm((current) => ({ ...current, name: event.target.value }))} required className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
              </label>
              <label className="block">
                <span className="mb-2 block text-sm font-medium text-slate-700">{dt(language, "code")}</span>
                <input value={countryForm.code} onChange={(event) => setCountryForm((current) => ({ ...current, code: event.target.value.toUpperCase() }))} required className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
              </label>
            </div>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{dt(language, "description")}</span>
              <textarea value={countryForm.description} onChange={(event) => setCountryForm((current) => ({ ...current, description: event.target.value }))} rows={3} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{dt(language, "visaNotes")}</span>
              <textarea value={countryForm.visaNotes} onChange={(event) => setCountryForm((current) => ({ ...current, visaNotes: event.target.value }))} rows={3} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
            </label>
            <div className="grid gap-4 md:grid-cols-2">
              <label className="block">
                <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "مدة المعالجة (أيام)" : "Processing days"}</span>
                <input type="number" min="0" value={countryForm.processingDays} onChange={(event) => setCountryForm((current) => ({ ...current, processingDays: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
              </label>
              <label className="block">
                <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "رسوم التأشيرة (USD)" : "Visa fee (USD)"}</span>
                <input type="number" min="0" value={countryForm.visaFeeUsd} onChange={(event) => setCountryForm((current) => ({ ...current, visaFeeUsd: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
              </label>
            </div>
            <div className="rounded-2xl border border-slate-200 p-4 space-y-3">
              <p className="text-sm font-medium text-slate-700">{language === "ar" ? "متطلبات اللغة" : "Language requirements"}</p>
              {countryForm.languageRequirements.map((item, index) => (
                <div key={index} className="flex gap-2">
                  <input value={item} onChange={(event) => setCountryForm((current) => ({ ...current, languageRequirements: current.languageRequirements.map((v, i) => i === index ? event.target.value : v) }))} placeholder={language === "ar" ? "مثال: IELTS 6.5" : "e.g. IELTS 6.5"} className="flex-1 rounded-2xl border border-slate-200 px-4 py-2 text-sm outline-none focus:ring" />
                  <button type="button" onClick={() => setCountryForm((current) => ({ ...current, languageRequirements: current.languageRequirements.filter((_, i) => i !== index) }))} className="rounded-full border border-rose-200 px-3 py-1 text-xs font-medium text-rose-700">✕</button>
                </div>
              ))}
              <button type="button" onClick={() => setCountryForm((current) => ({ ...current, languageRequirements: [...current.languageRequirements, ""] }))} className="rounded-full border border-slate-200 px-4 py-2 text-sm font-medium text-slate-700">+ {language === "ar" ? "إضافة لغة" : "Add language"}</button>
            </div>
            <div className="rounded-2xl border border-slate-200 p-4 space-y-3">
              <p className="text-sm font-medium text-slate-700">{language === "ar" ? "ملاحظات التأشيرة" : "Visa notes list"}</p>
              {countryForm.visaNotesList.map((item, index) => (
                <div key={index} className="flex gap-2">
                  <input value={item} onChange={(event) => setCountryForm((current) => ({ ...current, visaNotesList: current.visaNotesList.map((v, i) => i === index ? event.target.value : v) }))} placeholder={language === "ar" ? "ملاحظة..." : "Note..."} className="flex-1 rounded-2xl border border-slate-200 px-4 py-2 text-sm outline-none focus:ring" />
                  <button type="button" onClick={() => setCountryForm((current) => ({ ...current, visaNotesList: current.visaNotesList.filter((_, i) => i !== index) }))} className="rounded-full border border-rose-200 px-3 py-1 text-xs font-medium text-rose-700">✕</button>
                </div>
              ))}
              <button type="button" onClick={() => setCountryForm((current) => ({ ...current, visaNotesList: [...current.visaNotesList, ""] }))} className="rounded-full border border-slate-200 px-4 py-2 text-sm font-medium text-slate-700">+ {language === "ar" ? "إضافة ملاحظة" : "Add note"}</button>
            </div>
            <div className="rounded-2xl border border-slate-200 p-4 space-y-3">
              <p className="text-sm font-medium text-slate-700">{language === "ar" ? "متطلبات التأشيرة (وثائق)" : "Visa requirements (documents)"}</p>
              {countryForm.visaRequirements.map((item, index) => (
                <div key={index} className="flex gap-2">
                  <input value={item.docKey} onChange={(event) => setCountryForm((current) => ({ ...current, visaRequirements: current.visaRequirements.map((v, i) => i === index ? { ...v, docKey: event.target.value } : v) }))} placeholder={language === "ar" ? "المفتاح (e.g. passport)" : "Key (e.g. passport)"} className="w-32 rounded-2xl border border-slate-200 px-3 py-2 text-sm outline-none focus:ring" />
                  <input value={item.label} onChange={(event) => setCountryForm((current) => ({ ...current, visaRequirements: current.visaRequirements.map((v, i) => i === index ? { ...v, label: event.target.value } : v) }))} placeholder={language === "ar" ? "الوصف (e.g. جواز السفر)" : "Label (e.g. Passport)"} className="flex-1 rounded-2xl border border-slate-200 px-3 py-2 text-sm outline-none focus:ring" />
                  <button type="button" onClick={() => setCountryForm((current) => ({ ...current, visaRequirements: current.visaRequirements.filter((_, i) => i !== index) }))} className="rounded-full border border-rose-200 px-3 py-1 text-xs font-medium text-rose-700">✕</button>
                </div>
              ))}
              <button type="button" onClick={() => setCountryForm((current) => ({ ...current, visaRequirements: [...current.visaRequirements, { docKey: "", label: "" }] }))} className="rounded-full border border-slate-200 px-4 py-2 text-sm font-medium text-slate-700">+ {language === "ar" ? "إضافة وثيقة" : "Add document"}</button>
            </div>
            <div className="grid gap-4 md:grid-cols-3">
              <label className="block">
                <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "عدد الجامعات" : "Universities count"}</span>
                <input type="number" min="0" value={countryForm.universityCount} onChange={(event) => setCountryForm((current) => ({ ...current, universityCount: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
              </label>
              <label className="block">
                <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "عدد التخصصات" : "Specialties count"}</span>
                <input type="number" min="0" value={countryForm.specialtyCount} onChange={(event) => setCountryForm((current) => ({ ...current, specialtyCount: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
              </label>
              <label className="block">
                <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "متوسط الرسوم" : "Average tuition"}</span>
                <input type="number" min="0" value={countryForm.averageTuition} onChange={(event) => setCountryForm((current) => ({ ...current, averageTuition: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
              </label>
            </div>
            <ArticleContentFields
              articleTitle={countryForm.articleTitle}
              articleTitleColor={countryForm.articleTitleColor}
              articleHeadingColor={countryForm.articleHeadingColor}
              articleBodyColor={countryForm.articleBodyColor}
              articleHeadings={countryForm.articleHeadings}
              articleBodies={countryForm.articleBodies}
              onArticleTitleChange={(value) => setCountryForm((current) => ({ ...current, articleTitle: value }))}
              onArticleTitleColorChange={(value) => setCountryForm((current) => ({ ...current, articleTitleColor: value }))}
              onArticleHeadingColorChange={(value) => setCountryForm((current) => ({ ...current, articleHeadingColor: value }))}
              onArticleBodyColorChange={(value) => setCountryForm((current) => ({ ...current, articleBodyColor: value }))}
              onArticleHeadingChange={(index, value) =>
                setCountryForm((current) => ({
                  ...current,
                  articleHeadings: current.articleHeadings.map((item, itemIndex) => (itemIndex === index ? value : item)),
                }))
              }
              onArticleBodyChange={(index, value) =>
                setCountryForm((current) => ({
                  ...current,
                  articleBodies: current.articleBodies.map((item, itemIndex) => (itemIndex === index ? value : item)),
                }))
              }
              onAddArticleItem={() =>
                setCountryForm((current) => ({
                  ...current,
                  articleHeadings: appendArticleItem(current.articleHeadings),
                  articleBodies: appendArticleItem(current.articleBodies),
                }))
              }
              onRemoveArticleItem={(index) =>
                setCountryForm((current) => ({
                  ...current,
                  articleHeadings: removeArticleItem(current.articleHeadings, index),
                  articleBodies: removeArticleItem(current.articleBodies, index),
                }))
              }
              language={language}
            />
            <div className="rounded-2xl border border-slate-200 p-4">
              <p className="text-sm font-medium text-slate-700">{language === "ar" ? "صورة الدولة" : "Country cover image"}</p>
              <input type="file" accept="image/*" onChange={(event) => handleCountryImageUpload(event.target.files)} className="mt-4 w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm" />
              <p className="mt-2 text-xs text-slate-500">
                {uploadingCountryImage ? `${dt(language, "uploadImages")}...` : language === "ar" ? "ارفع صورة الدولة التي تظهر في بطاقة الوجهة الدراسية." : "Upload the image shown on the destination card."}
              </p>
              {countryForm.heroImage ? (
                <div className="mt-4 rounded-2xl border border-slate-200 p-3">
                  <img src={getApiAssetUrl(countryForm.heroImage)} alt="Country cover" className="h-36 w-full rounded-2xl object-cover" />
                  <button
                    type="button"
                    onClick={() => setCountryForm((current) => ({ ...current, heroImage: "" }))}
                    className="mt-3 rounded-full border border-rose-200 px-3 py-1 text-xs font-medium text-rose-700"
                  >
                    {dt(language, "removeImage")}
                  </button>
                </div>
              ) : null}
            </div>
            <label className="flex items-center gap-3 rounded-2xl border border-slate-200 px-4 py-3">
              <input type="checkbox" checked={countryForm.featured} onChange={(event) => setCountryForm((current) => ({ ...current, featured: event.target.checked }))} />
              <span className="text-sm font-medium text-slate-700">{dt(language, "featureDestination")}</span>
            </label>
            <div className="flex flex-wrap gap-3">
              <button type="submit" className="inline-flex items-center gap-2 rounded-full bg-slate-950 px-5 py-3 font-semibold text-white">
                <Plus className="h-4 w-4" />
                {editingCountryId ? dt(language, "updateCountry") : dt(language, "createCountry")}
              </button>
              <button type="button" onClick={resetCountryForm} className="rounded-full border border-slate-200 px-5 py-3 font-semibold text-slate-700">
                {dt(language, "clearForm")}
              </button>
            </div>
          </form>
        </section>
      </div>

      <section className="panel p-6">
        <div className="flex items-center gap-3">
          <div className="rounded-2xl bg-slate-100 p-3 text-slate-700">
            <GraduationCap className="h-5 w-5" />
          </div>
          <div>
            <h1 className="text-2xl font-semibold text-slate-900">{language === "ar" ? "التخصصات الدراسية" : "Study fields"}</h1>
            <p className="mt-1 text-sm text-slate-500">
              {language === "ar" ? "أدر التخصصات التي تظهر في الصفحة الرئيسية وفي فلاتر البرامج الدراسية." : "Manage the study fields shown on the homepage and in program filters."}
            </p>
          </div>
        </div>
        <form onSubmit={submitStudyField} className="mt-6 space-y-4">
          <div className="grid gap-4 md:grid-cols-2">
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "اسم التخصص" : "Field name"}</span>
              <input
                value={studyFieldForm.name}
                onChange={(event) => setStudyFieldForm((current) => ({ ...current, name: event.target.value }))}
                required
                className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
              />
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "الترتيب" : "Sort order"}</span>
              <input
                type="number"
                value={studyFieldForm.sortOrder}
                onChange={(event) => setStudyFieldForm((current) => ({ ...current, sortOrder: event.target.value }))}
                className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
              />
            </label>
          </div>
          <label className="block">
            <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "وصف مختصر" : "Short description"}</span>
            <textarea
              value={studyFieldForm.description}
              onChange={(event) => setStudyFieldForm((current) => ({ ...current, description: event.target.value }))}
              rows={3}
              className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
            />
          </label>
          <div className="rounded-2xl border border-slate-200 p-4">
            <p className="text-sm font-medium text-slate-700">{language === "ar" ? "صورة التخصص" : "Field image"}</p>
            <input type="file" accept="image/*" onChange={(event) => handleStudyFieldImageUpload(event.target.files)} className="mt-4 w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm" />
            <p className="mt-2 text-xs text-slate-500">
              {uploadingStudyFieldImage
                ? `${dt(language, "uploadImages")}...`
                : language === "ar"
                  ? "ارفع صورة التخصص التي تظهر في بطاقة التخصص بالواجهة الرئيسية."
                  : "Upload the image shown on the homepage study field card."}
            </p>
            {studyFieldForm.image ? (
              <div className="mt-4 rounded-2xl border border-slate-200 p-3">
                <img src={getApiAssetUrl(studyFieldForm.image)} alt="Study field" className="h-40 w-full rounded-2xl object-cover" />
                <button
                  type="button"
                  onClick={() => setStudyFieldForm((current) => ({ ...current, image: "" }))}
                  className="mt-3 rounded-full border border-rose-200 px-3 py-1 text-xs font-medium text-rose-700"
                >
                  {dt(language, "removeImage")}
                </button>
              </div>
            ) : null}
          </div>
          <label className="flex items-center gap-3 rounded-2xl border border-slate-200 px-4 py-3">
            <input type="checkbox" checked={studyFieldForm.featured} onChange={(event) => setStudyFieldForm((current) => ({ ...current, featured: event.target.checked }))} />
            <span className="text-sm font-medium text-slate-700">{language === "ar" ? "إظهار في الصفحة الرئيسية" : "Show on homepage"}</span>
          </label>
          <div className="flex flex-wrap gap-3">
            <button type="submit" className="inline-flex items-center gap-2 rounded-full bg-slate-950 px-5 py-3 font-semibold text-white">
              <Plus className="h-4 w-4" />
              {editingStudyFieldId ? (language === "ar" ? "تحديث التخصص" : "Update field") : language === "ar" ? "إضافة تخصص" : "Create field"}
            </button>
            <button type="button" onClick={resetStudyFieldForm} className="rounded-full border border-slate-200 px-5 py-3 font-semibold text-slate-700">
              {dt(language, "clearForm")}
            </button>
          </div>
        </form>
      </section>

      <div className="grid gap-6 xl:grid-cols-2">
        <section className="space-y-4">
          {studyFields.map((studyField) => (
            <div key={studyField._id} className="panel p-5">
              <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                <div className="flex-1">
                  {studyField.image ? <img src={getApiAssetUrl(studyField.image)} alt={studyField.name} className="h-40 w-full rounded-3xl object-cover" /> : null}
                  <div className="mt-4 flex flex-wrap items-center gap-2">
                    <p className="text-lg font-semibold text-slate-900">{studyField.name}</p>
                    {studyField.featured ? <span className="rounded-full bg-amber-100 px-3 py-1 text-xs font-semibold text-amber-700">{dt(language, "featured")}</span> : null}
                    <span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-600">{language === "ar" ? `الترتيب ${studyField.sortOrder || 0}` : `Order ${studyField.sortOrder || 0}`}</span>
                  </div>
                  {studyField.description ? <p className="mt-3 text-sm leading-6 text-slate-600">{studyField.description}</p> : null}
                </div>
                <div className="flex flex-wrap gap-2">
                  <button
                    onClick={() => {
                      setEditingStudyFieldId(studyField._id);
                      setStudyFieldForm({
                        name: studyField.name,
                        description: studyField.description || "",
                        image: studyField.image || "",
                        featured: Boolean(studyField.featured),
                        sortOrder: String(studyField.sortOrder || 0),
                      });
                    }}
                    className="inline-flex items-center gap-2 rounded-full border border-slate-200 px-4 py-2 font-medium text-slate-700"
                  >
                    <PencilLine className="h-4 w-4" />
                    {dt(language, "edit")}
                  </button>
                  <button onClick={() => adminService.removeStudyField(studyField._id).then(loadData)} className="inline-flex items-center gap-2 rounded-full border border-rose-200 px-4 py-2 font-medium text-rose-700">
                    <Trash2 className="h-4 w-4" />
                    {dt(language, "delete")}
                  </button>
                </div>
              </div>
            </div>
          ))}
        </section>

        <section className="space-y-4">
          {countries.map((country) => (
            <div key={country._id} className="panel p-5">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <div className="flex flex-wrap items-center gap-2">
                    <p className="text-lg font-semibold text-slate-900">{country.name}</p>
                    <span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-600">{country.code}</span>
                    {country.featured ? <span className="rounded-full bg-amber-100 px-3 py-1 text-xs font-semibold text-amber-700">{dt(language, "featured")}</span> : null}
                  </div>
                  {country.heroImage ? <img src={getApiAssetUrl(country.heroImage)} alt={country.name} className="mt-4 h-32 w-full rounded-2xl object-cover" /> : null}
                  {country.description ? <p className="mt-3 text-sm leading-6 text-slate-600">{country.description}</p> : null}
                  <div className="mt-3 flex flex-wrap gap-2 text-xs font-semibold text-slate-600">
                    <span className="rounded-full bg-slate-100 px-3 py-1">{language === "ar" ? `الجامعات ${country.universityCount || 0}` : `Universities ${country.universityCount || 0}`}</span>
                    <span className="rounded-full bg-slate-100 px-3 py-1">{language === "ar" ? `التخصصات ${country.specialtyCount || 0}` : `Specialties ${country.specialtyCount || 0}`}</span>
                    <span className="rounded-full bg-slate-100 px-3 py-1">{language === "ar" ? `متوسط الرسوم ${country.averageTuition || 0}$` : `Avg tuition $${country.averageTuition || 0}`}</span>
                  </div>
                  {country.visaNotes ? <p className="mt-3 rounded-2xl bg-slate-50 px-4 py-3 text-sm leading-6 text-slate-600">{country.visaNotes}</p> : null}
                </div>
                <div className="flex flex-wrap gap-2">
                  <button
                    onClick={() => {
                      const articleItemCount = Math.max(1, country.articleHeadings?.length || 0, country.articleBodies?.length || 0);
                      setEditingCountryId(country._id);
                      setCountryForm({
                        name: country.name,
                        code: country.code,
                        description: country.description || "",
                        visaNotes: country.visaNotes || "",
                        heroImage: country.heroImage || "",
                        universityCount: String(country.universityCount || 0),
                        specialtyCount: String(country.specialtyCount || 0),
                        averageTuition: String(country.averageTuition || 0),
                        articleTitle: country.articleTitle || "",
                        articleTitleColor: country.articleTitleColor || "#0f172a",
                        articleHeadingColor: country.articleHeadingColor || "#0f172a",
                        articleBodyColor: country.articleBodyColor || "#475569",
                        articleHeadings: normalizeArticleHeadings(country.articleHeadings, articleItemCount),
                        articleBodies: normalizeArticleBodies(country.articleBodies, articleItemCount),
                        featured: Boolean(country.featured),
                        processingDays: String(country.processingDays || 0),
                        visaFeeUsd: String(country.visaFeeUsd || 0),
                        languageRequirements: Array.isArray(country.languageRequirements) ? country.languageRequirements : [],
                        visaNotesList: Array.isArray(country.visaNotesList) ? country.visaNotesList : [],
                        visaRequirements: Array.isArray(country.visaRequirements) ? country.visaRequirements : [],
                      });
                    }}
                    className="inline-flex items-center gap-2 rounded-full border border-slate-200 px-4 py-2 font-medium text-slate-700"
                  >
                    <PencilLine className="h-4 w-4" />
                    {dt(language, "edit")}
                  </button>
                  <button onClick={() => adminService.removeCountry(country._id).then(loadData)} className="inline-flex items-center gap-2 rounded-full border border-rose-200 px-4 py-2 font-medium text-rose-700">
                    <Trash2 className="h-4 w-4" />
                    {dt(language, "delete")}
                  </button>
                </div>
              </div>
            </div>
          ))}
        </section>
      </div>
    </div>
  );
};

