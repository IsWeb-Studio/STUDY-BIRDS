import { useEffect, useState } from "react";
import { Award, Coins, RefreshCw, Star, TrendingUp } from "lucide-react";
import { EmptyState } from "../../components/EmptyState";
import { useLanguage } from "../../hooks/useLanguage";
import { api } from "../../lib/api";
import { getErrorMessage } from "../../utils/errors";
import { formatDate } from "../../utils/format";

type RewardRule = {
  _id: string;
  actionCode: string;
  labelAr: string;
  labelEn: string;
  points: number;
  maxPerUser?: number | null;
};

type RewardEntry = {
  _id: string;
  rule?: RewardRule;
  points: number;
  notes?: string;
  createdAt: string;
};

type RewardsData = {
  totalPoints: number;
  entries: RewardEntry[];
  rules: RewardRule[];
};

export const StudentRewardsPage = () => {
  const { language } = useLanguage();
  const ar = language === "ar";
  const t = (a: string, b: string) => (ar ? a : b);

  const [data, setData] = useState<RewardsData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  async function load() {
    setLoading(true);
    setError("");
    try {
      const res = await api.get<RewardsData>("/students/rewards");
      setData(res.data);
    } catch (e) {
      setError(getErrorMessage(e, t("تعذر تحميل المكافآت", "Unable to load rewards")));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { void load(); }, []);

  if (loading) {
    return (
      <div className="space-y-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="panel animate-pulse p-5">
            <div className="h-4 w-40 rounded bg-slate-200" />
            <div className="mt-3 h-3 w-56 rounded bg-slate-100" />
          </div>
        ))}
      </div>
    );
  }

  if (error) return (
    <div className="space-y-4">
      <EmptyState title={t("تعذر التحميل", "Unable to load")} description={error} />
      <div className="flex justify-center"><button onClick={load} className="btn-primary text-sm">{t("إعادة المحاولة", "Retry")}</button></div>
    </div>
  );

  const entries = data?.entries ?? [];
  const rules = data?.rules ?? [];
  const totalPoints = data?.totalPoints ?? 0;

  return (
    <div className="space-y-6" dir={ar ? "rtl" : "ltr"}>
      {/* Header */}
      <div className="panel dashboard-page-hero overflow-hidden p-6 sm:p-8">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-slate-900 sm:text-3xl">{t("المكافآت والنقاط", "Rewards & Points")}</h1>
            <p className="mt-1 text-sm text-slate-500">{t("تتبع نقاطك واستكشف طرق كسب المزيد", "Track your points and discover ways to earn more")}</p>
          </div>
          <button onClick={load} className="inline-flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50">
            <RefreshCw className="h-4 w-4" />
            {t("تحديث", "Refresh")}
          </button>
        </div>
      </div>

      {/* Points summary */}
      <div className="grid gap-4 sm:grid-cols-3">
        <div className="panel col-span-3 flex items-center gap-5 p-6 sm:col-span-1">
          <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-amber-50">
            <Coins className="h-8 w-8 text-amber-500" />
          </div>
          <div>
            <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">{t("إجمالي النقاط", "Total Points")}</p>
            <p className="text-3xl font-bold text-slate-900">{totalPoints.toLocaleString()}</p>
          </div>
        </div>
        <div className="panel flex items-center gap-5 p-6">
          <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-blue-50">
            <TrendingUp className="h-6 w-6 text-blue-500" />
          </div>
          <div>
            <p className="text-xs text-slate-400">{t("المعاملات", "Transactions")}</p>
            <p className="text-2xl font-bold text-slate-900">{entries.length}</p>
          </div>
        </div>
        <div className="panel flex items-center gap-5 p-6">
          <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-purple-50">
            <Star className="h-6 w-6 text-purple-500" />
          </div>
          <div>
            <p className="text-xs text-slate-400">{t("طرق الكسب المتاحة", "Available ways to earn")}</p>
            <p className="text-2xl font-bold text-slate-900">{rules.length}</p>
          </div>
        </div>
      </div>

      {/* How to earn */}
      {rules.length > 0 && (
        <div className="panel p-6">
          <h2 className="mb-4 flex items-center gap-2 text-base font-semibold text-slate-800">
            <Award className="h-5 w-5 text-amber-500" />
            {t("طرق كسب النقاط", "Ways to Earn Points")}
          </h2>
          <div className="grid gap-3 sm:grid-cols-2">
            {rules.map((rule) => (
              <div key={rule._id} className="flex items-center gap-4 rounded-xl border border-amber-100 bg-amber-50/50 p-4">
                <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-amber-100">
                  <Coins className="h-5 w-5 text-amber-600" />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="truncate text-sm font-semibold text-slate-800">{ar ? rule.labelAr : rule.labelEn}</p>
                  {rule.maxPerUser && (
                    <p className="text-xs text-slate-400">{t(`حتى ${rule.maxPerUser} مرة`, `Up to ${rule.maxPerUser}×`)}</p>
                  )}
                </div>
                <span className="shrink-0 rounded-full bg-amber-500 px-2.5 py-0.5 text-sm font-bold text-white">
                  +{rule.points}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* History */}
      <div className="panel p-6">
        <h2 className="mb-4 text-base font-semibold text-slate-800">{t("سجل النقاط", "Points History")}</h2>
        {entries.length === 0 ? (
          <EmptyState
            title={t("لا توجد نقاط بعد", "No points yet")}
            description={t("أكمل الإجراءات المدرجة أعلاه لكسب نقاط مكافأتك.", "Complete the actions listed above to earn your reward points.")}
          />
        ) : (
          <div className="divide-y divide-slate-100">
            {entries.map((entry) => (
              <div key={entry._id} className="flex items-center justify-between gap-4 py-3.5">
                <div className="flex items-center gap-3">
                  <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-amber-50">
                    <Star className="h-4 w-4 text-amber-500" />
                  </div>
                  <div>
                    <p className="text-sm font-medium text-slate-700">
                      {entry.rule ? (ar ? entry.rule.labelAr : entry.rule.labelEn) : (entry.notes ?? t("نقاط مضافة", "Points added"))}
                    </p>
                    <p className="text-xs text-slate-400">{formatDate(entry.createdAt)}</p>
                  </div>
                </div>
                <span className={`text-sm font-bold ${entry.points >= 0 ? "text-emerald-600" : "text-red-500"}`}>
                  {entry.points >= 0 ? "+" : ""}{entry.points}
                </span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};
