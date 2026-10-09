import { useEffect, useMemo, useState } from "react";
import { Download, Upload } from "lucide-react";
import { EmptyState } from "../../components/EmptyState";
import { ConfirmationModal } from "../../components/ConfirmationModal";
import { ToastViewport } from "../../components/ToastViewport";
import { AdminPagination } from "../../components/admin/AdminPagination";
import { DOCUMENT_UPLOAD_ACCEPT } from "../../constants/upload";
import { useLanguage } from "../../hooks/useLanguage";
import { useToasts } from "../../hooks/useToasts";
import { getDownloadableAssetUrl } from "../../lib/api";
import { studentService } from "../../services/studentService";
import type { InvoiceItem, StudentFinancialsResponse } from "../../types";
import { getErrorMessage } from "../../utils/errors";
import { formatCurrency, formatDate } from "../../utils/format";

const PAGE_SIZE = 5;

export const StudentFinancialsEnhancedPage = () => {
  const { language } = useLanguage();
  const isArabic = language === "ar";
  const [data, setData] = useState<StudentFinancialsResponse | null>(null);
  const [error, setError] = useState("");
  const [uploadingId, setUploadingId] = useState("");
  const [query, setQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<"all" | InvoiceItem["status"]>("all");
  const [invoicePage, setInvoicePage] = useState(1);
  const [proofPage, setProofPage] = useState(1);
  const [pendingUpload, setPendingUpload] = useState<{
    invoiceId: string;
    invoiceNumber: string;
    file: File;
  } | null>(null);
  const { toasts, pushToast, dismissToast } = useToasts();

  const loadFinancials = () =>
    studentService
      .getFinancials()
      .then(setData)
      .catch((issue) =>
        setError(
          getErrorMessage(
            issue,
            isArabic ? "تعذر تحميل البيانات المالية." : "Unable to load financial data."
          )
        )
      );

  useEffect(() => {
    loadFinancials();
  }, [isArabic]);

  const filteredInvoices = useMemo(() => {
    if (!data) return [];
    const normalizedQuery = query.trim().toLowerCase();
    return data.invoices.filter((invoice) => {
      const matchesStatus = statusFilter === "all" || invoice.status === statusFilter;
      const matchesQuery =
        !normalizedQuery ||
        [invoice.invoiceNumber, invoice.description, invoice.status]
          .filter(Boolean)
          .some((value) => String(value).toLowerCase().includes(normalizedQuery));
      return matchesStatus && matchesQuery;
    });
  }, [data, query, statusFilter]);

  const filteredProofs = useMemo(() => {
    if (!data) return [];
    const normalizedQuery = query.trim().toLowerCase();
    return data.paymentProofs.filter((proof) => {
      if (!normalizedQuery) return true;
      return [proof.fileName, proof.invoice?.invoiceNumber, proof.status]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes(normalizedQuery));
    });
  }, [data, query]);

  const invoiceTotalPages = Math.max(1, Math.ceil(filteredInvoices.length / PAGE_SIZE));
  const proofTotalPages = Math.max(1, Math.ceil(filteredProofs.length / PAGE_SIZE));
  const visibleInvoices = filteredInvoices.slice((invoicePage - 1) * PAGE_SIZE, invoicePage * PAGE_SIZE);
  const visibleProofs = filteredProofs.slice((proofPage - 1) * PAGE_SIZE, proofPage * PAGE_SIZE);

  useEffect(() => setInvoicePage(1), [query, statusFilter]);
  useEffect(() => setProofPage(1), [query]);
  useEffect(() => {
    if (invoicePage > invoiceTotalPages) setInvoicePage(invoiceTotalPages);
  }, [invoicePage, invoiceTotalPages]);
  useEffect(() => {
    if (proofPage > proofTotalPages) setProofPage(proofTotalPages);
  }, [proofPage, proofTotalPages]);

  const requestProofUpload = (invoiceId: string, invoiceNumber: string, file: File | null) => {
    if (!file) return;
    setPendingUpload({ invoiceId, invoiceNumber, file });
  };

  const confirmProofUpload = async () => {
    if (!pendingUpload) return;
    setUploadingId(pendingUpload.invoiceId);
    setError("");
    try {
      await studentService.uploadPaymentProof(pendingUpload.invoiceId, { file: pendingUpload.file });
      await loadFinancials();
      pushToast(
        isArabic ? "تم رفع إثبات الدفع بنجاح." : "Payment proof uploaded successfully.",
        "success"
      );
      setPendingUpload(null);
    } catch (issue) {
      setError(
        getErrorMessage(
          issue,
          isArabic ? "تعذر رفع إثبات الدفع." : "Unable to upload payment proof."
        )
      );
      pushToast(isArabic ? "تعذر رفع إثبات الدفع." : "Unable to upload payment proof.", "error");
    } finally {
      setUploadingId("");
    }
  };

  if (error && !data) {
    return <EmptyState title={isArabic ? "تعذر التحميل" : "Unable to load"} description={error} />;
  }

  if (!data) {
    return (
      <div className="panel flex min-h-[300px] items-center justify-center p-8 text-sm text-slate-500">
        {isArabic ? "جارٍ تحميل الشؤون المالية..." : "Loading financials..."}
      </div>
    );
  }

  const summaryCards = [
    { label: isArabic ? "المبالغ المستحقة" : "Outstanding", value: formatCurrency(data.summary.outstandingAmount) },
    { label: isArabic ? "بانتظار التأكيد" : "Pending Confirmation", value: formatCurrency(data.summary.pendingConfirmationAmount) },
    { label: isArabic ? "المدفوع" : "Paid", value: formatCurrency(data.summary.paidAmount) },
    { label: isArabic ? "عدد الفواتير" : "Invoices", value: data.summary.invoiceCount },
  ];

  return (
    <div className="space-y-6">
      <ToastViewport items={toasts} onDismiss={dismissToast} />

      <section className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {summaryCards.map((item) => (
          <article key={item.label} className="rounded-3xl border border-slate-200 bg-white p-5 shadow-sm">
            <p className="text-sm font-semibold text-slate-500">{item.label}</p>
            <p className="mt-4 text-3xl font-semibold text-slate-900">{item.value}</p>
          </article>
        ))}
      </section>

      <section className="panel p-6">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <h1 className="text-3xl font-semibold text-slate-900">{isArabic ? "المالية والفواتير" : "Financials & Invoices"}</h1>
            <p className="mt-2 text-sm text-slate-500">{isArabic ? "تابع الفواتير وارفع إثبات الدفع لكل دفعة." : "Track invoices and upload proof of payment for each item."}</p>
          </div>
          <div className="grid w-full max-w-2xl gap-4 md:grid-cols-[1fr_220px]">
            <label>
              <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "بحث" : "Search"}</span>
              <input
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder={isArabic ? "ابحث برقم الفاتورة أو الوصف أو الحالة" : "Search by invoice number, description, or status"}
                className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
              />
            </label>
            <label>
              <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "الحالة" : "Status"}</span>
              <select
                value={statusFilter}
                onChange={(event) => setStatusFilter(event.target.value as "all" | InvoiceItem["status"])}
                className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
              >
                <option value="all">{isArabic ? "كل الحالات" : "All statuses"}</option>
                <option value="unpaid">{isArabic ? "غير مدفوع" : "Unpaid"}</option>
                <option value="pending-confirmation">{isArabic ? "بانتظار التأكيد" : "Pending Confirmation"}</option>
                <option value="paid">{isArabic ? "مدفوع" : "Paid"}</option>
                <option value="rejected">{isArabic ? "مرفوض" : "Rejected"}</option>
              </select>
            </label>
          </div>
        </div>

        {error ? <div className="mt-5 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div> : null}

        <div className="mt-6 space-y-4">
          {visibleInvoices.length ? (
            visibleInvoices.map((invoice) => (
              <article key={invoice._id} className="rounded-3xl bg-slate-50 p-5">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <p className="font-semibold text-slate-900">{invoice.invoiceNumber}</p>
                    <p className="mt-1 text-sm text-slate-500">{invoice.description}</p>
                    <p className="mt-2 text-xs text-slate-500">{isArabic ? "تاريخ الاستحقاق:" : "Due Date:"} {formatDate(invoice.dueDate)}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-lg font-semibold text-slate-900">{formatCurrency(invoice.amount, invoice.currency)}</p>
                    {(invoice.crmPaidAmount || 0)>0 && <p className="mt-1 text-sm text-slate-500">{isArabic ? 'المدفوع: ' : 'Paid: '}{formatCurrency(invoice.crmPaidAmount,invoice.currency)} · {isArabic ? 'المتبقي: ' : 'Remaining: '}{formatCurrency(invoice.status==='paid'?0:Math.max(0,invoice.amount-(invoice.crmPaidAmount || 0)-(invoice.walletCreditApplied || 0)),invoice.currency)}</p>}
                    <span className={`mt-2 inline-flex rounded-full px-3 py-1 text-xs font-semibold ${invoice.status === "paid" ? "bg-emerald-100 text-emerald-700" : invoice.status === "rejected" ? "bg-rose-100 text-rose-700" : invoice.status === "pending-confirmation" ? "bg-amber-100 text-amber-700" : "bg-slate-200 text-slate-700"}`}>
                      {invoice.status}
                    </span>
                  </div>
                </div>
                {invoice.adminNote ? <p className="mt-4 rounded-2xl bg-white px-4 py-3 text-sm text-slate-600">{invoice.adminNote}</p> : null}
                <div className="mt-4 flex flex-wrap items-center gap-3">
                  {invoice.invoiceUrl ? (
                    <a href={getDownloadableAssetUrl(invoice.invoiceUrl)} target="_blank" rel="noreferrer" className="inline-flex items-center gap-2 rounded-full border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700">
                      <Download className="h-4 w-4" />
                      {isArabic ? "تحميل الفاتورة" : "Download Invoice"}
                    </a>
                  ) : null}
                  <label className="inline-flex cursor-pointer items-center gap-2 rounded-full bg-brand-900 px-4 py-2 text-sm font-semibold text-white">
                    <Upload className="h-4 w-4" />
                    {uploadingId === invoice._id ? (isArabic ? "جارٍ الرفع..." : "Uploading...") : isArabic ? "رفع إثبات الدفع" : "Upload Proof"}
                    <input type="file" accept={DOCUMENT_UPLOAD_ACCEPT} className="hidden" onChange={(event) => requestProofUpload(invoice._id, invoice.invoiceNumber, event.target.files?.[0] || null)} />
                  </label>
                </div>
              </article>
            ))
          ) : (
            <EmptyState title={isArabic ? "لا توجد فواتير مطابقة" : "No matching invoices"} description={isArabic ? "غيّر كلمات البحث أو فلتر الحالة لعرض نتائج أخرى." : "Adjust your search or status filter to see more results."} />
          )}
        </div>

        <div className="mt-5">
          <AdminPagination page={invoicePage} totalPages={invoiceTotalPages} totalItems={filteredInvoices.length} pageSize={PAGE_SIZE} isArabic={isArabic} onPageChange={setInvoicePage} />
        </div>
      </section>

      <section className="panel p-6">
        <h2 className="text-2xl font-semibold text-slate-900">{isArabic ? "إثباتات الدفع المرفوعة" : "Uploaded Payment Proofs"}</h2>
        <div className="mt-6 space-y-3">
          {visibleProofs.length ? (
            visibleProofs.map((proof) => (
              <div key={proof._id} className="rounded-2xl bg-slate-50 px-4 py-3">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div>
                    <p className="font-semibold text-slate-900">{proof.fileName}</p>
                    <p className="mt-1 text-sm text-slate-500">{proof.invoice?.invoiceNumber || "--"} • {formatDate(proof.createdAt)}</p>
                  </div>
                  <span className={`rounded-full px-3 py-1 text-xs font-semibold ${proof.status === "approved" ? "bg-emerald-100 text-emerald-700" : proof.status === "rejected" ? "bg-rose-100 text-rose-700" : "bg-amber-100 text-amber-700"}`}>{proof.status}</span>
                </div>
                {proof.reviewNote ? <p className="mt-3 text-sm text-slate-600">{proof.reviewNote}</p> : null}
              </div>
            ))
          ) : (
            <div className="rounded-2xl bg-slate-50 px-4 py-6 text-sm text-slate-500">{isArabic ? "لا توجد إثباتات دفع مطابقة." : "No matching payment proofs."}</div>
          )}
        </div>

        <div className="mt-5">
          <AdminPagination page={proofPage} totalPages={proofTotalPages} totalItems={filteredProofs.length} pageSize={PAGE_SIZE} isArabic={isArabic} onPageChange={setProofPage} />
        </div>
      </section>

      <ConfirmationModal
        open={Boolean(pendingUpload)}
        title={isArabic ? "تأكيد رفع الإثبات" : "Confirm Proof Upload"}
        description={
          pendingUpload
            ? isArabic
              ? `سيتم رفع الملف ${pendingUpload.file.name} للفاتورة ${pendingUpload.invoiceNumber}.`
              : `This will upload ${pendingUpload.file.name} for invoice ${pendingUpload.invoiceNumber}.`
            : ""
        }
        confirmLabel={isArabic ? "تأكيد الرفع" : "Confirm Upload"}
        cancelLabel={isArabic ? "إلغاء" : "Cancel"}
        loading={Boolean(uploadingId)}
        onConfirm={confirmProofUpload}
        onClose={() => !uploadingId && setPendingUpload(null)}
      />
    </div>
  );
};
