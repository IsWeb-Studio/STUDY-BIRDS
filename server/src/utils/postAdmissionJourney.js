const { applicationStatusInfo } = require('../constants/statusCatalog');
const STAGES = Object.freeze({
  visa: ['التأشيرة', 'Visa'],
  travel: ['ترتيبات السفر', 'Travel arrangements'],
  housing: ['السكن', 'Accommodation'],
  arrival: ['الوصول والاستقبال', 'Arrival and pickup'],
  registration: ['التسجيل في الجامعة', 'University registration'],
  residence: ['الإقامة والدعم المستمر', 'Residence and ongoing support'],
});
// University registration is a separate post-arrival milestone, not a travel prerequisite.
const TRAVEL_SUB_STAGES = ['housing', 'arrival', 'residence'];
const STATES = ['not-started', 'in-progress', 'action-required', 'waiting-team', 'waiting-university', 'completed', 'not-required'];
function isPostAdmissionEligible(app) {
  if (['rejected', 'file-completed-rejected', 'file-completed-accepted'].includes(app.status)) return false;
  return ['accepted', 'final-admission', 'visa-preparation'].includes(applicationStatusInfo(app).status);
}
function postAdmissionStages(app, now = new Date()) {
  if (!isPostAdmissionEligible(app) && !Object.values(app.postAdmission || {}).some(item => item?.updatedAt)) return [];
  return Object.entries(STAGES).map(([key, [titleAr, titleEn]]) => {
    const item = app.postAdmission?.[key] || {};
    let state = item.status || 'not-started';
    let extra = {};
    if (key === 'travel') {
      const subStatuses = TRAVEL_SUB_STAGES.map(k => (app.postAdmission?.[k] || {}).status || 'not-started');
      const completedSubCount = subStatuses.filter(s => ['completed', 'not-required'].includes(s)).length;
      const activeSubCount = subStatuses.filter(s => !['not-started'].includes(s)).length;
      const totalSubCount = TRAVEL_SUB_STAGES.length;
      // derive state from sub-stages; fallback to explicit travel status if nothing started yet
      if (completedSubCount === totalSubCount) state = 'completed';
      else if (activeSubCount > 0 && !['completed', 'not-required'].includes(state)) state = 'in-progress';
      // else keep the explicitly set travel status
      extra = ['completed', 'not-required'].includes(item.status) ? {} : { completedSubCount, totalSubCount };
    }
    const finished = ['completed', 'not-required'].includes(state);
    const overdue = !finished && Boolean(item.dueAt && new Date(item.dueAt) < now);
    return { key, titleAr, titleEn, status: overdue ? 'overdue' : state, recordedStatus: state,
      descriptionAr: item.note || (key === 'registration'
        ? 'التسجيل النهائي في الجامعة خطوة مستقلة بعد القبول. يؤكد الفريق اكتمالها بعد إنهاء إجراءات التسجيل؛ قبول الطلب وحده لا يعني اكتمال التسجيل.'
        : 'لم يحدد الفريق إجراءات هذه المرحلة بعد. تواصل مع مسؤول متابعتك.'),
      dueAt: item.dueAt || null, reference: item.reference || '',
      destination: 'support', updatedAt: item.updatedAt || null, ...extra };
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
