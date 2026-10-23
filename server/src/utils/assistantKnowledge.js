const catalog = require('../knowledge/assistantKnowledge.json');
const fs = require('node:fs');
const crypto = require('node:crypto');
let verified = false;
try {
  const snapshot = require('../knowledge/assistantSourceSnapshot.json');
  verified = snapshot.version === catalog.version && snapshot.catalogSHA256 ===
    crypto.createHash('sha256').update(fs.readFileSync(require.resolve('../knowledge/assistantKnowledge.json'))).digest('hex');
} catch { /* An unreviewed/missing knowledge artifact fails closed. */ }
const normalize = value => String(value).normalize('NFKC').toLowerCase()
  .replace(/[\u064b-\u065f\u0670\u0640\u200b-\u200f\u202a-\u202e\u2066-\u2069]/g, '')
  .replace(/[أإآ]/g, 'ا').replace(/ى/g, 'ي').replace(/ة/g, 'ه')
  .replace(/streack/g, 'streak').replace(/notifcations/g, 'notifications')
  .replace(/documants/g, 'documents').replace(/[^\p{L}\p{N}\s]/gu, ' ').replace(/\s+/g, ' ').trim();
const entries = (verified ? catalog.entries : []).map(entry => ({
  ...entry,
  source: entry.sources.filter(s => s.startsWith('mobile:lib/screens/')).map(s => s.slice(19)).join(';'),
  match: entry.pattern ? new RegExp(entry.pattern, 'i') : null,
  terms: entry.aliases.map(normalize),
  ar: `${entry.location.ar}\n${entry.steps.ar.map((s, i) => `${i + 1}. ${s}`).join('\n')}\n${entry.restrictions.ar}`,
  en: `${entry.location.en}\n${entry.steps.en.map((s, i) => `${i + 1}. ${s}`).join('\n')}\n${entry.restrictions.en}`,
}));
const byId = new Map(entries.map(entry=>[entry.id,entry]));
const tokenIndex = new Map();
const tokens = text => normalize(text).split(' ').flatMap(raw=>{
  const term=raw.replace(/^[وفبلك]?ال/,'');
  return /^[\u0600-\u06ff]+$/.test(term)&&term.length>4 ? [term,term.replace(/[هي]$/,'')] : [term];
});
for(const entry of entries) for(const term of entry.terms) for(const token of tokens(term)) {
  if(token.length<2)continue;
  if(!tokenIndex.has(token))tokenIndex.set(token,new Set());
  tokenIndex.get(token).add(entry.id);
}
const patternIds=entries.filter(e=>e.match).map(e=>e.id);
const screens = Object.freeze({
  home: ['الرئيسية', 'Home'], journey: ['رحلتي', 'My Journey'], explore: ['الاستكشاف', 'Explore'],
  services: ['الخدمات', 'Services'], community: ['مجتمع الطلاب', 'Student Community'],
  account: ['حسابي', 'My Account'], assistant: ['المساعد', 'Assistant'],
  documents: ['مستنداتي', 'My Documents'], applications: ['طلباتي', 'My Applications'],
  passport: ['جواز السفر', 'Passport'], settings: ['الإعدادات', 'Settings'],
  notifications: ['الإشعارات', 'Notifications'], game: ['الغمّازة', 'The Winker'],
});
function validateContext(body = {}) {
  const raw = body.context && typeof body.context === 'object' && !Array.isArray(body.context) ? body.context : {};
  const screen = raw.screen ?? body.screen;
  return {
    screen: typeof screen === 'string' && Object.hasOwn(screens, screen) ? screen : null,
    language: ['ar', 'en'].includes(raw.language) ? raw.language : null,
    appVersion: typeof raw.appVersion === 'string' && /^\d+\.\d+\.\d+(?:\+\d+)?$/.test(raw.appVersion) && raw.appVersion.length < 32 ? raw.appVersion : null,
    knowledgeVersion: typeof raw.knowledgeVersion === 'string' && raw.knowledgeVersion.length < 40 ? raw.knowledgeVersion : null,
    // Client flags are advisory only. They cannot enable a backend operation,
    // expand role access, or make an unavailable feature available.
    englishEnabled: raw.flags?.englishEnabled === true,
  };
}
function retrieve(message, { role = 'student', context = {} } = {}) {
  const text = normalize(message);
  const ids=new Set(patternIds);
  for(const token of tokens(text))for(const id of tokenIndex.get(token)||[])ids.add(id);
  const eligible = [...ids].map(id=>byId.get(id)).filter(e => e.reviewed && e.roles.includes(role));
  const ranked = eligible.map(entry => ({ entry,
    score: entry.terms.reduce((score, term) => text.includes(term) ? Math.max(score, term.split(' ').length * 10 + term.length) : score, 0)
      || (entry.match?.test(message) || entry.match?.test(text) ? 1 : 0),
  })).filter(row => row.score > 0).sort((a, b) => b.score - a.score);
  if (ranked.length) return ranked.filter(r => r.score === ranked[0].score).slice(0, 4).map(r => r.entry);
  if (/^(where do i tap|where do i go|how do i do it|what next|وين اضغط|وين اكبس|وين اروح|شو اعمل|كيف اعملها)$/.test(text)) {
    const id = ({ documents: 'documents', passport: 'passport', applications: 'applications',
      settings: 'account', account: 'profile', journey: 'journey', community: 'community',
      services: 'services', notifications: 'notifications', game: 'game', explore: 'catalog' })[context.screen];
    const entry=byId.get(id);
    return entry?.reviewed&&entry.roles.includes(role)?[entry]:[];
  }
  return [];
}
function answer(entry, context, ar) {
  const language=ar?'ar':'en';
  const steps=entry.screenHelp?.[context.screen]?.[language];
  return steps ? `${screens[context.screen][ar?0:1]}\n${steps.map((step,i)=>`${i+1}. ${step}`).join('\n')}\n${entry.restrictions[language]}` : entry[language];
}
// Summaries and details come only from the same reviewed record, never a model.
function presentation(entry, context, ar) {
  const language=ar?'ar':'en';
  const full=answer(entry,context,ar);
  const steps=entry.screenHelp?.[context.screen]?.[language] || entry.steps[language];
  const sentences=steps[0].match(/[^.!?؟]+[.!?؟]?/g) || [steps[0]];
  const first=sentences[0].trim();
  const caution=steps.flatMap(step=>step.match(/[^.!?؟]+[.!?؟]?/g)||[step])
    .map(s=>s.trim()).find(s=>s!==first && /cannot|never |do not |لا (?:ترسل|يمكن|أستطيع|استطيع)/i.test(s));
  const generic=/^(المعلومات حسب ما يعرضه حسابك|تحتاج اتصالًا وصلاحيات حسابك|Availability depends on your account|Requires connectivity and your account permissions)/.test(entry.restrictions[language]);
  const content=[entry.screenHelp?.[context.screen] ? screens[context.screen][ar?0:1] : entry.location[language],first,...(caution?[caution]:[]),...(generic?[]:[entry.restrictions[language]])].join('\n');
  const additional=steps.flatMap(step=>step.match(/[^.!?\u061f]+[.!?\u061f]?/g)||[step])
    .map(s=>s.trim()).some(s=>s!==first && s!==caution);
  return {content,details:additional?full:''};
}
function followup(message, previous, role, context) {
  const text=normalize(message);
  if(!/^(طيب )?(وين الزر|وين اضغط|وين اكبس|مش ظاهر عندي|مش لاقيه|ما ظهر|where is the button|i cant see it|i cannot see it|what next)$/.test(text))return null;
  if(previous?.knowledgeVersion!==catalog.version || (context.knowledgeVersion && context.knowledgeVersion!==catalog.version))return null;
  const entry=byId.get(previous.topicId);
  return entry?.reviewed && entry.roles.includes(role)?entry:null;
}
module.exports = { presentation, followup, catalog, entries, normalize, screens, validateContext, retrieve, verified, answer };
