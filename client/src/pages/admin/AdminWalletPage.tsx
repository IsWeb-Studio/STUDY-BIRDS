import { useEffect, useState } from "react";
import { api } from "../../lib/api";
import { ReferralPolicies } from '../../components/admin/ReferralPolicies';
import { useLanguage } from "../../hooks/useLanguage";
import { getErrorMessage } from "../../utils/errors";

type Entry = {
  _id: string; direction: string; kind: string; amount: number; notes?: string; createdAt: string;
  student?: { _id: string; name: string; email: string }; createdBy?: { name: string };
};
const kindLabels: Record<string, [string, string]> = {
  "referral-reward": ["مكافأة إحالة", "Referral reward"], redemption: ["سداد فاتورة", "Invoice redemption"], adjustment: ["تسوية يدوية", "Manual adjustment"],
};

export const AdminWalletPage = () => {
  const { language } = useLanguage();
  const ar = language === "ar";
  const t = (a: string, b: string) => (ar ? a : b);
  const [entries, setEntries] = useState<Entry[]>([]);
  const [studentFilter, setStudentFilter] = useState("");
  const [loading, setLoading] = useState(true), [busy, setBusy] = useState(false);
  const [error, setError] = useState(""), [success, setSuccess] = useState("");
  const [form, setForm] = useState({ studentId: "", direction: "credit", amount: "", notes: "" });
  const input = "rounded-xl border border-slate-300 bg-white p-3 text-slate-900";
  const button = "rounded-xl bg-brand-primary px-4 py-2 text-white disabled:opacity-50";

  async function load() {
    setLoading(true);
    try {
      const { data } = await api.get<Entry[]>(`/admin/student-financials/wallet-entries${studentFilter ? `?student=${studentFilter}` : ""}`);
      setEntries(data);
    } catch (e) { setError(getErrorMessage(e, t("تعذر تحميل سجل المحفظة", "Unable to load wallet entries"))); }
    finally { setLoading(false); }
  }
  useEffect(() => { void load(); }, [studentFilter]);

  async function submitAdjustment() {
    setBusy(true); setError(""); setSuccess("");
    try {
      await api.post("/admin/student-financials/wallet-entries", { ...form, amount: Number(form.amount) });
      setSuccess(t("تم تسجيل التسوية.", "Adjustment recorded."));
      setForm({ studentId: "", direction: "credit", amount: "", notes: "" });
      await load();
    } catch (e) { setError(getErrorMessage(e, t("تعذر تسجيل التسوية", "Unable to record the adjustment"))); }
    finally { setBusy(false); }
  }

  return <div className="space-y-6" dir={ar ? "rtl" : "ltr"}>
    <h1 className="text-2xl font-bold">{t("محفظة الطلاب", "Student Wallets")}</h1>
    <ReferralPolicies />
    {error && <p role="alert" className="rounded-xl bg-red-50 p-3 text-red-800">{error}</p>}
    {success && <p role="status" className="rounded-xl bg-green-50 p-3 text-green-800">{success}</p>}

    <section className="space-y-3 rounded-2xl border bg-white p-5">
      <h2 className="text-xl font-semibold">{t("تسوية يدوية", "Manual adjustment")}</h2>
      <div className="grid gap-3 md:grid-cols-2">
        <label>{t("معرّف الطالب (ID)", "Student ID")}<input className={`${input} block w-full`} value={form.studentId} onChange={(e) => setForm({ ...form, studentId: e.target.value })} /></label>
        <label>{t("النوع", "Direction")}<select className={`${input} block w-full`} value={form.direction} onChange={(e) => setForm({ ...form, direction: e.target.value })}>
          <option value="credit">{t("إضافة", "Credit")}</option><option value="debit">{t("خصم", "Debit")}</option>
        </select></label>
        <label>{t("المبلغ", "Amount")}<input type="number" min="0" className={`${input} block w-full`} value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} /></label>
        <label>{t("السبب", "Reason")}<input className={`${input} block w-full`} value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} /></label>
      </div>
      <button className={button} disabled={busy || !form.studentId || !form.amount || !form.notes} onClick={() => void submitAdjustment()}>{t("تسجيل", "Record")}</button>
    </section>

    <section className="rounded-2xl border bg-white p-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h2 className="text-xl font-semibold">{t("سجل المعاملات", "Transaction log")}</h2>
        <div className="flex gap-2">
          <input placeholder={t("تصفية بمعرّف طالب", "Filter by student ID")} className={input} value={studentFilter} onChange={(e) => setStudentFilter(e.target.value)} />
          <button className={button} disabled={busy || loading} onClick={() => void load()}>{t("تحديث", "Refresh")}</button>
        </div>
      </div>
      {loading ? <p className="mt-3">{t("جارٍ التحميل…", "Loading…")}</p> : !entries.length && <p className="mt-3">{t("لا توجد معاملات", "No entries")}</p>}
      <div className="mt-3 space-y-2">
        {entries.map((e) => <div key={e._id} className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-slate-200 p-3 text-sm">
          <div><p className="font-semibold">{e.student?.name} — {e.student?.email}</p>
            <p className="text-slate-600">{kindLabels[e.kind]?.[ar ? 0 : 1] || e.kind}{e.notes ? ` — ${e.notes}` : ""}{e.createdBy ? ` (${e.createdBy.name})` : ""}</p></div>
          <span className={e.direction === "credit" ? "font-semibold text-emerald-700" : "font-semibold text-red-700"}>{e.direction === "credit" ? "+" : "-"}{e.amount}</span>
        </div>)}
      </div>
    </section>
  </div>;
};
