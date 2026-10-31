import { useEffect, useState } from "react";
import { Copy, Link2, MousePointerClick } from "lucide-react";
import { StatsCard } from "../../components/dashboard/StatsCard";
import { partnerService } from "../../services/partnerService";
import type { ReferralSummary } from "../../types";
import { useLanguage } from "../../hooks/useLanguage";
import { getErrorMessage } from "../../utils/errors";

const formatCurrency = (value: number) =>
  new Intl.NumberFormat("en-US", { style: "currency", currency: "USD", maximumFractionDigits: 0 }).format(value || 0);

export const PartnerReferralPage = () => {
  const { language } = useLanguage();
  const isArabic = language === "ar";
  const [data, setData] = useState<ReferralSummary | null>(null);
  const [error, setError] = useState("");
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    partnerService
      .getReferral()
      .then(setData)
      .catch((issue) => setError(getErrorMessage(issue, isArabic ? "تعذر تحميل رابط الإحالة." : "Unable to load your referral link.")));
  }, [isArabic]);

  const handleCopy = async () => {
    if (!data) return;
    await navigator.clipboard.writeText(data.referralLink);
    setCopied(true);
    window.setTimeout(() => setCopied(false), 1500);
  };

  if (!data) {
    return <div className="panel p-8 text-sm text-slate-500">{error || (isArabic ? "جارٍ تحميل البيانات..." : "Loading referral data...")}</div>;
  }

  return (
    <div className="space-y-6">
      <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-4">
        <StatsCard label={isArabic ? "عدد الضغطات" : "Link Clicks"} value={data.summary.clicks} icon={<MousePointerClick className="h-5 w-5" />} />
        <StatsCard label={isArabic ? "عدد التسجيلات" : "Registrations"} value={data.summary.signups} icon={<Link2 className="h-5 w-5" />} />
        <StatsCard label={isArabic ? "الطلاب المقبولون" : "Accepted Students"} value={data.summary.acceptedStudents} icon={<Link2 className="h-5 w-5" />} />
        <StatsCard label={isArabic ? "العمولات الناتجة" : "Generated Commissions"} value={formatCurrency(data.summary.generatedCommissions)} icon={<Link2 className="h-5 w-5" />} />
      </div>

      <section className="panel p-6">
        {!!data.registrations?.length && <div className="mb-6 space-y-2"><h2 className="font-semibold">{isArabic?'التسجيلات عبر رابطك':'Registrations through your link'}</h2>{data.registrations.map(row=><p key={row.id} className="rounded-xl bg-slate-50 p-3 text-sm">{row.name} · {new Date(row.createdAt).toLocaleDateString(isArabic?'ar':'en')}</p>)}</div>}
        <h1 className="text-3xl font-semibold text-slate-900">{isArabic ? "رابط الإحالة" : "Affiliate & Referral Link"}</h1>
        <p className="mt-2 text-sm text-slate-500">
          {isArabic ? "شارك هذا الرابط لربط التسجيلات الجديدة بحسابك مباشرة." : "Share this link to associate new registrations with your account."}
        </p>
        <div className="mt-6 rounded-[2rem] border border-slate-200 bg-slate-50 p-5">
          <div className="rounded-2xl bg-white px-4 py-4 text-sm text-slate-700">{data.referralLink}</div>
          <div className="mt-4 flex flex-wrap items-center gap-3">
            <button onClick={handleCopy} className="inline-flex items-center gap-2 rounded-full bg-brand-900 px-5 py-3 text-sm font-semibold text-white">
              <Copy className="h-4 w-4" />
              {copied ? (isArabic ? "تم النسخ" : "Copied") : isArabic ? "نسخ الرابط" : "Copy Link"}
            </button>
            <span className="rounded-full bg-white px-4 py-2 text-sm font-semibold text-slate-700">
              {isArabic ? "كود الإحالة" : "Referral Code"}: {data.referralCode}
            </span>
          </div>
        </div>
      </section>
    </div>
  );
};
