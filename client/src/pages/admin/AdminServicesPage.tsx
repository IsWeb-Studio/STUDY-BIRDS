import { useEffect, useState, type FormEvent } from "react";
import { Award, PencilLine, Plus, Trash2 } from "lucide-react";
import { useLanguage } from "../../hooks/useLanguage";
import { getApiAssetUrl } from "../../lib/api";
import { adminService } from "../../services/adminService";
import type { Country, OurService } from "../../types";
import { getErrorMessage } from "../../utils/errors";
import { dt } from "../../utils/dashboardTranslations";
import { repairMojibake } from "../../utils/textCodec";

const countryLabel = (country: Country) => country.name;
const normalizeService = (service: OurService): OurService => ({
  ...service,
  title: repairMojibake(service.title),
  detailTitle: repairMojibake(service.detailTitle),
  detailBody: repairMojibake(service.detailBody),
});

const JOURNEY_STAGES = [
  { value: "", labelAr: "— لا ترتبط بمرحلة —", labelEn: "— No journey link —" },
  { value: "visa",         labelAr: "التأشيرة",               labelEn: "Visa" },
  { value: "travel",       labelAr: "ترتيبات السفر",          labelEn: "Travel arrangements" },
  { value: "housing",      labelAr: "السكن",                  labelEn: "Accommodation" },
  { value: "arrival",      labelAr: "الوصول والاستقبال",      labelEn: "Arrival & pickup" },
  { value: "registration", labelAr: "التسجيل في الجامعة",     labelEn: "University registration" },
  { value: "residence",    labelAr: "الإقامة والدعم المستمر", labelEn: "Residence & support" },
];

const emptyServiceForm = {
  title: "",
  image: "",
  detailTitle: "",
  detailBody: "",
  detailImage: "",
  priceDescription: "",
  estimatedDuration: "",
  price: "0",
  durationDays: "0",
  journeyStage: "",
  featured: true,
  sortOrder: "0",
  country: "",
};

export const AdminServicesPage = () => {
  const { language } = useLanguage();
  const [services, setServices] = useState<OurService[]>([]);
  const [countries, setCountries] = useState<Country[]>([]);
  const [serviceForm, setServiceForm] = useState(emptyServiceForm);
  const [editingServiceId, setEditingServiceId] = useState<string | null>(null);
  const [uploadingServiceImage, setUploadingServiceImage] = useState(false);
  const [formError, setFormError] = useState("");

  const loadData = async () => {
    const [servicesData, countriesData] = await Promise.all([adminService.getOurServices(), adminService.getCountries()]);
    setServices(servicesData.map(normalizeService));
    setCountries(countriesData);
  };

  useEffect(() => {
    loadData().catch((error) => setFormError(getErrorMessage(error, dt(language, "loadContentFailed"))));
  }, [language]);

  const resetServiceForm = () => {
    setEditingServiceId(null);
    setServiceForm(emptyServiceForm);
  };

  const handleServiceImageUpload = async (fileList: FileList | null) => {
    if (!fileList?.length) return;
    setFormError("");
    setUploadingServiceImage(true);

    try {
      const imageUrl = await adminService.uploadOurServiceImage(fileList[0]);
      setServiceForm((current) => ({ ...current, image: imageUrl }));
    } catch (error) {
      setFormError(getErrorMessage(error, dt(language, "imageUploadFailed")));
    } finally {
      setUploadingServiceImage(false);
    }
  };

  const handleServiceDetailImageUpload = async (fileList: FileList | null) => {
    if (!fileList?.length) return;
    setFormError("");
    setUploadingServiceImage(true);

    try {
      const imageUrl = await adminService.uploadOurServiceImage(fileList[0]);
      setServiceForm((current) => ({ ...current, detailImage: imageUrl }));
    } catch (error) {
      setFormError(getErrorMessage(error, dt(language, "imageUploadFailed")));
    } finally {
      setUploadingServiceImage(false);
    }
  };

  const submitService = async (event: FormEvent) => {
    event.preventDefault();
    setFormError("");

    const payload = {
      title: serviceForm.title,
      image: serviceForm.image || "",
      detailTitle: serviceForm.detailTitle || serviceForm.title,
      detailBody: serviceForm.detailBody || "",
      detailImage: serviceForm.detailImage || serviceForm.image || "",
      priceDescription: serviceForm.priceDescription || "",
      estimatedDuration: serviceForm.estimatedDuration || "",
      price: Number(serviceForm.price || 0),
      durationDays: Number(serviceForm.durationDays || 0),
      journeyStage: serviceForm.journeyStage || "",
      featured: serviceForm.featured,
      sortOrder: Number(serviceForm.sortOrder || 0),
      country: serviceForm.country || null,
    };

    try {
      if (editingServiceId) {
        await adminService.updateOurService(editingServiceId, payload);
      } else {
        await adminService.createOurService(payload);
      }

      resetServiceForm();
      await loadData();
    } catch (error) {
      setFormError(getErrorMessage(error, dt(language, "saveContentFailed")));
    }
  };

  return (
    <div className="space-y-6">
      {formError ? <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{formError}</div> : null}

      <section className="panel p-6">
        <div className="flex items-center gap-3">
          <div className="rounded-2xl bg-slate-100 p-3 text-slate-700">
            <Award className="h-5 w-5" />
          </div>
          <div>
            <h1 className="text-2xl font-semibold text-slate-900">{dt(language, "servicesContent")}</h1>
            <p className="mt-1 text-sm text-slate-500">{dt(language, "servicesHelp")}</p>
          </div>
        </div>

        <form onSubmit={submitService} className="mt-6 space-y-4">
          <div className="grid gap-4 md:grid-cols-2">
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{dt(language, "serviceTitle")}</span>
              <input
                value={serviceForm.title}
                onChange={(event) => setServiceForm((current) => ({ ...current, title: event.target.value }))}
                required
                className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
              />
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "الترتيب" : "Sort order"}</span>
              <input
                type="number"
                value={serviceForm.sortOrder}
                onChange={(event) => setServiceForm((current) => ({ ...current, sortOrder: event.target.value }))}
                className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
              />
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "السعر (بالدولار)" : "Price (USD)"}</span>
              <input type="number" min="0" step="0.01"
                value={serviceForm.price}
                onChange={(e) => setServiceForm((c) => ({ ...c, price: e.target.value }))}
                className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
              />
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "المدة التقريبية (أيام)" : "Duration (days)"}</span>
              <input type="number" min="0"
                value={serviceForm.durationDays}
                onChange={(e) => setServiceForm((c) => ({ ...c, durationDays: e.target.value }))}
                className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
              />
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "وصف السعر (نص يظهر للطالب)" : "Price description (shown to student)"}</span>
              <input maxLength={200}
                value={serviceForm.priceDescription}
                onChange={(e) => setServiceForm((c) => ({ ...c, priceDescription: e.target.value }))}
                placeholder={language === "ar" ? "مثال: يبدأ من $50" : "e.g. Starting from $50"}
                className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
              />
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "مرحلة الرحلة المرتبطة" : "Linked journey stage"}</span>
              <select
                value={serviceForm.journeyStage}
                onChange={(e) => setServiceForm((c) => ({ ...c, journeyStage: e.target.value }))}
                className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
              >
                {JOURNEY_STAGES.map((s) => (
                  <option key={s.value} value={s.value}>{language === "ar" ? s.labelAr : s.labelEn}</option>
                ))}
              </select>
              <p className="mt-1 text-xs text-slate-400">{language === "ar" ? "عند إتمام طلب هذه الخدمة يتحدث هذا القسم في رحلة الطالب تلقائياً." : "When this service request is completed, the linked journey stage updates automatically."}</p>
            </label>
            <label className="block md:col-span-2">
              <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "الدولة" : "Country"}</span>
              <select
                value={serviceForm.country}
                onChange={(event) => setServiceForm((current) => ({ ...current, country: event.target.value }))}
                className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
              >
                <option value="">{language === "ar" ? "خدمة عامة لكل الدول" : "General service for all countries"}</option>
                {countries.map((country) => (
                  <option key={country._id} value={country._id}>
                    {countryLabel(country)}
                  </option>
                ))}
              </select>
            </label>
          </div>
          <div className="grid gap-4 md:grid-cols-2">
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">
                {language === "ar" ? "عنوان صفحة الخدمة" : "Service page title"}
              </span>
              <input
                value={serviceForm.detailTitle}
                onChange={(event) => setServiceForm((current) => ({ ...current, detailTitle: event.target.value }))}
                placeholder={language === "ar" ? "يظهر داخل صفحة الخدمة" : "Shown inside the service page"}
                className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
              />
            </label>
            <div className="rounded-2xl border border-slate-200 p-4">
              <p className="text-sm font-medium text-slate-700">
                {language === "ar" ? "صورة صفحة الخدمة" : "Service page image"}
              </p>
              <input
                type="file"
                accept="image/*"
                onChange={(event) => handleServiceDetailImageUpload(event.target.files)}
                className="mt-4 w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm"
              />
              <p className="mt-2 text-xs text-slate-500">
                {uploadingServiceImage
                  ? `${dt(language, "uploadImages")}...`
                  : language === "ar"
                    ? "ارفع الصورة التي ستظهر داخل صفحة الخدمة."
                    : "Upload the image that will appear inside the service page."}
              </p>
              {serviceForm.detailImage ? (
                <div className="mt-4 rounded-2xl border border-slate-200 p-3">
                  <img src={getApiAssetUrl(serviceForm.detailImage)} alt={serviceForm.detailTitle || serviceForm.title || "Service details"} className="h-40 w-full rounded-2xl object-cover" />
                  <button
                    type="button"
                    onClick={() => setServiceForm((current) => ({ ...current, detailImage: "" }))}
                    className="mt-3 rounded-full border border-rose-200 px-3 py-1 text-xs font-medium text-rose-700"
                  >
                    {dt(language, "removeImage")}
                  </button>
                </div>
              ) : null}
            </div>
          </div>
          <label className="block">
            <span className="mb-2 block text-sm font-medium text-slate-700">
              {language === "ar" ? "نص صفحة الخدمة" : "Service page text"}
            </span>
            <textarea
              value={serviceForm.detailBody}
              onChange={(event) => setServiceForm((current) => ({ ...current, detailBody: event.target.value }))}
              rows={6}
              placeholder={
                language === "ar"
                  ? "اكتب النص الذي سيظهر داخل صفحة الخدمة."
                  : "Write the text that should appear inside the service page."
              }
              className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
            />
          </label>
          <div className="rounded-2xl border border-slate-200 p-4">
            <p className="text-sm font-medium text-slate-700">{dt(language, "serviceImage")}</p>
            <input type="file" accept="image/*" onChange={(event) => handleServiceImageUpload(event.target.files)} className="mt-4 w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm" />
            <p className="mt-2 text-xs text-slate-500">
              {uploadingServiceImage
                ? `${dt(language, "uploadImages")}...`
                : language === "ar"
                  ? "ارفع صورة الخدمة كما ستظهر في الصفحة الرئيسية."
                  : "Upload the service image as it will appear on the homepage."}
            </p>
            {serviceForm.image ? (
              <div className="mt-4 rounded-2xl border border-slate-200 p-3">
                <img src={getApiAssetUrl(serviceForm.image)} alt={serviceForm.title || "Service"} className="h-40 w-full rounded-2xl object-cover" />
                <button
                  type="button"
                  onClick={() => setServiceForm((current) => ({ ...current, image: "" }))}
                  className="mt-3 rounded-full border border-rose-200 px-3 py-1 text-xs font-medium text-rose-700"
                >
                  {dt(language, "removeImage")}
                </button>
              </div>
            ) : null}
          </div>
          <label className="flex items-center gap-3 rounded-2xl border border-slate-200 px-4 py-3">
            <input type="checkbox" checked={serviceForm.featured} onChange={(event) => setServiceForm((current) => ({ ...current, featured: event.target.checked }))} />
            <span className="text-sm font-medium text-slate-700">{dt(language, "showFeaturedService")}</span>
          </label>
          <div className="flex flex-wrap gap-3">
            <button type="submit" className="inline-flex items-center gap-2 rounded-full bg-slate-950 px-5 py-3 font-semibold text-white">
              <Plus className="h-4 w-4" />
              {editingServiceId ? dt(language, "updateService") : dt(language, "createService")}
            </button>
            <button type="button" onClick={resetServiceForm} className="rounded-full border border-slate-200 px-5 py-3 font-semibold text-slate-700">
              {dt(language, "clearForm")}
            </button>
          </div>
        </form>
      </section>

      <section className="space-y-4">
        {services.map((service) => (
          <div key={service._id} className="panel p-5">
            <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
              <div className="flex-1">
                {service.image ? <img src={getApiAssetUrl(service.image)} alt={service.title} className="h-40 w-full rounded-3xl object-cover" /> : null}
                <div className="mt-4 flex flex-wrap items-center gap-2">
                  <p className="text-lg font-semibold text-slate-900">{service.title}</p>
                  {service.featured ? <span className="rounded-full bg-emerald-100 px-3 py-1 text-xs font-semibold text-emerald-700">{dt(language, "featured")}</span> : null}
                  <span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-600">
                    {language === "ar" ? `ترتيب ${service.sortOrder || 0}` : `Order ${service.sortOrder || 0}`}
                  </span>
                  {service.country && typeof service.country !== "string" ? (
                    <span className="rounded-full bg-brand-50 px-3 py-1 text-xs font-semibold text-brand-700">
                      {countryLabel(service.country)}
                    </span>
                  ) : (
                    <span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-600">
                      {language === "ar" ? "عام" : "General"}
                    </span>
                  )}
                </div>
                {service.journeyStage ? (
                  <span className="mt-2 inline-block rounded-full bg-violet-100 px-3 py-1 text-xs font-semibold text-violet-700">
                    {language === "ar" ? "رحلة: " : "Journey: "}{JOURNEY_STAGES.find((s) => s.value === service.journeyStage)?.[language === "ar" ? "labelAr" : "labelEn"] || service.journeyStage}
                  </span>
                ) : null}
                {service.detailTitle ? <p className="mt-3 text-sm font-medium text-slate-800">{service.detailTitle}</p> : null}
                {service.detailBody ? <p className="mt-2 line-clamp-3 text-sm leading-6 text-slate-500">{service.detailBody}</p> : null}
              </div>
              <div className="flex flex-wrap gap-2">
                <button
                  onClick={() => {
                    setEditingServiceId(service._id);
                    setServiceForm({
                      title: service.title,
                      image: service.image || "",
                      detailTitle: service.detailTitle || "",
                      detailBody: service.detailBody || "",
                      detailImage: service.detailImage || "",
                      priceDescription: service.priceDescription || "",
                      estimatedDuration: service.estimatedDuration || "",
                      price: String(service.price ?? 0),
                      durationDays: String(service.durationDays ?? 0),
                      journeyStage: service.journeyStage || "",
                      featured: Boolean(service.featured),
                      sortOrder: String(service.sortOrder || 0),
                      country: service.country && typeof service.country !== "string" ? service.country._id : typeof service.country === "string" ? service.country : "",
                    });
                  }}
                  className="inline-flex items-center gap-2 rounded-full border border-slate-200 px-4 py-2 font-medium text-slate-700"
                >
                  <PencilLine className="h-4 w-4" />
                  {dt(language, "edit")}
                </button>
                <button onClick={() => adminService.removeOurService(service._id).then(loadData)} className="inline-flex items-center gap-2 rounded-full border border-rose-200 px-4 py-2 font-medium text-rose-700">
                  <Trash2 className="h-4 w-4" />
                  {dt(language, "delete")}
                </button>
              </div>
            </div>
          </div>
        ))}
      </section>
    </div>
  );
};
