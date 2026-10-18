import { useEffect, useMemo, useState } from "react";
import { ArrowLeft, Bell, FileText, GraduationCap, Mail, Phone, Search, Wallet } from "lucide-react";
import { Link, useParams } from "react-router-dom";
import { adminService } from "../../services/adminService";
import type { AdminStudentDetails, AdminStudentItem } from "../../types";
import { useLanguage } from "../../hooks/useLanguage";
import { getErrorMessage } from "../../utils/errors";
import { AdminPagination } from "../../components/admin/AdminPagination";
import { AdminToastViewport } from "../../components/admin/AdminToastViewport";
import { useAdminToasts } from "../../hooks/useAdminToasts";
import { formatCurrency, formatDate } from "../../utils/format";
import { AdminConfirmationModal } from "../../components/admin/AdminConfirmationModal";
import { StudentSupportTeam } from '../../components/admin/StudentSupportTeam';

const PAGE_SIZE = 8;

const statusBadgeClass = (isActive?: boolean) => (isActive === false ? "bg-rose-100 text-rose-700" : "bg-emerald-100 text-emerald-700");

const stageBadgeClass = (stage?: string) => {
  switch (stage) {
    case "travel-and-settlement":
      return "bg-emerald-100 text-emerald-700";
    case "final-accepted":
    case "first-payment":
      return "bg-sky-100 text-sky-700";
    case "preliminary-accepted":
      return "bg-violet-100 text-violet-700";
    case "applying":
      return "bg-amber-100 text-amber-700";
    default:
      return "bg-slate-100 text-slate-700";
  }
};

const applicationStatusBadgeClass = (status?: string) => {
  switch (status) {
    case "accepted":
      return "bg-emerald-100 text-emerald-700";
    case "rejected":
      return "bg-rose-100 text-rose-700";
    case "under-review":
      return "bg-amber-100 text-amber-700";
    default:
      return "bg-slate-100 text-slate-700";
  }
};

export const AdminStudentsResponsivePage = () => {
  const { language } = useLanguage();
  const isArabic = language === "ar";
  const { id } = useParams();
  const [students, setStudents] = useState<AdminStudentItem[]>([]);
  const [details, setDetails] = useState<AdminStudentDetails | null>(null);
  const [query, setQuery] = useState("");
  const [page, setPage] = useState(1);
  const [loadingDetails, setLoadingDetails] = useState(false);
  const [error, setError] = useState("");
  const [selectedIds, setSelectedIds] = useState<string[]>([]);
  const [bulkAction, setBulkAction] = useState<"activate" | "deactivate" | "clear">("activate");
  const [bulkOpen, setBulkOpen] = useState(false);
  const [bulkLoading, setBulkLoading] = useState(false);
  const { toasts, pushToast, dismissToast } = useAdminToasts();

  useEffect(() => {
    adminService
      .getStudents()
      .then(setStudents)
      .catch((issue) => setError(getErrorMessage(issue, isArabic ? "تعذر تحميل الطلاب." : "Unable to load students.")));
  }, [isArabic]);

  useEffect(() => {
    if (!id) {
      setDetails(null);
      return;
    }

    setLoadingDetails(true);
    adminService
      .getStudentDetails(id)
      .then(setDetails)
      .catch((issue) => {
        const message = getErrorMessage(issue, isArabic ? "تعذر تحميل ملف الطالب." : "Unable to load student details.");
        setError(message);
        pushToast(message, "error");
      })
      .finally(() => setLoadingDetails(false));
  }, [id, isArabic, pushToast]);

  const filteredStudents = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();
    if (!normalizedQuery) {
      return students;
    }

    return students.filter((student) =>
      [
        student.name,
        student.email,
        student.profile?.phone || "",
        student.profile?.passportNumber || "",
        student.profile?.nationality || "",
        student.profile?.currentEducation || "",
      ]
        .join(" ")
        .toLowerCase()
        .includes(normalizedQuery)
    );
  }, [students, query]);

  const totalPages = Math.max(1, Math.ceil(filteredStudents.length / PAGE_SIZE));
  const visibleStudents = useMemo(() => filteredStudents.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE), [filteredStudents, page]);

  useEffect(() => {
    setPage(1);
  }, [query]);

  useEffect(() => {
    if (page > totalPages) {
      setPage(totalPages);
    }
  }, [page, totalPages]);

  useEffect(() => {
    setSelectedIds((current) => current.filter((studentId) => filteredStudents.some((student) => student._id === studentId)));
  }, [filteredStudents]);

  const allVisibleSelected = visibleStudents.length > 0 && visibleStudents.every((student) => selectedIds.includes(student._id));

  const toggleSelection = (studentId: string) => {
    setSelectedIds((current) => (current.includes(studentId) ? current.filter((value) => value !== studentId) : [...current, studentId]));
  };

  const toggleSelectVisible = () => {
    if (allVisibleSelected) {
      setSelectedIds((current) => current.filter((value) => !visibleStudents.some((student) => student._id === value)));
      return;
    }

    setSelectedIds((current) => Array.from(new Set([...current, ...visibleStudents.map((student) => student._id)])));
  };

  const executeBulkAction = async () => {
    if (bulkAction === "clear") {
      setSelectedIds([]);
      setBulkOpen(false);
      pushToast(isArabic ? "تم إلغاء التحديد." : "Selection cleared.", "success");
      return;
    }

    setBulkLoading(true);
    setError("");

    try {
      const shouldActivate = bulkAction === "activate";
      const updatedStudents = await Promise.all(selectedIds.map((studentId) => adminService.updateSectionAccountStatus("students", studentId, shouldActivate)));
      const map = new Map(updatedStudents.map((student) => [student._id, student]));

      setStudents((current) => current.map((student) => (map.has(student._id) ? ({ ...student, ...map.get(student._id) } as AdminStudentItem) : student)));

      if (details && map.has(details.student._id)) {
        setDetails((current) => (current ? { ...current, student: { ...current.student, ...map.get(current.student._id) } } : current));
      }

      setSelectedIds([]);
      setBulkOpen(false);
      pushToast(
        shouldActivate ? (isArabic ? "تم تفعيل الطلاب المحددين." : "Selected students activated.") : isArabic ? "تم تعطيل الطلاب المحددين." : "Selected students deactivated.",
        "success"
      );
    } catch (issue) {
      const message = getErrorMessage(issue, isArabic ? "تعذر تنفيذ الإجراء الجماعي." : "Unable to complete the bulk action.");
      setError(message);
      pushToast(message, "error");
    } finally {
      setBulkLoading(false);
    }
  };

  const financialSummary = useMemo(() => {
    if (!details) {
      return { outstanding: 0, paid: 0 };
    }

    return details.invoices.reduce(
      (summary, invoice) => {
        if (invoice.status === "paid") {
          summary.paid += invoice.amount || 0;
        } else {
          summary.outstanding += invoice.amount || 0;
        }
        return summary;
      },
      { outstanding: 0, paid: 0 }
    );
  }, [details]);

  return (
    <div className="space-y-6">
      <section className="panel p-6">
        <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <h1 className="text-3xl font-semibold text-slate-900">{isArabic ? "كل الطلاب" : "All Students"}</h1>
            <p className="mt-2 text-sm text-slate-500">
              {isArabic ? "عرض ملف كل طالب وطلباته ومستنداته والمالية الخاصة به في مكان واحد." : "View each student profile, applications, documents, and financial details in one place."}
            </p>
          </div>
          <label className="w-full max-w-md rounded-2xl border border-slate-200 bg-white px-4 py-3">
            <span className="mb-2 block text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">{isArabic ? "بحث" : "Search"}</span>
            <div className="flex items-center gap-2">
              <Search className="h-4 w-4 text-slate-400" />
              <input
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder={isArabic ? "ابحث باسم الطالب أو البريد أو الهاتف" : "Search by student name, email, or phone"}
                className="w-full border-none bg-transparent p-0 outline-none"
              />
            </div>
          </label>
        </div>
        {error ? <div className="mt-5 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div> : null}
      </section>

      <div className="grid gap-6 2xl:grid-cols-[minmax(0,1.08fr)_minmax(420px,0.92fr)]">
        <section className="order-1 panel overflow-hidden p-4 sm:p-6 2xl:order-2">
          {!id ? (
            <div className="flex min-h-[320px] items-center justify-center text-center text-sm text-slate-500">
              {isArabic ? "اختر طالبًا من القائمة لعرض ملفه الكامل." : "Select a student from the list to view the full profile."}
            </div>
          ) : loadingDetails ? (
            <div className="flex min-h-[320px] items-center justify-center text-sm text-slate-500">{isArabic ? "جارٍ تحميل بيانات الطالب..." : "Loading student details..."}</div>
          ) : details ? (
            <div className="space-y-6">
              <div className="rounded-[28px] border border-slate-200 bg-gradient-to-br from-slate-50 to-white p-5 sm:p-6">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0 flex-1">
                    <h2 className="break-words text-2xl font-semibold text-slate-900 sm:text-3xl">{details.student.name}</h2>
                    <p className="mt-2 break-words text-sm text-slate-500">{details.student.profile?.currentEducation || (isArabic ? "ملف طالب بدون مرحلة تعليمية" : "Student profile without education stage")}</p>
                  </div>
                  <span className={`inline-flex rounded-full px-3 py-1 text-xs font-semibold ${stageBadgeClass(details.student.profile?.applicationStage)}`}>
                    {details.student.profile?.applicationStage || (isArabic ? "بداية الملف" : "file-received")}
                  </span>
                </div>
                <div className="mt-4 flex flex-wrap items-center gap-3">
                  <Link to="/admin/students" className="inline-flex items-center gap-2 rounded-full border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700">
                    <ArrowLeft className="h-4 w-4" />
                    {isArabic ? "العودة للقائمة" : "Back to list"}
                  </Link>
                  <div className="min-w-0 text-sm text-slate-500">
                    <span className="font-medium text-slate-700">{isArabic ? "البريد:" : "Email:"}</span> <span className="break-all">{details.student.email}</span>
                  </div>
                </div>
              </div>

              <StudentSupportTeam key={details.student._id} studentId={details.student._id} ar={isArabic} />
              <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
                <div className="rounded-3xl bg-slate-50 p-4 text-center sm:text-start">
                  <div className="flex items-center justify-center gap-2 text-sm font-semibold text-slate-900 sm:justify-start">
                    <GraduationCap className="h-4 w-4 text-brand-700" />
                    {isArabic ? "الطلبات" : "Applications"}
                  </div>
                  <p className="mt-3 text-3xl font-semibold text-slate-900">{details.applications.length}</p>
                </div>
                <div className="rounded-3xl bg-slate-50 p-4 text-center sm:text-start">
                  <div className="flex items-center justify-center gap-2 text-sm font-semibold text-slate-900 sm:justify-start">
                    <FileText className="h-4 w-4 text-brand-700" />
                    {isArabic ? "المستندات" : "Documents"}
                  </div>
                  <p className="mt-3 text-3xl font-semibold text-slate-900">{details.documents.length}</p>
                </div>
                <div className="rounded-3xl bg-slate-50 p-4 text-center sm:text-start">
                  <div className="flex items-center justify-center gap-2 text-sm font-semibold text-slate-900 sm:justify-start">
                    <Wallet className="h-4 w-4 text-brand-700" />
                    {isArabic ? "المستحقات" : "Outstanding"}
                  </div>
                  <p className="mt-3 break-words text-lg font-semibold text-slate-900">{formatCurrency(financialSummary.outstanding)}</p>
                </div>
                <div className="rounded-3xl bg-slate-50 p-4 text-center sm:text-start">
                  <div className="flex items-center justify-center gap-2 text-sm font-semibold text-slate-900 sm:justify-start">
                    <Bell className="h-4 w-4 text-brand-700" />
                    {isArabic ? "تذاكر الدعم" : "Support Tickets"}
                  </div>
                  <p className="mt-3 text-3xl font-semibold text-slate-900">{details.supportTickets.length}</p>
                </div>
              </div>

              <div className="grid gap-4 xl:grid-cols-2">
                <div className="rounded-3xl border border-slate-200 p-5">
                  <h3 className="text-lg font-semibold text-slate-900">{isArabic ? "بيانات الطالب" : "Student Profile"}</h3>
                  <div className="mt-4 grid gap-3 sm:grid-cols-2">
                    <div className="rounded-2xl bg-slate-50 px-4 py-3 text-sm text-slate-600 sm:col-span-2">
                      <p className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">{isArabic ? "البريد" : "Email"}</p>
                      <p className="mt-2 break-all font-medium text-slate-900">{details.student.email}</p>
                    </div>
                    <div className="rounded-2xl bg-slate-50 px-4 py-3 text-sm text-slate-600">
                      <p className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">{isArabic ? "الهاتف" : "Phone"}</p>
                      <p className="mt-2 break-words font-medium text-slate-900">{details.student.profile?.phone || "--"}</p>
                    </div>
                    <div className="rounded-2xl bg-slate-50 px-4 py-3 text-sm text-slate-600">
                      <p className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">{isArabic ? "الجنسية" : "Nationality"}</p>
                      <p className="mt-2 break-words font-medium text-slate-900">{details.student.profile?.nationality || "--"}</p>
                    </div>
                    <div className="rounded-2xl bg-slate-50 px-4 py-3 text-sm text-slate-600">
                      <p className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">{isArabic ? "المرحلة" : "Education"}</p>
                      <p className="mt-2 break-words font-medium text-slate-900">{details.student.profile?.currentEducation || "--"}</p>
                    </div>
                    <div className="rounded-2xl bg-slate-50 px-4 py-3 text-sm text-slate-600">
                      <p className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">{isArabic ? "موعد الدراسة" : "Intake"}</p>
                      <p className="mt-2 break-words font-medium text-slate-900">{details.student.profile?.intake || "--"}</p>
                    </div>
                    <div className="rounded-2xl bg-slate-50 px-4 py-3 text-sm text-slate-600 sm:col-span-2">
                      <p className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">{isArabic ? "الدول المستهدفة" : "Target Countries"}</p>
                      <p className="mt-2 break-words font-medium text-slate-900">{details.student.profile?.targetCountries?.join("، ") || "--"}</p>
                    </div>
                  </div>
                </div>

                <div className="rounded-3xl border border-slate-200 p-5">
                  <h3 className="text-lg font-semibold text-slate-900">{isArabic ? "المالية والوصول" : "Financials & Arrival"}</h3>
                  <div className="mt-4 grid gap-3 sm:grid-cols-2">
                    <div className="rounded-2xl bg-slate-50 px-4 py-3 text-sm text-slate-600">
                      <p className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">{isArabic ? "الفواتير" : "Invoices"}</p>
                      <p className="mt-2 font-medium text-slate-900">{details.invoices.length}</p>
                    </div>
                    <div className="rounded-2xl bg-slate-50 px-4 py-3 text-sm text-slate-600">
                      <p className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">{isArabic ? "إثباتات الدفع" : "Payment Proofs"}</p>
                      <p className="mt-2 font-medium text-slate-900">{details.paymentProofs.length}</p>
                    </div>
                    <div className="rounded-2xl bg-slate-50 px-4 py-3 text-sm text-slate-600">
                      <p className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">{isArabic ? "المدفوع" : "Paid"}</p>
                      <p className="mt-2 font-medium text-slate-900">{formatCurrency(financialSummary.paid)}</p>
                    </div>
                    <div className="rounded-2xl bg-slate-50 px-4 py-3 text-sm text-slate-600">
                      <p className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">{isArabic ? "حالة الوصول" : "Arrival Status"}</p>
                      <p className="mt-2 font-medium text-slate-900">{details.arrivalRequest?.status || "--"}</p>
                    </div>
                    <div className="rounded-2xl bg-slate-50 px-4 py-3 text-sm text-slate-600 sm:col-span-2">
                      <p className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">{isArabic ? "الخدمات المطلوبة" : "Requested Services"}</p>
                      <p className="mt-2 break-words font-medium text-slate-900">
                        {details.arrivalRequest
                          ? [
                              details.arrivalRequest.services.airportPickup ? (isArabic ? "استقبال المطار" : "Airport pickup") : "",
                              details.arrivalRequest.services.studentHousing ? (isArabic ? "سكن طلابي" : "Student housing") : "",
                              details.arrivalRequest.services.residencePermitSupport ? (isArabic ? "دعم الإقامة" : "Residence permit") : "",
                              details.arrivalRequest.services.visaSupport ? (isArabic ? "دعم الفيزا" : "Visa support") : "",
                            ]
                              .filter(Boolean)
                              .join("، ") || "--"
                          : "--"}
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              <div className="rounded-3xl border border-slate-200 p-5">
                <h3 className="text-lg font-semibold text-slate-900">{isArabic ? "الطلبات الأخيرة" : "Recent Applications"}</h3>
                <div className="mt-4 space-y-3">
                  {details.applications.length === 0 ? (
                    <div className="rounded-2xl bg-slate-50 px-4 py-6 text-center text-sm text-slate-500">{isArabic ? "لا توجد طلبات حتى الآن." : "No applications yet."}</div>
                  ) : (
                    details.applications.slice(0, 5).map((application) => (
                      <div key={application._id} className="rounded-2xl border border-slate-200 px-4 py-4">
                        <div className="flex flex-wrap items-start justify-between gap-3">
                          <div className="min-w-0 flex-1">
                            <p className="font-semibold text-slate-900">{application.program?.title || "--"}</p>
                            <p className="mt-1 text-sm text-slate-500">{application.program?.university?.name || "--"}</p>
                          </div>
                          <span className={`inline-flex rounded-full px-3 py-1 text-xs font-semibold ${applicationStatusBadgeClass(application.status)}`}>{application.status}</span>
                        </div>
                        <p className="mt-3 text-xs text-slate-500">{formatDate(application.submittedAt || application.createdAt)}</p>
                      </div>
                    ))
                  )}
                </div>
              </div>

              <div className="grid gap-4 xl:grid-cols-2">
                <div className="rounded-3xl border border-slate-200 p-5">
                  <h3 className="text-lg font-semibold text-slate-900">{isArabic ? "المستندات" : "Documents"}</h3>
                  <div className="mt-4 space-y-3">
                    {details.documents.length === 0 ? (
                      <div className="rounded-2xl bg-slate-50 px-4 py-6 text-center text-sm text-slate-500">{isArabic ? "لا توجد مستندات." : "No documents uploaded."}</div>
                    ) : (
                      details.documents.slice(0, 6).map((document) => (
                        <div key={document._id} className="flex items-center justify-between gap-3 rounded-2xl bg-slate-50 px-4 py-3">
                          <div className="min-w-0">
                            <p className="truncate font-medium text-slate-900">{document.fileName}</p>
                            <p className="mt-1 text-xs text-slate-500">{document.type}</p>
                          </div>
                          <span className={`inline-flex rounded-full px-3 py-1 text-xs font-semibold ${applicationStatusBadgeClass(document.status)}`}>{document.status}</span>
                        </div>
                      ))
                    )}
                  </div>
                </div>

                <div className="rounded-3xl border border-slate-200 p-5">
                  <h3 className="text-lg font-semibold text-slate-900">{isArabic ? "الدعم والإشعارات" : "Support & Notifications"}</h3>
                  <div className="mt-4 space-y-3">
                    {details.supportTickets.slice(0, 3).map((ticket) => (
                      <div key={ticket._id} className="rounded-2xl bg-slate-50 px-4 py-3">
                        <p className="font-medium text-slate-900">{ticket.subject}</p>
                        <p className="mt-1 text-xs text-slate-500">{ticket.status}</p>
                      </div>
                    ))}
                    {details.notifications.slice(0, 3).map((notification) => (
                      <div key={notification._id} className="rounded-2xl border border-slate-200 px-4 py-3">
                        <p className="font-medium text-slate-900">{notification.title}</p>
                        <p className="mt-1 text-xs text-slate-500">{formatDate(notification.createdAt)}</p>
                      </div>
                    ))}
                    {details.supportTickets.length === 0 && details.notifications.length === 0 ? (
                      <div className="rounded-2xl bg-slate-50 px-4 py-6 text-center text-sm text-slate-500">{isArabic ? "لا توجد تذاكر أو إشعارات." : "No tickets or notifications."}</div>
                    ) : null}
                  </div>
                </div>
              </div>
            </div>
          ) : null}
        </section>

        <section className="order-2 space-y-4 2xl:order-1">
          <div className="panel overflow-hidden">
            <div className="flex flex-col gap-3 border-b border-slate-100 px-4 py-4 sm:flex-row sm:items-center sm:justify-between sm:px-6">
              <div className="flex flex-wrap items-center gap-3">
                <button
                  type="button"
                  onClick={() => setBulkOpen(true)}
                  disabled={selectedIds.length === 0}
                  className="rounded-full bg-slate-400 px-5 py-2 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50"
                >
                  {isArabic ? "تنفيذ جماعي" : "Bulk action"}
                </button>
                <select
                  value={bulkAction}
                  onChange={(event) => setBulkAction(event.target.value as "activate" | "deactivate" | "clear")}
                  className="rounded-full border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700 outline-none"
                >
                  <option value="activate">{isArabic ? "تفعيل المحدد" : "Activate selected"}</option>
                  <option value="deactivate">{isArabic ? "تعطيل المحدد" : "Deactivate selected"}</option>
                  <option value="clear">{isArabic ? "إلغاء التحديد" : "Clear selection"}</option>
                </select>
              </div>
              <label className="inline-flex items-center gap-2 text-sm text-slate-600">
                <input type="checkbox" checked={allVisibleSelected} onChange={toggleSelectVisible} className="h-4 w-4 rounded border-slate-300 text-brand-700 focus:ring-brand-700" />
                {isArabic ? `تحديد الصفحة ${selectedIds.length} محدد` : `Select page ${selectedIds.length} selected`}
              </label>
            </div>

            <div className="overflow-x-auto">
              <table className="min-w-full text-sm">
                <thead className="bg-slate-50 text-slate-500">
                  <tr>
                    <th className="px-4 py-4 text-start font-medium sm:px-6"></th>
                    <th className="px-4 py-4 text-start font-medium sm:px-6">{isArabic ? "الطالب" : "Student"}</th>
                    <th className="px-4 py-4 text-start font-medium sm:px-6">{isArabic ? "المرحلة" : "Stage"}</th>
                    <th className="px-4 py-4 text-start font-medium sm:px-6">{isArabic ? "الحالة" : "Status"}</th>
                    <th className="px-4 py-4 text-start font-medium sm:px-6">{isArabic ? "الانضمام" : "Joined"}</th>
                    <th className="px-4 py-4 text-start font-medium sm:px-6">{isArabic ? "إجراء" : "Action"}</th>
                  </tr>
                </thead>
                <tbody>
                  {visibleStudents.map((student) => (
                    <tr key={student._id} className="border-t border-slate-100 align-top">
                      <td className="px-4 py-5 sm:px-6">
                        <input
                          type="checkbox"
                          checked={selectedIds.includes(student._id)}
                          onChange={() => toggleSelection(student._id)}
                          className="h-4 w-4 rounded border-slate-300 text-brand-700 focus:ring-brand-700"
                        />
                      </td>
                      <td className="px-4 py-5 sm:px-6">
                        <div className="space-y-1">
                          <p className="font-semibold text-slate-900">{student.name}</p>
                          <p className="break-all text-slate-500">{student.email}</p>
                          {student.profile?.phone ? (
                            <div className="inline-flex items-center gap-1 text-xs text-slate-500">
                              <Phone className="h-3.5 w-3.5" />
                              {student.profile.phone}
                            </div>
                          ) : null}
                        </div>
                      </td>
                      <td className="px-4 py-5 sm:px-6">
                        <span className={`inline-flex rounded-full px-3 py-1 text-xs font-semibold ${stageBadgeClass(student.profile?.applicationStage)}`}>
                          {student.profile?.applicationStage || (isArabic ? "بداية الملف" : "file-received")}
                        </span>
                      </td>
                      <td className="px-4 py-5 sm:px-6">
                        <span className={`inline-flex rounded-full px-3 py-1 text-xs font-semibold ${statusBadgeClass(student.isActive)}`}>
                          {student.isActive === false ? (isArabic ? "معطل" : "Inactive") : isArabic ? "نشط" : "Active"}
                        </span>
                      </td>
                      <td className="px-4 py-5 text-slate-600 sm:px-6">{formatDate(student.createdAt)}</td>
                      <td className="px-4 py-5 sm:px-6">
                        <Link to={`/admin/students/${student._id}`} className="inline-flex items-center gap-2 rounded-full border border-slate-200 px-4 py-2 font-medium text-slate-700">
                          <Mail className="h-4 w-4" />
                          {isArabic ? "عرض الملف" : "View profile"}
                        </Link>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {visibleStudents.length === 0 ? <div className="px-6 py-10 text-center text-sm text-slate-500">{isArabic ? "لا يوجد طلاب مطابقون." : "No matching students found."}</div> : null}
          </div>

          <AdminPagination page={page} totalPages={totalPages} totalItems={filteredStudents.length} pageSize={PAGE_SIZE} isArabic={isArabic} onPageChange={setPage} />
        </section>
      </div>

      <AdminConfirmationModal
        open={bulkOpen}
        title={
          bulkAction === "activate"
            ? isArabic
              ? "تأكيد تفعيل الطلاب"
              : "Confirm student activation"
            : bulkAction === "deactivate"
              ? isArabic
                ? "تأكيد تعطيل الطلاب"
                : "Confirm student deactivation"
              : isArabic
                ? "تأكيد إلغاء التحديد"
                : "Confirm clear selection"
        }
        description={
          bulkAction === "activate"
            ? isArabic
              ? `سيتم تفعيل ${selectedIds.length} طالب/طلاب محددين.`
              : `This will activate ${selectedIds.length} selected student(s).`
            : bulkAction === "deactivate"
              ? isArabic
                ? `سيتم تعطيل ${selectedIds.length} طالب/طلاب محددين.`
                : `This will deactivate ${selectedIds.length} selected student(s).`
              : isArabic
                ? "سيتم مسح جميع التحديدات الحالية."
                : "This will clear the current selection."
        }
        confirmLabel={isArabic ? "تأكيد" : "Confirm"}
        cancelLabel={isArabic ? "إلغاء" : "Cancel"}
        onConfirm={executeBulkAction}
        onClose={() => !bulkLoading && setBulkOpen(false)}
        tone={bulkAction === "deactivate" ? "danger" : "primary"}
        loading={bulkLoading}
      />

      <AdminToastViewport items={toasts} onDismiss={dismissToast} />
    </div>
  );
};
