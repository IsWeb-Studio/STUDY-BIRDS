// Read-only evidence, scoped by the overview controller to the current student.
const { missingDocumentTypes, requiredDocumentTypesFor } = require('./applicationRequirements');
const { studentNextAction } = require('./studentNextAction');
const { postAdmissionStages } = require('./postAdmissionJourney');
const id = value => String(value?._id || value || '');
function studentJourneys({ applications = [], documents = [], invoices = [] }, now = new Date()) {
  return applications.map(app => {
    const linked = new Set((app.documents || []).map(id));
    const files = documents.filter(doc => linked.has(id(doc)));
    const bills = invoices.filter(invoice => id(invoice.application) === id(app));
    const state = app.status === 'rejected' ? 'rejected' : app.detailedStatus || app.status;
    const closed = ['rejected', 'completed'].includes(state);
    const required = app.requiredDocumentTypes ?? requiredDocumentTypesFor(app.program);
    const missing = missingDocumentTypes(required, files);
    const requests = app.documentRequests || [];
    const needsFiles = missing.length > 0 || requests.some(r => r.status === 'requested');
    const pendingFiles = required.some(type => !files.some(doc => doc.type === type && doc.status === 'verified' && !['expired','needs-revision','needs-translation','rejected'].includes(doc.detailedStatus))) || requests.some(r => r.status === 'submitted');
    const unpaid = bills.filter(b => ['unpaid','rejected'].includes(b.status));
    const overdue = unpaid.some(b => b.dueDate && new Date(b.dueDate) < now);
    const accepted = ['accepted','final-admission','visa-preparation','completed'].includes(state);
    const stages = [
      { key: 'documents', titleAr: 'مستندات الطلب', status: needsFiles ? 'action-required' : pendingFiles ? 'waiting' : 'completed', descriptionAr: needsFiles ? 'هناك مستندات ناقصة أو مطلوب تصحيحها. افتح الطلب لمراجعة التفاصيل.' : pendingFiles ? 'المستندات مرفقة وتنتظر اعتماد الفريق.' : 'استُوفيت متطلبات المستندات المعتمدة لهذا الطلب.', destination: 'applications' },
      { key: 'admission', titleAr: 'مراجعة الطلب والقبول', status: state === 'rejected' ? 'rejected' : accepted ? 'completed' : ['draft','ready-to-apply'].includes(state) ? 'action-required' : 'waiting', descriptionAr: state === 'rejected' ? 'لم يُقبل هذا الطلب. راجع النتيجة وملاحظات الفريق.' : accepted ? 'القبول مسجل في الطلب.' : 'يعتمد الانتقال على مراجعة الفريق وقرار الجامعة؛ رفع المستندات لا يعني القبول.', destination: 'applications' },
      { key: 'payments', titleAr: 'فواتير الطلب', status: overdue ? 'overdue' : unpaid.length ? 'action-required' : bills.some(b => b.status === 'pending-confirmation') ? 'waiting' : bills.length ? 'completed' : 'not-issued', descriptionAr: overdue ? 'توجد فاتورة تجاوزت موعد الاستحقاق.' : unpaid.length ? 'توجد فاتورة تحتاج السداد أو تصحيح إثبات الدفع.' : bills.some(b => b.status === 'pending-confirmation') ? 'إثبات الدفع ينتظر مراجعة المالية.' : bills.length ? 'كل الفواتير المرتبطة بهذا الطلب مسددة.' : 'لا توجد فاتورة مرتبطة بهذا الطلب حتى الآن.', destination: 'payments' },
    ];
    stages.push(...postAdmissionStages(app, now));
    const advisor = app.assignedAdvisor?.name && app.assignedAdvisor.isActive !== false ? { name: app.assignedAdvisor.name } : null;
    const followUp = { advisor, dueAt: app.followUpDueAt || null, overdue: !closed && Boolean(advisor && app.followUpDueAt && new Date(app.followUpDueAt) < now) };
    return { followUp, applicationId: id(app), title: app.program?.title || 'طلب دراسي', applicationStatus: state, closed, missingDocumentTypes: missing, stages,
      nextAction: closed ? null : studentNextAction({ applications: [app], documents: files, invoices: bills }, now) };
  });
}
module.exports = { studentJourneys };
