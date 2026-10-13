// Read-only evaluation: never promotes an admission or approves a payment.
// The caller must supply records scoped to the authenticated student.
const CLOSED = new Set(['rejected', 'completed']);
const id = (record) => String(record?._id || record || '');
const status = (record) => record.status === 'rejected' ? 'rejected' : record.detailedStatus || record.status;
const { missingDocumentTypes } = require('./applicationRequirements');
const { postAdmissionNextAction } = require('./postAdmissionJourney');
const documentLabels = { passport: 'جواز السفر', 'biometric-photo': 'الصورة الشخصية', 'latest-qualification': 'آخر مؤهل دراسي', transcript: 'كشف الدرجات', 'language-certificate': 'شهادة اللغة', other: 'مستند إضافي' };

function studentNextAction({ applications = [], documents = [], invoices = [] }, now = new Date()) {
  const actions = [];
  function add(code, destination, titleAr, titleEn, descriptionAr, descriptionEn, record, priority, waiting = false) {
    actions.push({ code, destination, titleAr, titleEn, descriptionAr, descriptionEn,
      entityId: id(record), priority, waiting, dueDate: record?.dueDate || null });
  }
  const active = applications.filter((app) => !CLOSED.has(status(app)));
  // Documents referenced exclusively by closed applications must not block a new journey.
  const closedIds = new Set(applications.filter((app) => CLOSED.has(status(app))).flatMap((app) => (app.documents || []).map(id)));
  const activeIds = new Set(active.flatMap((app) => (app.documents || []).map(id)));
  for (const app of applications) {
    for (const revision of app.documentRevisions || []) {
      for (const old of revision.previousDocuments || []) closedIds.add(id(old));
    }
  }
  const relevant = documents.filter((doc) => !closedIds.has(id(doc)) || activeIds.has(id(doc)));
  for (const invoice of invoices) {
    if (['unpaid', 'rejected'].includes(invoice.status)) {
      const overdue = invoice.dueDate && new Date(invoice.dueDate) < now;
      add('payment-required', 'payments', overdue ? 'فاتورة متأخرة' : 'سداد فاتورة', overdue ? 'Overdue invoice' : 'Pay an invoice',
        invoice.description, invoice.description, invoice, overdue ? 0 : 20);
    } else if (invoice.status === 'pending-confirmation') {
      add('payment-review', 'payments', 'بانتظار تأكيد الدفع', 'Payment under review',
        'استلمنا إثبات الدفع؛ تابع نتيجة المراجعة.', 'Your payment proof is awaiting review.', invoice, 70, true);
    }
  }
  for (const doc of relevant) {
    if (['rejected', 'needs-revision', 'needs-translation', 'expired', 'missing'].includes(status(doc))) {
      add('document-correction', 'documents', 'استكمال مستند', 'Update a document',
        `راجع المستند المطلوب: ${documentLabels[doc.type] || doc.type}`, `Review the required document: ${doc.type}`, doc, 10);
    }
  }
  for (const app of active) {
    const postAdmissionAction = postAdmissionNextAction(app, now);
    if (postAdmissionAction) actions.push(postAdmissionAction);
    for (const request of app.documentRequests || []) {
      if (request.status === 'requested') add('additional-document-request', 'applications', 'مستند إضافي مطلوب', 'Additional document requested', request.note, request.note, app, 5);
      if (request.status === 'submitted') add('additional-document-review', 'applications', 'بانتظار مراجعة المستند الإضافي', 'Additional document under review', request.note, request.note, app, 65, true);
    }
    const attachedIds = new Set((app.documents || []).map(id));
    const missing = missingDocumentTypes(app.requiredDocumentTypes || [], documents.filter(doc => attachedIds.has(id(doc))));
    if (missing.length && ['draft', 'documents-missing', 'ready-to-apply', 'submitted', 'additional-documents-required'].includes(status(app))) {
      add('documents-required', 'applications', 'مستندات مطلوبة للطلب', 'Application documents required',
        `راجع مستندات الطلب: ${missing.map(type => documentLabels[type] || type).join('، ')}`, `Review application documents: ${missing.join(', ')}`, app, 15);
    }
    if (status(app) === 'documents-missing' && Array.isArray(app.requiredDocumentTypes) && !missing.length) {
      add('document-review', 'applications', 'بانتظار مراجعة المستندات', 'Documents awaiting review', 'تم إرفاق المستندات المطلوبة. تابع مراجعة الفريق.', 'Required documents are attached. Await team review.', app, 75, true);
    } else if (['documents-missing', 'additional-documents-required'].includes(status(app))) {
      add('documents-required', 'applications', 'مستندات مطلوبة للطلب', 'Application documents required',
        'افتح الطلب لمراجعة المستندات وملاحظات الفريق.', 'Open the application to review documents and team notes.', app, 15);
    } else if (['draft', 'ready-to-apply'].includes(status(app))) {
      add('complete-application', 'applications', 'استكمال طلب التقديم', 'Complete your application',
        'راجع بيانات الطلب واستكمل التقديم.', 'Review your application and finish submitting it.', app, 30);
    } else if (status(app) === 'payment-required' && !invoices.some((inv) => id(inv.application) === id(app))) {
      add('request-invoice', 'support', 'طلب تفاصيل الدفع', 'Request payment details',
        'الطلب يتطلب دفعًا، ولم تصدر فاتورته بعد. تواصل مع الفريق.', 'Payment is required but no invoice has been issued. Contact your team.', app, 25);
    } else {
      add('track-application', 'applications', 'متابعة طلبك', 'Track your application',
        'راجع آخر تحديث وملاحظات فريقك داخل الطلب.', 'Review the latest update and team notes in your application.', app, 80, true);
    }
  }
  if (!applications.length && !actions.length) {
    add('explore-programs', 'catalog', 'اختر برنامجك الدراسي', 'Find your study program',
      'استكشف الجامعات والبرامج وابدأ طلبك.', 'Explore universities and programs to start your application.', null, 90);
  }
  if (!actions.length) {
    add('review-applications', 'applications', 'مراجعة طلباتك', 'Review your applications',
      'اطّلع على نتائج طلباتك أو تواصل مع الفريق للخطوة التالية.', 'Review your application outcomes or contact your team about the next step.', null, 90);
  }
  actions.sort((a, b) => a.priority - b.priority ||
    (a.dueDate ? new Date(a.dueDate).getTime() : Infinity) - (b.dueDate ? new Date(b.dueDate).getTime() : Infinity) ||
    a.entityId.localeCompare(b.entityId));
  return actions[0];
}

module.exports = { studentNextAction };
