// Retrieval helpers for Bird AI — grounds replies in the platform's own
// knowledge base and the asking student's own data. Read-only; only ever
// built from the caller's own data, never another user's.
const Application  = require("../models/Application");
const Document     = require("../models/Document");
const Invoice      = require("../models/Invoice");
const KnowledgeBaseItem = require("../models/KnowledgeBaseItem");
const { Booking }  = require("../models/Consultation");
const ServiceRequest = require("../models/ServiceRequest");
const { studentNextAction } = require("./studentNextAction");

async function buildStudentContext(userId) {
  const [applications, documents, invoices, consultations, serviceRequests] = await Promise.all([
    Application.find({ student: userId })
      .populate("program", "title tuitionFee currency")
      .populate("university", "name country")
      .lean(),
    Document.find({ student: userId }).select("type status detailedStatus").lean(),
    Invoice.find({ student: userId }).select("status dueDate amount currency").lean(),
    Booking.find({ student: userId, status: "booked", startsAt: { $gt: new Date() } })
      .populate("advisor", "name")
      .populate("slot", "mode meetingUrl")
      .sort({ startsAt: 1 })
      .limit(3)
      .lean(),
    ServiceRequest.find({ student: userId, status: { $in: ["pending", "assigned", "in-progress"] } })
      .select("serviceTitle status staffNote assignedTo")
      .populate("assignedTo", "name")
      .limit(5)
      .lean(),
  ]);

  const lines = [];

  // Applications
  if (!applications.length) {
    lines.push("لم يقدّم هذا الطالب أي طلب حتى الآن.");
  } else {
    lines.push("=== طلبات القبول ===");
    for (const app of applications) {
      const prog = app.program?.title || "برنامج";
      const uni  = app.university?.name || "جامعة";
      const country = app.university?.country || "";
      const fee  = app.program?.tuitionFee ? `${app.program.tuitionFee} ${app.program.currency || "USD"}/سنة` : "";
      const stageLine = app.postAdmissionStages?.length
        ? `مرحلة ما بعد القبول: ${app.postAdmissionStages.map(s => `${s.stage}(${s.status})`).join(', ')}`
        : "";
      const visaLine = app.visaCase?.status && app.visaCase.status !== "not-started"
        ? `التأشيرة: ${app.visaCase.status}`
        : "";
      lines.push(`- ${prog} في ${uni}${country ? ` (${country})` : ""}${fee ? ` — الرسوم: ${fee}` : ""}: الحالة "${app.detailedStatus || app.status}"${visaLine ? ` — ${visaLine}` : ""}${stageLine ? ` — ${stageLine}` : ""}`);
    }
  }

  // Next action
  const next = studentNextAction({ applications, documents, invoices });
  lines.push(next ? `الإجراء التالي المطلوب: ${next.titleAr}` : "لا يوجد إجراء عاجل مسجل حاليًا.");

  // Documents summary
  const pendingDocs = documents.filter(d => d.status === "pending" || d.status === "in-review");
  const rejectedDocs = documents.filter(d => d.status === "rejected");
  if (pendingDocs.length) lines.push(`مستندات معلقة/قيد المراجعة: ${pendingDocs.length}`);
  if (rejectedDocs.length) lines.push(`مستندات مرفوضة تحتاج إعادة رفع: ${rejectedDocs.length}`);

  // Invoices
  const unpaidInvoices = invoices.filter(i => i.status === "unpaid" || i.status === "overdue");
  if (unpaidInvoices.length) {
    lines.push(`=== فواتير غير مدفوعة ===`);
    for (const inv of unpaidInvoices) {
      const due = inv.dueDate ? `تستحق ${new Date(inv.dueDate).toLocaleDateString("ar")}` : "";
      lines.push(`- ${inv.amount} ${inv.currency || "USD"} ${due} (${inv.status})`);
    }
  }

  // Upcoming consultations
  if (consultations.length) {
    lines.push(`=== استشارات قادمة ===`);
    for (const c of consultations) {
      const when = new Date(c.startsAt).toLocaleString("ar", { dateStyle: "medium", timeStyle: "short" });
      const mode = { online: "أونلاين", phone: "هاتف", office: "مكتب" }[c.slot?.mode] || c.slot?.mode || "";
      lines.push(`- ${when} مع ${c.advisor?.name || "مستشار"} (${mode})`);
    }
  }

  // Active service requests
  if (serviceRequests.length) {
    lines.push(`=== طلبات خدمات نشطة ===`);
    for (const sr of serviceRequests) {
      const statusAr = { pending: "في الانتظار", assigned: "تم التعيين", "in-progress": "قيد التنفيذ" }[sr.status] || sr.status;
      const assignee = sr.assignedTo?.name ? ` — مع ${sr.assignedTo.name}` : "";
      lines.push(`- ${sr.serviceTitle}: ${statusAr}${assignee}${sr.staffNote ? ` (ملاحظة: ${sr.staffNote})` : ""}`);
    }
  }

  return lines.join("\n");
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

async function findRelevantKnowledge(message, limit = 4) {
  const keywords = String(message)
    .toLowerCase()
    .split(/\s+/)
    .filter(w => w.length >= 3)
    .slice(0, 10);
  if (!keywords.length) return [];

  const regex = new RegExp(keywords.map(escapeRegex).join("|"), "i");

  // Search knowledge base + FAQs
  const [kbItems, faqs] = await Promise.all([
    KnowledgeBaseItem.find({
      published: true,
      targetRole: { $in: ["all", "student"] },
      $or: [{ title: regex }, { summary: regex }, { body: regex }],
    }).select("title summary body").limit(limit).lean(),

    (async () => {
      try {
        const Faq = require("../models/Faq");
        return await Faq.find({
          $or: [{ question: regex }, { answer: regex }],
        }).select("question answer").limit(2).lean();
      } catch { return []; }
    })(),
  ]);

  const results = [
    ...kbItems.map(item => `- ${item.title}: ${(item.summary || item.body).slice(0, 400)}`),
    ...faqs.map(faq => `- س: ${faq.question}\n  ج: ${String(faq.answer || "").slice(0, 300)}`),
  ];

  return results.slice(0, limit);
}

// Returns context-aware suggested questions for the Flutter UI
// based on the student's current state
async function buildSuggestedQuestions(userId) {
  const [applications, invoices, serviceRequests, consultations] = await Promise.all([
    Application.find({ student: userId }).select("status detailedStatus").lean(),
    Invoice.find({ student: userId, status: { $in: ["unpaid", "overdue"] } }).lean(),
    ServiceRequest.find({ student: userId, status: { $in: ["pending", "assigned", "in-progress"] } }).lean(),
    Booking.find({ student: userId, status: "booked", startsAt: { $gt: new Date() } }).lean(),
  ]);

  const questions = [];

  if (!applications.length) {
    questions.push("كيف أبدأ التقديم على جامعة؟");
    questions.push("ما هي المستندات المطلوبة للتقديم؟");
    questions.push("كيف أختار التخصص المناسب لي؟");
  } else {
    questions.push("ما هو الإجراء التالي المطلوب مني؟");
    if (applications.some(a => a.status === "under-review")) questions.push("متى سيرد على طلبي؟");
    if (applications.some(a => a.detailedStatus === "accepted")) questions.push("ما هي خطوات التأشيرة بعد القبول؟");
    if (invoices.length) questions.push("كيف أدفع الفاتورة المستحقة؟");
  }

  if (consultations.length) questions.push("ما الذي أحضره لاستشارتي القادمة؟");
  if (serviceRequests.length) questions.push("ما هي حالة طلب الخدمة النشط لديّ؟");

  questions.push("ما هي متطلبات التأشيرة الدراسية؟");
  questions.push("ما هي أفضل الجامعات في مجالي؟");

  return questions.slice(0, 5);
}

module.exports = { buildStudentContext, findRelevantKnowledge, buildSuggestedQuestions };
