import { type ReactNode, useEffect, useState } from "react";
import { CheckCircle2, Download, FileText, Globe, HeartPulse, RefreshCw, ShieldCheck, XCircle } from "lucide-react";
import { Link } from "react-router-dom";
import { EmptyState } from "../../components/EmptyState";
import { useLanguage } from "../../hooks/useLanguage";
import { api } from "../../lib/api";
import { studentService } from "../../services/studentService";
import type { DocumentItem, StudentDashboardOverview } from "../../types";
import { getErrorMessage } from "../../utils/errors";

type Tab = "visa" | "insurance" | "equivalency";

const VISA_REQUIREMENTS = [
  { docKey: "passport", labelAr: "جواز السفر", labelEn: "Passport" },
  { docKey: "biometric-photo", labelAr: "صورة شخصية", labelEn: "Biometric Photo" },
  { docKey: "latest-qualification", labelAr: "آخر مؤهل دراسي", labelEn: "Latest Qualification" },
  { docKey: "language-certificate", labelAr: "شهادة اللغة (إن وُجدت)", labelEn: "Language Certificate (if any)" },
];

const VISA_STAGES = [
  { labelAr: "لم تبدأ", labelEn: "Not Started" },
  { labelAr: "التحضير", labelEn: "Preparation" },
  { labelAr: "إعداد المستندات", labelEn: "Document Preparation" },
  { labelAr: "تم التقديم", labelEn: "Submitted" },
  { labelAr: "قيد المراجعة", labelEn: "Under Review" },
  { labelAr: "تمت الموافقة", labelEn: "Approved" },
];

function visaStepFromStageKey(stageKey: string, allStages: StudentDashboardOverview["progress"]["stages"]): number {
  const idx = allStages.findIndex((s) => s.key === stageKey);
  if (idx < 0) return 0;
  if (idx < 5) return 0;
  if (idx < 7) return 1;
  if (idx < 8) return 2;
  if (idx === 8) return 3;
  return 5;
}

const statusBadge = (s: string | undefined): { label: string; labelAr: string; cls: string } => {
  switch (s) {
    case "active": return { label: "Active", labelAr: "ساري", cls: "bg-emerald-100 text-emerald-700" };
    case "expired": return { label: "Expired", labelAr: "منتهي", cls: "bg-red-100 text-red-700" };
    case "completed": return { label: "Completed", labelAr: "مكتمل", cls: "bg-blue-100 text-blue-700" };
    case "under-review": return { label: "Under Review", labelAr: "قيد المراجعة", cls: "bg-yellow-100 text-yellow-700" };
    case "submitted": return { label: "Submitted", labelAr: "مقدّم", cls: "bg-blue-100 text-blue-700" };
    case "rejected": return { label: "Rejected", labelAr: "مرفوض", cls: "bg-red-100 text-red-700" };
    default: return { label: "Pending", labelAr: "في الانتظار", cls: "bg-slate-100 text-slate-600" };
  }
};

function fmtDate(raw: unknown): string {
  const d = raw ? new Date(String(raw)) : null;
  if (!d || isNaN(d.getTime())) return "—";
  return d.toLocaleDateString("ar-SA", { year: "numeric", month: "short", day: "numeric" });
}

export const StudentVisaCenterPage = () => {
  const { language } = useLanguage();
  const ar = language === "ar";
  const t = (a: string, b: string) => (ar ? a : b);

  const [tab, setTab] = useState<Tab>("visa");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [stages, setStages] = useState<StudentDashboardOverview["progress"]["stages"]>([]);
  const [currentStageKey, setCurrentStageKey] = useState("");
  const [uploadedDocKeys, setUploadedDocKeys] = useState<Set<string>>(new Set());
  const [insurance, setInsurance] = useState<Record<string, unknown> | null>(null);
  const [equivalency, setEquivalency] = useState<Record<string, unknown> | null>(null);

  async function load() {
    setLoading(true);
    setError("");
    try {
      const [overview, docs, ins, eq] = await Promise.all([
        studentService.getOverview(),
        studentService.getDocuments(),
        api.get<Record<string, unknown> | null>("/students/insurance").then((r) => r.data).catch(() => null),
        api.get<Record<string, unknown> | null>("/students/equivalency").then((r) => r.data).catch(() => null),
      ]);
      setStages(overview.progress.stages);
      const current = overview.progress.stages.find((s) => s.status === "current");
      setCurrentStageKey(current?.key ?? "");
      setUploadedDocKeys(new Set((docs as DocumentItem[]).map((d) => d.type ?? "")));
      setInsurance(ins ?? null);
      setEquivalency(eq ?? null);
    } catch (e) {
      setError(getErrorMessage(e, t("تعذر تحميل بيانات التأشيرة", "Unable to load visa center data")));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { void load(); }, []);

  const visaStep = visaStepFromStageKey(currentStageKey, stages);
  const currentStageName = stages.find((s) => s.key === currentStageKey);

  const tabs: { key: Tab; labelAr: string; labelEn: string; icon: ReactNode }[] = [
    { key: "visa", labelAr: "التأشيرة", labelEn: "Visa", icon: <Globe className="h-4 w-4" /> },
    { key: "insurance", labelAr: "التأمين", labelEn: "Insurance", icon: <HeartPulse className="h-4 w-4" /> },
    { key: "equivalency", labelAr: "المعادلة", labelEn: "Equivalency", icon: <ShieldCheck className="h-4 w-4" /> },
  ];

  if (loading) {
    return (
      <div className="space-y-4">
        {Array.from({ length: 5 }).map((_, i) => (
          <div key={i} className="panel animate-pulse p-5">
            <div className="h-4 w-48 rounded bg-slate-200" />
            <div className="mt-3 h-3 w-full rounded bg-slate-100" />
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

  return (
    <div className="space-y-6" dir={ar ? "rtl" : "ltr"}>
      {/* Header */}
      <div className="panel dashboard-page-hero overflow-hidden p-6 sm:p-8">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-slate-900 sm:text-3xl">{t("مركز التأشيرة والخدمات", "Visa & Services Center")}</h1>
            <p className="mt-1 text-sm text-slate-500">{t("التأشيرة والتأمين الصحي ومعادلة الشهادة", "Visa requirements, health insurance, and certificate equivalency")}</p>
          </div>
          <button onClick={load} className="inline-flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50">
            <RefreshCw className="h-4 w-4" />
            {t("تحديث", "Refresh")}
          </button>
        </div>

        {/* Current stage */}
        {currentStageName && (
          <div className="mt-5 flex items-center gap-3 rounded-xl bg-white/10 p-3">
            <span className="text-xs text-slate-400">{t("المرحلة الحالية:", "Current stage:")}</span>
            <span className="text-sm font-semibold text-slate-800">{ar ? currentStageName.titleAr : currentStageName.titleEn}</span>
          </div>
        )}
      </div>

      {/* Tabs */}
      <div className="panel p-0 overflow-hidden">
        <div className="flex border-b border-slate-200" role="tablist">
          {tabs.map((tb) => (
            <button
              key={tb.key}
              role="tab"
              aria-selected={tab === tb.key}
              onClick={() => setTab(tb.key)}
              className={`flex flex-1 items-center justify-center gap-2 px-4 py-3 text-sm font-medium transition-colors ${tab === tb.key ? "border-b-2 border-blue-600 text-blue-600" : "text-slate-500 hover:text-slate-700"}`}
            >
              {tb.icon}
              {ar ? tb.labelAr : tb.labelEn}
            </button>
          ))}
        </div>

        <div className="p-6">
          {/* VISA TAB */}
          {tab === "visa" && (
            <div className="space-y-6">
              {/* Visa progress steps */}
              <div>
                <h2 className="mb-4 text-sm font-semibold text-slate-700">{t("مراحل التأشيرة", "Visa Stages")}</h2>
                <ol className="flex flex-col gap-0">
                  {VISA_STAGES.map((stage, i) => {
                    const done = i < visaStep;
                    const active = i === visaStep;
                    const isLast = i === VISA_STAGES.length - 1;
                    return (
                      <li key={i} className="relative flex items-start gap-3 pb-6 last:pb-0">
                        {!isLast && (
                          <div className={`absolute top-7 ${ar ? "right-3" : "left-3"} bottom-0 w-0.5 ${done ? "bg-emerald-300" : "bg-slate-200"}`} />
                        )}
                        <div className={`relative z-10 flex h-7 w-7 shrink-0 items-center justify-center rounded-full border-2 ${done ? "border-emerald-500 bg-emerald-500" : active ? "border-orange-500 bg-orange-50" : "border-slate-300 bg-white"}`}>
                          {done ? <CheckCircle2 className="h-4 w-4 text-white" /> : <span className={`text-xs font-bold ${active ? "text-orange-600" : "text-slate-400"}`}>{i + 1}</span>}
                        </div>
                        <div className="pt-0.5">
                          <p className={`text-sm font-medium ${done ? "text-emerald-700" : active ? "text-orange-600 font-semibold" : "text-slate-400"}`}>
                            {ar ? stage.labelAr : stage.labelEn}
                          </p>
                        </div>
                      </li>
                    );
                  })}
                </ol>
              </div>

              {/* Document checklist */}
              <div>
                <h2 className="mb-3 text-sm font-semibold text-slate-700">{t("المستندات المطلوبة للتأشيرة", "Required Visa Documents")}</h2>
                <div className="divide-y divide-slate-100 rounded-xl border border-slate-200">
                  {VISA_REQUIREMENTS.map((req) => {
                    const done = uploadedDocKeys.has(req.docKey);
                    return (
                      <div key={req.docKey} className="flex items-center justify-between gap-3 px-4 py-3">
                        <div className="flex items-center gap-3">
                          {done
                            ? <CheckCircle2 className="h-5 w-5 text-emerald-500 shrink-0" />
                            : <XCircle className="h-5 w-5 text-slate-300 shrink-0" />
                          }
                          <span className={`text-sm ${done ? "text-slate-700" : "text-slate-500"}`}>
                            {ar ? req.labelAr : req.labelEn}
                          </span>
                        </div>
                        {done
                          ? <span className="text-xs font-semibold text-emerald-600">{t("مرفوع", "Uploaded")}</span>
                          : <Link to="/student/documents" className="text-xs font-semibold text-blue-600 hover:underline">{t("رفع", "Upload")}</Link>
                        }
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* Notice */}
              <p className="rounded-xl bg-blue-50 p-4 text-sm text-blue-700">
                {t(
                  "الموعد الدقيق لمقابلة القنصلية يُحدَّد من قِبل فريق Study Birds وسيتم إبلاغك عبر الإشعارات.",
                  "The exact consulate interview date is scheduled by the Study Birds team. You will be notified via notifications."
                )}
              </p>
            </div>
          )}

          {/* INSURANCE TAB */}
          {tab === "insurance" && (
            <div className="space-y-4">
              {!insurance ? (
                <EmptyState
                  title={t("لا تتوفر بيانات التأمين بعد", "No insurance data yet")}
                  description={t("سيقوم الفريق بإضافة تفاصيل وثيقة تأمينك الصحي هنا.", "The team will add your health insurance policy details here.")}
                />
              ) : (
                <>
                  {/* Status card */}
                  <div className="flex items-center gap-4 rounded-xl border border-slate-200 bg-white p-5">
                    <div className="flex h-14 w-14 items-center justify-center rounded-xl bg-emerald-50">
                      <HeartPulse className="h-7 w-7 text-emerald-500" />
                    </div>
                    <div>
                      <p className="text-sm font-bold text-slate-900">{t("التأمين الصحي", "Health Insurance")}</p>
                      <span className={`mt-1 inline-flex rounded-full px-2.5 py-0.5 text-xs font-semibold ${statusBadge(insurance.status as string).cls}`}>
                        {ar ? statusBadge(insurance.status as string).labelAr : statusBadge(insurance.status as string).label}
                      </span>
                    </div>
                  </div>

                  <div className="divide-y divide-slate-100 rounded-xl border border-slate-200 bg-white">
                    {[
                      [t("مزود التأمين", "Insurance Provider"), insurance.provider],
                      [t("رقم الوثيقة", "Policy Number"), insurance.policyNumber],
                      [t("نطاق التغطية", "Coverage"), insurance.coverage],
                      [t("تاريخ البداية", "Start Date"), fmtDate(insurance.startDate)],
                      [t("تاريخ الانتهاء", "End Date"), fmtDate(insurance.endDate)],
                    ].map(([label, value]) => (
                      <div key={String(label)} className="flex items-center justify-between gap-4 px-5 py-3.5">
                        <span className="text-sm text-slate-500">{label}</span>
                        <span className="text-sm font-semibold text-slate-800">{String(value ?? "—")}</span>
                      </div>
                    ))}
                  </div>

                  {insurance.notes && (
                    <p className="rounded-xl bg-slate-50 p-4 text-sm text-slate-600">{String(insurance.notes)}</p>
                  )}

                  {insurance.cardFileUrl && (
                    <a href={String(insurance.cardFileUrl)} target="_blank" rel="noreferrer" className="btn-primary flex w-full items-center justify-center gap-2">
                      <Download className="h-4 w-4" />
                      {t("تحميل بطاقة التأمين", "Download Insurance Card")}
                    </a>
                  )}
                </>
              )}
            </div>
          )}

          {/* EQUIVALENCY TAB */}
          {tab === "equivalency" && (
            <div className="space-y-4">
              {!equivalency ? (
                <EmptyState
                  title={t("لا تتوفر بيانات المعادلة بعد", "No equivalency data yet")}
                  description={t("سيقوم الفريق بإضافة تفاصيل إجراءات معادلة شهادتك هنا.", "The team will add your certificate equivalency procedure details here.")}
                />
              ) : (
                <>
                  {/* Status card */}
                  <div className="flex items-center gap-4 rounded-xl border border-slate-200 bg-white p-5">
                    <div className={`flex h-14 w-14 items-center justify-center rounded-xl ${statusBadge(equivalency.status as string).cls}`}>
                      <ShieldCheck className="h-7 w-7" />
                    </div>
                    <div>
                      <p className="text-sm font-bold text-slate-900">{t("معادلة الشهادة", "Certificate Equivalency")}</p>
                      <span className={`mt-1 inline-flex rounded-full px-2.5 py-0.5 text-xs font-semibold ${statusBadge(equivalency.status as string).cls}`}>
                        {ar ? statusBadge(equivalency.status as string).labelAr : statusBadge(equivalency.status as string).label}
                      </span>
                    </div>
                  </div>

                  <div className="divide-y divide-slate-100 rounded-xl border border-slate-200 bg-white">
                    {[
                      [t("الجهة المختصة", "Authority"), equivalency.authority],
                      [t("رقم الطلب", "Application Number"), equivalency.applicationNumber],
                      [t("تاريخ التقديم", "Submission Date"), fmtDate(equivalency.submittedAt)],
                      [t("الموعد المتوقع للانتهاء", "Expected Completion"), fmtDate(equivalency.expectedCompletionDate)],
                      [t("الرسوم", "Fees"), equivalency.fees],
                    ].map(([label, value]) => (
                      <div key={String(label)} className="flex items-center justify-between gap-4 px-5 py-3.5">
                        <span className="text-sm text-slate-500">{label}</span>
                        <span className="text-sm font-semibold text-slate-800">{String(value ?? "—")}</span>
                      </div>
                    ))}
                  </div>

                  {(equivalency.requiredDocuments as string[] | undefined)?.length ? (
                    <div className="rounded-xl border border-slate-200 bg-white p-5">
                      <p className="mb-3 text-sm font-semibold text-slate-700">{t("المستندات المطلوبة", "Required Documents")}</p>
                      <ul className="space-y-2">
                        {(equivalency.requiredDocuments as string[]).map((doc, i) => (
                          <li key={i} className="flex items-center gap-2 text-sm text-slate-600">
                            <FileText className="h-4 w-4 text-blue-400 shrink-0" />
                            {doc}
                          </li>
                        ))}
                      </ul>
                    </div>
                  ) : null}

                  {equivalency.notes && (
                    <p className="rounded-xl bg-slate-50 p-4 text-sm text-slate-600">{String(equivalency.notes)}</p>
                  )}

                  {equivalency.resultFileUrl && (
                    <a href={String(equivalency.resultFileUrl)} target="_blank" rel="noreferrer" className="btn-primary flex w-full items-center justify-center gap-2">
                      <Download className="h-4 w-4" />
                      {t("تحميل وثيقة المعادلة", "Download Equivalency Document")}
                    </a>
                  )}
                </>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
