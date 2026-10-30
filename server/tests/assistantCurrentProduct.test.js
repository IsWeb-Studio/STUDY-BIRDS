const {test}=require('node:test');
const assert=require('node:assert/strict');
const k=require('../src/utils/assistantKnowledge');
const scope=require('../src/utils/assistantScope');
test('current product questions retrieve specific reviewed help in both languages',()=>{
 for(const [q,id] of [
  ['وين المحظورين','blocked-users'],['كيف اعمل فك الحظر','blocked-users'],
  ['How do I remove someone from my blocked list?','blocked-users'],
  ['Where are recognitions?','recognitions'],['وين الشهادات والاعترافات','recognitions'],
  ['Why is the microphone gone?','voice-disabled'],['وين المايك','voice-disabled'],
  ['How do I earn streak points?','streak'],['كيف اكسب نقاط الستريك','streak'],
  ['منشور جديد','community-posts'],['How do I create a new post?','community-posts'],
  ['منشورات الإدارة','community-admin-posts'],['admin posts','community-admin-posts'],
  ['حساب الناشر','public-profile'],['profile grid','public-profile'],
  ['الكاش','local-cache'],['cached data','local-cache'],
  ['قبل استخدام المساعد','ai-consent'],['ai consent','ai-consent'],
  ['What are my unpaid invoices?','payments'],['Where is the journey button?','home-menu'],
 ]){
  const result=scope.classify(q,{role:'student'});
  assert.equal(result.kind,'help',q);
  assert.equal(result.candidates[0].id,id,q);
  assert.equal(result.candidates.length,1,q);
 }
});
test('current answers explain real navigation, required text, optional image and streak rules',()=>{
 const get=id=>k.entries.find(e=>e.id===id);
 assert.match(get('journey').en,/menu beside notifications/i);
 assert.doesNotMatch(get('journey').en,/Bottom navigation/);
 assert.doesNotMatch(get('services').en,/Bottom navigation/);
 assert.match(get('community-posts').en,/text marked Required/);
 assert.match(get('community-posts').en,/image are optional/);
 assert.match(get('streak').en,/36 hours/);
 assert.match(get('streak').en,/100 points/);
 assert.match(get('streak').en,/at least two real players/);
 assert.doesNotMatch(get('streak').en,/longest streak|recent activity/);
 assert.match(get('public-profile').en,/diary section is hidden/);
 assert.match(get('voice-disabled').en,/removed/);
 assert.match(get('payments').en,/does not read your balance/);
});
test('content revision is separate from compatible protocol and stale followups are rejected',()=>{
 assert.equal(k.catalog.revision,'2026.10.30.1');
 assert.equal(k.catalog.version,'2026.10.23.3');
 const previous={topicId:'passport',knowledgeVersion:k.catalog.version,knowledgeRevision:'old'};
 assert.equal(k.followup('وين الزر',previous,'student',{}),null);
 assert.equal(k.followup('وين الزر',{...previous,knowledgeRevision:k.catalog.revision},'student',{}).id,'passport');
 for(const screen of ['payments','support','profile','universities','programs','security']){
  assert.equal(k.validateContext({context:{screen}}).screen,screen);
  assert.equal(scope.classify('Where do I tap',{context:{screen}}).kind,'help',screen);
 }
});
