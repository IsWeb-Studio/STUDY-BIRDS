import { useEffect, useState, type FormEvent } from "react";
import { Image, PencilLine, Plus, Trash2 } from "lucide-react";
import { useLanguage } from "../../hooks/useLanguage";
import { adminService } from "../../services/adminService";
import type { Banner } from "../../types";
import { getErrorMessage } from "../../utils/errors";

const emptyForm: Partial<Banner> = {
  tag: "",
  title: "",
  subtitle: "",
  actionLabel: "اكتشف المزيد",
  destination: "universities",
  imageUrl: "",
  active: true,
  order: 0,
};

export const AdminBannersPage = () => {
  const { language } = useLanguage();
  const [banners, setBanners] = useState<Banner[]>([]);
  const [form, setForm] = useState<Partial<Banner>>(emptyForm);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [formError, setFormError] = useState("");
  const [uploading, setUploading] = useState(false);

  const ar = language === "ar";

  const load = async () => {
    const data = await adminService.getBanners();
    setBanners(data);
  };

  useEffect(() => {
    load().catch((e) => setFormError(getErrorMessage(e, ar ? "فشل تحميل البنرات" : "Failed to load banners")));
  }, []);

  const reset = () => {
    setEditingId(null);
    setForm(emptyForm);
  };

  const handleImageUpload = async (files: FileList | null) => {
    if (!files?.length) return;
    setUploading(true);
    setFormError("");
    try {
      const url = await adminService.uploadBannerImage(files[0]);
      setForm((f) => ({ ...f, imageUrl: url }));
    } catch (e) {
      setFormError(getErrorMessage(e, ar ? "فشل رفع الصورة" : "Image upload failed"));
    } finally {
      setUploading(false);
    }
  };

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setFormError("");
    try {
      if (editingId) {
        await adminService.updateBanner(editingId, form);
      } else {
        await adminService.createBanner(form);
      }
      reset();
      await load();
    } catch (e) {
      setFormError(getErrorMessage(e, ar ? "فشل حفظ البنر" : "Failed to save banner"));
    }
  };

  const field = (key: keyof Banner, value: string | number | boolean) =>
    setForm((f) => ({ ...f, [key]: value }));

  return (
    <div className="space-y-6">
      {formError ? (
        <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{formError}</div>
      ) : null}

      <section className="panel p-6">
        <div className="flex items-center gap-3">
          <div className="rounded-2xl bg-slate-100 p-3 text-slate-700">
            <Image className="h-5 w-5" />
          </div>
          <div>
            <h1 className="text-2xl font-semibold text-slate-900">{ar ? "إدارة البنرات" : "Banner Management"}</h1>
            <p className="mt-1 text-sm text-slate-500">
              {ar ? "البنرات تظهر فقط في تطبيق الموبايل." : "Banners appear only in the mobile app."}
            </p>
          </div>
        </div>

        <form onSubmit={submit} className="mt-6 space-y-4">
          <div className="grid gap-4 md:grid-cols-2">
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{ar ? "العنوان *" : "Title *"}</span>
              <input
                value={form.title ?? ""}
                onChange={(e) => field("title", e.target.value)}
                required
                className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
              />
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{ar ? "التاج (وسم صغير)" : "Tag"}</span>
              <input
                value={form.tag ?? ""}
                onChange={(e) => field("tag", e.target.value)}
                className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
              />
            </label>
          </div>
          <label className="block">
            <span className="mb-2 block text-sm font-medium text-slate-700">{ar ? "العنوان الفرعي" : "Subtitle"}</span>
            <input
              value={form.subtitle ?? ""}
              onChange={(e) => field("subtitle", e.target.value)}
              className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
            />
          </label>
          <div className="grid gap-4 md:grid-cols-2">
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{ar ? "نص الزر" : "Button Label"}</span>
              <input
                value={form.actionLabel ?? ""}
                onChange={(e) => field("actionLabel", e.target.value)}
                className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
              />
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{ar ? "الوجهة" : "Destination"}</span>
              <select
                value={form.destination ?? "universities"}
                onChange={(e) => field("destination", e.target.value)}
                className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
              >
                <option value="universities">{ar ? "الجامعات" : "Universities"}</option>
                <option value="programs">{ar ? "البرامج" : "Programs"}</option>
                <option value="apply">{ar ? "التقديم" : "Apply"}</option>
                <option value="services">{ar ? "الخدمات" : "Services"}</option>
              </select>
            </label>
          </div>
          <div className="grid gap-4 md:grid-cols-2">
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{ar ? "الترتيب" : "Order"}</span>
              <input
                type="number"
                value={form.order ?? 0}
                onChange={(e) => field("order", Number(e.target.value))}
                className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
              />
            </label>
            <label className="flex items-center gap-3 rounded-2xl border border-slate-200 px-4 py-3 self-end">
              <input
                type="checkbox"
                checked={form.active ?? true}
                onChange={(e) => field("active", e.target.checked)}
              />
              <span className="text-sm font-medium text-slate-700">{ar ? "نشط (يظهر للمستخدمين)" : "Active (visible to users)"}</span>
            </label>
          </div>

          <div className="rounded-2xl border border-slate-200 p-4">
            <p className="text-sm font-medium text-slate-700">{ar ? "صورة البنر" : "Banner Image"}</p>
            <input
              type="file"
              accept="image/*"
              onChange={(e) => handleImageUpload(e.target.files)}
              className="mt-4 w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm"
            />
            <p className="mt-2 text-xs text-slate-500">
              {uploading ? (ar ? "جاري الرفع..." : "Uploading...") : ar ? "ارفع صورة البنر (اختياري)" : "Upload banner image (optional)"}
            </p>
            {form.imageUrl ? (
              <div className="mt-4 rounded-2xl border border-slate-200 p-3">
                <img src={form.imageUrl} alt="Banner preview" className="h-32 w-full rounded-xl object-cover" />
                <button
                  type="button"
                  onClick={() => field("imageUrl", "")}
                  className="mt-3 rounded-full border border-rose-200 px-3 py-1 text-xs font-medium text-rose-700"
                >
                  {ar ? "إزالة الصورة" : "Remove image"}
                </button>
              </div>
            ) : null}
          </div>

          <div className="flex flex-wrap gap-3">
            <button type="submit" className="inline-flex items-center gap-2 rounded-full bg-slate-950 px-5 py-3 font-semibold text-white">
              <Plus className="h-4 w-4" />
              {editingId ? (ar ? "تحديث البنر" : "Update Banner") : (ar ? "إضافة بنر" : "Add Banner")}
            </button>
            <button type="button" onClick={reset} className="rounded-full border border-slate-200 px-5 py-3 font-semibold text-slate-700">
              {ar ? "إلغاء" : "Cancel"}
            </button>
          </div>
        </form>
      </section>

      <section className="space-y-4">
        {banners.map((banner) => (
          <div key={banner._id} className="panel p-5">
            <div className="flex items-start gap-4">
              {banner.imageUrl ? (
                <img src={banner.imageUrl} alt={banner.title} className="h-24 w-40 shrink-0 rounded-xl object-cover" />
              ) : (
                <div className="flex h-24 w-40 shrink-0 items-center justify-center rounded-xl bg-slate-100 text-slate-400">
                  <Image className="h-8 w-8" />
                </div>
              )}
              <div className="min-w-0 flex-1">
                <div className="flex flex-wrap items-center gap-2">
                  {banner.tag ? <span className="rounded-full bg-orange-100 px-2 py-0.5 text-xs font-semibold text-orange-700">{banner.tag}</span> : null}
                  <p className="text-lg font-semibold text-slate-900">{banner.title}</p>
                  <span className={`rounded-full px-2 py-0.5 text-xs font-semibold ${banner.active ? "bg-emerald-100 text-emerald-700" : "bg-slate-100 text-slate-500"}`}>
                    {banner.active ? (ar ? "نشط" : "Active") : (ar ? "مخفي" : "Hidden")}
                  </span>
                  <span className="rounded-full bg-slate-100 px-2 py-0.5 text-xs text-slate-600">
                    {ar ? `ترتيب: ${banner.order ?? 0}` : `Order: ${banner.order ?? 0}`}
                  </span>
                </div>
                {banner.subtitle ? <p className="mt-1 text-sm text-slate-600">{banner.subtitle}</p> : null}
                <p className="mt-1 text-xs text-slate-400">
                  {ar ? `الوجهة: ${banner.destination}` : `Destination: ${banner.destination}`}
                  {banner.actionLabel ? ` · ${banner.actionLabel}` : ""}
                </p>
              </div>
              <div className="flex shrink-0 flex-wrap gap-2">
                <button
                  onClick={() => {
                    setEditingId(banner._id);
                    setForm({
                      tag: banner.tag ?? "",
                      title: banner.title,
                      subtitle: banner.subtitle ?? "",
                      actionLabel: banner.actionLabel ?? "اكتشف المزيد",
                      destination: banner.destination ?? "universities",
                      imageUrl: banner.imageUrl ?? "",
                      active: banner.active ?? true,
                      order: banner.order ?? 0,
                    });
                  }}
                  className="inline-flex items-center gap-2 rounded-full border border-slate-200 px-4 py-2 font-medium text-slate-700"
                >
                  <PencilLine className="h-4 w-4" />
                  {ar ? "تعديل" : "Edit"}
                </button>
                <button
                  onClick={() => adminService.removeBanner(banner._id).then(load)}
                  className="inline-flex items-center gap-2 rounded-full border border-rose-200 px-4 py-2 font-medium text-rose-700"
                >
                  <Trash2 className="h-4 w-4" />
                  {ar ? "حذف" : "Delete"}
                </button>
              </div>
            </div>
          </div>
        ))}
        {banners.length === 0 ? (
          <div className="panel flex flex-col items-center gap-3 p-12 text-center text-slate-500">
            <Image className="h-10 w-10 opacity-40" />
            <p className="text-sm">{ar ? "لا توجد بنرات بعد. أضف أول بنر أعلاه." : "No banners yet. Add your first banner above."}</p>
          </div>
        ) : null}
      </section>
    </div>
  );
};
