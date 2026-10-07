// #35-43: Admin management of student service requests
import { useEffect, useState } from "react";
import { api } from "../../lib/api";
import { getErrorMessage } from "../../utils/errors";

type ServiceRequest = {
  _id: string;
  serviceTitle: string;
  status: "pending" | "assigned" | "in-progress" | "completed" | "cancelled";
  notes: string;
  staffNote: string;
  student?: { name: string; email: string };
  assignedTo?: { _id: string; name: string } | null;
  createdAt: string;
};

const STATUS_OPTIONS = [
  { value: "pending",     label: "في الانتظار" },
  { value: "assigned",    label: "تم التعيين" },
  { value: "in-progress", label: "قيد التنفيذ" },
  { value: "completed",   label: "مكتمل" },
  { value: "cancelled",   label: "ملغى" },
];

const statusColor = (status: string) => {
  switch (status) {
    case "pending":     return "bg-amber-50 text-amber-700";
    case "assigned":    return "bg-blue-50 text-blue-700";
    case "in-progress": return "bg-indigo-50 text-indigo-700";
    case "completed":   return "bg-emerald-50 text-emerald-700";
    case "cancelled":   return "bg-red-50 text-red-700";
    default:            return "bg-slate-100 text-slate-600";
  }
};

export const AdminServiceRequestsPage = () => {
  const [items, setItems] = useState<ServiceRequest[]>([]);
  const [filterStatus, setFilterStatus] = useState("");
  const [error, setError] = useState("");
  const [updating, setUpdating] = useState<string | null>(null);
  const [drafts, setDrafts] = useState<Record<string, { status: string; staffNote: string }>>({});

  const load = async (status?: string) => {
    try {
      const params = status ? `?status=${status}` : "";
      const { data } = await api.get<ServiceRequest[]>(`/service-requests${params}`);
      setItems(data);
      setDrafts(
        data.reduce<Record<string, { status: string; staffNote: string }>>((acc, r) => ({
          ...acc,
          [r._id]: { status: r.status, staffNote: r.staffNote || "" },
        }), {})
      );
    } catch (e) {
      setError(getErrorMessage(e, "تعذر تحميل طلبات الخدمات."));
    }
  };

  useEffect(() => { load(filterStatus || undefined); }, [filterStatus]);

  const handleUpdate = async (id: string) => {
    setUpdating(id);
    try {
      const draft = drafts[id];
      const { data: updated } = await api.patch<ServiceRequest>(`/service-requests/${id}`, {
        status: draft.status,
        staffNote: draft.staffNote,
      });
      setItems(prev => prev.map(r => r._id === id ? { ...r, ...updated } : r));
    } catch (e) {
      alert(getErrorMessage(e, "تعذر التحديث."));
    } finally {
      setUpdating(null);
    }
  };

  const setDraft = (id: string, patch: Partial<{ status: string; staffNote: string }>) => {
    setDrafts(prev => ({ ...prev, [id]: { ...prev[id], ...patch } }));
  };

  const formatDate = (raw: string) => {
    const d = new Date(raw);
    return isNaN(d.getTime()) ? "—" : d.toLocaleDateString("ar-SA", { year: "numeric", month: "short", day: "numeric" });
  };

  return (
    <div className="space-y-6" dir="rtl">
      <section className="panel p-6">
        <h1 className="text-3xl font-semibold text-slate-900">طلبات الخدمات</h1>
        <p className="mt-2 text-sm text-slate-500">تابع وأدِر طلبات الخدمات المقدمة من الطلاب.</p>

        <div className="mt-4 flex flex-wrap gap-2">
          <button
            onClick={() => setFilterStatus("")}
            className={`rounded-full px-4 py-1.5 text-sm font-medium transition ${!filterStatus ? "bg-slate-800 text-white" : "bg-slate-100 text-slate-600 hover:bg-slate-200"}`}
          >
            الكل
          </button>
          {STATUS_OPTIONS.map(opt => (
            <button
              key={opt.value}
              onClick={() => setFilterStatus(opt.value)}
              className={`rounded-full px-4 py-1.5 text-sm font-medium transition ${filterStatus === opt.value ? "bg-slate-800 text-white" : "bg-slate-100 text-slate-600 hover:bg-slate-200"}`}
            >
              {opt.label}
            </button>
          ))}
        </div>

        {error && <div className="mt-4 rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div>}
      </section>

      {items.length === 0 && !error && (
        <div className="panel p-10 text-center text-slate-400">لا توجد طلبات خدمات.</div>
      )}

      <div className="space-y-4">
        {items.map(item => {
          const draft = drafts[item._id] ?? { status: item.status, staffNote: item.staffNote || "" };
          const changed = draft.status !== item.status || draft.staffNote !== (item.staffNote || "");
          return (
            <article key={item._id} className="panel p-6 space-y-4">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <h2 className="text-lg font-semibold text-slate-900">{item.serviceTitle}</h2>
                  <p className="mt-0.5 text-sm text-slate-500">
                    {item.student?.name || "—"} · {item.student?.email || "—"}
                  </p>
                  <p className="text-xs text-slate-400 mt-0.5">{formatDate(item.createdAt)}</p>
                </div>
                <span className={`rounded-full px-3 py-1 text-xs font-semibold ${statusColor(item.status)}`}>
                  {STATUS_OPTIONS.find(o => o.value === item.status)?.label ?? item.status}
                </span>
              </div>

              {item.notes && (
                <div className="rounded-xl bg-slate-50 px-4 py-3 text-sm text-slate-600">
                  <span className="font-semibold text-slate-700">ملاحظة الطالب: </span>{item.notes}
                </div>
              )}

              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                <div>
                  <label className="block text-xs font-medium text-slate-500 mb-1">تغيير الحالة</label>
                  <select
                    value={draft.status}
                    onChange={e => setDraft(item._id, { status: e.target.value })}
                    className="w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-slate-300"
                  >
                    {STATUS_OPTIONS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-medium text-slate-500 mb-1">ملاحظة داخلية للطالب</label>
                  <input
                    type="text"
                    value={draft.staffNote}
                    onChange={e => setDraft(item._id, { staffNote: e.target.value })}
                    placeholder="رسالة تظهر للطالب..."
                    className="w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-slate-300"
                  />
                </div>
              </div>

              <div className="flex items-center justify-end gap-3">
                {item.assignedTo && (
                  <span className="text-xs text-slate-400">مُعيَّن لـ: {item.assignedTo.name}</span>
                )}
                <button
                  disabled={!changed || updating === item._id}
                  onClick={() => handleUpdate(item._id)}
                  className="rounded-xl bg-slate-800 px-5 py-2 text-sm font-semibold text-white disabled:opacity-40 hover:bg-slate-700 transition"
                >
                  {updating === item._id ? "جاري الحفظ..." : "حفظ"}
                </button>
              </div>
            </article>
          );
        })}
      </div>
    </div>
  );
};
