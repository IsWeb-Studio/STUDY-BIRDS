import { useEffect, useMemo, useRef, useState, type FormEvent } from "react";
import { Building2, MapPin, PencilLine, Plus, Search, Trash2, X } from "lucide-react";
import { ArticleContentFields } from "../../components/admin/ArticleContentFields";
import { useLanguage } from "../../hooks/useLanguage";
import { getApiAssetUrl } from "../../lib/api";
import { adminService } from "../../services/adminService";
import { universityService } from "../../services/universityService";
import type { Country, University } from "../../types";
import { createEmptyArticleBodies, createEmptyArticleHeadings, normalizeArticleBodies, normalizeArticleHeadings } from "../../constants/articleContent";
import { getErrorMessage } from "../../utils/errors";
import { formatCurrency } from "../../utils/format";
import { dt } from "../../utils/dashboardTranslations";
import { getPaginatedItems } from "../../utils/pagination";

const emptyUniversityForm = {
  name: "",
  country: "",
  city: "",
  language: "",
  studentCount: "",
  specialtyCount: "",
  ranking: "",
  tuitionMin: "",
  tuitionMax: "",
  overview: "",
  articleTitle: "",
  articleTitleColor: "#0f172a",
  articleHeadingColor: "#0f172a",
  articleBodyColor: "#475569",
  articleHeadings: createEmptyArticleHeadings(),
  articleBodies: createEmptyArticleBodies(),
  featured: false,
  isPartnerInstitution: false,
  logo: "",
  campusImages: [] as string[],
};

const appendArticleItem = (items: string[]) => [...items, ""];
const removeArticleItem = (items: string[], index: number) => (items.length > 1 ? items.filter((_, itemIndex) => itemIndex !== index) : items);

export const AdminUniversitiesPage = () => {
  const { language, t, tv } = useLanguage();
  const [universities, setUniversities] = useState<University[]>([]);
  const [countries, setCountries] = useState<Country[]>([]);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState(emptyUniversityForm);
  const [formError, setFormError] = useState("");
  const [uploadingLogo, setUploadingLogo] = useState(false);
  const [uploadingGallery, setUploadingGallery] = useState(false);
  const [search, setSearch] = useState("");
  const [editorOpen, setEditorOpen] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const editorRef = useRef<HTMLElement>(null);
  const filteredUniversities = useMemo(() => {
    const query = search.trim().toLocaleLowerCase();
    return universities.filter((university) => [university.name, university.city, university.language, university.country?.name, tv(university.country?.name)]
      .filter(Boolean).join(" ").toLocaleLowerCase().includes(query));
  }, [universities, search, tv]);

  useEffect(() => {
    if (editorOpen) editorRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
  }, [editorOpen, editingId]);

  const loadData = async () => {
    const [universitiesData, countriesData] = await Promise.all([universityService.getAll(), adminService.getCountries()]);
    setUniversities(getPaginatedItems(universitiesData));
    setCountries(countriesData);
  };

  useEffect(() => {
    setLoading(true);
    loadData().catch((error) => setFormError(getErrorMessage(error, dt(language, "loadUniversitiesFailed")))).finally(() => setLoading(false));
  }, [language]);

  const resetForm = () => {
    setEditingId(null);
    setForm(emptyUniversityForm);
  };

  const startEdit = (university: University) => {
    setFormError("");
    setEditorOpen(true);
    const articleItemCount = Math.max(1, university.articleHeadings?.length || 0, university.articleBodies?.length || 0);
    setEditingId(university._id);
    setForm({
      name: university.name || "",
      country: university.country?._id || "",
      city: university.city || "",
      language: university.language || "",
      studentCount: university.studentCount ? String(university.studentCount) : "",
      specialtyCount: university.specialtyCount ? String(university.specialtyCount) : "",
      ranking: university.ranking ? String(university.ranking) : "",
      tuitionMin: university.tuitionRange?.min ? String(university.tuitionRange.min) : "",
      tuitionMax: university.tuitionRange?.max ? String(university.tuitionRange.max) : "",
      overview: university.overview || "",
      articleTitle: university.articleTitle || "",
      articleTitleColor: university.articleTitleColor || "#0f172a",
      articleHeadingColor: university.articleHeadingColor || "#0f172a",
      articleBodyColor: university.articleBodyColor || "#475569",
      articleHeadings: normalizeArticleHeadings(university.articleHeadings, articleItemCount),
      articleBodies: normalizeArticleBodies(university.articleBodies, articleItemCount),
      featured: Boolean(university.featured),
      isPartnerInstitution: Boolean(university.isPartnerInstitution),
      logo: university.logo || "",
      campusImages: university.campusImages || [],
    });
  };

  const handleLogoUpload = async (fileList: FileList | null) => {
    if (!fileList?.length) return;
    setFormError("");
    setUploadingLogo(true);
    try {
      const urls = await universityService.uploadImages([fileList[0]]);
      setForm((current) => ({ ...current, logo: urls[0] || "" }));
    } catch (error) {
      setFormError(getErrorMessage(error, dt(language, "imageUploadFailed")));
    } finally {
      setUploadingLogo(false);
    }
  };

  const handleGalleryUpload = async (fileList: FileList | null) => {
    if (!fileList?.length) return;
    setFormError("");
    setUploadingGallery(true);
    try {
      const urls = await universityService.uploadImages(Array.from(fileList));
      setForm((current) => ({ ...current, campusImages: [...current.campusImages, ...urls] }));
    } catch (error) {
      setFormError(getErrorMessage(error, dt(language, "imageUploadFailed")));
    } finally {
      setUploadingGallery(false);
    }
  };

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    if (saving || uploadingLogo || uploadingGallery) return;
    setSaving(true);
    setFormError("");

    const payload = {
      name: form.name,
      country: form.country,
      city: form.city || undefined,
      language: form.language || undefined,
      studentCount: form.studentCount ? Number(form.studentCount) : 0,
      specialtyCount: form.specialtyCount ? Number(form.specialtyCount) : 0,
      ranking: form.ranking ? Number(form.ranking) : undefined,
      overview: form.overview || undefined,
      articleTitle: form.articleTitle.trim() || undefined,
      articleTitleColor: form.articleTitleColor || "#0f172a",
      articleHeadingColor: form.articleHeadingColor || "#0f172a",
      articleBodyColor: form.articleBodyColor || "#475569",
      articleHeadings: form.articleHeadings.map((item) => item.trim()).filter(Boolean),
      articleBodies: form.articleBodies.map((item) => item.trim()).filter(Boolean),
      featured: form.featured,
      isPartnerInstitution: form.isPartnerInstitution,
      logo: form.logo || undefined,
      campusImages: form.campusImages,
      tuitionRange: {
        min: form.tuitionMin ? Number(form.tuitionMin) : undefined,
        max: form.tuitionMax ? Number(form.tuitionMax) : undefined,
      },
    };

    try {
      if (editingId) {
        await universityService.update(editingId, payload);
      } else {
        await universityService.create(payload);
      }
      resetForm();
      setEditorOpen(false);
      await loadData();
    } catch (error) {
      setFormError(getErrorMessage(error, dt(language, "saveUniversityFailed")));
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id: string) => {
    setFormError("");
    try {
      await universityService.remove(id);
      setUniversities((current) => current.filter((item) => item._id !== id));
      if (editingId === id) {
        resetForm();
        setEditorOpen(false);
      }
    } catch (error) {
      setFormError(getErrorMessage(error, dt(language, "deleteUniversityFailed")));
    }
  };

  return (
    <div className="min-w-0 space-y-6">
      <header className="panel flex flex-wrap items-center justify-between gap-4 p-5 sm:p-6">
        <div className="flex min-w-0 items-center gap-3">
          <div className="rounded-xl bg-blue-50 p-3 text-blue-700"><Building2 className="h-6 w-6" /></div>
          <div><h1 className="text-2xl font-bold text-slate-900">{dt(language, "universityManagement")}</h1><p className="mt-1 text-sm text-slate-500">{dt(language, "universityHelp")}</p></div>
        </div>
        <button type="button" disabled={saving || uploadingLogo || uploadingGallery} onClick={() => { resetForm(); setFormError(""); setEditorOpen(true); }} className="inline-flex items-center gap-2 rounded-xl bg-slate-950 px-5 py-3 text-sm font-semibold text-white hover:bg-slate-800 disabled:opacity-50"><Plus className="h-4 w-4" />{dt(language, "createUniversity")}</button>
      </header>
      {!editorOpen && formError && <div role="alert" className="rounded-xl border border-rose-200 bg-rose-50 p-4 text-sm text-rose-700">{formError}</div>}
      {editorOpen && <section ref={editorRef} className="university-editor panel scroll-mt-6 p-5 sm:p-7">
        <div className="flex items-center gap-3">
          <div className="rounded-2xl bg-slate-100 p-3 text-slate-700">
            <Building2 className="h-5 w-5" />
          </div>
          <div>
            <h2 className="text-xl font-semibold text-slate-900">{editingId ? dt(language, "updateUniversity") : dt(language, "createUniversity")}</h2>
            <p className="mt-1 text-sm text-slate-500">{dt(language, "universityHelp")}</p>
          </div>
          <button type="button" disabled={saving || uploadingLogo || uploadingGallery} onClick={() => setEditorOpen(false)} aria-label={language === "ar" ? "إغلاق النموذج" : "Close editor"} className="ms-auto rounded-xl p-2 text-slate-500 hover:bg-slate-100"><X className="h-5 w-5" /></button>
        </div>
        {formError ? <div className="mt-5 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{formError}</div> : null}
        <form onSubmit={handleSubmit} className="mt-6 space-y-5">
          <div className="grid gap-4 md:grid-cols-2">
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{dt(language, "universityName")}</span>
              <input value={form.name} onChange={(event) => setForm((current) => ({ ...current, name: event.target.value }))} required className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{t("country")}</span>
              <select value={form.country} onChange={(event) => setForm((current) => ({ ...current, country: event.target.value }))} required className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring">
                <option value="">{dt(language, "selectCountry")}</option>
                {countries.map((country) => (
                  <option key={country._id} value={country._id}>
                    {tv(country.name)}
                  </option>
                ))}
              </select>
            </label>
          </div>

          <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{t("city")}</span>
              <input value={form.city} onChange={(event) => setForm((current) => ({ ...current, city: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "اللغة" : "Language"}</span>
              <input value={form.language} onChange={(event) => setForm((current) => ({ ...current, language: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "عدد الطلاب" : "Students count"}</span>
              <input type="number" min="0" value={form.studentCount} onChange={(event) => setForm((current) => ({ ...current, studentCount: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "عدد التخصصات" : "Specialties count"}</span>
              <input type="number" min="0" value={form.specialtyCount} onChange={(event) => setForm((current) => ({ ...current, specialtyCount: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{t("ranking")}</span>
              <input type="number" value={form.ranking} onChange={(event) => setForm((current) => ({ ...current, ranking: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
            </label>
          </div>

          <div className="grid gap-4 md:grid-cols-1">
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{dt(language, "partnerInstitution")}</span>
              <select value={form.isPartnerInstitution ? "yes" : "no"} onChange={(event) => setForm((current) => ({ ...current, isPartnerInstitution: event.target.value === "yes" }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring">
                <option value="no">{dt(language, "no")}</option>
                <option value="yes">{dt(language, "yes")}</option>
              </select>
            </label>
          </div>

          <div className="grid gap-4 md:grid-cols-2">
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{dt(language, "minTuition")}</span>
              <input type="number" value={form.tuitionMin} onChange={(event) => setForm((current) => ({ ...current, tuitionMin: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{dt(language, "maxTuition")}</span>
              <input type="number" value={form.tuitionMax} onChange={(event) => setForm((current) => ({ ...current, tuitionMax: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
            </label>
          </div>

          <label className="block">
            <span className="mb-2 block text-sm font-medium text-slate-700">{dt(language, "overviewText")}</span>
            <textarea value={form.overview} onChange={(event) => setForm((current) => ({ ...current, overview: event.target.value }))} rows={5} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
          </label>

          <ArticleContentFields
            articleTitle={form.articleTitle}
            articleTitleColor={form.articleTitleColor}
            articleHeadingColor={form.articleHeadingColor}
            articleBodyColor={form.articleBodyColor}
            articleHeadings={form.articleHeadings}
            articleBodies={form.articleBodies}
            onArticleTitleChange={(value) => setForm((current) => ({ ...current, articleTitle: value }))}
            onArticleTitleColorChange={(value) => setForm((current) => ({ ...current, articleTitleColor: value }))}
            onArticleHeadingColorChange={(value) => setForm((current) => ({ ...current, articleHeadingColor: value }))}
            onArticleBodyColorChange={(value) => setForm((current) => ({ ...current, articleBodyColor: value }))}
            onArticleHeadingChange={(index, value) =>
              setForm((current) => ({
                ...current,
                articleHeadings: current.articleHeadings.map((item, itemIndex) => (itemIndex === index ? value : item)),
              }))
            }
            onArticleBodyChange={(index, value) =>
              setForm((current) => ({
                ...current,
                articleBodies: current.articleBodies.map((item, itemIndex) => (itemIndex === index ? value : item)),
              }))
            }
            onAddArticleItem={() =>
              setForm((current) => ({
                ...current,
                articleHeadings: appendArticleItem(current.articleHeadings),
                articleBodies: appendArticleItem(current.articleBodies),
              }))
            }
            onRemoveArticleItem={(index) =>
              setForm((current) => ({
                ...current,
                articleHeadings: removeArticleItem(current.articleHeadings, index),
                articleBodies: removeArticleItem(current.articleBodies, index),
              }))
            }
            language={language}
          />

          <div className="rounded-2xl border border-slate-200 p-4">
            <p className="text-sm font-medium text-slate-700">{dt(language, "imageUploadHelp")}</p>
            <div className="mt-4 grid gap-4 md:grid-cols-2">
              <label className="block">
                <span className="mb-2 block text-sm font-medium text-slate-700">{dt(language, "universityLogo")}</span>
                <input type="file" accept="image/*" onChange={(event) => handleLogoUpload(event.target.files)} className="w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm" />
                <p className="mt-2 text-xs text-slate-500">{uploadingLogo ? `${dt(language, "uploadImages")}...` : dt(language, "logoPreview")}</p>
                {form.logo ? (
                  <div className="mt-3 rounded-2xl border border-slate-200 p-3">
                    <img src={getApiAssetUrl(form.logo)} alt="University logo" className="h-20 w-20 rounded-xl object-contain" />
                  </div>
                ) : null}
              </label>

              <label className="block">
                <span className="mb-2 block text-sm font-medium text-slate-700">{dt(language, "campusImages")}</span>
                <input type="file" accept="image/*" multiple onChange={(event) => handleGalleryUpload(event.target.files)} className="w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm" />
                <p className="mt-2 text-xs text-slate-500">{uploadingGallery ? `${dt(language, "uploadImages")}...` : dt(language, "galleryPreview")}</p>
              </label>
            </div>
            {form.campusImages.length ? (
              <div className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                {form.campusImages.map((imageUrl) => (
                  <div key={imageUrl} className="rounded-2xl border border-slate-200 p-3">
                    <img src={getApiAssetUrl(imageUrl)} alt="Campus" className="h-28 w-full rounded-xl object-cover" />
                    <button
                      type="button"
                      onClick={() => setForm((current) => ({ ...current, campusImages: current.campusImages.filter((item) => item !== imageUrl) }))}
                      className="mt-3 rounded-full border border-rose-200 px-3 py-1 text-xs font-medium text-rose-700"
                    >
                      {dt(language, "removeImage")}
                    </button>
                  </div>
                ))}
              </div>
            ) : null}
          </div>

          <label className="flex items-center gap-3 rounded-2xl border border-slate-200 px-4 py-3">
            <input type="checkbox" checked={form.featured} onChange={(event) => setForm((current) => ({ ...current, featured: event.target.checked }))} />
            <span className="text-sm font-medium text-slate-700">{dt(language, "featureUniversity")}</span>
          </label>

          <div className="flex flex-wrap gap-3">
            <button type="submit" disabled={saving || uploadingLogo || uploadingGallery} className="inline-flex items-center gap-2 rounded-xl bg-slate-950 px-5 py-3 font-semibold text-white disabled:opacity-50">
              <Plus className="h-4 w-4" />
              {saving ? (language === "ar" ? "جارٍ الحفظ..." : "Saving...") : editingId ? dt(language, "updateUniversity") : dt(language, "createUniversity")}
            </button>
            <button type="button" disabled={saving || uploadingLogo || uploadingGallery} onClick={resetForm} className="rounded-xl border border-slate-200 px-5 py-3 font-semibold text-slate-700 disabled:opacity-50">
              {dt(language, "clearForm")}
            </button>
          </div>
        </form>
      </section>}

      <section className="min-w-0 space-y-4" aria-busy={loading}>
        <div className="panel flex flex-wrap items-center justify-between gap-4 p-5">
          <div><h2 className="font-semibold text-slate-900">{language === "ar" ? "دليل الجامعات" : "University catalog"}</h2><p className="mt-1 text-xs text-slate-500" role="status">{filteredUniversities.length} / {universities.length} {language === "ar" ? "جامعة" : "universities"}</p></div>
          <div className="relative w-full min-w-0 sm:w-80">
            <Search className="pointer-events-none absolute start-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
            <input type="search" value={search} onChange={(event) => setSearch(event.target.value)} aria-label={language === "ar" ? "البحث في الجامعات" : "Search universities"} placeholder={language === "ar" ? "ابحث بالجامعة أو الدولة أو المدينة..." : "Search university, country or city..."} className="w-full min-w-0 rounded-xl border border-slate-200 py-3 ps-10 pe-10 text-sm outline-none focus:ring" />
            {search && <button type="button" onClick={() => setSearch("")} aria-label={language === "ar" ? "مسح البحث" : "Clear search"} className="absolute end-3 top-1/2 -translate-y-1/2 rounded-md p-1 text-slate-400 hover:text-slate-700"><X className="h-4 w-4" /></button>}
          </div>
        </div>
        {filteredUniversities.map((university) => (
          <article key={university._id} className="university-list-card panel min-w-0 p-5 sm:p-6">
            <div className="flex min-w-0 flex-col gap-5 lg:flex-row lg:items-center lg:justify-between">
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-3">
                  <div className="relative flex h-14 w-14 shrink-0 items-center justify-center rounded-xl bg-slate-50 text-blue-700">
                    <Building2 className="h-6 w-6" />
                    {university.logo && <img src={getApiAssetUrl(university.logo)} alt={university.name} onError={(event) => { event.currentTarget.style.display = "none"; }} className="absolute inset-0 h-full w-full rounded-xl bg-white object-contain" />}
                  </div>
                  <div className="min-w-0 flex-1">
                <div className="flex flex-wrap items-center gap-2">
                  <h3 className="break-words text-lg font-semibold text-slate-900">{university.name}</h3>
                  {university.featured ? <span className="rounded-full bg-amber-100 px-3 py-1 text-xs font-semibold text-amber-700">{dt(language, "featured")}</span> : null}
                  {university.isPartnerInstitution ? <span className="rounded-full bg-emerald-100 px-3 py-1 text-xs font-semibold text-emerald-700">{dt(language, "partner")}</span> : null}
                </div>
                <p className="mt-1 flex items-center gap-1.5 text-sm text-slate-500">
                  <MapPin className="h-3.5 w-3.5 shrink-0" />
                  <span className="break-words">
                  {tv(university.country?.name)}
                  {university.city ? ` - ${university.city}` : ""}
                  </span>
                </p>
                  </div>
                </div>
                <div className="mt-3 flex flex-wrap gap-3 text-xs text-slate-500">
                  {university.language ? <span className="rounded-full bg-slate-100 px-3 py-1">{language === "ar" ? `اللغة: ${university.language}` : `Language: ${university.language}`}</span> : null}
                  <span className="rounded-full bg-slate-100 px-3 py-1">{language === "ar" ? `الطلاب: ${university.studentCount || 0}` : `Students: ${university.studentCount || 0}`}</span>
                  <span className="rounded-full bg-slate-100 px-3 py-1">{language === "ar" ? `التخصصات: ${university.specialtyCount || 0}` : `Specialties: ${university.specialtyCount || 0}`}</span>
                  <span className="rounded-full bg-slate-100 px-3 py-1">{dt(language, "rankingLabel")}: {university.ranking || dt(language, "notAvailable")}</span>
                  <span className="rounded-full bg-slate-100 px-3 py-1">
                    {dt(language, "tuitionLabel")}: {formatCurrency(university.tuitionRange?.min)} - {formatCurrency(university.tuitionRange?.max)}
                  </span>
                </div>
                {university.overview ? <p className="mt-3 line-clamp-2 break-words text-sm leading-6 text-slate-500">{university.overview}</p> : null}
              </div>
              <div className="flex shrink-0 flex-wrap gap-2 border-t border-slate-100 pt-4 lg:border-t-0 lg:pt-0">
                <button type="button" disabled={saving || uploadingLogo || uploadingGallery} onClick={() => startEdit(university)} className="inline-flex items-center gap-2 rounded-xl border border-slate-200 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50 disabled:opacity-50">
                  <PencilLine className="h-4 w-4" />
                  {dt(language, "edit")}
                </button>
                <button type="button" disabled={saving || uploadingLogo || uploadingGallery} onClick={() => handleDelete(university._id)} className="inline-flex items-center gap-2 rounded-xl border border-rose-200 px-4 py-2 text-sm font-medium text-rose-700 hover:bg-rose-50 disabled:opacity-50">
                  <Trash2 className="h-4 w-4" />
                  {dt(language, "delete")}
                </button>
              </div>
            </div>
          </article>
        ))}
        {loading && <div className="panel p-10 text-center text-sm text-slate-500">{language === "ar" ? "جارٍ تحميل الجامعات..." : "Loading universities..."}</div>}
        {!loading && filteredUniversities.length === 0 && <div className="panel p-10 text-center"><Search className="mx-auto h-8 w-8 text-slate-300" /><p className="mt-3 font-medium text-slate-600">{language === "ar" ? "لا توجد جامعات لعرضها" : "No universities to display"}</p><p className="mt-1 text-sm text-slate-400">{language === "ar" ? "غيّر كلمات البحث أو أضف جامعة جديدة." : "Try another search or add a new university."}</p></div>}
      </section>
    </div>
  );
};
