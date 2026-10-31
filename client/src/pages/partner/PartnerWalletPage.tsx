import { useEffect, useState } from "react";
import { Link } from 'react-router-dom';
import { DollarSign, Landmark, Wallet } from "lucide-react";
import { StatsCard } from "../../components/dashboard/StatsCard";
import { EmptyState } from "../../components/EmptyState";
import { partnerService } from "../../services/partnerService";
import type { AgentWalletEntry, PayoutRequestItem } from "../../types";
import { useLanguage } from "../../hooks/useLanguage";
import { getErrorMessage } from "../../utils/errors";

const formatCurrency = (value: number) =>
  new Intl.NumberFormat("en-US", { style: "currency", currency: "USD", minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(value || 0);

export const PartnerWalletPage = () => {
  const { language } = useLanguage();
  const isArabic = language === "ar";
  const [entries, setEntries] = useState<AgentWalletEntry[]>([]);
  const [payouts, setPayouts] = useState<PayoutRequestItem[]>([]);
  const [summary, setSummary] = useState({ availableBalance: 0, pendingBalance: 0, receivedBalance: 0 });
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [form, setForm] = useState({ amount: "", method: "bank-account", payoutDetails: "", notes: "" });

  const loadWallet = () =>
    partnerService
      .getWallet()
      .then((data) => {
        setEntries(data.entries);
        setPayouts(data.payouts);
        setSummary(data.summary);
      })
      .catch((issue) => setError(getErrorMessage(issue, isArabic ? "تعذر تحميل المحفظة." : "Unable to load wallet data.")));

  useEffect(() => {
    loadWallet();
  }, [isArabic]);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    if (submitting) return;
    const amount = Number(form.amount);
    if (!Number.isFinite(amount) || amount < 1 || amount > summary.availableBalance || !form.payoutDetails.trim()) {
      setError(isArabic ? 'أدخل مبلغًا ضمن الرصيد المتاح وبيانات الاستلام.' : 'Enter an amount within your available balance and payout details.'); return;
    }
    setError("");
    setSuccess("");
    setSubmitting(true);
    try {
      await partnerService.requestPayout({
        amount: Number(form.amount),
        method: form.method,
        payoutDetails: form.payoutDetails,
        notes: form.notes,
      });
      setSuccess(isArabic ? "تم إرسال طلب السحب بنجاح." : "Payout request submitted successfully.");
      setForm({ amount: "", method: "bank-account", payoutDetails: "", notes: "" });
      await loadWallet();
    } catch (issue) {
      setError(getErrorMessage(issue, isArabic ? "تعذر إرسال طلب السحب." : "Unable to submit payout request."));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="space-y-6">
      <section className="panel p-6">
        <h2 className="text-xl font-semibold">{isArabic ? 'كيف تعمل المحفظة؟' : 'How the wallet works'}</h2>
        <p>{isArabic ? 'تعتمد الإدارة العمولات أو التسويات لتصبح متاحة. طلب السحب يحجز المبلغ حتى المراجعة؛ يُخصم بعد تسجيل التحويل الفعلي ويعود متاحًا إذا رُفض الطلب.' : 'Admin-approved commissions and adjustments become available. A payout request reserves its amount until review. It is deducted after the actual transfer is recorded, or released if rejected.'}</p>
        <p>{isArabic ? 'محجوز لطلبات السحب: ' : 'Reserved for payouts: '}{formatCurrency(payouts.filter(p => ['pending', 'approved'].includes(p.status)).reduce((total, p) => total + p.amount, 0))}</p>
        <Link to="/partner/tickets" className="font-semibold underline">{isArabic ? 'طلب مراجعة رصيد أو عمولة — اختر قسم العمولات وأضف بيانات الطالب أو الطلب' : 'Request a balance or commission review — choose Commission and include the student or application details'}</Link>
      </section>
      <div className="grid gap-5 md:grid-cols-3">
        <StatsCard label={isArabic ? "المتاح للسحب" : "Available Balance"} value={formatCurrency(summary.availableBalance)} icon={<Wallet className="h-5 w-5" />} />
        <StatsCard label={isArabic ? "الأرباح المعلقة" : "Pending Earnings"} value={formatCurrency(summary.pendingBalance)} icon={<DollarSign className="h-5 w-5" />} />
        <StatsCard label={isArabic ? "الأرباح المستلمة" : "Received Earnings"} value={formatCurrency(summary.receivedBalance)} icon={<Landmark className="h-5 w-5" />} />
      </div>

      <section className="panel p-6">
        <h1 className="text-3xl font-semibold text-slate-900">{isArabic ? "المحفظة والعمولات" : "Wallet & Financials"}</h1>
        <p className="mt-2 text-sm text-slate-500">
          {isArabic ? "تابع أرباحك وطلبات السحب السابقة من هنا." : "Track your earnings and payout history here."}
        </p>
        {success ? <div className="mt-5 rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{success}</div> : null}
        {error ? <div className="mt-5 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div> : null}

        <form onSubmit={handleSubmit} className="mt-6 grid gap-4 rounded-[2rem] border border-slate-200 bg-slate-50 p-5 md:grid-cols-2">
          <label>
            <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "المبلغ المطلوب سحبه" : "Requested Amount"}</span>
            <input value={form.amount} onChange={(event) => setForm((current) => ({ ...current, amount: event.target.value }))} type="number" className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 outline-none focus:ring" />
          </label>
          <label>
            <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "طريقة الاستلام" : "Payout Method"}</span>
            <select value={form.method} onChange={(event) => setForm((current) => ({ ...current, method: event.target.value }))} className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 outline-none focus:ring">
              <option value="bank-account">{isArabic ? "حساب بنكي" : "Bank Account"}</option>
              <option value="usdt">USDT</option>
              <option value="wise">Wise</option>
              <option value="other">{isArabic ? "أخرى" : "Other"}</option>
            </select>
          </label>
          <label className="md:col-span-2">
            <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "بيانات الاستلام" : "Payout Details"}</span>
            <textarea value={form.payoutDetails} onChange={(event) => setForm((current) => ({ ...current, payoutDetails: event.target.value }))} rows={3} className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 outline-none focus:ring" />
          </label>
          <label className="md:col-span-2">
            <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "ملاحظات" : "Notes"}</span>
            <textarea value={form.notes} onChange={(event) => setForm((current) => ({ ...current, notes: event.target.value }))} rows={3} className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 outline-none focus:ring" />
          </label>
          <button type="submit" disabled={submitting} className="w-fit rounded-full bg-brand-900 px-6 py-3 font-semibold text-white">
            {submitting ? (isArabic ? "جارٍ الإرسال..." : "Submitting...") : isArabic ? "طلب سحب أرباح" : "Request Payout"}
          </button>
        </form>
      </section>

      {payouts.length ? (
        <section className="panel overflow-hidden p-0">
          <div className="overflow-x-auto">
            <table className="min-w-full text-sm">
              <thead className="bg-slate-50 text-slate-600">
                <tr>
                  {[isArabic ? "التاريخ" : "Date", isArabic ? "المبلغ" : "Amount", isArabic ? "الطريقة" : "Method", isArabic ? "الحالة" : "Status"].map((header) => (
                    <th key={header} className="px-5 py-4 text-start font-semibold">
                      {header}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {payouts.map((item) => (
                  <tr key={item._id} className="border-t border-slate-100">
                    <td className="px-5 py-4 text-slate-600">{item.createdAt ? new Date(item.createdAt).toLocaleDateString() : "--"}</td>
                    <td className="px-5 py-4 font-semibold text-slate-900">{formatCurrency(item.amount)}</td>
                    <td className="px-5 py-4 text-slate-600">{item.method}</td>
                    <td className="px-5 py-4">
                      <span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-700">{item.status}</span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      ) : (
        <EmptyState title={isArabic ? "لا توجد طلبات سحب" : "No payout requests"} description={isArabic ? "عند إرسال أول طلب سحب سيظهر هنا." : "Your payout requests will appear here."} />
      )}
    </div>
  );
};
