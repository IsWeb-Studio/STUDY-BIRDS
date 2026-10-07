import { DocumentFileLink } from '../../components/DocumentFileLink';
import { useEffect, useMemo, useState } from "react";
import { adminService } from "../../services/adminService";
import type { Application, InvoiceItem, PaymentProofItem, User } from "../../types";
import { ConfirmationModal } from "../../components/ConfirmationModal";
import { AdminPagination } from "../../components/admin/AdminPagination";
import { ToastViewport } from "../../components/ToastViewport";
import { useLanguage } from "../../hooks/useLanguage";
import { useToasts } from "../../hooks/useToasts";
import { getErrorMessage } from "../../utils/errors";
import { formatCurrency, formatDate } from "../../utils/format";

const PAGE_SIZE = 6;

export const AdminStudentFinancialsEnhancedPage = () => {
  const { language } = useLanguage();
  const isArabic = language === "ar";
  const [invoices, setInvoices] = useState<InvoiceItem[]>([]);
  const [paymentProofs, setPaymentProofs] = useState<PaymentProofItem[]>([]);
  const [students, setStudents] = useState<User[]>([]);
  const [error, setError] = useState("");
  const [creating, setCreating] = useState(false);
  const [invoiceQuery, setInvoiceQuery] = useState("");
  const [proofQuery, setProofQuery] = useState("");
  const [invoicePage, setInvoicePage] = useState(1);
  const [proofPage, setProofPage] = useState(1);
  const [pendingReview, setPendingReview] = useState<{
    id: string;
    status: PaymentProofItem["status"];
    studentName: string;
    invoiceNumber: string;
  } | null>(null);
  const [reviewLoading, setReviewLoading] = useState(false);
  const [updatingInvoiceId, setUpdatingInvoiceId] = useState<string | null>(null);
  const [deletingInvoiceId, setDeletingInvoiceId] = useState<string | null>(null);
  const [pendingDelete, setPendingDelete] = useState<{ id: string; invoiceNumber: string } | null>(null);
  const [filterStudentId, setFilterStudentId] = useState("");
  const [studentApplications, setStudentApplications] = useState<Array<Application & { program?: { title?: string; tuition?: number } }>>([]);
  const [studentServiceRequests, setStudentServiceRequests] = useState<Array<{ _id: string; service?: { title?: string }; status: string }>>([]);
  const [studentAccommodationBookings, setStudentAccommodationBookings] = useState<Array<{ _id: string; listing?: { title?: string }; status: string }>>([]);
  const { toasts, pushToast, dismissToast } = useToasts();
  const [form, setForm] = useState({
    studentId: "",
    applicationId: "",
    serviceRequestId: "",
    accommodationBookingId: "",
    invoiceNumber: "",
    description: "",
    amount: "",
    dueDate: "",
    category: "application-fee",
  });

  useEffect(() => {
    Promise.all([adminService.getStudentFinancials(), adminService.getStudents()])
      .then(([financials, studentItems]) => {
        setInvoices(financials.invoices);
        setPaymentProofs(financials.paymentProofs);
        setStudents(studentItems.filter((item) => item.role === "student"));
      })
      .catch((issue) =>
        setError(
          getErrorMessage(
            issue,
            isArabic ? "تعذر تحميل البيانات المالية للطلاب." : "Unable to load student financials."
          )
        )
      );
  }, [isArabic]);

  const filteredInvoices = useMemo(() => {
    const query = invoiceQuery.trim().toLowerCase();
    let list = invoices;
    if (filterStudentId) list = list.filter((inv) => inv.student?._id === filterStudentId);
    if (!query) return list;
    return list.filter((invoice) =>
      [
        invoice.student?.name,
        invoice.student?.email,
        invoice.invoiceNumber,
        invoice.description,
        invoice.status,
      ]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes(query))
    );
  }, [invoiceQuery, invoices, filterStudentId]);

  const filteredProofs = useMemo(() => {
    const query = proofQuery.trim().toLowerCase();
    let list = paymentProofs;
    if (filterStudentId) list = list.filter((p) => p.student?._id === filterStudentId);
    if (!query) return list;
    return list.filter((proof) =>
      [
        proof.student?.name,
        proof.student?.email,
        proof.invoice?.invoiceNumber,
        proof.fileName,
        proof.status,
      ]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes(query))
    );
  }, [paymentProofs, proofQuery, filterStudentId]);

  const invoiceTotalPages = Math.max(1, Math.ceil(filteredInvoices.length / PAGE_SIZE));
  const proofTotalPages = Math.max(1, Math.ceil(filteredProofs.length / PAGE_SIZE));
  const visibleInvoices = filteredInvoices.slice((invoicePage - 1) * PAGE_SIZE, invoicePage * PAGE_SIZE);
  const visibleProofs = filteredProofs.slice((proofPage - 1) * PAGE_SIZE, proofPage * PAGE_SIZE);

  useEffect(() => setInvoicePage(1), [invoiceQuery, filterStudentId]);
  useEffect(() => setProofPage(1), [proofQuery, filterStudentId]);
  useEffect(() => {
    if (invoicePage > invoiceTotalPages) setInvoicePage(invoiceTotalPages);
  }, [invoicePage, invoiceTotalPages]);
  useEffect(() => {
    if (proofPage > proofTotalPages) setProofPage(proofTotalPages);
  }, [proofPage, proofTotalPages]);

  const handleStudentChange = async (studentId: string) => {
    setForm((current) => ({ ...current, studentId, applicationId: "", serviceRequestId: "", accommodationBookingId: "" }));
    setStudentApplications([]);
    setStudentServiceRequests([]);
    setStudentAccommodationBookings([]);
    if (!studentId) return;
    try {
      const [details, serviceReqs, accommodationBookings] = await Promise.all([
        adminService.getStudentDetails(studentId),
        adminService.getStudentServiceRequests(studentId),
        adminService.getStudentAccommodationBookings(studentId),
      ]);
      setStudentApplications(details.applications || []);
      setStudentServiceRequests(serviceReqs || []);
      setStudentAccommodationBookings(accommodationBookings || []);
      if (details.applications?.length === 1) {
        setForm((current) => ({ ...current, applicationId: details.applications[0]._id }));
      }
    } catch {}
  };

  const handleCreateInvoice = async (event: React.FormEvent) => {
    event.preventDefault();
    setCreating(true);
    setError("");
    try {
      const created = await adminService.createStudentInvoice({
        studentId: form.studentId,
        applicationId: ["application-fee", "tuition"].includes(form.category) ? (form.applicationId || undefined) : undefined,
        serviceRequestId: form.category === "service" ? (form.serviceRequestId || undefined) : undefined,
        accommodationBookingId: form.category === "housing" ? (form.accommodationBookingId || undefined) : undefined,
        invoiceNumber: form.invoiceNumber,
        description: form.description,
        amount: Number(form.amount),
        dueDate: form.dueDate,
        category: form.category as InvoiceItem["category"],
      });
      setInvoices((current) => [created, ...current]);
      setForm({
        studentId: "",
        applicationId: "",
        serviceRequestId: "",
        accommodationBookingId: "",
        invoiceNumber: "",
        description: "",
        amount: "",
        dueDate: "",
        category: "application-fee",
      });
      setStudentApplications([]);
      setStudentServiceRequests([]);
      setStudentAccommodationBookings([]);
      pushToast(
        isArabic ? "تم إصدار الفاتورة وإضافتها لحساب الطالب." : "Invoice created successfully.",
        "success"
      );
    } catch (issue) {
      setError(getErrorMessage(issue, isArabic ? "تعذر إصدار الفاتورة." : "Unable to create invoice."));
      pushToast(isArabic ? "تعذر إصدار الفاتورة." : "Unable to create invoice.", "error");
    } finally {
      setCreating(false);
    }
  };

  const handleApplicationChange = (appId: string) => {
    const selected = studentApplications.find((a) => a._id === appId);
    const tuition = selected?.program?.tuition;
    setForm((current) => ({
      ...current,
      applicationId: appId,
      amount: tuition && ["application-fee", "tuition"].includes(current.category) ? String(tuition) : current.amount,
    }));
  };

  const handleDeleteInvoice = async () => {
    if (!pendingDelete) return;
    setDeletingInvoiceId(pendingDelete.id);
    try {
      await adminService.deleteStudentInvoice(pendingDelete.id);
      setInvoices((current) => current.filter((item) => item._id !== pendingDelete.id));
      pushToast(isArabic ? "تم حذف الفاتورة." : "Invoice deleted.", "success");
    } catch (issue) {
      pushToast(getErrorMessage(issue, isArabic ? "تعذر حذف الفاتورة." : "Unable to delete invoice."), "error");
    } finally {
      setDeletingInvoiceId(null);
      setPendingDelete(null);
    }
  };

  const handleInvoiceStatusChange = async (id: string, status: InvoiceItem["status"]) => {
    setUpdatingInvoiceId(id);
    try {
      const updated = await adminService.updateStudentInvoice(id, { status });
      setInvoices((current) => current.map((item) => (item._id === id ? updated : item)));
      pushToast(
        isArabic ? "تم تحديث حالة الفاتورة." : "Invoice status updated.",
        "success"
      );
    } catch (issue) {
      pushToast(getErrorMessage(issue, isArabic ? "تعذر تحديث حالة الفاتورة." : "Unable to update invoice status."), "error");
    } finally {
      setUpdatingInvoiceId(null);
    }
  };

  const confirmProofReview = async () => {
    if (!pendingReview) return;
    setReviewLoading(true);
    try {
      const updated = await adminService.reviewPaymentProof(pendingReview.id, {
        status: pendingReview.status,
      });
      setPaymentProofs((current) =>
        current.map((item) => (item._id === pendingReview.id ? updated : item))
      );
      if (updated.invoice?._id) {
        setInvoices((current) =>
          current.map((item) =>
            item._id === updated.invoice?._id ? { ...item, status: updated.invoice?.status } : item
          )
        );
      }
      pushToast(
        pendingReview.status === "approved"
          ? isArabic
            ? "تم اعتماد إثبات الدفع."
            : "Payment proof approved."
          : isArabic
            ? "تم رفض إثبات الدفع."
            : "Payment proof rejected.",
        pendingReview.status === "approved" ? "success" : "info"
      );
      setPendingReview(null);
    } catch (issue) {
      setError(getErrorMessage(issue, isArabic ? "تعذر تحديث إثبات الدفع." : "Unable to review payment proof."));
      pushToast(isArabic ? "تعذر تحديث إثبات الدفع." : "Unable to review payment proof.", "error");
    } finally {
      setReviewLoading(false);
    }
  };

  return (
    <div className="space-y-6">
      <ToastViewport items={toasts} onDismiss={dismissToast} />

      <section className="panel p-6">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <h1 className="text-3xl font-semibold text-slate-900">{isArabic ? "مالية الطلاب" : "Student Financials"}</h1>
            <p className="mt-2 text-sm text-slate-500">
              {isArabic ? "مراجعة الفواتير وإثباتات الدفع الخاصة بالطلاب." : "Review student invoices and uploaded payment proofs."}
            </p>
          </div>
          <label className="block w-full max-w-xs shrink-0">
            <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "عرض طالب محدد" : "Filter by student"}</span>
            <select
              value={filterStudentId}
              onChange={(e) => setFilterStudentId(e.target.value)}
              className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 outline-none focus:ring"
            >
              <option value="">{isArabic ? "كل الطلاب" : "All students"}</option>
              {students.map((s) => (
                <option key={s._id} value={s._id}>{s.name} — {s.email}</option>
              ))}
            </select>
          </label>
        </div>
        {error ? <div className="mt-5 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div> : null}
      </section>

      <section className="panel p-6">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <h2 className="text-2xl font-semibold text-slate-900">{isArabic ? "الفواتير" : "Invoices"}</h2>
            <p className="mt-2 text-sm text-slate-500">
              {isArabic ? "إنشاء الفواتير والبحث فيها حسب الطالب أو الرقم أو الحالة." : "Create invoices and search by student, invoice number, or status."}
            </p>
          </div>
          <label className="block w-full max-w-md">
            <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "بحث الفواتير" : "Search Invoices"}</span>
            <input
              value={invoiceQuery}
              onChange={(event) => setInvoiceQuery(event.target.value)}
              placeholder={isArabic ? "ابحث باسم الطالب أو البريد أو رقم الفاتورة" : "Search by student, email, or invoice number"}
              className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 outline-none focus:ring"
            />
          </label>
        </div>

        <form onSubmit={handleCreateInvoice} className="mt-6 grid gap-4 rounded-3xl border border-slate-200 bg-slate-50 p-5 md:grid-cols-2 xl:grid-cols-3">
          <label>
            <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "الطالب" : "Student"}</span>
            <select value={form.studentId} onChange={(event) => handleStudentChange(event.target.value)} className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 outline-none focus:ring">
              <option value="">{isArabic ? "اختر الطالب" : "Select student"}</option>
              {students.map((student) => (
                <option key={student._id} value={student._id}>
                  {student.name} - {student.email}
                </option>
              ))}
            </select>
          </label>
          {["application-fee", "tuition"].includes(form.category) && studentApplications.length > 0 && (
            <label>
              <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "الطلب والبرنامج" : "Application / Program"}</span>
              <select value={form.applicationId} onChange={(e) => handleApplicationChange(e.target.value)} className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 outline-none focus:ring">
                <option value="">{isArabic ? "اختر الطلب" : "Select application"}</option>
                {studentApplications.map((app) => (
                  <option key={app._id} value={app._id}>
                    {app.program?.title || app._id}
                    {app.program?.tuition ? ` — $${app.program.tuition.toLocaleString()}` : ""}
                    {" — "}{app.status}
                  </option>
                ))}
              </select>
              {form.applicationId && (() => {
                const sel = studentApplications.find((a) => a._id === form.applicationId);
                const tuition = sel?.program?.tuition;
                if (!tuition) return null;
                const paid = invoices.filter((inv) => (inv as InvoiceItem & { application?: { _id?: string } }).application?._id === form.applicationId && inv.status !== "rejected").reduce((s, inv) => s + Number(inv.amount || 0), 0);
                const remaining = tuition - paid;
                return (
                  <p className="mt-1 text-xs text-slate-500">
                    {isArabic ? `إجمالي الرسوم: $${tuition.toLocaleString()} | مُصدَر: $${paid.toLocaleString()} | المتبقي: ` : `Tuition: $${tuition.toLocaleString()} | Billed: $${paid.toLocaleString()} | Remaining: `}
                    <span className={remaining <= 0 ? "font-semibold text-emerald-600" : "font-semibold text-slate-700"}>${remaining.toLocaleString()}</span>
                  </p>
                );
              })()}
            </label>
          )}
          {form.category === "service" && form.studentId && (
            <label>
              <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "طلب الخدمة" : "Service Request"}</span>
              <select value={form.serviceRequestId} onChange={(event) => setForm((current) => ({ ...current, serviceRequestId: event.target.value }))} className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 outline-none focus:ring">
                <option value="">{isArabic ? "اختر الخدمة" : "Select service"}</option>
                {studentServiceRequests.map((req) => (
                  <option key={req._id} value={req._id}>
                    {req.service?.title || req._id} — {req.status}
                  </option>
                ))}
              </select>
              {studentServiceRequests.length === 0 && <p className="mt-1 text-xs text-slate-400">{isArabic ? "لا توجد طلبات خدمة لهذا الطالب" : "No service requests found"}</p>}
            </label>
          )}
          {form.category === "housing" && form.studentId && (
            <label>
              <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "حجز السكن" : "Accommodation Booking"}</span>
              <select value={form.accommodationBookingId} onChange={(event) => setForm((current) => ({ ...current, accommodationBookingId: event.target.value }))} className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 outline-none focus:ring">
                <option value="">{isArabic ? "اختر الحجز" : "Select booking"}</option>
                {studentAccommodationBookings.map((booking) => (
                  <option key={booking._id} value={booking._id}>
                    {booking.listing?.title || booking._id} — {booking.status}
                  </option>
                ))}
              </select>
              {studentAccommodationBookings.length === 0 && <p className="mt-1 text-xs text-slate-400">{isArabic ? "لا توجد حجوزات سكن لهذا الطالب" : "No accommodation bookings found"}</p>}
            </label>
          )}
          <label>
            <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "رقم الفاتورة" : "Invoice Number"}</span>
            <input value={form.invoiceNumber} onChange={(event) => setForm((current) => ({ ...current, invoiceNumber: event.target.value }))} className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 outline-none focus:ring" />
          </label>
          <label>
            <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "الوصف" : "Description"}</span>
            <input value={form.description} onChange={(event) => setForm((current) => ({ ...current, description: event.target.value }))} className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 outline-none focus:ring" />
          </label>
          <label>
            <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "المبلغ" : "Amount"}</span>
            <input type="number" min="0" value={form.amount} onChange={(event) => setForm((current) => ({ ...current, amount: event.target.value }))} className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 outline-none focus:ring" />
          </label>
          <label>
            <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "تاريخ الاستحقاق" : "Due Date"}</span>
            <input type="date" value={form.dueDate} onChange={(event) => setForm((current) => ({ ...current, dueDate: event.target.value }))} className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 outline-none focus:ring" />
          </label>
          <label>
            <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "الفئة" : "Category"}</span>
            <select value={form.category} onChange={(event) => setForm((current) => ({ ...current, category: event.target.value, applicationId: "", serviceRequestId: "", accommodationBookingId: "", amount: "" }))} className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 outline-none focus:ring">
              <option value="application-fee">{isArabic ? "رسوم التقديم" : "Application Fee"}</option>
              <option value="tuition">{isArabic ? "رسوم دراسية" : "Tuition"}</option>
              <option value="service">{isArabic ? "خدمة" : "Service"}</option>
              <option value="housing">{isArabic ? "سكن" : "Housing"}</option>
              <option value="other">{isArabic ? "أخرى" : "Other"}</option>
            </select>
          </label>
          <button type="submit" disabled={creating} className="w-fit rounded-full bg-slate-950 px-6 py-3 text-sm font-semibold text-white xl:col-span-3">
            {creating ? (isArabic ? "جارٍ الإصدار..." : "Creating...") : isArabic ? "إصدار فاتورة" : "Create Invoice"}
          </button>
        </form>

        <div className="mt-6 overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead className="bg-slate-50 text-slate-500">
              <tr>
                <th className="px-4 py-3 font-medium">{isArabic ? "الطالب" : "Student"}</th>
                <th className="px-4 py-3 font-medium">{isArabic ? "رقم الفاتورة" : "Invoice #"}</th>
                <th className="px-4 py-3 font-medium">{isArabic ? "الوصف" : "Description"}</th>
                <th className="px-4 py-3 font-medium">{isArabic ? "المبلغ" : "Amount"}</th>
                <th className="px-4 py-3 font-medium">{isArabic ? "الحالة" : "Status"}</th>
                <th className="px-4 py-3 font-medium">{isArabic ? "الاستحقاق" : "Due Date"}</th>
                <th className="px-4 py-3 font-medium">{isArabic ? "تغيير الحالة" : "Change Status"}</th>
                <th className="px-4 py-3 font-medium"></th>
              </tr>
            </thead>
            <tbody>
              {visibleInvoices.map((invoice) => (
                <tr key={invoice._id} className="border-t border-slate-100">
                  <td className="px-4 py-4">{invoice.student?.name || "--"}</td>
                  <td className="px-4 py-4">{invoice.invoiceNumber}</td>
                  <td className="px-4 py-4">{invoice.description}</td>
                  <td className="px-4 py-4">{formatCurrency(invoice.amount)}</td>
                  <td className="px-4 py-4">
                    <span className={`rounded-full px-2 py-1 text-xs font-semibold ${
                      invoice.status === "paid" ? "bg-emerald-100 text-emerald-700" :
                      invoice.status === "rejected" ? "bg-rose-100 text-rose-700" :
                      invoice.status === "pending-confirmation" ? "bg-amber-100 text-amber-700" :
                      "bg-slate-100 text-slate-700"
                    }`}>{invoice.status}</span>
                  </td>
                  <td className="px-4 py-4">{formatDate(invoice.dueDate)}</td>
                  <td className="px-4 py-4">
                    <select
                      value={invoice.status}
                      disabled={updatingInvoiceId === invoice._id}
                      onChange={(e) => handleInvoiceStatusChange(invoice._id, e.target.value as InvoiceItem["status"])}
                      className="rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-sm outline-none focus:ring disabled:opacity-50"
                    >
                      <option value="unpaid">{isArabic ? "غير مدفوعة" : "Unpaid"}</option>
                      <option value="pending-confirmation">{isArabic ? "بانتظار التأكيد" : "Pending Confirmation"}</option>
                      <option value="paid">{isArabic ? "مدفوعة ✓" : "Paid ✓"}</option>
                      <option value="rejected">{isArabic ? "مرفوضة" : "Rejected"}</option>
                    </select>
                  </td>
                  <td className="px-4 py-4">
                    <button
                      type="button"
                      disabled={deletingInvoiceId === invoice._id}
                      onClick={() => setPendingDelete({ id: invoice._id, invoiceNumber: invoice.invoiceNumber })}
                      className="rounded-full border border-rose-200 bg-rose-50 px-3 py-1.5 text-xs font-semibold text-rose-700 hover:bg-rose-100 disabled:opacity-40"
                    >
                      {isArabic ? "حذف" : "Delete"}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {!filteredInvoices.length ? (
          <div className="mt-4 rounded-2xl bg-slate-50 px-4 py-6 text-sm text-slate-500">
            {isArabic ? "لا توجد فواتير مطابقة للبحث الحالي." : "No invoices match the current search."}
          </div>
        ) : null}

        <div className="mt-5">
          <AdminPagination
            page={invoicePage}
            totalPages={invoiceTotalPages}
            totalItems={filteredInvoices.length}
            pageSize={PAGE_SIZE}
            isArabic={isArabic}
            onPageChange={setInvoicePage}
          />
        </div>
      </section>

      <section className="panel p-6">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <h2 className="text-2xl font-semibold text-slate-900">{isArabic ? "إثباتات الدفع" : "Payment Proofs"}</h2>
            <p className="mt-2 text-sm text-slate-500">
              {isArabic ? "راجع الإثباتات ثم اعتمدها أو ارفضها بعد التأكيد." : "Review uploaded proofs, then approve or reject with confirmation."}
            </p>
          </div>
          <label className="block w-full max-w-md">
            <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "بحث الإثباتات" : "Search Proofs"}</span>
            <input
              value={proofQuery}
              onChange={(event) => setProofQuery(event.target.value)}
              placeholder={isArabic ? "ابحث باسم الطالب أو رقم الفاتورة أو الملف" : "Search by student, invoice number, or file"}
              className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 outline-none focus:ring"
            />
          </label>
        </div>

        <div className="mt-6 space-y-4">
          {visibleProofs.map((proof) => (
            <article key={proof._id} className="rounded-3xl bg-slate-50 p-5">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <p className="font-semibold text-slate-900">
                    {proof.student?.name || "--"} • {proof.invoice?.invoiceNumber || "--"}
                  </p>
                  <p className="mt-1 text-sm text-slate-500">
                    {proof.fileName} • {formatDate(proof.createdAt)}
                  </p>
                </div>
                <span className="rounded-full bg-white px-3 py-1 text-xs font-semibold text-slate-700">{proof.status}</span>
              </div>
              {proof.reviewNote ? <p className="mt-3 text-sm text-slate-600">{proof.reviewNote}</p> : null}
              <div className="mt-4 flex flex-wrap gap-3">
                <DocumentFileLink className="rounded-full border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700" path={proof.filePath}>
                  {isArabic ? "عرض الملف" : "View file"}
                </DocumentFileLink>
                <button
                  type="button"
                  onClick={() =>
                    setPendingReview({
                      id: proof._id,
                      status: "approved",
                      studentName: proof.student?.name || "--",
                      invoiceNumber: proof.invoice?.invoiceNumber || "--",
                    })
                  }
                  className="rounded-full bg-emerald-600 px-4 py-2 text-sm font-semibold text-white"
                >
                  {isArabic ? "اعتماد" : "Approve"}
                </button>
                <button
                  type="button"
                  onClick={() =>
                    setPendingReview({
                      id: proof._id,
                      status: "rejected",
                      studentName: proof.student?.name || "--",
                      invoiceNumber: proof.invoice?.invoiceNumber || "--",
                    })
                  }
                  className="rounded-full bg-rose-600 px-4 py-2 text-sm font-semibold text-white"
                >
                  {isArabic ? "رفض" : "Reject"}
                </button>
              </div>
            </article>
          ))}
        </div>

        {!filteredProofs.length ? (
          <div className="mt-4 rounded-2xl bg-slate-50 px-4 py-6 text-sm text-slate-500">
            {isArabic ? "لا توجد إثباتات دفع مطابقة للبحث الحالي." : "No payment proofs match the current search."}
          </div>
        ) : null}

        <div className="mt-5">
          <AdminPagination
            page={proofPage}
            totalPages={proofTotalPages}
            totalItems={filteredProofs.length}
            pageSize={PAGE_SIZE}
            isArabic={isArabic}
            onPageChange={setProofPage}
          />
        </div>
      </section>

      <ConfirmationModal
        open={Boolean(pendingDelete)}
        title={isArabic ? "حذف الفاتورة" : "Delete Invoice"}
        description={
          pendingDelete
            ? isArabic
              ? `سيتم حذف الفاتورة رقم ${pendingDelete.invoiceNumber} نهائياً. لا يمكن التراجع عن هذا الإجراء.`
              : `Invoice ${pendingDelete.invoiceNumber} will be permanently deleted.`
            : ""
        }
        confirmLabel={isArabic ? "تأكيد الحذف" : "Confirm Delete"}
        cancelLabel={isArabic ? "إلغاء" : "Cancel"}
        tone="danger"
        loading={deletingInvoiceId !== null}
        onConfirm={handleDeleteInvoice}
        onClose={() => !deletingInvoiceId && setPendingDelete(null)}
      />

      <ConfirmationModal
        open={Boolean(pendingReview)}
        title={
          pendingReview?.status === "approved"
            ? isArabic
              ? "اعتماد إثبات الدفع"
              : "Approve Payment Proof"
            : isArabic
              ? "رفض إثبات الدفع"
              : "Reject Payment Proof"
        }
        description={
          pendingReview
            ? pendingReview.status === "approved"
              ? isArabic
                ? `سيتم اعتماد إثبات الدفع الخاص بالطالب ${pendingReview.studentName} للفاتورة ${pendingReview.invoiceNumber}.`
                : `This will approve ${pendingReview.studentName}'s proof for invoice ${pendingReview.invoiceNumber}.`
              : isArabic
                ? `سيتم رفض إثبات الدفع الخاص بالطالب ${pendingReview.studentName} للفاتورة ${pendingReview.invoiceNumber}.`
                : `This will reject ${pendingReview.studentName}'s proof for invoice ${pendingReview.invoiceNumber}.`
            : ""
        }
        confirmLabel={
          pendingReview?.status === "approved"
            ? isArabic
              ? "تأكيد الاعتماد"
              : "Confirm Approval"
            : isArabic
              ? "تأكيد الرفض"
              : "Confirm Rejection"
        }
        cancelLabel={isArabic ? "إلغاء" : "Cancel"}
        tone={pendingReview?.status === "rejected" ? "danger" : "primary"}
        loading={reviewLoading}
        onConfirm={confirmProofReview}
        onClose={() => !reviewLoading && setPendingReview(null)}
      />
    </div>
  );
};
