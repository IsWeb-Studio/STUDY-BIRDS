import { useEffect, useState } from "react";
import { api } from "../../lib/api";
import { studentService } from "../../services/studentService";
import { useLanguage } from "../../hooks/useLanguage";
import { getErrorMessage } from "../../utils/errors";
import type { InvoiceItem } from "../../types";

type Wallet = {
  referralRewardAmount?: number;
  referralCode: string; balance: number;
  referrals: { _id: string; name: string; status: string; createdAt: string; qualifiedAt?: string | null }[];
  transactions: { _id: string; direction: string; kind: string; amount: number; notes?: string; createdAt: string }[];
};
const kindLabels: Record<string, [string, string]> = {
  "referral-reward": ["مكافأة إحالة", "Referral reward"], redemption: ["سداد فاتورة", "Invoice redemption"], adjustment: ["تسوية من الفريق", "Team adjustment"],
};

export const StudentWalletPage = () => {
  const { language } = useLanguage();
  const ar = language === "ar";
  const t = (a: string, b: string) => (ar ? a : b);
  const [wallet, setWallet] = useState<Wallet | null>(null);
  const [invoices, setInvoices] = useState<InvoiceItem[]>([]);
  const [redeemAmount, setRedeemAmount] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true), [busy, setBusy] = useState(false);
  const [error, setError] = useState(""), [success, setSuccess] = useState("");

  async function load() {
    setLoading(true);
    try {
      const [w, financials] = await Promise.all([api.get<Wallet>("/students/wallet"), studentService.getFinancials()]);
      setWallet(w.data);
      setInvoices(financials.invoices.filter((i) => i.status === "unpaid"));
    } catch (e) { setError(getErrorMessage(e, t("تعذر تحميل بيانات المحفظة", "Unable to load wallet data"))); }
    finally { setLoading(false); }
  }
  useEffect(() => { void load(); }, []);

  const referralLink = wallet ? `${window.location.origin}/register?ref=${wallet.referralCode}` : "";

  async function redeem(invoice: InvoiceItem) {
    const amount = Number(redeemAmount[invoice._id]);
    if (!Number.isFinite(amount) || amount <= 0) return;
    setBusy(true); setError(""); setSuccess("");
    try {
      await api.post("/students/wallet/redeem", { invoiceId: invoice._id, amount });
      setSuccess(t("تم استخدام الرصيد على الفاتورة.", "Credit applied to the invoice."));
      await load();
    } catch (e) { setError(getErrorMessage(e, t("تعذر استخدام الرصيد", "Unable to apply credit"))); }
    finally { setBusy(false); }
  }

  if (loading) return <p>{t("جارٍ التحميل…", "Loading…")}</p>;

  return <div className="space-y-6" dir={ar ? "rtl" : "ltr"}>
    <h1 className="text-2xl font-bold">{t("محفظتي", "My Wallet")}</h1>
    {error && <p role="alert" className="rounded-xl bg-red-50 p-3 text-red-800">{error}</p>}
    {success && <p role="status" className="rounded-xl bg-green-50 p-3 text-green-800">{success}</p>}

    <section className="rounded-2xl border bg-white p-5">
      <p className="text-sm text-slate-500">{t("رصيدك الحالي", "Current balance")}</p>
      <p className="mt-1 text-3xl font-bold text-slate-900">{wallet?.balance ?? 0}</p>
    </section>

    <section className="rounded-2xl border bg-white p-5">
      <h2 className="text-xl font-semibold">{t("ادعُ أصدقاءك", "Invite your friends")}</h2>
      <p className="mt-2 font-medium">{t('مكافأتك للإحالات الجديدة:','Your reward for new referrals:')} {wallet?.referralRewardAmount ?? '—'} USD</p>
      <p className="mt-2 text-sm text-slate-600">{t("عندما يقدّم صديقك أول طلب باستخدام كودك، تحصل على رصيد في محفظتك.", "When a friend submits their first application using your code, you get wallet credit.")}</p>
      <div className="mt-3 flex flex-wrap items-center gap-3">
        <code className="rounded-xl bg-slate-100 px-3 py-2 font-mono">{wallet?.referralCode}</code>
        <button className="rounded-xl border border-slate-300 px-3 py-2 text-sm" onClick={() => navigator.clipboard?.writeText(referralLink)}>{t("نسخ الرابط", "Copy link")}</button>
      </div>
      <div className="mt-4 space-y-2">
        {wallet?.referrals.length ? wallet.referrals.map((r) => <div key={r._id} className="flex items-center justify-between rounded-xl border border-slate-200 p-3 text-sm">
          <span>{r.name}</span>
          <span className="rounded-full bg-slate-100 px-3 py-1">{r.status === "qualified" ? t("مكتملة", "Qualified") : t("بانتظار أول طلب", "Awaiting first application")}</span>
        </div>) : <p className="text-sm text-slate-500">{t("لسه ما دعوت حدا.", "No referrals yet.")}</p>}
      </div>
    </section>

    {invoices.length > 0 && <section className="rounded-2xl border bg-white p-5">
      <h2 className="text-xl font-semibold">{t("استخدم رصيدك لسداد فاتورة", "Use your credit toward an invoice")}</h2>
      <div className="mt-3 space-y-3">
        {invoices.map((invoice) => {
          const remaining = invoice.amount - (invoice.walletCreditApplied || 0);
          return <div key={invoice._id} className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-slate-200 p-3">
            <div><p className="font-semibold">{invoice.description}</p><p className="text-sm text-slate-600">{t("متبقٍ", "Remaining")}: {remaining} {t("(رقم الفاتورة", "(invoice")} {invoice.invoiceNumber})</p></div>
            <div className="flex items-center gap-2">
              <input type="number" min="0" max={Math.min(remaining, wallet?.balance || 0)} className="w-24 rounded-xl border border-slate-300 p-2"
                value={redeemAmount[invoice._id] || ""} onChange={(e) => setRedeemAmount((d) => ({ ...d, [invoice._id]: e.target.value }))} />
              <button className="rounded-xl bg-brand-primary px-3 py-2 text-sm text-white disabled:opacity-50" disabled={busy || !(wallet?.balance)} onClick={() => void redeem(invoice)}>{t("استخدام", "Apply")}</button>
            </div>
          </div>;
        })}
      </div>
    </section>}

    <section className="rounded-2xl border bg-white p-5">
      <h2 className="text-xl font-semibold">{t("سجل المعاملات", "Transaction history")}</h2>
      <div className="mt-3 space-y-2">
        {wallet?.transactions.length ? wallet.transactions.map((tx) => <div key={tx._id} className="flex items-center justify-between rounded-xl border border-slate-200 p-3 text-sm">
          <span>{kindLabels[tx.kind]?.[ar ? 0 : 1] || tx.kind}{tx.notes ? ` — ${tx.notes}` : ""}</span>
          <span className={tx.direction === "credit" ? "font-semibold text-emerald-700" : "font-semibold text-red-700"}>{tx.direction === "credit" ? "+" : "-"}{tx.amount}</span>
        </div>) : <p className="text-sm text-slate-500">{t("لا توجد معاملات بعد.", "No transactions yet.")}</p>}
      </div>
    </section>
  </div>;
};
