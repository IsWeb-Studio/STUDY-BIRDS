// Student-facing copy for every application and document status (PRD 103–105).
//
// The database keeps fixed internal codes (Application.detailedStatus,
// Document.detailedStatus). Clients never show those codes: they render
// `statusInfo`, built here, which says in plain language what the status
// means for the student now and what happens next. This file is the single
// source of that copy for the website, the app and notifications.
//
// Timings are deliberately not promised in days: expected durations depend on
// the university and are not yet business-approved.

const APPLICATION_STATUS_COPY = Object.freeze({
  draft: {
    code: "APP_01_DRAFT", tone: "neutral",
    ar: { label: "مسودة", meaning: "طلبك محفوظ ولم يُرسل بعد.", nextStep: "أكمل البيانات والمستندات، ثم أرسل الطلب متى كنت جاهزًا." },
    en: { label: "Draft", meaning: "Your application is saved but not sent yet.", nextStep: "Complete your details and documents, then submit when you're ready." },
  },
  "documents-missing": {
    code: "APP_02_DOCUMENTS_MISSING", tone: "action",
    ar: { label: "مستندات ناقصة", meaning: "لا يمكن متابعة طلبك قبل رفع كل المستندات المطلوبة.", nextStep: "ارفع المستندات الناقصة الظاهرة في الطلب، وسنكمل مباشرة بعدها." },
    en: { label: "Documents missing", meaning: "Your application can't move forward until all required documents are uploaded.", nextStep: "Upload the missing documents shown in your application and we'll continue right away." },
  },
  "ready-to-apply": {
    code: "APP_03_READY_TO_APPLY", tone: "info",
    ar: { label: "جاهز للتقديم", meaning: "كل ما يلزم موجود وطلبك جاهز للإرسال إلى الجامعة.", nextStep: "سيرسل فريقنا طلبك إلى الجامعة، وسنبلغك فور إرساله." },
    en: { label: "Ready to apply", meaning: "Everything needed is in place and your application is ready for the university.", nextStep: "Our team will send it to the university and let you know once it's sent." },
  },
  submitted: {
    code: "APP_04_SUBMITTED", tone: "info",
    ar: { label: "تم التقديم", meaning: "وصل طلبك وسيبدأ فريقنا بمتابعته.", nextStep: "لا مطلوب منك شيء الآن. سنبلغك بأي تحديث." },
    en: { label: "Submitted", meaning: "We've received your application and our team is on it.", nextStep: "Nothing is needed from you right now. We'll tell you about any update." },
  },
  "under-review": {
    code: "APP_05_UNDER_REVIEW", tone: "info",
    ar: { label: "قيد المراجعة", meaning: "طلبك قيد المراجعة والتدقيق من قبل فريق الجامعة.", nextStep: "لا مطلوب منك شيء الآن. سنبلغك فور صدور قرار الجامعة." },
    en: { label: "Under review", meaning: "Your application is being reviewed by the university.", nextStep: "Nothing is needed from you right now. We'll tell you as soon as the university decides." },
  },
  "additional-documents-required": {
    code: "APP_06_ADDITIONAL_DOCUMENTS_REQUIRED", tone: "action",
    ar: { label: "مطلوب مستندات إضافية", meaning: "طُلبت مستندات إضافية لإكمال دراسة طلبك.", nextStep: "افتح الطلب وارفع المستندات المطلوبة حتى يستمر التقييم." },
    en: { label: "Additional documents required", meaning: "More documents are needed to finish assessing your application.", nextStep: "Open your application and upload the requested documents so the review can continue." },
  },
  "conditional-admission": {
    code: "APP_07_CONDITIONAL_ADMISSION", tone: "success",
    ar: { label: "قبول مبدئي", meaning: "مبروك! حصلت على قبول مبدئي مشروط باستكمال بعض المتطلبات.", nextStep: "راجع شروط القبول في طلبك، وسيتواصل معك مستشارك بالخطوات التالية." },
    en: { label: "Conditional admission", meaning: "Congratulations! You have a conditional offer that depends on a few remaining requirements.", nextStep: "Check the offer conditions in your application; your advisor will contact you with next steps." },
  },
  "payment-required": {
    code: "APP_08_PAYMENT_REQUIRED", tone: "action",
    ar: { label: "مطلوب الدفع", meaning: "لتثبيت مقعدك يجب دفع الرسوم المطلوبة.", nextStep: "ادفع الفاتورة من قسم المدفوعات، ثم ارفع إثبات الدفع." },
    en: { label: "Payment required", meaning: "A payment is needed to secure your place.", nextStep: "Pay the invoice in Payments, then upload your proof of payment." },
  },
  "payment-verification": {
    code: "APP_09_PAYMENT_VERIFICATION", tone: "info",
    ar: { label: "التحقق من الدفع", meaning: "استلمنا إثبات الدفع ونتحقق منه الآن.", nextStep: "لا مطلوب منك شيء الآن. سنبلغك فور تأكيد الدفع." },
    en: { label: "Verifying payment", meaning: "We received your proof of payment and are verifying it.", nextStep: "Nothing is needed from you right now. We'll tell you once it's confirmed." },
  },
  "final-admission": {
    code: "APP_10_FINAL_ADMISSION", tone: "success",
    ar: { label: "قبول نهائي", meaning: "مبروك! حصلت على القبول النهائي.", nextStep: "تبدأ الآن إجراءات التأشيرة والسفر، وسيرشدك فريقنا خطوة بخطوة." },
    en: { label: "Final admission", meaning: "Congratulations! You have final admission.", nextStep: "Visa and travel steps start now, and our team will guide you through each one." },
  },
  "visa-preparation": {
    code: "APP_11_VISA_PREPARATION", tone: "action",
    ar: { label: "تجهيز التأشيرة", meaning: "نعمل معك على تجهيز ملف التأشيرة.", nextStep: "تابع متطلبات التأشيرة في طلبك وجهّز المستندات المطلوبة للسفارة." },
    en: { label: "Visa preparation", meaning: "We're preparing your visa file with you.", nextStep: "Follow the visa checklist in your application and prepare the embassy documents." },
  },
  completed: {
    code: "APP_12_COMPLETED", tone: "success",
    ar: { label: "مكتمل", meaning: "اكتملت إجراءات طلبك بنجاح.", nextStep: "تابع رحلتك في مراحل ما بعد القبول: السفر والسكن والتسجيل." },
    en: { label: "Completed", meaning: "Your application process is complete.", nextStep: "Continue with your post-admission steps: travel, housing and registration." },
  },
  accepted: {
    code: "APP_13_ACCEPTED", tone: "success",
    ar: { label: "مقبول", meaning: "مبروك! قبلتك الجامعة.", nextStep: "سيتواصل معك فريقنا لإكمال الخطوات التالية." },
    en: { label: "Accepted", meaning: "Congratulations! The university accepted you.", nextStep: "Our team will contact you to complete the next steps." },
  },
  rejected: {
    code: "APP_14_NOT_ACCEPTED", tone: "danger",
    ar: { label: "غير مقبول", meaning: "للأسف لم تُقبل في هذا البرنامج.", nextStep: "يمكن لمستشارك مساعدتك في اختيار برنامج بديل. تواصل معه من صفحة الطلب." },
    en: { label: "Not accepted", meaning: "Unfortunately you weren't accepted to this program.", nextStep: "Your advisor can help you choose an alternative program. Contact them from your application." },
  },
});

const DOCUMENT_STATUS_COPY = Object.freeze({
  missing: {
    code: "DOC_01_MISSING", tone: "action",
    ar: { label: "مطلوب", meaning: "هذا المستند مطلوب ولم يُرفع بعد.", nextStep: "ارفع المستند بصيغة PDF أو صورة واضحة." },
    en: { label: "Required", meaning: "This document is required and hasn't been uploaded yet.", nextStep: "Upload it as a PDF or a clear photo." },
  },
  uploaded: {
    code: "DOC_02_UPLOADED", tone: "info",
    ar: { label: "تم الرفع", meaning: "استلمنا المستند وسيراجعه فريقنا.", nextStep: "لا مطلوب منك شيء الآن. سنبلغك بنتيجة المراجعة." },
    en: { label: "Uploaded", meaning: "We received the document and our team will review it.", nextStep: "Nothing is needed from you right now. We'll tell you the result." },
  },
  "under-review": {
    code: "DOC_03_UNDER_REVIEW", tone: "info",
    ar: { label: "قيد المراجعة", meaning: "يدقق فريقنا المستند الآن.", nextStep: "سنبلغك فور انتهاء المراجعة." },
    en: { label: "Under review", meaning: "Our team is checking the document now.", nextStep: "We'll tell you as soon as the review is done." },
  },
  approved: {
    code: "DOC_04_APPROVED", tone: "success",
    ar: { label: "معتمد", meaning: "تمت مراجعة المستند واعتماده.", nextStep: "لا حاجة لأي إجراء." },
    en: { label: "Approved", meaning: "The document was reviewed and approved.", nextStep: "No action needed." },
  },
  rejected: {
    code: "DOC_05_REJECTED", tone: "danger",
    ar: { label: "مرفوض", meaning: "تم رفض المستند.", reasonMeaning: "تم رفض المستند نظرًا لـ: {reason}", nextStep: "يرجى إعادة رفع المستند بعد معالجة السبب." },
    en: { label: "Rejected", meaning: "The document was rejected.", reasonMeaning: "The document was rejected because: {reason}", nextStep: "Please upload it again after fixing the issue." },
  },
  "needs-revision": {
    code: "DOC_06_NEEDS_REVISION", tone: "action",
    ar: { label: "يحتاج تعديل", meaning: "المستند يحتاج تعديلًا قبل اعتماده.", reasonMeaning: "المستند يحتاج تعديلًا قبل اعتماده: {reason}", nextStep: "عدّل المستند وأعد رفعه." },
    en: { label: "Needs revision", meaning: "The document needs changes before it can be approved.", reasonMeaning: "The document needs changes before it can be approved: {reason}", nextStep: "Fix the document and upload it again." },
  },
  "needs-translation": {
    code: "DOC_07_NEEDS_TRANSLATION", tone: "action",
    ar: { label: "يحتاج ترجمة", meaning: "يلزم ترجمة معتمدة لهذا المستند.", reasonMeaning: "يلزم ترجمة معتمدة لهذا المستند: {reason}", nextStep: "ارفع ترجمة معتمدة، أو اطلب خدمة الترجمة من مركز الخدمات." },
    en: { label: "Needs translation", meaning: "A certified translation of this document is required.", reasonMeaning: "A certified translation of this document is required: {reason}", nextStep: "Upload a certified translation, or request the translation service." },
  },
  expired: {
    code: "DOC_08_EXPIRED", tone: "action",
    ar: { label: "منتهي الصلاحية", meaning: "انتهت صلاحية المستند.", expiredMeaning: "انتهت صلاحية المستند بتاريخ {date}.", nextStep: "ارفع نسخة سارية المفعول." },
    en: { label: "Expired", meaning: "The document has expired.", expiredMeaning: "The document expired on {date}.", nextStep: "Upload a valid copy." },
  },
});

const { APPLICATION_STATUS_TO_DETAILED_STATUS } = require("./roles");

// Statuses where the student must fix something, so a reason is mandatory.
const DOCUMENT_STATUSES_REQUIRING_REASON = Object.freeze(["rejected", "needs-revision", "needs-translation"]);

const LEGACY_DOCUMENT_TO_DETAILED = Object.freeze({ pending: "uploaded", verified: "approved", rejected: "rejected" });

function pick(entry, extra) {
  const lang = (copy) => ({ label: copy.label, meaning: extra?.(copy) || copy.meaning, nextStep: copy.nextStep });
  return { code: entry.code, tone: entry.tone, ar: lang(entry.ar), en: lang(entry.en) };
}

function applicationStatusInfo(application) {
  const raw = application?.detailedStatus || application?.status;
  // Website review codes (e.g. timeline entries "preliminary-accepted") map to their lifecycle stage.
  const key = APPLICATION_STATUS_COPY[raw] ? raw : APPLICATION_STATUS_TO_DETAILED_STATUS[raw] || raw;
  const entry = APPLICATION_STATUS_COPY[key] || APPLICATION_STATUS_COPY.submitted;
  return { status: APPLICATION_STATUS_COPY[key] ? key : "submitted", ...pick(entry) };
}

function documentStatusInfo(document) {
  const key = document?.detailedStatus || LEGACY_DOCUMENT_TO_DETAILED[document?.status] || "uploaded";
  const entry = DOCUMENT_STATUS_COPY[key] || DOCUMENT_STATUS_COPY.uploaded;
  const reason = String(document?.reviewNote || "").trim();
  const expiresAt = document?.expiresAt ? new Date(document.expiresAt) : null;
  const info = pick(entry, (copy) => {
    if (copy.reasonMeaning && reason) return copy.reasonMeaning.replace("{reason}", reason);
    if (copy.expiredMeaning && expiresAt && !Number.isNaN(expiresAt.getTime())) {
      return copy.expiredMeaning.replace("{date}", expiresAt.toISOString().slice(0, 10));
    }
    return null;
  });
  return { status: DOCUMENT_STATUS_COPY[key] ? key : "uploaded", ...info, reason: reason || null };
}

// Plain-language notification when a status changes (Arabic, the students' default).
function applicationStatusNotice(application, programTitle) {
  const info = applicationStatusInfo(application);
  return {
    title: `تحديث طلبك: ${info.ar.label}`,
    message: `${programTitle ? `${programTitle} — ` : ""}${info.ar.meaning} ${info.ar.nextStep}`,
    type: info.tone === "success" ? "success" : info.tone === "danger" || info.tone === "action" ? "warning" : "info",
    link: "/student/applications",
  };
}

function documentStatusNotice(document, typeLabel) {
  const info = documentStatusInfo(document);
  return {
    title: `${typeLabel || "مستندك"}: ${info.ar.label}`,
    message: `${info.ar.meaning} ${info.ar.nextStep}`,
    type: info.tone === "success" ? "success" : info.tone === "info" ? "info" : "warning",
  };
}

module.exports = {
  APPLICATION_STATUS_COPY,
  DOCUMENT_STATUS_COPY,
  DOCUMENT_STATUSES_REQUIRING_REASON,
  applicationStatusInfo,
  documentStatusInfo,
  applicationStatusNotice,
  documentStatusNotice,
};
