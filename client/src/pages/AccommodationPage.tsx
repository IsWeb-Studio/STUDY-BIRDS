import { useEffect, useState } from "react";
import { api } from "../lib/api";
import { useLanguage } from "../hooks/useLanguage";
import { getErrorMessage } from "../utils/errors";

type University = { _id: string; name: string };
type Listing = {
  _id: string; title: string; type: string; university: University | null;
  distanceFromCampusKm: number | null; amenities: string[]; price: number; currency: string; rules: string; capacity: number; isActive: boolean;
};
type Booking = {
  _id: string; __v: number; status: string; moveInDate: string | null; notes: string; staffNote: string;
  student?: { _id: string; name: string }; listing: Listing;
};
type ArrivalHousingItem = {
  _id: string;
  status: string;
  student?: { _id: string; name: string; email?: string };
  arrivalDate?: string | null;
  notes?: string;
  services: { studentHousing: boolean; airportPickup: boolean; residencePermitSupport: boolean; visaSupport: boolean };
};
const typeLabels: Record<string, [string, string]> = { single: ["فردي", "Single"], shared: ["مشترك", "Shared"], apartment: ["شقة طلابية", "Apartment"] };
const statusLabels: Record<string, [string, string]> = {
  pending: ["قيد المراجعة", "Pending"], confirmed: ["مؤكد", "Confirmed"], rejected: ["مرفوض", "Rejected"], cancelled: ["ملغى", "Cancelled"],
};
const emptyForm = { title: "", type: "single", university: "", distanceFromCampusKm: "", amenities: "", price: "", currency: "USD", rules: "", capacity: "1", isActive: true };

export const AccommodationPage = ({ staff = false }: { staff?: boolean }) => {
  const { language } = useLanguage();
  const ar = language === "ar";
  const t = (a: string, b: string) => ar ? a : b;
  const [listings, setListings] = useState<Listing[]>([]);
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [arrivalHousing, setArrivalHousing] = useState<ArrivalHousingItem[]>([]);
  const [universities, setUniversities] = useState<University[]>([]);
  const [loading, setLoading] = useState(true), [busy, setBusy] = useState(false);
  const [error, setError] = useState(""), [success, setSuccess] = useState("");
  const [editingId, setEditingId] = useState("");
  const [form, setForm] = useState(emptyForm);
  const input = "rounded-xl border border-slate-300 bg-white p-3 text-slate-900";
  const button = "rounded-xl bg-brand-primary px-4 py-2 text-white disabled:opacity-50";

  async function load() {
    setLoading(true);
    try {
      if (staff) {
        const [l, b, u, arr] = await Promise.all([
          api.get<Listing[]>("/admin/accommodation-listings"),
          api.get<Booking[]>("/admin/accommodation-bookings"),
          api.get<University[]>("/universities"),
          api.get<ArrivalHousingItem[]>("/admin/student-arrival-requests"),
        ]);
        setListings(l.data); setBookings(b.data); setUniversities(u.data);
        setArrivalHousing(arr.data.filter((r) => r.services?.studentHousing));
      } else {
        const [l, b] = await Promise.all([api.get<Listing[]>("/accommodation/listings"), api.get<Booking[]>("/accommodation/bookings/mine")]);
        setListings(l.data); setBookings(b.data);
      }
    } catch (e) { setError(getErrorMessage(e, t("تعذر تحميل بيانات السكن", "Unable to load housing data"))); }
    finally { setLoading(false); }
  }
  useEffect(() => { void load(); }, [staff]);

  async function change(action: () => Promise<unknown>, message: string) {
    if (busy) return;
    setBusy(true); setError(""); setSuccess("");
    try { await action(); setSuccess(message); await load(); }
    catch (e) { setError(getErrorMessage(e, t("تعذر إتمام العملية", "Unable to complete the action"))); }
    finally { setBusy(false); }
  }

  function startEdit(listing?: Listing) {
    if (!listing) { setEditingId("new"); setForm(emptyForm); return; }
    setEditingId(listing._id);
    setForm({
      title: listing.title, type: listing.type, university: listing.university?._id || "",
      distanceFromCampusKm: listing.distanceFromCampusKm?.toString() || "", amenities: listing.amenities.join(", "),
      price: listing.price.toString(), currency: listing.currency, rules: listing.rules, capacity: listing.capacity.toString(), isActive: listing.isActive,
    });
  }
  function buildPayload() {
    return {
      title: form.title.trim(), type: form.type, university: form.university,
      distanceFromCampusKm: form.distanceFromCampusKm ? Number(form.distanceFromCampusKm) : null,
      amenities: form.amenities.split(",").map((a) => a.trim()).filter(Boolean),
      price: Number(form.price), currency: form.currency.trim() || "USD", rules: form.rules.trim(),
      capacity: Number(form.capacity), isActive: form.isActive,
    };
  }

  return <div className="space-y-6" dir={ar ? "rtl" : "ltr"}>
    <h1 className="text-2xl font-bold">{t("السكن الطلابي", "Student Housing")}</h1>
    {error && <p role="alert" className="rounded-xl bg-red-50 p-3 text-red-800">{error}</p>}
    {success && <p role="status" className="rounded-xl bg-green-50 p-3 text-green-800">{success}</p>}
    <button className={button} disabled={busy || loading} onClick={() => void load()}>{t("تحديث", "Refresh")}</button>

    {staff && <section className="space-y-3 rounded-2xl border bg-white p-5">
      <div className="flex items-center justify-between">
        <h2 className="text-xl font-semibold">{t("خيارات السكن", "Housing listings")}</h2>
        <button className={button} disabled={busy} onClick={() => startEdit()}>{t("إضافة خيار سكن", "Add listing")}</button>
      </div>
      {editingId && <form className="grid gap-3 rounded-xl border border-slate-200 p-4 md:grid-cols-2" onSubmit={(e) => {
        e.preventDefault();
        const payload = buildPayload();
        void change(() => editingId === "new" ? api.post("/admin/accommodation-listings", payload) : api.put(`/admin/accommodation-listings/${editingId}`, payload),
          editingId === "new" ? t("أُضيف خيار السكن", "Listing added") : t("حُدّث خيار السكن", "Listing updated")).then(() => setEditingId(""));
      }}>
        <label>{t("العنوان", "Title")}<input className={`${input} block w-full`} required maxLength={200} value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} /></label>
        <label>{t("النوع", "Type")}<select className={`${input} block w-full`} value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })}>{Object.entries(typeLabels).map(([k, v]) => <option key={k} value={k}>{v[ar ? 0 : 1]}</option>)}</select></label>
        <label>{t("الجامعة", "University")}<select className={`${input} block w-full`} required value={form.university} onChange={(e) => setForm({ ...form, university: e.target.value })}><option value="">{t("اختر جامعة", "Choose university")}</option>{universities.map((u) => <option key={u._id} value={u._id}>{u.name}</option>)}</select></label>
        <label>{t("المسافة من الحرم (كم)", "Distance from campus (km)")}<input type="number" min="0" step="0.1" className={`${input} block w-full`} value={form.distanceFromCampusKm} onChange={(e) => setForm({ ...form, distanceFromCampusKm: e.target.value })} /></label>
        <label>{t("السعر الشهري", "Monthly price")}<input type="number" min="0" required className={`${input} block w-full`} value={form.price} onChange={(e) => setForm({ ...form, price: e.target.value })} /></label>
        <label>{t("العملة", "Currency")}<input maxLength={10} className={`${input} block w-full`} value={form.currency} onChange={(e) => setForm({ ...form, currency: e.target.value })} /></label>
        <label>{t("السعة (عدد الوحدات المتاحة)", "Capacity (available units)")}<input type="number" min="0" required className={`${input} block w-full`} value={form.capacity} onChange={(e) => setForm({ ...form, capacity: e.target.value })} /></label>
        <label>{t("المرافق (مفصولة بفاصلة)", "Amenities (comma-separated)")}<input className={`${input} block w-full`} value={form.amenities} onChange={(e) => setForm({ ...form, amenities: e.target.value })} /></label>
        <label className="md:col-span-2">{t("القواعد والشروط", "Rules and terms")}<textarea className={`${input} block w-full`} maxLength={2000} value={form.rules} onChange={(e) => setForm({ ...form, rules: e.target.value })} /></label>
        <label className="flex items-center gap-2"><input type="checkbox" checked={form.isActive} onChange={(e) => setForm({ ...form, isActive: e.target.checked })} />{t("مرئي للطلاب", "Visible to students")}</label>
        <div className="flex gap-3 md:col-span-2">
          <button className={button} disabled={busy}>{t("حفظ", "Save")}</button>
          <button type="button" className="rounded-xl border border-slate-300 px-4 py-2" disabled={busy} onClick={() => setEditingId("")}>{t("إلغاء", "Cancel")}</button>
        </div>
      </form>}
      <div className="space-y-2">
        {listings.map((l) => <div key={l._id} className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-slate-200 p-3">
          <div><p className="font-semibold">{l.title} {!l.isActive && <span className="text-sm text-slate-500">({t("مخفي", "Hidden")})</span>}</p>
            <p className="text-sm text-slate-600">{l.university?.name} · {typeLabels[l.type]?.[ar ? 0 : 1]} · {l.price} {l.currency} · {t("السعة", "Capacity")}: {l.capacity}</p></div>
          <div className="flex gap-2">
            <button className="rounded-xl border border-slate-300 px-3 py-1 text-sm" disabled={busy} onClick={() => startEdit(l)}>{t("تعديل", "Edit")}</button>
            <button className="rounded-xl border border-red-300 px-3 py-1 text-sm text-red-700" disabled={busy} onClick={() => { if (window.confirm(t("حذف خيار السكن؟", "Delete this listing?"))) void change(() => api.delete(`/admin/accommodation-listings/${l._id}`), t("حُذف الخيار", "Listing deleted")); }}>{t("حذف", "Delete")}</button>
          </div>
        </div>)}
      </div>
    </section>}

    {staff && arrivalHousing.length > 0 && <section className="space-y-3 rounded-2xl border bg-white p-5">
      <h2 className="text-xl font-semibold">{t("طلبات السكن عبر خدمة الوصول", "Housing via Arrival Requests")}</h2>
      <p className="text-sm text-slate-500">{t("هؤلاء الطلاب اختاروا خيار السكن ضمن طلب خدمة الوصول.", "These students selected housing as part of their arrival service request.")}</p>
      {arrivalHousing.map((r) => (
        <article key={r._id} className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-slate-200 bg-slate-50 p-4">
          <div>
            <p className="font-semibold">{r.student?.name || "--"}</p>
            {r.student?.email && <p className="text-sm text-slate-500">{r.student.email}</p>}
            {r.arrivalDate && <p className="text-sm text-slate-500">{t("تاريخ الوصول: ", "Arrival: ")}{new Date(r.arrivalDate).toLocaleDateString(ar ? "ar" : "en")}</p>}
            <p className="mt-1 text-xs text-slate-400">{t("الحالة: ", "Status: ")}{r.status}</p>
          </div>
          <div className="flex gap-2">
            <button
              className="rounded-xl border border-amber-400 px-3 py-2 text-sm font-semibold text-amber-700 disabled:opacity-50"
              disabled={busy}
              onClick={() => void change(() => api.patch(`/admin/student-arrival-requests/${r._id}`, { serviceKey: "studentHousing", serviceStatus: "in-progress" }), t("تم تحديث حالة السكن.", "Housing status updated."))}
            >{t("قيد التنفيذ", "In Progress")}</button>
            <button
              className={`${button} disabled:opacity-50`}
              disabled={busy}
              onClick={() => void change(() => api.patch(`/admin/student-arrival-requests/${r._id}`, { serviceKey: "studentHousing", serviceStatus: "completed" }), t("تم إتمام السكن.", "Housing completed."))}
            >{t("مكتمل", "Completed")}</button>
          </div>
        </article>
      ))}
    </section>}

    <section className="space-y-3"><h2 className="text-xl font-semibold">{staff ? t("طلبات الحجز", "Booking requests") : t("طلبات حجزي", "My requests")}</h2>
      {loading ? <p>{t("جارٍ التحميل…", "Loading…")}</p> : !bookings.length && <p>{t("لا توجد طلبات", "No requests")}</p>}
      {bookings.map((b) => <article key={b._id} className="space-y-1 rounded-2xl border bg-white p-4">
        <h3 className="font-semibold">{b.listing?.title} {staff && `— ${b.student?.name || ""}`}</h3>
        <p className="text-sm text-slate-600">{b.listing?.university?.name} · {typeLabels[b.listing?.type]?.[ar ? 0 : 1]} · {statusLabels[b.status]?.[ar ? 0 : 1]}</p>
        {b.moveInDate && <p className="text-sm">{t("تاريخ الانتقال المطلوب: ", "Requested move-in: ")}{new Date(b.moveInDate).toLocaleDateString(ar ? "ar" : "en")}</p>}
        {b.notes && <p className="text-sm">{b.notes}</p>}
        {b.staffNote && <p className="text-sm text-slate-600">{t("ملاحظة الفريق: ", "Team note: ")}{b.staffNote}</p>}
        {!staff && ["pending", "confirmed"].includes(b.status) && <button className={button} disabled={busy} onClick={() => { if (window.confirm(t("إلغاء طلب السكن؟", "Cancel this housing request?"))) void change(() => api.post(`/accommodation/bookings/${b._id}/cancel`, { version: b.__v }), t("أُلغي الطلب", "Request cancelled")); }}>{t("إلغاء الطلب", "Cancel request")}</button>}
        {staff && b.status === "pending" && <div className="flex gap-2">
          <button className={button} disabled={busy} onClick={() => void change(() => api.patch(`/admin/accommodation-bookings/${b._id}`, { status: "confirmed", version: b.__v }), t("تم التأكيد", "Confirmed"))}>{t("تأكيد", "Confirm")}</button>
          <button className="rounded-xl border border-red-300 px-4 py-2 text-red-700" disabled={busy} onClick={() => void change(() => api.patch(`/admin/accommodation-bookings/${b._id}`, { status: "rejected", version: b.__v }), t("تم الرفض", "Rejected"))}>{t("رفض", "Reject")}</button>
        </div>}
        {staff && b.status === "confirmed" && <button className="rounded-xl border border-red-300 px-4 py-2 text-red-700" disabled={busy} onClick={() => void change(() => api.patch(`/admin/accommodation-bookings/${b._id}`, { status: "cancelled", version: b.__v }), t("تم الإلغاء", "Cancelled"))}>{t("إلغاء", "Cancel")}</button>}
      </article>)}
    </section>

    {!staff && <section className="space-y-3"><h2 className="text-xl font-semibold">{t("خيارات السكن المتاحة", "Available housing")}</h2>
      {!loading && !listings.length && <p>{t("لا توجد خيارات سكن متاحة حاليًا", "No housing available right now")}</p>}
      {listings.map((l) => <article key={l._id} className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border bg-white p-4">
        <div>
          <h3 className="font-semibold">{l.title}</h3>
          <p className="text-sm text-slate-600">{l.university?.name} · {typeLabels[l.type]?.[ar ? 0 : 1]}{l.distanceFromCampusKm != null ? ` · ${l.distanceFromCampusKm} ${t("كم من الحرم", "km from campus")}` : ""}</p>
          <p className="text-sm text-slate-600">{l.price} {l.currency}/{t("شهريًا", "month")} · {t("متاح", "Available")}: {l.capacity}</p>
          {l.amenities.length > 0 && <p className="text-sm text-slate-600">{l.amenities.join(" · ")}</p>}
          {l.rules && <p className="text-sm text-slate-500">{l.rules}</p>}
        </div>
        <button className={button} disabled={busy || bookings.some((b) => ["pending", "confirmed"].includes(b.status))}
          onClick={() => void change(() => api.post("/accommodation/bookings", { listingId: l._id }), t("أُرسل طلب الحجز", "Booking request sent"))}>{t("طلب حجز", "Request booking")}</button>
      </article>)}
    </section>}
  </div>;
};
