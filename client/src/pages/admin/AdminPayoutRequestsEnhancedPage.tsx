import { useEffect, useMemo, useState } from "react";
import { CheckCircle2, Clock3, Landmark, Search, XCircle } from "lucide-react";
import { adminService } from "../../services/adminService";
import type { PayoutRequestItem } from "../../types";
import { useLanguage } from "../../hooks/useLanguage";
import { getErrorMessage } from "../../utils/errors";
import { AdminConfirmationModal } from "../../components/admin/AdminConfirmationModal";
import { AdminPagination } from "../../components/admin/AdminPagination";
import { AdminToastViewport } from "../../components/admin/AdminToastViewport";
import { useAdminToasts } from "../../hooks/useAdminToasts";
import { formatCurrency } from "../../utils/format";
import { AgentWalletAdjustment } from "../../components/admin/AgentWalletAdjustment";

const PAGE_SIZE = 6;

interface PayoutTarget {
  item: PayoutRequestItem;
  status: PayoutRequestItem["status"];
}

export const AdminPayoutRequestsEnhancedPage = () => {
  const { language } = useLanguage();
  const isArabic = language === "ar";
  const [items, setItems] = useState<PayoutRequestItem[]>([]);
  const [filter, setFilter] = useState<PayoutRequestItem["status"] | "all">("all");
  const [query, setQuery] = useState("");
  const [page, setPage] = useState(1);
  const [notes, setNotes] = useState<Record<string, string>>({});
  const [error, setError] = useState("");
  const [updateTarget, setUpdateTarget] = useState<PayoutTarget | null>(null);
  const [updating, setUpdating] = useState(false);
  const { toasts, pushToast, dismissToast } = useAdminToasts();

  useEffect(() => {
    adminService
      .getPayoutRequests()
      .then((data) => {
        setItems(data);
        setNotes(data.reduce<Record<string, string>>((acc, item) => ({ ...acc, [item._id]: item.reviewNote || "" }), {}));
      })
      .catch((issue) => setError(getErrorMessage(issue, isArabic ? "تعذر تحميل طلبات السحب." : "Unable to load payout requests.")));
  }, [isArabic]);

  const filteredItems = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();
    return items.filter((item) => {
      const matchesStatus = filter === "all" || item.status === filter;
      const matchesQuery =
        !normalizedQuery ||
        [item.agent?.name || "", item.agent?.email || "", item.method, item.payoutDetails].join(" ").toLowerCase().includes(normalizedQuery);
      return matchesStatus && matchesQuery;
    });
  }, [filter, items, query]);

  const totalPages = Math.max(1, Math.ceil(filteredItems.length / PAGE_SIZE));
  const visibleItems = useMemo(() => filteredItems.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE), [filteredItems, page]);

  useEffect(() => {
    setPage(1);
  }, [filter, query]);

  useEffect(() => {
    if (page > totalPages) {
      setPage(totalPages);
    }
  }, [page, totalPages]);

  const handleUpdate = async () => {
    if (!updateTarget) {
      return;
    }

    setUpdating(true);
    try {
      const updated = await adminService.updatePayoutRequestStatus(updateTarget.item._id, {
        status: updateTarget.status,
        reviewNote: notes[updateTarget.item._id] || "",
      });
      setItems((current) => current.map((item) => (item._id === updated._id ? updated : item)));
      pushToast(isArabic ? "تم تحديث طلب السحب." : "Payout request updated.", "success");
      setUpdateTarget(null);
    } catch (issue) {
      const message = getErrorMessage(issue, isArabic ? "تعذر تحديث الطلب." : "Unable to update payout request.");
      setError(message);
      pushToast(message, "error");
    } finally {
      setUpdating(false);
    }
  };

  return (
    <div className="space-y-6">
      <AgentWalletAdjustment ar={isArabic} />
      <section className="panel p-6">
        <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <h1 className="text-3xl font-semibold text-slate-900">{isArabic ? "طلبات سحب الأرباح" : "Payout Requests"}</h1>
            <p className="mt-2 text-sm text-slate-500">{isArabic ? "راجع طلبات السحب وحدّث حالتها." : "Review agent payout requests and update their status."}</p>
          </div>
          <div className="grid gap-3 sm:grid-cols-2">
            <label className="rounded-2xl border border-slate-200 bg-white px-4 py-3">
              <span className="mb-2 block text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">{isArabic ? "بحث" : "Search"}</span>
              <div className="flex items-center gap-2">
                <Search className="h-4 w-4 text-slate-400" />
                <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder={isArabic ? "ابحث باسم الوكيل أو البريد أو وسيلة الدفع" : "Search by agent, email, or payout method"} className="w-full border-none p-0 outline-none" />
              </div>
            </label>
            <label className="rounded-2xl border border-slate-200 bg-white px-4 py-3">
              <span className="mb-2 block text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">{isArabic ? "الحالة" : "Status"}</span>
              <select value={filter} onChange={(event) => setFilter(event.target.value as PayoutRequestItem["status"] | "all")} className="w-full border-none bg-transparent p-0 outline-none">
                <option value="all">{isArabic ? "كل الحالات" : "All statuses"}</option>
                <option value="pending">{isArabic ? "قيد المراجعة" : "Pending"}</option>
                <option value="approved">{isArabic ? "معتمد" : "Approved"}</option>
                <option value="rejected">{isArabic ? "مرفوض" : "Rejected"}</option>
                <option value="paid">{isArabic ? "مدفوع" : "Paid"}</option>
              </select>
            </label>
          </div>
        </div>
        {error ? <div className="mt-5 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div> : null}
      </section>

      <div className="space-y-4">
        {visibleItems.map((item) => (
          <article key={item._id} className="panel p-6">
            <div className="flex flex-col gap-5 xl:flex-row xl:items-start xl:justify-between">
              <div className="flex-1">
                <div className="flex flex-wrap items-center gap-3">
                  <h2 className="text-xl font-semibold text-slate-900">{item.agent?.name || "--"}</h2>
                  <span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-700">{item.status}</span>
                </div>
                <p className="mt-2 text-sm text-slate-500">{item.agent?.email || "--"}</p>
                <div className="mt-4 grid gap-3 md:grid-cols-2 xl:grid-cols-4">
                  <div className="rounded-2xl bg-slate-50 px-4 py-3 text-sm"><span className="font-semibold">{isArabic ? "المبلغ" : "Amount"}:</span> {formatCurrency(item.amount)}</div>
                  <div className="rounded-2xl bg-slate-50 px-4 py-3 text-sm"><span className="font-semibold">{isArabic ? "الطريقة" : "Method"}:</span> {item.method}</div>
                  <div className="rounded-2xl bg-slate-50 px-4 py-3 text-sm md:col-span-2"><span className="font-semibold">{isArabic ? "بيانات الاستلام" : "Payout Details"}:</span> {item.payoutDetails}</div>
                </div>
                {item.notes ? <p className="mt-4 text-sm leading-6 text-slate-600">{item.notes}</p> : null}
              </div>
              <div className="w-full xl:max-w-sm">
                <textarea value={notes[item._id] || ""} onChange={(event) => setNotes((current) => ({ ...current, [item._id]: event.target.value }))} rows={4} placeholder={isArabic ? "ملاحظات المراجعة" : "Review note"} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
                <div className="mt-4 grid gap-2 sm:grid-cols-2">
                  <button type="button" onClick={() => setUpdateTarget({ item, status: "approved" })} className="inline-flex items-center justify-center gap-2 rounded-2xl bg-emerald-600 px-4 py-3 text-sm font-semibold text-white">
                    <CheckCircle2 className="h-4 w-4" />
                    {isArabic ? "اعتماد" : "Approve"}
                  </button>
                  <button type="button" onClick={() => setUpdateTarget({ item, status: "paid" })} className="inline-flex items-center justify-center gap-2 rounded-2xl bg-slate-950 px-4 py-3 text-sm font-semibold text-white">
                    <Landmark className="h-4 w-4" />
                    {isArabic ? "تم الدفع" : "Mark Paid"}
                  </button>
                  <button type="button" onClick={() => setUpdateTarget({ item, status: "pending" })} className="inline-flex items-center justify-center gap-2 rounded-2xl border border-slate-200 px-4 py-3 text-sm font-semibold text-slate-700">
                    <Clock3 className="h-4 w-4" />
                    {isArabic ? "تعليق" : "Pending"}
                  </button>
                  <button type="button" onClick={() => setUpdateTarget({ item, status: "rejected" })} className="inline-flex items-center justify-center gap-2 rounded-2xl bg-rose-600 px-4 py-3 text-sm font-semibold text-white">
                    <XCircle className="h-4 w-4" />
                    {isArabic ? "رفض" : "Reject"}
                  </button>
                </div>
              </div>
            </div>
          </article>
        ))}
        {filteredItems.length === 0 ? <div className="panel px-6 py-12 text-center text-sm text-slate-500">{isArabic ? "لا توجد طلبات مطابقة." : "No payout requests match your filters."}</div> : null}
      </div>

      <AdminPagination page={page} totalPages={totalPages} totalItems={filteredItems.length} pageSize={PAGE_SIZE} isArabic={isArabic} onPageChange={setPage} />

      <AdminConfirmationModal
        open={Boolean(updateTarget)}
        title={isArabic ? "تأكيد تحديث الطلب" : "Confirm payout update"}
        description={
          isArabic
            ? `سيتم تحديث طلب ${updateTarget?.item.agent?.name || ""} إلى الحالة ${updateTarget?.status || ""}.`
            : `The payout request for ${updateTarget?.item.agent?.name || "this agent"} will be updated to ${updateTarget?.status || ""}.`
        }
        confirmLabel={isArabic ? "تأكيد" : "Confirm"}
        cancelLabel={isArabic ? "إلغاء" : "Cancel"}
        loading={updating}
        onConfirm={handleUpdate}
        onClose={() => !updating && setUpdateTarget(null)}
      />
      <AdminToastViewport items={toasts} onDismiss={dismissToast} />
    </div>
  );
};
