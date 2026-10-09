import { useEffect, useState } from "react";
import { BellRing, Clock3, ShieldCheck, UserPlus } from "lucide-react";
import { ApplicationStatusBadge } from "../../components/ApplicationStatusBadge";
import { StatsCard } from "../../components/dashboard/StatsCard";
import { adminService } from "../../services/adminService";
import type { AdminOverview } from "../../types";
import { formatDate } from "../../utils/format";
import { useLanguage } from "../../hooks/useLanguage";
import { dt } from "../../utils/dashboardTranslations";

const emptyOverview: AdminOverview = {
  stats: {
    users: 0,
    students: 0,
    admins: 0,
    partners: 0,
    inactiveUsers: 0,
    universities: 0,
    programs: 0,
    applications: 0,
    submittedApplications: 0,
    underReviewApplications: 0,
  },
  recentApplications: [],
  recentUsers: [],
  applicationsByStatus: {},
};

export const AdminDashboardPage = () => {
  const { language, t } = useLanguage();
  const [overview, setOverview] = useState<AdminOverview>(emptyOverview);

  useEffect(() => {
    adminService.getOverview().then(setOverview);
  }, []);

  const { stats, recentApplications, recentUsers, applicationsByStatus } = overview;

  return (
    <div className="space-y-6">
      <section className="dashboard-page-hero panel overflow-hidden bg-white text-slate-900">
        <div className="grid gap-8 px-8 py-9 lg:grid-cols-[1.35fr_0.85fr]">
          <div>
            <p className="text-xs uppercase tracking-[0.3em] text-brand-300">{dt(language, "adminMissionControl")}</p>
            <h1 className="mt-3 text-3xl font-semibold leading-tight">{dt(language, "professionalDashboard")}</h1>
            <p className="mt-4 max-w-2xl text-sm text-slate-300">
              {dt(language, "monitorEverything")}
            </p>
            <div className="mt-6 grid gap-3 sm:grid-cols-3">
              <div className="rounded-3xl border border-white/10 bg-white/5 p-4">
                <p className="text-xs text-slate-400">{dt(language, "submittedTodayFocus")}</p>
                <p className="mt-2 text-2xl font-semibold">{stats.submittedApplications}</p>
              </div>
              <div className="rounded-3xl border border-white/10 bg-white/5 p-4">
                <p className="text-xs text-slate-400">{dt(language, "underReview")}</p>
                <p className="mt-2 text-2xl font-semibold">{stats.underReviewApplications}</p>
              </div>
              <div className="rounded-3xl border border-white/10 bg-white/5 p-4">
                <p className="text-xs text-slate-400">{dt(language, "inactiveAccounts")}</p>
                <p className="mt-2 text-2xl font-semibold">{stats.inactiveUsers}</p>
              </div>
            </div>
          </div>
          <div className="grid gap-3">
            <div className="rounded-3xl border border-emerald-400/20 bg-emerald-400/10 p-5">
              <div className="flex items-center gap-3">
                <ShieldCheck className="h-5 w-5 text-emerald-300" />
                <p className="font-semibold">{dt(language, "operationsHealth")}</p>
              </div>
              <p className="mt-3 text-sm text-slate-200">{dt(language, "modulesConnected")}</p>
            </div>
            <div className="rounded-3xl border border-brand-300/20 bg-brand-300/10 p-5">
              <div className="flex items-center gap-3">
                <BellRing className="h-5 w-5 text-brand-300" />
                <p className="font-semibold">{dt(language, "whatNeedsAttention")}</p>
              </div>
              <p className="mt-3 text-sm text-slate-200">
                {applicationsByStatus["submitted"] || 0} / {applicationsByStatus["under-review"] || 0} {dt(language, "waitingPipeline")}
              </p>
            </div>
          </div>
        </div>
      </section>

      <section className="grid gap-5 md:grid-cols-2 xl:grid-cols-4">
        <StatsCard label={dt(language, "users")} value={stats.users} />
        <StatsCard label={t("students")} value={stats.students} />
        <StatsCard label={t("universities")} value={stats.universities} />
        <StatsCard label={t("programs")} value={stats.programs} />
      </section>

      <section className="grid gap-6 xl:grid-cols-[1.2fr_0.8fr]">
        <div className="panel p-6">
          <div className="flex items-center justify-between gap-4">
            <div>
              <h2 className="text-2xl font-semibold text-slate-900">{dt(language, "latestApplications")}</h2>
              <p className="mt-1 text-sm text-slate-500">{dt(language, "incomingRequests")}</p>
            </div>
            <div className="rounded-full bg-slate-100 px-4 py-2 text-sm font-medium text-slate-600">{stats.applications} {dt(language, "total")}</div>
          </div>
          <div className="mt-6 space-y-4">
            {recentApplications.map((application) => (
              <div key={application._id} className="rounded-3xl border border-slate-200 bg-slate-50 p-5">
                <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
                  <div>
                    <p className="font-semibold text-slate-900">{application.program?.title || "Untitled application"}</p>
                    <p className="mt-1 text-sm text-slate-500">
                      {application.student?.name || "Unknown student"} • {application.program?.university?.name || "Unknown university"}
                    </p>
                  </div>
                  <ApplicationStatusBadge status={application.status} />
                </div>
                <div className="mt-4 flex flex-wrap gap-3 text-xs text-slate-500">
                  <span className="rounded-full bg-white px-3 py-1">{dt(language, "submitted")} {formatDate(application.submittedAt || application.createdAt)}</span>
                  <span className="rounded-full bg-white px-3 py-1">{application.documents?.length || 0} {dt(language, "documents")}</span>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="space-y-6">
          <div className="panel p-6">
            <h2 className="text-2xl font-semibold text-slate-900">{dt(language, "applicationPipeline")}</h2>
            <div className="mt-6 space-y-4">
              {[
                ["submitted", dt(language, "submitted")],
                ["under-review", dt(language, "underReview")],
                ["accepted", dt(language, "reviewStatusAccepted")],
                ["rejected", dt(language, "reviewStatusRejected")],
              ].map(([status, label]) => (
                <div key={status}>
                  <div className="mb-2 flex items-center justify-between text-sm">
                    <span className="font-medium text-slate-700">{label}</span>
                    <span className="text-slate-500">{applicationsByStatus[status] || 0}</span>
                  </div>
                  <div className="h-2 rounded-full bg-slate-100">
                    <div
                      className="h-2 rounded-full bg-brand-900"
                      style={{
                        width: `${stats.applications ? ((applicationsByStatus[status] || 0) / stats.applications) * 100 : 0}%`,
                      }}
                    />
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="panel p-6">
            <h2 className="text-2xl font-semibold text-slate-900">{dt(language, "newestUsers")}</h2>
            <div className="mt-5 space-y-4">
              {recentUsers.map((user) => (
                <div key={user._id} className="flex items-center justify-between rounded-3xl border border-slate-200 px-4 py-3">
                  <div className="flex items-center gap-3">
                    <div className="flex h-11 w-11 items-center justify-center rounded-full bg-brand-100 text-brand-700">
                      <UserPlus className="h-4 w-4" />
                    </div>
                    <div>
                      <p className="font-semibold text-slate-900">{user.name}</p>
                      <p className="text-sm text-slate-500">{user.email}</p>
                    </div>
                  </div>
                  <div className="text-right text-xs text-slate-500">
                    <p className="capitalize">{user.role}</p>
                    <p className="mt-1 flex items-center gap-1">
                      <Clock3 className="h-3.5 w-3.5" />
                      {formatDate(user.createdAt)}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>
    </div>
  );
};
