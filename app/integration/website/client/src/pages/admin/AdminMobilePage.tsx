import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { MobileAccountsPanel } from './MobileAccountsPanel';
import { api, getDownloadableAssetUrl } from "../../lib/api";

type Module = { key: string; title: string; enabled: boolean; order: number };
type Config = { title: string; welcome: string; primaryColor: string; maintenance: boolean; maintenanceMessage: string; supportEmail: string; supportPhone: string; revision: number; modules: Module[]; banners: { title: string; imageUrl: string; linkUrl: string }[] };
type Content = { _id?: string; section: string; title: string; body: string; imageUrl: string; linkUrl: string; date: string | null; published: boolean; requestable: boolean; order: number };
type Request = { _id: string; title: string; user: { name: string; email: string } | null; message: string; status: string; adminNote: string };
const sections = ["scholarships", "visa", "travel", "accommodation", "services", "consultations", "calendar", "team", "insurance", "equivalency", "registration"];
const blank = (): Content => ({ section: "services", title: "", body: "", imageUrl: "", linkUrl: "", date: null, published: false, requestable: false, order: 0 });
const field = "w-full rounded-xl border border-slate-300 bg-white px-3 py-2 text-slate-900";
const button = "rounded-xl bg-slate-900 px-4 py-2 text-white disabled:opacity-50";
const message = (e: unknown) => (e as { response?: { data?: { message?: string } } })?.response?.data?.message || "تعذر تنفيذ العملية. تحقق من الاتصال وحاول مجدداً.";

export const AdminMobilePage = () => {
  const [config, setConfig] = useState<Config | null>(null);
  const [content, setContent] = useState<Content[]>([]);
  const [requests, setRequests] = useState<Request[]>([]);
  const [edit, setEdit] = useState<Content>(blank);
  const [tab, setTab] = useState("settings");
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState({ userId: "", title: "", message: "" });
  const [students, setStudents] = useState<{ _id: string; name: string; email: string }[]>([]);
  const [recipients, setRecipients] = useState<{ _id: string; name: string; email: string }[]>([]);
  const [documents, setDocuments] = useState<{ _id: string; fileName: string; filePath: string; status: string; student?: { name: string } }[]>([]);
  const [stage, setStage] = useState({ userId: "", applicationStage: "file-received" });
  const load = async () => {
    setBusy(true); setError("");
    try {
      const [settings, items, jobs, users, docs] = await Promise.all([api.get("/mobile/admin/settings"), api.get("/mobile/admin/content"), api.get("/mobile/admin/requests"), api.get("/admin/users"), api.get("/admin/student-documents")]);
      setDocuments(docs.data);
      setConfig(settings.data); setContent(items.data); setRequests(jobs.data);
      const list = Array.isArray(users.data) ? users.data : users.data.items || users.data.users || [];
      setStudents(list.filter((u: { role: string }) => u.role === "student"));
      setRecipients(list.filter((u: { role: string }) => u.role !== 'admin'));
    } catch (e) { setError(message(e)); } finally { setBusy(false); }
  };
  useEffect(() => { void load(); }, []);
  const act = async (work: () => Promise<void>) => {
    setBusy(true); setError(""); setSuccess("");
    try { await work(); setSuccess("تم الحفظ بنجاح. تظهر التغييرات في التطبيق عند التحديث."); }
    catch (e) { setError(message(e)); } finally { setBusy(false); }
  };
  const patch = (change: Partial<Config>) => setConfig((current) => current ? { ...current, ...change } : current);
  return <section dir="rtl" className="min-w-0 space-y-5">
    <div className="rounded-3xl bg-slate-900 p-6 text-white"><p className="text-sm text-orange-300">Study Birds Mobile</p><h1 className="mt-2 text-2xl font-bold">لوحة تحكم التطبيق</h1><p className="mt-2">إدارة المحتوى والخدمات والإعدادات. حسابات الطلاب وطلباتهم متزامنة مع الموقع.</p></div>
    <nav className="flex flex-wrap gap-2" aria-label="أقسام إدارة التطبيق">{[["settings", "إعدادات التطبيق"], ["content", "المحتوى"], ["requests", "طلبات الخدمات"], ["notifications", "إرسال إشعار"], ["review", "مراجعة المستندات والرحلة"], ["operations", "إدارة الطلاب والبيانات"]].map(([key, label]) => <button key={key} onClick={() => setTab(key)} className={`rounded-xl border px-4 py-2 ${tab === key ? "bg-orange-100 border-orange-400" : "bg-white"}`}>{label}</button>)}</nav>
    <button onClick={() => setTab('accounts')} className={button}>الحسابات والصلاحيات والمهام والمحادثات</button>
    {tab === 'accounts' && <MobileAccountsPanel />}
    {error && <div role="alert" className="rounded-xl bg-red-50 p-4 text-red-800">{error} <button disabled={busy} onClick={() => void load()} className="underline">إعادة تحميل البيانات</button></div>}
    {success && <p role="status" className="rounded-xl bg-green-50 p-4 text-green-800">{success}</p>}
    {!config && !error && <p role="status">جارٍ تحميل لوحة التطبيق…</p>}
    {tab === "settings" && config && <form className="space-y-5 rounded-2xl bg-white p-5" onSubmit={(event) => { event.preventDefault(); void act(async () => { const result = await api.put("/mobile/admin/settings", config); setConfig(result.data); }); }}>
      <fieldset disabled={busy} className="space-y-4">
        <div className="grid gap-4 sm:grid-cols-2">{([['title', 'اسم التطبيق'], ['welcome', 'رسالة الترحيب'], ['supportEmail', 'بريد الدعم'], ['supportPhone', 'هاتف الدعم'], ['maintenanceMessage', 'رسالة الصيانة']] as const).map(([key, label]) => <label key={key} className="block space-y-1"><span>{label}</span><input className={field} required={key === "title"} maxLength={key === "title" ? 80 : key === "supportEmail" ? 150 : key === "supportPhone" ? 50 : 500} value={config[key]} onChange={(e) => patch({ [key]: e.target.value })} /></label>)}
        <label>لون التطبيق<input aria-label="لون التطبيق" className="block h-11 w-24" type="color" value={config.primaryColor} onChange={(e) => patch({ primaryColor: e.target.value })} /></label></div>
        <label className="flex gap-2"><input type="checkbox" checked={config.maintenance} onChange={(e) => patch({ maintenance: e.target.checked })} />تفعيل وضع الصيانة في التطبيق</label>
        <h2 className="text-lg font-bold">أقسام التطبيق</h2><p className="text-sm text-slate-600">الرقم الأصغر يظهر أولاً. إخفاء القسم يتحكم في ظهوره بالتطبيق؛ صلاحيات البيانات تظل محمية بالحساب.</p>
        {config.modules.map((module, index) => <div key={module.key} className="flex flex-wrap items-center gap-3 rounded-xl border p-3">
          <label className="flex gap-2"><input type="checkbox" aria-label={`إظهار ${module.title}`} checked={module.enabled} onChange={(e) => patch({ modules: config.modules.map((m, i) => i === index ? { ...m, enabled: e.target.checked } : m) })} />إظهار</label>
          <input className={`${field} max-w-xs`} aria-label={`اسم ${module.title}`} maxLength={80} required value={module.title} onChange={(e) => patch({ modules: config.modules.map((m, i) => i === index ? { ...m, title: e.target.value } : m) })} />
          <input className={`${field} max-w-24`} aria-label={`ترتيب ${module.title}`} type="number" min={0} max={1000} required value={module.order} onChange={(e) => patch({ modules: config.modules.map((m, i) => i === index ? { ...m, order: Number(e.target.value) } : m) })} />
        </div>)}
        <h2 className="text-lg font-bold">البانرات</h2>{config.banners.map((banner, index) => <div key={index} className="space-y-2 rounded-xl border p-3">{([['title', 'عنوان البانر'], ['imageUrl', 'رابط الصورة HTTPS'], ['linkUrl', 'رابط الوجهة HTTPS']] as const).map(([key, label]) => <label className="block" key={key}>{label}<input className={field} value={banner[key]} type={key === "title" ? "text" : "url"} onChange={(e) => patch({ banners: config.banners.map((b, i) => i === index ? { ...b, [key]: e.target.value } : b) })} /></label>)}<button type="button" className="text-red-700" onClick={() => patch({ banners: config.banners.filter((_, i) => i !== index) })}>حذف البانر</button></div>)}
        <button type="button" className="rounded-xl border px-4 py-2" disabled={config.banners.length >= 20} onClick={() => patch({ banners: [...config.banners, { title: "", imageUrl: "", linkUrl: "" }] })}>إضافة بانر</button>
        <div><button className={button} type="submit">{busy ? "جارٍ الحفظ…" : "حفظ إعدادات التطبيق"}</button></div>
      </fieldset>
    </form>}
    {tab === "content" && <div className="space-y-4">
      <form className="space-y-3 rounded-2xl bg-white p-5" onSubmit={(e) => { e.preventDefault(); void act(async () => {
        const { data } = edit._id ? await api.put(`/mobile/admin/content/${edit._id}`, edit) : await api.post("/mobile/admin/content", edit);
        setContent((items) => edit._id ? items.map((item) => item._id === edit._id ? data : item) : [...items, data]); setEdit(blank());
      }); }}><fieldset disabled={busy} className="space-y-3"><h2 className="text-lg font-bold">{edit._id ? "تعديل المحتوى" : "إضافة محتوى"}</h2>
        <label className="block">القسم<select className={field} value={edit.section} onChange={(e) => setEdit({ ...edit, section: e.target.value })}>{sections.map((key) => <option key={key} value={key}>{config?.modules.find((m) => m.key === key)?.title || key}</option>)}</select></label>
        <label className="block">العنوان<input className={field} required maxLength={150} value={edit.title} onChange={(e) => setEdit({ ...edit, title: e.target.value })} /></label>
        <label className="block">المحتوى<textarea className={field} rows={6} maxLength={20000} value={edit.body} onChange={(e) => setEdit({ ...edit, body: e.target.value })} /></label>
        {([['imageUrl', 'رابط الصورة HTTPS'], ['linkUrl', 'الرابط الخارجي HTTPS']] as const).map(([key, label]) => <label className="block" key={key}>{label}<input type="url" className={field} value={edit[key]} onChange={(e) => setEdit({ ...edit, [key]: e.target.value })} /></label>)}
        <label className="block">التاريخ (اختياري)<input type="date" className={field} value={edit.date?.slice(0, 10) || ""} onChange={(e) => setEdit({ ...edit, date: e.target.value || null })} /></label>
        <label className="block">الترتيب<input type="number" min={-10000} max={10000} className={field} value={edit.order} onChange={(e) => setEdit({ ...edit, order: Number(e.target.value) })} /></label>
        <label className="flex gap-2"><input type="checkbox" checked={edit.published} onChange={(e) => setEdit({ ...edit, published: e.target.checked })} />منشور في التطبيق</label>
        <label className="flex gap-2"><input type="checkbox" checked={edit.requestable} onChange={(e) => setEdit({ ...edit, requestable: e.target.checked })} />السماح للطالب بطلب هذه الخدمة</label>
        <div className="flex gap-3"><button className={button}>حفظ المحتوى</button><button type="button" onClick={() => setEdit(blank())}>إلغاء التعديل</button></div>
      </fieldset></form>
      {content.length === 0 && <p>لا يوجد محتوى بعد.</p>}{content.map((item) => <article key={item._id} className="flex flex-wrap items-center justify-between gap-3 rounded-xl bg-white p-4"><div><h3 className="font-bold">{item.title}</h3><p>{config?.modules.find((m) => m.key === item.section)?.title} · {item.published ? "منشور" : "مسودة"}</p></div><div className="flex gap-4"><button disabled={busy} onClick={() => { setEdit(item); window.scrollTo({ top: 0, behavior: "smooth" }); }}>تعديل</button><button disabled={busy} className="text-red-700" onClick={() => { if (window.confirm(`حذف «${item.title}»؟`)) void act(async () => { await api.delete(`/mobile/admin/content/${item._id}`); setContent((items) => items.filter((i) => i._id !== item._id)); if (edit._id === item._id) setEdit(blank()); }); }}>حذف</button></div></article>)}
    </div>}
    {tab === "requests" && <div className="space-y-4">{requests.length === 0 && <p>لا توجد طلبات خدمات من التطبيق.</p>}{requests.map((request, index) => <article key={request._id} className="space-y-3 rounded-2xl bg-white p-5"><h2 className="font-bold">{request.title}</h2><p>{request.user?.name} · {request.user?.email}</p><p className="whitespace-pre-wrap">{request.message}</p><label className="block">الحالة<select aria-label="حالة الطلب" className={field} value={request.status} onChange={(e) => setRequests((items) => items.map((r, i) => i === index ? { ...r, status: e.target.value } : r))}>{[["submitted", "جديد"], ["in-progress", "قيد التنفيذ"], ["completed", "مكتمل"], ["cancelled", "ملغي"]].map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label><label className="block">رد الإدارة (يظهر للطالب)<textarea className={field} maxLength={4000} value={request.adminNote} onChange={(e) => setRequests((items) => items.map((r, i) => i === index ? { ...r, adminNote: e.target.value } : r))} /></label><button disabled={busy} className={button} onClick={() => void act(async () => { await api.patch(`/mobile/admin/requests/${request._id}`, { status: request.status, adminNote: request.adminNote }); })}>حفظ الرد والحالة</button></article>)}</div>}
    {tab === "notifications" && <form className="space-y-4 rounded-2xl bg-white p-5" onSubmit={(e) => { e.preventDefault(); void act(async () => { await api.post("/mobile/admin/notifications", notice); setNotice({ userId: "", title: "", message: "" }); }); }}><h2 className="text-lg font-bold">إشعار داخل التطبيق</h2><label className="block">الطالب<select className={field} required value={notice.userId} onChange={(e) => setNotice({ ...notice, userId: e.target.value })}><option value="">اختر الطالب</option>{recipients.map((s) => <option key={s._id} value={s._id}>{s.name} — {s.email}</option>)}</select></label><label className="block">العنوان<input className={field} required maxLength={150} value={notice.title} onChange={(e) => setNotice({ ...notice, title: e.target.value })} /></label><label className="block">الرسالة<textarea className={field} required maxLength={4000} value={notice.message} onChange={(e) => setNotice({ ...notice, message: e.target.value })} /></label><button disabled={busy} className={button}>إرسال الإشعار</button></form>}
    {tab === "review" && <div className="space-y-4"><form className="space-y-3 rounded-2xl bg-white p-5" onSubmit={(e) => { e.preventDefault(); void act(async () => { await api.patch(`/mobile/admin/students/${stage.userId}/stage`, { applicationStage: stage.applicationStage }); }); }}><h2 className="font-bold">تحديث مرحلة رحلة الطالب</h2><label className="block">الطالب<select className={field} required value={stage.userId} onChange={(e) => setStage({ ...stage, userId: e.target.value })}><option value="">اختر الطالب</option>{students.map((s) => <option value={s._id} key={s._id}>{s.name} — {s.email}</option>)}</select></label><label className="block">المرحلة الجديدة<select className={field} value={stage.applicationStage} onChange={(e) => setStage({ ...stage, applicationStage: e.target.value })}>{[["file-received", "استلام الملف"], ["applying", "التقديم"], ["preliminary-accepted", "القبول المبدئي"], ["first-payment", "الدفعة الأولى"], ["final-accepted", "القبول النهائي"], ["travel-and-settlement", "السفر والاستقرار"]].map(([key, label]) => <option value={key} key={key}>{label}</option>)}</select></label><button className={button} disabled={busy}>حفظ المرحلة</button></form>
      <h2 className="text-lg font-bold">مراجعة مستندات الطلاب</h2>{documents.length === 0 && <p>لا توجد مستندات.</p>}{documents.map((doc) => <article key={doc._id} className="space-y-3 rounded-2xl bg-white p-5"><h3 className="font-bold">{doc.fileName}</h3><p>{doc.student?.name}</p><a className="underline" href={getDownloadableAssetUrl(doc.filePath)} target="_blank" rel="noreferrer">عرض المستند</a><label className="block">الحالة<select className={field} value={doc.status} onChange={(e) => setDocuments((items) => items.map((d) => d._id === doc._id ? { ...d, status: e.target.value } : d))}>{[["pending", "قيد المراجعة"], ["verified", "مقبول"], ["rejected", "مرفوض"]].map(([key, label]) => <option value={key} key={key}>{label}</option>)}</select></label><button className={button} disabled={busy} onClick={() => void act(async () => { await api.patch(`/mobile/admin/documents/${doc._id}`, { status: doc.status }); })}>حفظ المراجعة</button></article>)}</div>}
    {tab === "operations" && <div className="grid gap-3 sm:grid-cols-2">{[["users", "الحسابات والصلاحيات"], ["students", "ملفات الطلاب"], ["applications", "طلبات القبول"], ["student-documents", "المستندات"], ["student-financials", "الفواتير وإثباتات الدفع"], ["student-arrivals", "السفر والسكن والاستقبال"], ["support-tickets", "الدعم والردود"], ["student-notifications", "سجل الإشعارات"], ["universities", "الجامعات"], ["programs", "التخصصات"], ["content", "الدول"], ["knowledge-base", "دليل الطالب"], ["student-favorites", "المفضلة"], ["student-orientation-results", "التوجيه الدراسي"]].map(([path, label]) => <Link className="rounded-xl border bg-white p-5 font-bold hover:border-orange-400" key={path} to={`/admin/mobile/manage/${path}`}>{label}</Link>)}</div>}
  </section>;
};
