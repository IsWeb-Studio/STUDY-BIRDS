import { useEffect, useMemo, useRef, useState, type FormEvent } from "react";
import { GraduationCap, PencilLine, Plus, Search, Trash2, X } from "lucide-react";

import { useLanguage } from "../../hooks/useLanguage";
import { getApiAssetUrl } from "../../lib/api";
import { adminService } from "../../services/adminService";
import type { StudyField } from "../../types";

import { getErrorMessage } from "../../utils/errors";
import { dt } from "../../utils/dashboardTranslations";

const emptyStudyFieldForm = {
  name: "",
  description: "",
  image: "",
  featured: true,
  sortOrder: "0",
};


export const AdminStudyFieldsPage = () => {
  const { language, t } = useLanguage();
  const [studyFields, setStudyFields] = useState<StudyField[]>([]);
  const [studyFieldForm, setStudyFieldForm] = useState(emptyStudyFieldForm);
  const [editingStudyFieldId, setEditingStudyFieldId] = useState<string | null>(null);
  const [formError, setFormError] = useState("");
  const [uploadingStudyFieldImage, setUploadingStudyFieldImage] = useState(false);
  const [search, setSearch] = useState("");
  const [editorOpen, setEditorOpen] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const editorRef = useRef<HTMLElement>(null);
  const filtered = useMemo(() => {
    const query = search.trim().toLocaleLowerCase();
    return studyFields.filter(row => [row.name, row.description].filter(Boolean).join(" ").toLocaleLowerCase().includes(query));
  }, [studyFields, search]);
  const loadData = async () => { setStudyFields(await adminService.getStudyFields()); };
  useEffect(() => {
    setLoading(true);
    loadData().catch(error => setFormError(getErrorMessage(error, dt(language,"loadContentFailed")))).finally(() => setLoading(false));
  }, [language]);
  useEffect(() => { if(editorOpen) editorRef.current?.scrollIntoView({behavior:"smooth",block:"start"}); }, [editorOpen, editingStudyFieldId]);
  const resetStudyFieldForm = () => {
    setEditingStudyFieldId(null);
    setStudyFieldForm(emptyStudyFieldForm);
  };

  const submitStudyField = async (event: FormEvent) => {
    event.preventDefault();
    if (saving || uploadingStudyFieldImage) return;
    setSaving(true);
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
      setEditorOpen(false);
      await loadData();
    } catch (error) {
      setFormError(getErrorMessage(error, dt(language, "saveContentFailed")));
    } finally {
      setSaving(false);
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


  const handleDelete = async (id: string) => {
    if (saving || uploadingStudyFieldImage || !window.confirm(language === "ar" ? "هل تريد حذف هذا السجل؟" : "Delete this record?")) return;
    setSaving(true); setFormError("");
    try {
      await adminService.removeStudyField(id);
      setStudyFields(current => current.filter(row => row._id !== id));
      if(editingStudyFieldId === id) { resetStudyFieldForm(); setEditorOpen(false); }
    } catch(error) { setFormError(getErrorMessage(error, dt(language,"saveContentFailed"))); }
    finally { setSaving(false); }
  };
  return <div className="min-w-0 space-y-6">
    <header className="panel flex flex-wrap items-center justify-between gap-4 p-5 sm:p-6">
      <div className="flex min-w-0 items-center gap-3">
        <div className="rounded-xl bg-blue-50 p-3 text-blue-700"><GraduationCap className="h-6 w-6" /></div>
        <div><h1 className="text-2xl font-bold text-slate-900">{language === "ar" ? "إدارة مجالات الدراسة" : "Study field management"}</h1><p className="mt-1 text-sm text-slate-500">{language === "ar" ? "إدارة مجالات الدراسة التي تظهر في الموقع وفلاتر البرامج." : "Manage study fields shown on the website and in program filters."}</p></div>
      </div>
      <button type="button" disabled={saving || uploadingStudyFieldImage} onClick={() => { resetStudyFieldForm(); setFormError(""); setEditorOpen(true); }} className="inline-flex items-center gap-2 rounded-xl bg-slate-950 px-5 py-3 text-sm font-semibold text-white hover:bg-slate-800 disabled:opacity-50"><Plus className="h-4 w-4" />{language === "ar" ? "إضافة مجال دراسة" : "Add study field"}</button>
    </header>
    {formError && <div role="alert" className="rounded-xl border border-rose-200 bg-rose-50 p-4 text-sm text-rose-700">{formError}</div>}
    {editorOpen && <section ref={editorRef} className="panel min-w-0 scroll-mt-6 p-5 sm:p-7">
      <div className="flex items-center gap-3"><h2 className="text-xl font-semibold text-slate-900">{editingStudyFieldId ? (language === "ar" ? "تعديل البيانات" : "Edit details") : (language === "ar" ? "إضافة مجال دراسة" : "Add study field")}</h2><button type="button" disabled={saving || uploadingStudyFieldImage} onClick={() => setEditorOpen(false)} aria-label={language === "ar" ? "إغلاق النموذج" : "Close editor"} className="ms-auto rounded-xl p-2 text-slate-500 hover:bg-slate-100"><X className="h-5 w-5" /></button></div>
        <form onSubmit={submitStudyField} className="mt-6 space-y-4">
<fieldset disabled={saving || uploadingStudyFieldImage} className="min-w-0 space-y-4">
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
                  className="mt-3 rounded-xl border border-rose-200 px-3 py-1 text-xs font-medium text-rose-700"
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
            <button type="submit" className="inline-flex items-center gap-2 rounded-xl bg-slate-950 px-5 py-3 font-semibold text-white">
              <Plus className="h-4 w-4" />
              {editingStudyFieldId ? (language === "ar" ? "تحديث التخصص" : "Update field") : language === "ar" ? "إضافة تخصص" : "Create field"}
            </button>
            <button type="button" onClick={resetStudyFieldForm} className="rounded-xl border border-slate-200 px-5 py-3 font-semibold text-slate-700">
              {dt(language, "clearForm")}
            </button>
          </div>
        </fieldset></form>
    </section>}
    <section className="panel flex flex-col gap-3 p-4 sm:flex-row sm:items-center sm:justify-between sm:p-5">
      <div className="relative w-full sm:max-w-xl"><Search className="pointer-events-none absolute start-4 top-1/2 h-5 w-5 -translate-y-1/2 text-slate-400" /><input type="search" value={search} onChange={event => setSearch(event.target.value)} placeholder={language === "ar" ? "ابحث باسم مجال الدراسة أو الوصف..." : "Search study field name or description..."} aria-label={language === "ar" ? "ابحث باسم مجال الدراسة أو الوصف..." : "Search study field name or description..."} className="w-full rounded-xl border border-slate-200 bg-white py-3 pe-4 ps-12 text-sm outline-none focus:border-blue-400 focus:ring-2 focus:ring-blue-100" /></div>
      <p className="shrink-0 text-sm text-slate-500">{filtered.length} / {studyFields.length} {language === "ar" ? "سجل" : "records"}</p>
    </section>
    <section className="space-y-4">
      {!loading && <>          {filtered.map((studyField) => (
            <div key={studyField._id} className="panel min-w-0 p-5 sm:p-6">
              <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                <div className="min-w-0 flex-1">
                  {studyField.image ? <img src={getApiAssetUrl(studyField.image)} alt={studyField.name} className="h-40 w-full rounded-3xl object-cover" /> : null}
                  <div className="mt-4 flex flex-wrap items-center gap-2">
                    <p className="text-lg font-semibold text-slate-900">{studyField.name}</p>
                    {studyField.featured ? <span className="rounded-xl bg-amber-100 px-3 py-1 text-xs font-semibold text-amber-700">{dt(language, "featured")}</span> : null}
                    <span className="rounded-xl bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-600">{language === "ar" ? `الترتيب ${studyField.sortOrder || 0}` : `Order ${studyField.sortOrder || 0}`}</span>
                  </div>
                  {studyField.description ? <p className="mt-3 line-clamp-2 break-words text-sm leading-6 text-slate-500">{studyField.description}</p> : null}
                </div>
                <div className="flex flex-wrap gap-2">
                  <button
                    type="button" disabled={saving || uploadingStudyFieldImage}
                    onClick={() => {
                      setFormError("");
                      setEditorOpen(true);
                      setEditingStudyFieldId(studyField._id);
                      setStudyFieldForm({
                        name: studyField.name,
                        description: studyField.description || "",
                        image: studyField.image || "",
                        featured: Boolean(studyField.featured),
                        sortOrder: String(studyField.sortOrder || 0),
                      });
                    }}
                    className="inline-flex items-center gap-2 rounded-xl border border-slate-200 px-4 py-2 font-medium text-slate-700"
                  >
                    <PencilLine className="h-4 w-4" />
                    {dt(language, "edit")}
                  </button>
                  <button type="button" disabled={saving || uploadingStudyFieldImage} onClick={() => handleDelete(studyField._id)} className="inline-flex items-center gap-2 rounded-xl border border-rose-200 px-4 py-2 font-medium text-rose-700">
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
