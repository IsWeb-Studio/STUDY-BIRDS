// Assembles the student home screen (PRD 9, 10, 11, 96, 97, 98) from records
// the overview controller already scoped to the signed-in student. Read-only.
const { applicationStatusInfo, documentStatusInfo } = require('../constants/statusCatalog');
const { isPostAdmissionEligible } = require('./postAdmissionJourney');

const DAY = 24 * 60 * 60 * 1000;
const id = value => String(value?._id || value || '');
const state = app => (app.status === 'rejected' ? 'rejected' : app.detailedStatus || app.status);
const CLOSED = new Set(['rejected', 'completed']);
// Lifecycle order used to pick the application that best represents the journey.
const ORDER = ['draft', 'documents-missing', 'ready-to-apply', 'submitted', 'under-review', 'additional-documents-required',
  'conditional-admission', 'payment-required', 'payment-verification', 'accepted', 'final-admission', 'visa-preparation', 'completed'];
const DOCUMENT_ACTIONS = new Set(['document-correction', 'documents-required', 'additional-document-request']);
const { documentLabel } = require('../constants/documentTypes');
const VISA_LABELS = {
  'not-started': ['لم تبدأ', 'Not started'], 'preparing-documents': ['تجهيز المستندات', 'Preparing documents'],
  ready: ['جاهز للتقديم', 'Ready to submit'], submitted: ['مقدّم للسفارة', 'Submitted'], 'under-review': ['قيد مراجعة السفارة', 'Under embassy review'],
  approved: ['صدرت التأشيرة', 'Approved'], rejected: ['مرفوضة', 'Rejected'],
};
const DEPARTURE_WINDOW_DAYS = 30;

// Shortcuts shown on the home screen (PRD 11). Served as data so they can
// later be customised without an app release.
const QUICK_ACTIONS = [
  ['programs', 'البرامج', 'Programs'], ['universities', 'الجامعات', 'Universities'], ['applications', 'طلباتي', 'My applications'],
  ['upload-document', 'رفع مستند', 'Upload document'], ['consultation', 'حجز استشارة', 'Book consultation'], ['visa', 'التأشيرة', 'Visa'],
  ['travel', 'السفر والوصول', 'Travel'], ['accommodation', 'السكن', 'Accommodation'], ['payments', 'المدفوعات', 'Payments'],
  ['support', 'الدعم', 'Support'], ['bird-ai', 'COVEY AI', 'COVEY AI'],
].map(([key, labelAr, labelEn]) => ({ key, labelAr, labelEn, destination: key }));

// The context card (PRD 96): one headline that changes with where the student is.
const CONTEXTS = {
  start: ['ابدأ رحلتك', 'Start your journey', 'اختر دولتك وتخصصك، ونحن نرافقك حتى تبدأ الدراسة.', 'Pick your country and program; we will guide you until classes start.', 'catalog'],
  documents: ['أكمل أوراقك المطلوبة', 'Complete your documents', 'هناك مستندات مطلوبة منك حتى يستمر طلبك.', 'Some documents are needed from you so your application can move on.', 'documents'],
  'in-progress': ['طلبك قيد المعالجة', 'Application in progress', 'فريقنا والجامعة يعملان على طلبك.', 'Our team and the university are working on your application.', 'applications'],
  visa: ['خطوتك القادمة: التأشيرة', 'Next step: Visa', 'مبروك القبول! الآن نجهز معك ملف التأشيرة.', 'Congratulations on your admission! Now we prepare your visa file together.', 'journey'],
  travel: ['رتّب سفرك ووصولك', 'Plan your travel and arrival', 'صدرت التأشيرة. حدد موعد وصولك لنرتب الاستقبال والسكن.', 'Your visa is ready. Set your arrival date so we can arrange pickup and housing.', 'travel'],
  'confirm-arrival': ['هل وصلت؟', 'Have you arrived?', 'مرّ موعد وصولك المسجل. أكّد وصولك أو حدّث موعد السفر حتى نرتب خطوتك التالية.', 'Your planned arrival date has passed. Confirm your arrival or update your travel date so we can arrange your next step.', 'travel'],
  departure: ['جهّز حقائبك للسفر', 'Get ready for departure', 'موعد سفرك يقترب. راجع قائمة ما قبل السفر وتفاصيل الاستقبال.', 'Your trip is close. Review the pre-departure checklist and pickup details.', 'travel'],
  registration: ['استكمل تسجيلك الجامعي', 'Complete university registration', 'وصلت بالسلامة! الخطوة التالية تسجيلك في الجامعة.', 'Welcome! Your next step is registering at the university.', 'journey'],
  settled: ['رحلتك مكتملة', 'You are all set', 'أنهيت التسجيل. فريقنا معك للإقامة والدعم المستمر.', 'Registration is done. Our team stays with you for residence and ongoing support.', 'journey'],
};

const daysUntil = (date, now) => Math.ceil((new Date(date).getTime() - now.getTime()) / DAY);
const valid = date => date && Number.isFinite(new Date(date).getTime());

function pickMainApplication(applications) {
  const rank = app => ORDER.indexOf(state(app));
  const active = applications.filter(app => !CLOSED.has(state(app)));
  const pool = active.length ? active : applications;
  return [...pool].sort((a, b) => rank(b) - rank(a) || new Date(b.createdAt || 0) - new Date(a.createdAt || 0))[0] || null;
}

function importantDates({ applications, invoices, arrivals, bookings, consultations, documents }, now) {
  const dates = [];
  const add = (key, date, titleAr, titleEn, destination, entityId, overdueAllowed = false) => {
    if (!valid(date)) return;
    const days = daysUntil(date, now);
    if (days < 0 && !overdueAllowed) return;
    dates.push({ key, date: new Date(date).toISOString(), daysLeft: days, overdue: days < 0, critical: days <= 7, titleAr, titleEn, destination, entityId: id(entityId) });
  };
  for (const app of applications.filter(item => !CLOSED.has(state(item)))) {
    const program = app.program?.title || '';
    add('visa-appointment', app.visaCase?.appointment?.date, 'موعد السفارة والتأشيرة', 'Embassy / visa appointment', 'journey', app);
    if (['draft', 'documents-missing', 'ready-to-apply'].includes(state(app))) {
      add('application-deadline', app.program?.applicationDeadline, `آخر موعد للتقديم: ${program}`, `Application deadline: ${program}`, 'applications', app);
    }
    add('studies-start', app.studiesStartAt, 'بدء الدراسة', 'Classes start', 'journey', app);
    for (const [stage, item] of Object.entries(app.postAdmission || {})) {
      if (item?.dueAt && !['completed', 'not-required'].includes(item.status)) {
        const titles = { visa: 'التأشيرة', travel: 'ترتيبات السفر', housing: 'السكن', arrival: 'الوصول', registration: 'التسجيل في الجامعة', residence: 'الإقامة' };
        add(`stage-${stage}`, item.dueAt, `موعد مرحلة: ${titles[stage] || stage}`, `Stage deadline: ${stage}`, 'journey', app, true);
      }
    }
  }
  for (const invoice of invoices.filter(item => ['unpaid', 'rejected'].includes(item.status))) {
    add('payment-due', invoice.dueDate, `استحقاق دفعة: ${invoice.description || ''}`.trim(), `Payment due: ${invoice.description || ''}`.trim(), 'payments', invoice, true);
  }
  for (const arrival of arrivals.filter(item => item.status !== 'draft')) {
    add('arrival', arrival.arrivalDate, 'موعد السفر والوصول', 'Travel and arrival', 'travel', arrival);
  }
  for (const booking of bookings.filter(item => ['pending', 'confirmed'].includes(item.status))) {
    add('housing-start', booking.moveInDate, 'بدء السكن', 'Housing move-in', 'accommodation', booking);
  }
  for (const booking of consultations) add('consultation', booking.startsAt, 'موعد استشارتك', 'Your consultation', 'consultation', booking);
  for (const document of documents.filter(item => item.detailedStatus === 'approved' && valid(item.expiresAt))) {
    if (daysUntil(document.expiresAt, now) <= 60) {
      add('document-expiry', document.expiresAt, `انتهاء صلاحية ${documentLabel(document.type)}`, `Document expires: ${document.type}`, 'documents', document);
    }
  }
  return dates.sort((a, b) => Number(b.overdue) - Number(a.overdue) || new Date(a.date) - new Date(b.date)).slice(0, 8);
}

function homeContext({ applications, arrivals, nextAction, main }, now) {
  if (!applications.length) return 'start';
  if (nextAction && DOCUMENT_ACTIONS.has(nextAction.code)) return 'documents';
  const arrival = [...arrivals].filter(item => valid(item.arrivalDate) && item.status !== 'draft')
    .sort((a, b) => new Date(b.arrivalDate) - new Date(a.arrivalDate))[0];
  // Arrival counts only once confirmed (request completed or pickup reached);
  // a planned date that has passed may mean a postponed trip.
  const arrived = arrival && (arrival.status === 'completed' || ['arrived', 'completed'].includes(arrival.pickup?.status));
  const registration = main?.postAdmission?.registration?.status;
  if (arrived) return ['completed', 'not-required'].includes(registration) ? 'settled' : 'registration';
  if (arrival && new Date(arrival.arrivalDate) <= now) return 'confirm-arrival';
  if (arrival && daysUntil(arrival.arrivalDate, now) <= DEPARTURE_WINDOW_DAYS) return 'departure';
  if (main && isPostAdmissionEligible(main)) {
    const visa = main.visaCase?.status || 'not-started';
    const visaStage = main.postAdmission?.visa?.status;
    return visa === 'approved' || ['completed', 'not-required'].includes(visaStage) ? 'travel' : 'visa';
  }
  return 'in-progress';
}

function progressPercent(journey) {
  const stages = (journey?.stages || []).filter(stage => stage.status !== 'not-required');
  if (!stages.length) return 0;
  const done = stages.filter(stage => stage.status === 'completed').length;
  return Math.round((done / stages.length) * 100);
}

function studentHome({ user, applications = [], documents = [], invoices = [], arrivals = [], bookings = [], consultations = [],
  openTickets = 0, unreadNotifications = 0, latestNotification = null, nextAction = null, journeys = [] }, now = new Date()) {
  const main = pickMainApplication(applications);
  const mainInfo = main ? applicationStatusInfo(main) : null;
  const journey = main ? journeys.find(item => item.applicationId === id(main)) : null;
  const university = main?.program?.university;
  const contextKey = homeContext({ applications, arrivals, nextAction, main }, now);
  const [titleAr, titleEn, descriptionAr, descriptionEn, destination] = CONTEXTS[contextKey];

  const docInfos = documents.map(doc => ({ doc, info: documentStatusInfo(doc) }));
  const unpaid = invoices.filter(item => ['unpaid', 'rejected'].includes(item.status));
  const nextDue = unpaid.filter(item => valid(item.dueDate)).sort((a, b) => new Date(a.dueDate) - new Date(b.dueDate))[0];
  const arrival = [...arrivals].filter(item => item.status !== 'draft').sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0))[0];
  const housing = bookings.filter(item => ['pending', 'confirmed'].includes(item.status)).sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0))[0];
  const visaStatus = main?.visaCase?.status;

  // Recent activity: application status changes and document reviews, newest first.
  const activity = [
    ...applications.flatMap(app => (app.statusTimeline || []).map(entry => {
      const info = applicationStatusInfo({ detailedStatus: entry.status });
      return { at: entry.changedAt, kind: 'application', titleAr: `${app.program?.title || 'طلبك'}: ${info.ar.label}`, titleEn: `${app.program?.title || 'Application'}: ${info.en.label}`, destination: 'applications', entityId: id(app) };
    })),
    ...docInfos.filter(({ doc }) => valid(doc.reviewedAt)).map(({ doc, info }) => ({
      at: doc.reviewedAt, kind: 'document', titleAr: `${documentLabel(doc.type)}: ${info.ar.label}`, titleEn: `${doc.type}: ${info.en.label}`, destination: 'documents', entityId: id(doc),
    })),
  ].filter(item => valid(item.at)).sort((a, b) => new Date(b.at) - new Date(a.at)).slice(0, 6);

  return {
    greeting: { name: user?.name || '' },
    context: { key: contextKey, titleAr, titleEn, descriptionAr, descriptionEn,
      // The documents context points at the exact item needing action.
      destination: contextKey === 'documents' && nextAction ? nextAction.destination : destination },
    statusCard: {
      statusInfo: mainInfo,
      labelAr: mainInfo?.ar.label || titleAr, labelEn: mainInfo?.en.label || titleEn,
      nextStepAr: nextAction?.titleAr || '', nextStepEn: nextAction?.titleEn || '',
      nextStepDescriptionAr: nextAction?.descriptionAr || '', nextStepDescriptionEn: nextAction?.descriptionEn || '',
      destination: nextAction?.destination || destination, waiting: Boolean(nextAction?.waiting),
    },
    currentJourney: main ? {
      applicationId: id(main), country: university?.country?.name || '', city: university?.city || '',
      university: university?.name || '', program: main.program?.title || '',
    } : null,
    progressPercent: progressPercent(journey),
    importantDates: importantDates({ applications, invoices, arrivals, bookings, consultations, documents }, now),
    sections: {
      application: main ? { applicationId: id(main), program: main.program?.title || '', statusInfo: mainInfo } : null,
      documents: {
        total: documents.length,
        approved: docInfos.filter(({ info }) => info.status === 'approved').length,
        needsAction: docInfos.filter(({ info }) => ['action', 'danger'].includes(info.tone)).length,
        underReview: docInfos.filter(({ info }) => ['uploaded', 'under-review'].includes(info.status)).length,
      },
      admission: mainInfo ? { statusInfo: mainInfo } : null,
      visa: main && isPostAdmissionEligible(main) ? {
        status: visaStatus || 'not-started', labelAr: VISA_LABELS[visaStatus || 'not-started']?.[0] || '', labelEn: VISA_LABELS[visaStatus || 'not-started']?.[1] || '',
        appointmentDate: main.visaCase?.appointment?.date || null,
      } : null,
      travel: arrival || housing ? {
        arrivalDate: arrival?.arrivalDate || null, arrivalStatus: arrival?.status || null, pickupStatus: arrival?.pickup?.status || null,
        housingStatus: housing?.status || null, moveInDate: housing?.moveInDate || null,
      } : null,
      payments: { unpaid: unpaid.length, overdue: unpaid.filter(item => valid(item.dueDate) && new Date(item.dueDate) < now).length,
        nextDueDate: nextDue?.dueDate || null, nextDueAmount: nextDue?.amount ?? null },
      support: { openTickets },
      notifications: { unread: unreadNotifications, latest: latestNotification ? { title: latestNotification.title, message: latestNotification.message, createdAt: latestNotification.createdAt } : null },
      recentActivity: activity,
    },
    quickActions: QUICK_ACTIONS,
  };
}

module.exports = { studentHome, importantDates, homeContext, QUICK_ACTIONS, VISA_LABELS };
