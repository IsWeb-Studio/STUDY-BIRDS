const STAGES = Object.freeze({
  visa: ['التأشيرة', 'Visa'],
  travel: ['ترتيبات السفر', 'Travel arrangements'],
  housing: ['السكن', 'Accommodation'],
  arrival: ['الوصول والاستقبال', 'Arrival and pickup'],
  registration: ['التسجيل في الجامعة', 'University registration'],
  residence: ['الإقامة والدعم المستمر', 'Residence and ongoing support'],
});
const STATES = ['not-started', 'in-progress', 'action-required', 'waiting-team', 'waiting-university', 'completed', 'not-required'];
function isPostAdmissionEligible(app) {
  if (['rejected', 'file-completed-rejected', 'file-completed-accepted'].includes(app.status)) return false;
  return ['accepted', 'final-admission', 'visa-preparation'].includes(app.detailedStatus || app.status)
    || (!app.detailedStatus && app.status === 'final-accepted');
}
function postAdmissionStages(app, now = new Date()) {
  if (!isPostAdmissionEligible(app) && !Object.values(app.postAdmission || {}).some(item => item?.updatedAt)) return [];
  return Object.entries(STAGES).map(([key, [titleAr, titleEn]]) => {
    const item = app.postAdmission?.[key] || {};
    const state = item.status || 'not-started';
    const finished = ['completed', 'not-required'].includes(state);
    const overdue = !finished && Boolean(item.dueAt && new Date(item.dueAt) < now);
    return { key, titleAr, titleEn, status: overdue ? 'overdue' : state, recordedStatus: state,
      descriptionAr: item.note || 'لم يحدد الفريق إجراءات هذه المرحلة بعد. تواصل مع مسؤول متابعتك.',
      dueAt: item.dueAt || null, reference: item.reference || '',
      destination: 'support', updatedAt: item.updatedAt || null };
  });
}
function postAdmissionNextAction(app, now = new Date()) {
  if (!isPostAdmissionEligible(app)) return null;
  const candidates = postAdmissionStages(app, now).filter(s => !['completed', 'not-required'].includes(s.recordedStatus));
  const priority = s => s.status === 'overdue' ? 25 : s.recordedStatus === 'action-required' ? 35 : s.recordedStatus === 'not-started' ? 78 : 72;
  candidates.sort((a, b) => priority(a) - priority(b));
  const stage = candidates[0];
  if (!stage) return null;
  return { code: `post-admission-${stage.key}`, destination: 'journey', entityId: String(app._id),
    titleAr: `${stage.status === 'overdue' ? 'متابعة مرحلة متأخرة' : 'الخطوة التالية'}: ${stage.titleAr}`,
    titleEn: `${stage.status === 'overdue' ? 'Overdue follow-up' : 'Next step'}: ${stage.titleEn}`,
    descriptionAr: stage.descriptionAr, descriptionEn: stage.descriptionAr,
    priority: priority(stage), waiting: stage.recordedStatus !== 'action-required', dueDate: stage.dueAt };
}
module.exports = { STAGES, STATES, isPostAdmissionEligible, postAdmissionStages, postAdmissionNextAction };
