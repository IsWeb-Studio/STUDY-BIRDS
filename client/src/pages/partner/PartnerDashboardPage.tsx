import { useEffect, useState } from "react";
import { Bell, CircleDollarSign, FileCheck2, Users } from "lucide-react";
import { StatsCard } from "../../components/dashboard/StatsCard";
import { EmptyState } from "../../components/EmptyState";
import { partnerService } from "../../services/partnerService";
import type { PartnerOverview } from "../../types";
import { useLanguage } from "../../hooks/useLanguage";
import { getErrorMessage } from "../../utils/errors";

const formatCurrency = (value: number) =>
  new Intl.NumberFormat("en-US", { style: "currency", currency: "USD", maximumFractionDigits: 0 }).format(value || 0);

export const PartnerDashboardPage = () => {
  const { language } = useLanguage();
  const isArabic = language === "ar";
  const [overview, setOverview] = useState<PartnerOverview | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    partnerService
      .getOverview()
      .then(setOverview)
      .catch((issue) =>
        setError(
          getErrorMessage(
            issue,
            isArabic ? "تعذر تحميل لوحة الوكيل الآن." : "Unable to load the agent dashboard right now."
          )
        )
      );
  }, [isArabic]);

  if (error) {
    return <EmptyState title={isArabic ? "تعذر التحميل" : "Unable to load"} description={error} />;
  }

  if (!overview) {
    return <div className="panel p-8 text-sm text-slate-500">{isArabic ? "جارٍ تحميل البيانات..." : "Loading dashboard..."}</div>;
  }

  const cards = [
    {
      label: isArabic ? "إجمالي الطلاب" : "Total Students",
      value: overview.stats.totalStudents,
      icon: <Users className="h-5 w-5" />,
    },
    {
      label: isArabic ? "الطلاب المقبولون" : "Accepted Students",
      value: overview.stats.acceptedStudents,
      icon: <FileCheck2 className="h-5 w-5" />,
    },
    {
      label: isArabic ? "إجمالي الأرباح المستلمة" : "Total Received Earnings",
      value: formatCurrency(overview.stats.totalReceivedEarnings),
      icon: <CircleDollarSign className="h-5 w-5" />,
    },
    {
      label: isArabic ? "الأرباح المعلقة" : "Pending Earnings",
      value: formatCurrency(overview.stats.pendingEarnings),
      icon: <Bell className="h-5 w-5" />,
    },
  ];

  const recentCards = [
    {
      title: isArabic ? "آخر طالب تمت إضافته" : "Latest student added",
      body: overview.recent.latestStudent
        ? `${overview.recent.latestStudent.name} • ${overview.recent.latestStudent.desiredProgram || (isArabic ? "بدون تخصص محدد" : "No program selected")}`
        : isArabic
          ? "لم تتم إضافة أي طالب بعد."
          : "No students have been added yet.",
    },
    {
      title: isArabic ? "آخر تحديث على حالة طالب" : "Latest student status update",
      body: overview.recent.latestStudentStatusUpdate
        ? `${overview.recent.latestStudentStatusUpdate.name} • ${overview.recent.latestStudentStatusUpdate.applicationStatus}`
        : isArabic
          ? "لا توجد تحديثات حالة بعد."
          : "No status updates yet.",
    },
    {
      title: isArabic ? "آخر طلب سحب أرباح" : "Latest payout request",
      body: overview.recent.latestPayoutRequest
        ? `${formatCurrency(overview.recent.latestPayoutRequest.amount)} • ${overview.recent.latestPayoutRequest.status}`
        : isArabic
          ? "لا توجد طلبات سحب حتى الآن."
          : "No payout requests yet.",
    },
    {
      title: isArabic ? "آخر إشعار" : "Latest notification",
      body: overview.recent.latestNotification
        ? `${overview.recent.latestNotification.title} • ${overview.recent.latestNotification.message}`
        : isArabic
          ? "لا توجد إشعارات جديدة."
          : "No new notifications.",
    },
  ];

  return (
    <div className="space-y-6">
      <section className="dashboard-page-hero panel overflow-hidden bg-white p-6 text-slate-900">
        <p className="text-sm font-semibold uppercase tracking-[0.24em] text-orange-300">{isArabic ? "لوحة الوكيل" : "Agent Dashboard"}</p>
        <h1 className="mt-3 text-3xl font-semibold">{isArabic ? "مرحباً بك في لوحة وكلاء Study Birds" : "Welcome to the Study Birds agent workspace"}</h1>
        <p className="mt-3 max-w-3xl text-sm leading-7 text-slate-200">
          {isArabic
            ? "مرحباً بك في لوحة تحكم وكلاء Study Birds، أدر حسابك وتتبع طلابك وعمولاتك من مكان واحد."
            : "Manage your account, students, and earnings from one organized workspace."}
        </p>
      </section>

      <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-4">
        {cards.map((card) => (
          <StatsCard key={card.label} label={card.label} value={card.value} icon={card.icon} />
        ))}
      </div>

      <section className="panel p-6">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h2 className="text-2xl font-semibold text-slate-900">{isArabic ? "آخر التحديثات" : "Latest updates"}</h2>
            <p className="mt-2 text-sm text-slate-500">
              {isArabic ? "ملخص سريع لآخر ما حدث في حسابك." : "A quick summary of the latest changes in your account."}
            </p>
          </div>
          <span className="rounded-full bg-slate-100 px-4 py-2 text-sm font-semibold text-slate-700">
            {isArabic ? "حالة التوثيق" : "Verification"}: {overview.stats.verificationStatus}
          </span>
        </div>
        <div className="mt-6 grid gap-4 lg:grid-cols-2">
          {recentCards.map((item) => (
            <div key={item.title} className="rounded-3xl border border-slate-200 bg-slate-50 p-5">
              <h3 className="text-base font-semibold text-slate-900">{item.title}</h3>
              <p className="mt-3 text-sm leading-6 text-slate-600">{item.body}</p>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
};
