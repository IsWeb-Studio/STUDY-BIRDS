import { useEffect, useMemo, useRef, useState, type FormEvent } from "react";
import { BookOpenText, Check, ChevronDown, PencilLine, Plus, Search, Trash2, X } from "lucide-react";
import { ArticleContentFields } from "../../components/admin/ArticleContentFields";
import { useLanguage } from "../../hooks/useLanguage";
import { getApiAssetUrl } from "../../lib/api";
import { adminService } from "../../services/adminService";
import { programService } from "../../services/programService";
import { universityService } from "../../services/universityService";
import type { Program, StudyField, University } from "../../types";
import { createEmptyArticleBodies, createEmptyArticleHeadings, normalizeArticleBodies, normalizeArticleHeadings } from "../../constants/articleContent";
import { PROGRAM_DEGREE_LEVELS, PROGRAM_INTAKES } from "../../constants/programOptions";
import { getErrorMessage } from "../../utils/errors";
import { formatCurrency, formatDate } from "../../utils/format";
import { dt } from "../../utils/dashboardTranslations";
import { getPaginatedItems } from "../../utils/pagination";

const SearchableSelect = ({
  value, onChange, options, placeholder, required,
}: {
  value: string;
  onChange: (v: string) => void;
  options: { value: string; label: string }[];
  placeholder: string;
  required?: boolean;
}) => {
  const { language } = useLanguage();
  const [open, setOpen] = useState(false);
  const [search, setSearch] = useState("");
  const ref = useRef<HTMLDivElement>(null);
  const filtered = options.filter((o) => o.label.toLowerCase().includes(search.toLowerCase()));
  const selected = options.find((o) => o.value === value);

  useEffect(() => {
    const close = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", close);
    return () => document.removeEventListener("mousedown", close);
  }, []);

  return (
    <div ref={ref} className="relative" onKeyDown={(event) => { if (event.key === "Escape") { event.stopPropagation(); setOpen(false); } }}>
      <button
        type="button"
        aria-expanded={open}
        aria-label={placeholder}
        onClick={() => { setOpen((o) => !o); setSearch(""); }}
        className="flex min-h-12 w-full items-center justify-between gap-3 rounded-xl border border-slate-200 px-4 py-3 text-start outline-none focus:ring"
      >
        <span className={selected ? "text-slate-900" : "text-slate-400"}>{selected?.label || placeholder}</span>
        <ChevronDown className={`h-4 w-4 text-slate-400 transition-transform ${open ? "rotate-180" : ""}`} />
      </button>
      {open && (
        <div className="absolute z-50 mt-1 w-full overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-xl">
          <div className="p-2">
            <div className="relative">
              <Search className="pointer-events-none absolute start-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
              <input
                autoFocus
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                aria-label={language === "ar" ? "البحث في الخيارات" : "Search options"}
                onKeyDown={(event) => { if (event.key === "Enter") event.preventDefault(); }}
                placeholder={language === "ar" ? "بحث..." : "Search..."}
                className="w-full rounded-xl border border-slate-200 py-2 ps-9 pe-4 text-sm outline-none focus:ring"
              />
            </div>
          </div>
          <div className="max-h-52 overflow-y-auto pb-2">
            {!required && (
              <button type="button" onClick={() => { onChange(""); setOpen(false); }}
                className="w-full px-4 py-2 text-start text-sm text-slate-400 hover:bg-slate-50">
                {placeholder}
              </button>
            )}
            {filtered.map((o) => (
              <button key={o.value} type="button"
                onClick={() => { onChange(o.value); setOpen(false); }}
                className={`w-full px-4 py-2 text-start text-sm hover:bg-slate-50 ${o.value === value ? "font-semibold text-slate-900 bg-slate-50" : "text-slate-700"}`}>
                {o.label}
              </button>
            ))}
            {filtered.length === 0 && (
              <p className="px-4 py-3 text-center text-sm text-slate-400">{language === "ar" ? "لا توجد نتائج" : "No results"}</p>
            )}
          </div>
        </div>
      )}
    </div>
  );
};

const SectionHeader = ({ title }: { title: string }) => (
  <div className="flex items-center gap-3 pt-2">
    <span className="text-xs font-semibold uppercase tracking-widest text-slate-400">{title}</span>
    <div className="flex-1 border-t border-slate-100" />
  </div>
);

const emptyProgramForm = {
  title: "",
  university: "",
  degreeLevel: "",
  fieldOfStudy: "",
  fieldsOfStudy: [] as string[],
  language: "",
  duration: "",
  tuition: "",
  partnerTuition: "",
  intake: "",
  applicationDeadline: "",
  popularity: "",
  summary: "",
  requirements: "",
  careerOpportunities: "",
  requiredDocumentTypes: ["passport", "biometric-photo", "latest-qualification"],
  articleTitle: "",
  articleTitleColor: "#0f172a",
  articleHeadingColor: "#0f172a",
  articleBodyColor: "#475569",
  articleHeadings: createEmptyArticleHeadings(),
  articleBodies: createEmptyArticleBodies(),
  featured: false,
  coverImage: "",
};

const appendArticleItem = (items: string[]) => [...items, ""];
const removeArticleItem = (items: string[], index: number) => (items.length > 1 ? items.filter((_, itemIndex) => itemIndex !== index) : items);

export const AdminProgramsPage = () => {
  const { language, t } = useLanguage();
  const [programs, setPrograms] = useState<Program[]>([]);
  const [universities, setUniversities] = useState<University[]>([]);
  const [studyFields, setStudyFields] = useState<StudyField[]>([]);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState(emptyProgramForm);
  const [programSearch, setProgramSearch] = useState("");
  const [formError, setFormError] = useState("");
  const [uploadingCover, setUploadingCover] = useState(false);
  const [editorOpen, setEditorOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const editorRef = useRef<HTMLElement>(null);

  useEffect(() => {
    if (editorOpen) editorRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
  }, [editorOpen, editingId]);

  const loadData = async () => {
    const [programsData, universitiesData, studyFieldsData] = await Promise.all([
      programService.getAll(),
      universityService.getAll(),
      adminService.getStudyFields(),
    ]);
    setPrograms(getPaginatedItems(programsData));
    setUniversities(getPaginatedItems(universitiesData));
    setStudyFields(studyFieldsData);
  };

  useEffect(() => {
    loadData().catch((error) => setFormError(getErrorMessage(error, dt(language, "loadProgramsFailed"))));
  }, [language]);

  const resetForm = () => {
    setEditingId(null);
    setForm(emptyProgramForm);
  };

  const startEdit = async (item: Program) => {
    let program: Program;
    try { program = await programService.getById(item._id); }
    catch (issue) { setFormError(getErrorMessage(issue, "Unable to load program")); return; }
    const articleItemCount = Math.max(1, program.articleHeadings?.length || 0, program.articleBodies?.length || 0);
    setEditingId(program._id);
    setEditorOpen(true);
    setForm({
      title: program.title || "",
      university: program.university?._id || "",
      degreeLevel: program.degreeLevel || "",
      fieldOfStudy: program.fieldOfStudy || "",
      fieldsOfStudy: program.fieldsOfStudy?.length ? program.fieldsOfStudy : program.fieldOfStudy ? [program.fieldOfStudy] : [],
      language: program.language || "",
      duration: program.duration || "",
      tuition: typeof program.tuition === "number" ? String(program.tuition) : "",
      partnerTuition: typeof program.partnerTuition === "number" ? String(program.partnerTuition) : "",
      intake: program.intake || "",
      applicationDeadline: program.applicationDeadline ? new Date(program.applicationDeadline).toISOString().slice(0, 10) : "",
      popularity: typeof program.popularity === "number" ? String(program.popularity) : "",
      summary: program.summary || "",
      requirements: program.requirements?.join("\n") || "",
      careerOpportunities: program.careerOpportunities?.join("\n") || "",
      requiredDocumentTypes: program.requiredDocumentTypes ?? ["passport", "biometric-photo", "latest-qualification"],
      articleTitle: program.articleTitle || "",
      articleTitleColor: program.articleTitleColor || "#0f172a",
      articleHeadingColor: program.articleHeadingColor || "#0f172a",
      articleBodyColor: program.articleBodyColor || "#475569",
      articleHeadings: normalizeArticleHeadings(program.articleHeadings, articleItemCount),
      articleBodies: normalizeArticleBodies(program.articleBodies, articleItemCount),
      featured: Boolean(program.featured),
      coverImage: program.coverImage || "",
    });
  };

  const handleCoverUpload = async (fileList: FileList | null) => {
    if (!fileList?.length) return;
    setFormError("");
    setUploadingCover(true);
    try {
      const coverImage = await programService.uploadCoverImage(fileList[0]);
      setForm((current) => ({ ...current, coverImage }));
    } catch (error) {
      setFormError(getErrorMessage(error, dt(language, "imageUploadFailed")));
    } finally {
      setUploadingCover(false);
    }
  };

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    setFormError("");

    if (!form.university || !form.degreeLevel || !form.fieldOfStudy) {
      setFormError(language === "ar" ? "اختر الجامعة والدرجة العلمية ومجال الدراسة الأساسي." : "Select a university, degree level and primary study field.");
      return;
    }
    setSaving(true);
    const payload = {
      requiredDocumentTypes: form.requiredDocumentTypes,
      title: form.title,
      university: form.university,
      degreeLevel: form.degreeLevel,
      fieldOfStudy: form.fieldOfStudy || form.fieldsOfStudy[0] || "",
      fieldsOfStudy: Array.from(new Set([form.fieldOfStudy, ...form.fieldsOfStudy].filter(Boolean))),
      language: form.language || undefined,
      duration: form.duration || undefined,
      tuition: form.tuition ? Number(form.tuition) : undefined,
      partnerTuition: form.partnerTuition ? Number(form.partnerTuition) : undefined,
      intake: form.intake || undefined,
      applicationDeadline: form.applicationDeadline || undefined,
      popularity: form.popularity ? Number(form.popularity) : undefined,
      summary: form.summary || undefined,
      articleTitle: form.articleTitle.trim() || undefined,
      articleTitleColor: form.articleTitleColor || "#0f172a",
      articleHeadingColor: form.articleHeadingColor || "#0f172a",
      articleBodyColor: form.articleBodyColor || "#475569",
      articleHeadings: form.articleHeadings.map((item) => item.trim()).filter(Boolean),
      articleBodies: form.articleBodies.map((item) => item.trim()).filter(Boolean),
      requirements: form.requirements.split("\n").map((item) => item.trim()).filter(Boolean),
      careerOpportunities: form.careerOpportunities.split("\n").map((item) => item.trim()).filter(Boolean),
      featured: form.featured,
      coverImage: form.coverImage || undefined,
    };

    try {
      if (editingId) {
        await programService.update(editingId, payload);
      } else {
        await programService.create(payload);
      }
      resetForm();
      setEditorOpen(false);
      await loadData();
    } catch (error) {
      setFormError(getErrorMessage(error, dt(language, "saveProgramFailed")));
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id: string) => {
    setFormError("");
    try {
      await programService.remove(id);
      setPrograms((current) => current.filter((item) => item._id !== id));
      if (editingId === id) {
        resetForm();
      }
    } catch (error) {
      setFormError(getErrorMessage(error, dt(language, "deleteProgramFailed")));
    }
  };

  const filteredPrograms = useMemo(() => {
    const q = programSearch.trim().toLowerCase();
    if (!q) return programs;
    return programs.filter(
      (p) =>
        p.title.toLowerCase().includes(q) ||
        (p.university?.name || "").toLowerCase().includes(q) ||
        (p.fieldOfStudy || "").toLowerCase().includes(q) ||
        (p.degreeLevel || "").toLowerCase().includes(q) ||
        (p.language || "").toLowerCase().includes(q),
    );
  }, [programs, programSearch]);

  const studyFieldOptions =
    form.fieldOfStudy && !studyFields.some((studyField) => studyField.name === form.fieldOfStudy)
      ? [{ _id: "current-study-field", name: form.fieldOfStudy }, ...studyFields]
      : studyFields;

  return (
    <div className="min-w-0 space-y-6">
      <header className="panel flex flex-wrap items-center justify-between gap-4 p-5 sm:p-6">
        <div className="flex items-center gap-3">
          <div className="rounded-xl bg-blue-50 p-3 text-blue-700"><BookOpenText className="h-6 w-6" /></div>
          <div><h1 className="text-2xl font-bold text-slate-900">{dt(language, "programCatalogControl")}</h1><p className="mt-1 text-sm text-slate-500">{dt(language, "programCatalogHelp")}</p></div>
        </div>
        <button type="button" onClick={() => { resetForm(); setFormError(""); setEditorOpen(true); }} className="inline-flex items-center gap-2 rounded-xl bg-slate-950 px-5 py-3 text-sm font-semibold text-white hover:bg-slate-800"><Plus className="h-4 w-4" />{dt(language, "createProgram")}</button>
      </header>
      {!editorOpen && formError && <div role="alert" className="rounded-xl border border-rose-200 bg-rose-50 p-4 text-sm text-rose-700">{formError}</div>}
      {editorOpen && <section ref={editorRef} className="panel scroll-mt-6 p-5 sm:p-7">
        <div className="flex items-center gap-3">
          <div className="rounded-2xl bg-slate-100 p-3 text-slate-700">
            <BookOpenText className="h-5 w-5" />
          </div>
          <div>
            <h2 className="text-xl font-semibold text-slate-900">{editingId ? dt(language, "updateProgram") : dt(language, "createProgram")}</h2>
            <p className="mt-1 text-sm text-slate-500">{dt(language, "programCatalogHelp")}</p>
          </div>
          <button type="button" disabled={saving} onClick={() => setEditorOpen(false)} aria-label={language === "ar" ? "إغلاق النموذج" : "Close editor"} className="ms-auto rounded-xl p-2 text-slate-500 hover:bg-slate-100"><X className="h-5 w-5" /></button>
        </div>
        {formError ? <div className="mt-5 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{formError}</div> : null}
        <form onSubmit={handleSubmit} className="mt-6 space-y-5">
          <SectionHeader title={language === "ar" ? "المعلومات الأساسية" : "Basic Information"} />

          <div className="grid gap-4 md:grid-cols-2">
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{dt(language, "programTitle")}</span>
              <input value={form.title} onChange={(event) => setForm((current) => ({ ...current, title: event.target.value }))} required className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{t("university")}</span>
              <SearchableSelect
                value={form.university}
                onChange={(v) => setForm((c) => ({ ...c, university: v }))}
                options={universities.map((u) => ({ value: u._id, label: u.name }))}
                placeholder={dt(language, "selectUniversity")}
                required
              />
            </label>
          </div>

          <div className="grid gap-4 md:grid-cols-3">
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{dt(language, "degreeLevel")}</span>
              <SearchableSelect
                value={form.degreeLevel}
                onChange={(v) => setForm((c) => ({ ...c, degreeLevel: v }))}
                options={PROGRAM_DEGREE_LEVELS.map((o) => ({ value: o.value, label: t(o.translationKey) }))}
                placeholder={dt(language, "bachelorMasterDiploma")}
                required
              />
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{t("fieldOfStudy")}</span>
              <SearchableSelect
                value={form.fieldOfStudy}
                onChange={(v) => setForm((c) => ({ ...c, fieldOfStudy: v, fieldsOfStudy: Array.from(new Set([v, ...c.fieldsOfStudy.filter((field) => field !== c.fieldOfStudy)].filter(Boolean))) }))}
                options={studyFieldOptions.map((sf) => ({ value: sf.name, label: sf.name }))}
                placeholder={language === "ar" ? "اختر مجال الدراسة" : "Select field of study"}
                required
              />
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "لغة البرنامج" : "Program language"}</span>
              <input value={form.language} onChange={(event) => setForm((current) => ({ ...current, language: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
            </label>
          </div>

          <SectionHeader title={language === "ar" ? "مجالات الدراسة الإضافية" : "Additional Study Fields"} />

          <div className="rounded-2xl border border-slate-200 p-4">
            <p className="text-sm font-medium text-slate-700">{language === "ar" ? "مجالات الدراسة" : "Study fields"}</p>
            <p className="mt-1 text-xs text-slate-500">
              {language === "ar"
                ? "اختر مجالًا أساسيًا بالأعلى، ويمكنك هنا إضافة مجالات أخرى مرتبطة بنفس البرنامج."
                : "Choose a primary field above, and add any other related study fields here."}
            </p>
            <div className="mt-4">
              <SearchableSelect
                value=""
                onChange={(value) => { if (value) setForm((current) => ({ ...current, fieldsOfStudy: Array.from(new Set([...current.fieldsOfStudy, value])) })); }}
                options={studyFieldOptions.filter((field) => field.name !== form.fieldOfStudy && !form.fieldsOfStudy.includes(field.name)).map((field) => ({ value: field.name, label: field.name }))}
                placeholder={language === "ar" ? "ابحث لإضافة مجال دراسة آخر" : "Search to add another study field"}
              />
            </div>
            <div className="mt-3 flex flex-wrap gap-2">
              {form.fieldOfStudy && <span className="inline-flex items-center gap-2 rounded-lg bg-blue-50 px-3 py-2 text-xs font-medium text-blue-800"><Check className="h-3.5 w-3.5" />{form.fieldOfStudy}<span className="text-blue-500">{language === "ar" ? "أساسي" : "Primary"}</span></span>}
              {form.fieldsOfStudy.filter((field) => field !== form.fieldOfStudy).map((field) => (
                <span key={field} className="inline-flex items-center gap-2 rounded-lg bg-slate-100 px-3 py-2 text-xs font-medium text-slate-700">
                  {field}
                  <button type="button" aria-label={`${language === "ar" ? "إزالة" : "Remove"} ${field}`} onClick={() => setForm((current) => ({ ...current, fieldsOfStudy: current.fieldsOfStudy.filter((item) => item !== field) }))} className="rounded p-1 hover:bg-slate-200"><X className="h-3 w-3" /></button>
                </span>
              ))}
            </div>
          </div>

          <SectionHeader title={language === "ar" ? "تفاصيل البرنامج" : "Program Details"} />

          <div className="grid gap-4 md:grid-cols-2">
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{dt(language, "duration")}</span>
              <input value={form.duration} onChange={(event) => setForm((current) => ({ ...current, duration: event.target.value }))} placeholder={dt(language, "fourYears")} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{t("intake")}</span>
              <select value={form.intake} onChange={(event) => setForm((current) => ({ ...current, intake: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring">
                <option value="">{dt(language, "fall2026")}</option>
                {PROGRAM_INTAKES.map((option) => (
                  <option key={option.value} value={option.value}>
                    {t(option.translationKey)}
                  </option>
                ))}
              </select>
            </label>
          </div>

          <SectionHeader title={language === "ar" ? "التسعير والمواعيد" : "Pricing & Dates"} />

          <div className="grid gap-4 md:grid-cols-3">
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{t("tuition")}</span>
              <input type="number" value={form.tuition} onChange={(event) => setForm((current) => ({ ...current, tuition: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{dt(language, "deadline")}</span>
              <input type="date" value={form.applicationDeadline} onChange={(event) => setForm((current) => ({ ...current, applicationDeadline: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{dt(language, "popularity")}</span>
              <input type="number" value={form.popularity} onChange={(event) => setForm((current) => ({ ...current, popularity: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
            </label>
          </div>

          <SectionHeader title={language === "ar" ? "الوسيط والصورة" : "Partner & Media"} />

          <div className="grid gap-4 md:grid-cols-2">
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{dt(language, "partnerTuition")}</span>
              <input type="number" value={form.partnerTuition} onChange={(event) => setForm((current) => ({ ...current, partnerTuition: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{dt(language, "programCoverImage")}</span>
              <input type="file" accept="image/*" onChange={(event) => handleCoverUpload(event.target.files)} className="w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm outline-none focus:ring" />
              <p className="mt-2 text-xs text-slate-500">{uploadingCover ? `${dt(language, "uploadImages")}...` : dt(language, "coverPreview")}</p>
            </label>
          </div>

          {form.coverImage ? (
            <div className="rounded-2xl border border-slate-200 p-4">
              <img src={getApiAssetUrl(form.coverImage)} alt="Program cover" className="h-44 w-full rounded-2xl object-cover" />
              <button type="button" onClick={() => setForm((current) => ({ ...current, coverImage: "" }))} className="mt-3 rounded-full border border-rose-200 px-3 py-1 text-xs font-medium text-rose-700">
                {dt(language, "removeImage")}
              </button>
            </div>
          ) : null}

          <SectionHeader title={language === "ar" ? "المحتوى والمتطلبات" : "Content & Requirements"} />

          <label className="block">
            <span className="mb-2 block text-sm font-medium text-slate-700">{dt(language, "summary")}</span>
            <textarea value={form.summary} onChange={(event) => setForm((current) => ({ ...current, summary: event.target.value }))} rows={4} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
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

          <SectionHeader title={language === "ar" ? "المستندات والإعدادات" : "Documents & Settings"} />

          <fieldset className="rounded-2xl border border-slate-200 p-4">
            <legend className="px-2 font-semibold">{language === 'ar' ? 'المستندات المطلوبة للتقديم' : 'Required application documents'}</legend>
            {Object.entries({passport: ['جواز السفر', 'Passport'], 'biometric-photo': ['صورة شخصية', 'Photo'], 'latest-qualification': ['آخر مؤهل', 'Latest qualification'], transcript: ['كشف الدرجات', 'Transcript'], 'language-certificate': ['شهادة اللغة', 'Language certificate'], other: ['مستند إضافي', 'Additional document']}).map(([key, labels]) => (
              <label key={key} className="flex min-h-11 items-center gap-3"><input type="checkbox" checked={form.requiredDocumentTypes.includes(key)} onChange={(e) => setForm(current => ({...current, requiredDocumentTypes: e.target.checked ? [...current.requiredDocumentTypes, key] : current.requiredDocumentTypes.filter(value => value !== key)}))} />{labels[language === 'ar' ? 0 : 1]}</label>
            ))}
          </fieldset>

          <label className="block">
            <span className="mb-2 block text-sm font-medium text-slate-700">{dt(language, "requirements")}</span>
            <textarea value={form.requirements} onChange={(event) => setForm((current) => ({ ...current, requirements: event.target.value }))} rows={4} placeholder={dt(language, "oneRequirementPerLine")} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
          </label>

          <label className="block">
            <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "مجالات العمل بعد التخرج" : "Career opportunities"}</span>
            <textarea value={form.careerOpportunities} onChange={(event) => setForm((current) => ({ ...current, careerOpportunities: event.target.value }))} rows={3} placeholder={language === "ar" ? "مجال في كل سطر، مثل: طبيب عام" : "One per line, e.g. General practitioner"} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
          </label>

          <label className="flex items-center gap-3 rounded-2xl border border-slate-200 px-4 py-3">
            <input type="checkbox" checked={form.featured} onChange={(event) => setForm((current) => ({ ...current, featured: event.target.checked }))} />
            <span className="text-sm font-medium text-slate-700">{dt(language, "featureProgram")}</span>
          </label>

          <div className="flex flex-wrap gap-3">
            <button type="submit" disabled={saving || uploadingCover} className="inline-flex items-center gap-2 rounded-xl bg-slate-950 px-5 py-3 font-semibold text-white disabled:cursor-wait disabled:opacity-50">
              <Plus className="h-4 w-4" />
              {saving ? (language === "ar" ? "جارٍ الحفظ..." : "Saving...") : editingId ? dt(language, "updateProgram") : dt(language, "createProgram")}
            </button>
            <button type="button" onClick={resetForm} className="rounded-full border border-slate-200 px-5 py-3 font-semibold text-slate-700">
              {dt(language, "clearForm")}
            </button>
          </div>
        </form>
      </section>}

      <section className="space-y-4">
        <div className="panel flex flex-wrap items-center justify-between gap-4 px-5 py-4">
          <div><h2 className="font-semibold text-slate-900">{language === "ar" ? "دليل البرامج" : "Program catalog"}</h2><p className="mt-1 text-xs text-slate-500">{filteredPrograms.length} / {programs.length} {language === "ar" ? "برنامج" : "programs"}</p></div>
          <div className="relative w-full sm:w-80">
            <Search className="pointer-events-none absolute start-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
            <input
              value={programSearch}
              onChange={(e) => setProgramSearch(e.target.value)}
              placeholder={dt(language, "searchPrograms")}
              className="w-full rounded-2xl border border-slate-200 py-2.5 ps-9 pe-4 text-sm outline-none focus:ring"
            />
          </div>
          {programSearch ? (
            <p className="mt-2 text-xs text-slate-500">
              {filteredPrograms.length} {dt(language, "programsFound")}
            </p>
          ) : null}
        </div>
        <div className="grid min-w-0 gap-4 md:grid-cols-2 2xl:grid-cols-3">
        {filteredPrograms.map((program) => (
          <div key={program._id} className="panel min-w-0 p-5 transition-shadow hover:shadow-md">
            <div className="flex h-full flex-col gap-4">
              <div>
                {program.coverImage ? <img src={getApiAssetUrl(program.coverImage)} alt={program.title} className="mb-4 h-36 w-full rounded-xl object-cover" /> : null}
                <div className="flex flex-wrap items-center gap-2">
                  <p className="break-words text-lg font-semibold text-slate-900">{program.title}</p>
                  {program.featured ? <span className="rounded-full bg-amber-100 px-3 py-1 text-xs font-semibold text-amber-700">{dt(language, "featured")}</span> : null}
                </div>
                <p className="mt-2 text-sm text-slate-500">
                  {program.university?.name || dt(language, "unknownUniversity")} - {program.degreeLevel} - {program.fieldOfStudy}
                </p>
                <div className="mt-3 flex flex-wrap gap-3 text-xs text-slate-500">
                  {program.language ? <span className="rounded-full bg-slate-100 px-3 py-1">{language === "ar" ? `لغة البرنامج: ${program.language}` : `Program language: ${program.language}`}</span> : null}
                  {program.fieldsOfStudy?.length ? (
                    <span className="rounded-full bg-slate-100 px-3 py-1">
                      {language === "ar" ? `المجالات: ${program.fieldsOfStudy.join("، ")}` : `Fields: ${program.fieldsOfStudy.join(", ")}`}
                    </span>
                  ) : null}
                  <span className="rounded-full bg-slate-100 px-3 py-1">{dt(language, "tuitionLabel")}: {formatCurrency(program.tuition)}</span>
                  {typeof program.partnerTuition === "number" ? <span className="rounded-full bg-emerald-50 px-3 py-1 text-emerald-700">{dt(language, "partnerTuition")}: {formatCurrency(program.partnerTuition)}</span> : null}
                  <span className="rounded-full bg-slate-100 px-3 py-1">{dt(language, "deadline")}: {formatDate(program.applicationDeadline)}</span>
                  <span className="rounded-full bg-slate-100 px-3 py-1">{dt(language, "programIntake")}: {program.intake || dt(language, "flexible")}</span>
                </div>
                {program.summary ? <p className="mt-4 line-clamp-2 text-sm leading-6 text-slate-600">{program.summary}</p> : null}
                {program.requirements?.length ? (
                  <div className="mt-4 flex flex-wrap gap-2">
                    {program.requirements.map((requirement) => (
                      <span key={requirement} className="rounded-full bg-slate-100 px-3 py-1 text-xs text-slate-600">
                        {requirement}
                      </span>
                    ))}
                  </div>
                ) : null}
              </div>
              <div className="mt-auto flex flex-wrap gap-2 border-t border-slate-100 pt-4">
                <button onClick={() => startEdit(program)} className="inline-flex items-center gap-2 rounded-full border border-slate-200 px-4 py-2 font-medium text-slate-700">
                  <PencilLine className="h-4 w-4" />
                  {dt(language, "edit")}
                </button>
                <button onClick={() => handleDelete(program._id)} className="inline-flex items-center gap-2 rounded-full border border-rose-200 px-4 py-2 font-medium text-rose-700">
                  <Trash2 className="h-4 w-4" />
                  {dt(language, "delete")}
                </button>
              </div>
            </div>
          </div>
        ))}
        </div>
        {filteredPrograms.length === 0 && <div className="panel p-10 text-center"><Search className="mx-auto h-8 w-8 text-slate-300" /><p className="mt-3 font-medium text-slate-600">{language === "ar" ? "لا توجد برامج لعرضها" : "No programs to display"}</p><p className="mt-1 text-sm text-slate-400">{language === "ar" ? "غيّر كلمات البحث أو أضف برنامجًا جديدًا." : "Try another search or add a new program."}</p></div>}
      </section>
    </div>
  );
};
