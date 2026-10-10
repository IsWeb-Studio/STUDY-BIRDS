import { useEffect, useMemo, useRef, useState, type FormEvent } from "react";
import { Globe2, PencilLine, Plus, Search, Trash2, X } from "lucide-react";
import { ArticleContentFields } from "../../components/admin/ArticleContentFields";
import { useLanguage } from "../../hooks/useLanguage";
import { getApiAssetUrl } from "../../lib/api";
import { adminService } from "../../services/adminService";
import type { Country } from "../../types";
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

const appendArticleItem = (items: string[]) => [...items, ""];
const removeArticleItem = (items: string[], index: number) => (items.length > 1 ? items.filter((_, itemIndex) => itemIndex !== index) : items);


export const AdminCountriesPage = () => {
  const { language, t } = useLanguage();
  const [countries, setCountries] = useState<Country[]>([]);
  const [countryForm, setCountryForm] = useState(emptyCountryForm);
  const [editingCountryId, setEditingCountryId] = useState<string | null>(null);
  const [formError, setFormError] = useState("");
  const [uploadingCountryImage, setUploadingCountryImage] = useState(false);
  const [search, setSearch] = useState("");
  const [editorOpen, setEditorOpen] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const editorRef = useRef<HTMLElement>(null);
  const filtered = useMemo(() => {
    const query = search.trim().toLocaleLowerCase();
    return countries.filter(row => [row.name, row.code, row.description].filter(Boolean).join(" ").toLocaleLowerCase().includes(query));
  }, [countries, search]);
  const loadData = async () => { setCountries(await adminService.getCountries()); };
  useEffect(() => {
    setLoading(true);
    loadData().catch(error => setFormError(getErrorMessage(error, dt(language,"loadContentFailed")))).finally(() => setLoading(false));
  }, [language]);
  useEffect(() => { if(editorOpen) editorRef.current?.scrollIntoView({behavior:"smooth",block:"start"}); }, [editorOpen, editingCountryId]);
  const resetCountryForm = () => {
    setEditingCountryId(null);
    setCountryForm(emptyCountryForm);
  };

  const submitCountry = async (event: FormEvent) => {
    event.preventDefault();
    if (saving || uploadingCountryImage) return;
    setSaving(true);
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
      setEditorOpen(false);
      await loadData();
    } catch (error) {
      setFormError(getErrorMessage(error, dt(language, "saveContentFailed")));
    } finally {
      setSaving(false);
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


  const handleDelete = async (id: string) => {
    if (saving || uploadingCountryImage || !window.confirm(language === "ar" ? "هل تريد حذف هذا السجل؟" : "Delete this record?")) return;
    setSaving(true); setFormError("");
    try {
      await adminService.removeCountry(id);
      setCountries(current => current.filter(row => row._id !== id));
      if(editingCountryId === id) { resetCountryForm(); setEditorOpen(false); }
    } catch(error) { setFormError(getErrorMessage(error, dt(language,"saveContentFailed"))); }
    finally { setSaving(false); }
  };
  return <div className="min-w-0 space-y-6">
    <header className="panel flex flex-wrap items-center justify-between gap-4 p-5 sm:p-6">
      <div className="flex min-w-0 items-center gap-3">
        <div className="rounded-xl bg-blue-50 p-3 text-blue-700"><Globe2 className="h-6 w-6" /></div>
        <div><h1 className="text-2xl font-bold text-slate-900">{language === "ar" ? "إدارة الدول" : "Country management"}</h1><p className="mt-1 text-sm text-slate-500">{language === "ar" ? "إدارة وجهات الدراسة وبيانات الدول ومتطلبات التأشيرة." : "Manage study destinations, country information and visa requirements."}</p></div>
      </div>
      <button type="button" disabled={saving || uploadingCountryImage} onClick={() => { resetCountryForm(); setFormError(""); setEditorOpen(true); }} className="inline-flex items-center gap-2 rounded-xl bg-slate-950 px-5 py-3 text-sm font-semibold text-white hover:bg-slate-800 disabled:opacity-50"><Plus className="h-4 w-4" />{language === "ar" ? "إضافة دولة" : "Add country"}</button>
    </header>
    {formError && <div role="alert" className="rounded-xl border border-rose-200 bg-rose-50 p-4 text-sm text-rose-700">{formError}</div>}
    {editorOpen && <section ref={editorRef} className="panel min-w-0 scroll-mt-6 p-5 sm:p-7">
      <div className="flex items-center gap-3"><h2 className="text-xl font-semibold text-slate-900">{editingCountryId ? (language === "ar" ? "تعديل البيانات" : "Edit details") : (language === "ar" ? "إضافة دولة" : "Add country")}</h2><button type="button" disabled={saving || uploadingCountryImage} onClick={() => setEditorOpen(false)} aria-label={language === "ar" ? "إغلاق النموذج" : "Close editor"} className="ms-auto rounded-xl p-2 text-slate-500 hover:bg-slate-100"><X className="h-5 w-5" /></button></div>
          <form onSubmit={submitCountry} className="mt-6 space-y-4">
<fieldset disabled={saving || uploadingCountryImage} className="min-w-0 space-y-4">
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
                <div key={index} className="flex flex-wrap gap-2">
                  <input value={item} onChange={(event) => setCountryForm((current) => ({ ...current, languageRequirements: current.languageRequirements.map((v, i) => i === index ? event.target.value : v) }))} placeholder={language === "ar" ? "مثال: IELTS 6.5" : "e.g. IELTS 6.5"} className="min-w-0 flex-1 rounded-2xl border border-slate-200 px-4 py-2 text-sm outline-none focus:ring" />
                  <button type="button" onClick={() => setCountryForm((current) => ({ ...current, languageRequirements: current.languageRequirements.filter((_, i) => i !== index) }))} className="rounded-xl border border-rose-200 px-3 py-1 text-xs font-medium text-rose-700">✕</button>
                </div>
              ))}
              <button type="button" onClick={() => setCountryForm((current) => ({ ...current, languageRequirements: [...current.languageRequirements, ""] }))} className="rounded-xl border border-slate-200 px-4 py-2 text-sm font-medium text-slate-700">+ {language === "ar" ? "إضافة لغة" : "Add language"}</button>
            </div>
            <div className="rounded-2xl border border-slate-200 p-4 space-y-3">
              <p className="text-sm font-medium text-slate-700">{language === "ar" ? "ملاحظات التأشيرة" : "Visa notes list"}</p>
              {countryForm.visaNotesList.map((item, index) => (
                <div key={index} className="flex flex-wrap gap-2">
                  <input value={item} onChange={(event) => setCountryForm((current) => ({ ...current, visaNotesList: current.visaNotesList.map((v, i) => i === index ? event.target.value : v) }))} placeholder={language === "ar" ? "ملاحظة..." : "Note..."} className="min-w-0 flex-1 rounded-2xl border border-slate-200 px-4 py-2 text-sm outline-none focus:ring" />
                  <button type="button" onClick={() => setCountryForm((current) => ({ ...current, visaNotesList: current.visaNotesList.filter((_, i) => i !== index) }))} className="rounded-xl border border-rose-200 px-3 py-1 text-xs font-medium text-rose-700">✕</button>
                </div>
              ))}
              <button type="button" onClick={() => setCountryForm((current) => ({ ...current, visaNotesList: [...current.visaNotesList, ""] }))} className="rounded-xl border border-slate-200 px-4 py-2 text-sm font-medium text-slate-700">+ {language === "ar" ? "إضافة ملاحظة" : "Add note"}</button>
            </div>
            <div className="rounded-2xl border border-slate-200 p-4 space-y-3">
              <p className="text-sm font-medium text-slate-700">{language === "ar" ? "متطلبات التأشيرة (وثائق)" : "Visa requirements (documents)"}</p>
              {countryForm.visaRequirements.map((item, index) => (
                <div key={index} className="flex flex-wrap gap-2">
                  <input value={item.docKey} onChange={(event) => setCountryForm((current) => ({ ...current, visaRequirements: current.visaRequirements.map((v, i) => i === index ? { ...v, docKey: event.target.value } : v) }))} placeholder={language === "ar" ? "المفتاح (e.g. passport)" : "Key (e.g. passport)"} className="w-32 rounded-2xl border border-slate-200 px-3 py-2 text-sm outline-none focus:ring" />
                  <input value={item.label} onChange={(event) => setCountryForm((current) => ({ ...current, visaRequirements: current.visaRequirements.map((v, i) => i === index ? { ...v, label: event.target.value } : v) }))} placeholder={language === "ar" ? "الوصف (e.g. جواز السفر)" : "Label (e.g. Passport)"} className="min-w-0 flex-1 rounded-2xl border border-slate-200 px-3 py-2 text-sm outline-none focus:ring" />
                  <button type="button" onClick={() => setCountryForm((current) => ({ ...current, visaRequirements: current.visaRequirements.filter((_, i) => i !== index) }))} className="rounded-xl border border-rose-200 px-3 py-1 text-xs font-medium text-rose-700">✕</button>
                </div>
              ))}
              <button type="button" onClick={() => setCountryForm((current) => ({ ...current, visaRequirements: [...current.visaRequirements, { docKey: "", label: "" }] }))} className="rounded-xl border border-slate-200 px-4 py-2 text-sm font-medium text-slate-700">+ {language === "ar" ? "إضافة وثيقة" : "Add document"}</button>
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
                    className="mt-3 rounded-xl border border-rose-200 px-3 py-1 text-xs font-medium text-rose-700"
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
              <button type="submit" className="inline-flex items-center gap-2 rounded-xl bg-slate-950 px-5 py-3 font-semibold text-white">
                <Plus className="h-4 w-4" />
                {editingCountryId ? dt(language, "updateCountry") : dt(language, "createCountry")}
              </button>
              <button type="button" onClick={resetCountryForm} className="rounded-xl border border-slate-200 px-5 py-3 font-semibold text-slate-700">
                {dt(language, "clearForm")}
              </button>
            </div>
          </fieldset></form>
    </section>}
    <section className="panel flex flex-col gap-3 p-4 sm:flex-row sm:items-center sm:justify-between sm:p-5">
      <div className="relative w-full sm:max-w-xl"><Search className="pointer-events-none absolute start-4 top-1/2 h-5 w-5 -translate-y-1/2 text-slate-400" /><input type="search" value={search} onChange={event => setSearch(event.target.value)} placeholder={language === "ar" ? "ابحث باسم الدولة أو الرمز..." : "Search country name or code..."} aria-label={language === "ar" ? "ابحث باسم الدولة أو الرمز..." : "Search country name or code..."} className="w-full rounded-xl border border-slate-200 bg-white py-3 pe-4 ps-12 text-sm outline-none focus:border-blue-400 focus:ring-2 focus:ring-blue-100" /></div>
      <p className="shrink-0 text-sm text-slate-500">{filtered.length} / {countries.length} {language === "ar" ? "سجل" : "records"}</p>
    </section>
    <section className="space-y-4">
      {!loading && <>          {filtered.map((country) => (
            <div key={country._id} className="panel min-w-0 p-5 sm:p-6">
              <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <p className="text-lg font-semibold text-slate-900">{country.name}</p>
                    <span className="rounded-xl bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-600">{country.code}</span>
                    {country.featured ? <span className="rounded-xl bg-amber-100 px-3 py-1 text-xs font-semibold text-amber-700">{dt(language, "featured")}</span> : null}
                  </div>
                  {country.heroImage ? <img src={getApiAssetUrl(country.heroImage)} alt={country.name} className="mt-4 h-32 w-full rounded-2xl object-cover" /> : null}
                  {country.description ? <p className="mt-3 line-clamp-2 break-words text-sm leading-6 text-slate-500">{country.description}</p> : null}
                  <div className="mt-3 flex flex-wrap gap-2 text-xs font-semibold text-slate-600">
                    <span className="rounded-xl bg-slate-100 px-3 py-1">{language === "ar" ? `الجامعات ${country.universityCount || 0}` : `Universities ${country.universityCount || 0}`}</span>
                    <span className="rounded-xl bg-slate-100 px-3 py-1">{language === "ar" ? `التخصصات ${country.specialtyCount || 0}` : `Specialties ${country.specialtyCount || 0}`}</span>
                    <span className="rounded-xl bg-slate-100 px-3 py-1">{language === "ar" ? `متوسط الرسوم ${country.averageTuition || 0}$` : `Avg tuition $${country.averageTuition || 0}`}</span>
                  </div>
                  {country.visaNotes ? <p className="mt-3 rounded-2xl bg-slate-50 px-4 py-3 text-sm leading-6 text-slate-600">{country.visaNotes}</p> : null}
                </div>
                <div className="flex flex-wrap gap-2">
                  <button
                    type="button" disabled={saving || uploadingCountryImage}
                    onClick={() => {
                      const articleItemCount = Math.max(1, country.articleHeadings?.length || 0, country.articleBodies?.length || 0);
                      setFormError("");
                      setEditorOpen(true);
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
                    className="inline-flex items-center gap-2 rounded-xl border border-slate-200 px-4 py-2 font-medium text-slate-700"
                  >
                    <PencilLine className="h-4 w-4" />
                    {dt(language, "edit")}
                  </button>
                  <button type="button" disabled={saving || uploadingCountryImage} onClick={() => handleDelete(country._id)} className="inline-flex items-center gap-2 rounded-xl border border-rose-200 px-4 py-2 font-medium text-rose-700">
                    <Trash2 className="h-4 w-4" />
                    {dt(language, "delete")}
                  </button>
                </div>
              </div>
            </div>
          ))}</>}
      {loading && <div className="panel p-10 text-center text-sm text-slate-500">{language === "ar" ? "جارٍ تحميل البيانات..." : "Loading..."}</div>}
      {!loading && !filtered.length && <div className="panel p-10 text-center"><Search className="mx-auto h-8 w-8 text-slate-300" /><p className="mt-3 font-medium text-slate-600">{language === "ar" ? "لا توجد نتائج لعرضها" : "No results to display"}</p><p className="mt-1 text-sm text-slate-400">{language === "ar" ? "غيّر كلمات البحث أو أضف سجلًا جديدًا." : "Try another search or add a new record."}</p></div>}
    </section>
  </div>;
};
