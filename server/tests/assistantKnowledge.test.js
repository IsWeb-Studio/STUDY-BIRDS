const {test}=require('node:test');
const assert=require('node:assert/strict');
const knowledge=require('../src/utils/assistantKnowledge');
const scope=require('../src/utils/assistantScope');
const {compare,affectedEntries}=require('../scripts/assistant-knowledge-tools.cjs');
test('every reviewed feature category has retrievable help, source references and bilingual steps',()=>{
  const questions={applications:'How do I apply?',documents:'How do I upload documents?',catalog:'university catalog',account:'login',notifications:'notifications',community:'community'};
  questions.support='support';
  for(const entry of knowledge.catalog.entries){
    assert.ok(entry.reviewed && entry.sources.length && entry.steps.ar.length && entry.steps.en.length,entry.id);
    const question=questions[entry.id]||entry.aliases[0];
    assert.ok(question,entry.id);
    const result=scope.classify(question,{role:entry.roles[0]});
    assert.equal(result.kind,'help',`${entry.id}: ${question}`);
    assert.ok(result.candidates.some(e=>e.id===entry.id),entry.id);
  }
});
test('colloquial Arabic, spelling variation and document-screen context',()=>{
  for(const [question,id] of [['وين اشوف الستريك','streak'],['ارفع جوازي','passport'],['مش راضي يرفع','upload-failure'],['streack','streak'],['documants','documents'],['notifcations','notifications'],['باسوورد','password']]){
    assert.ok(scope.classify(question).candidates?.some(e=>e.id===id),question);
  }
  assert.equal(scope.classify('وين اضغط؟',{context:{screen:'documents'}}).candidates[0].id,'documents');
});
test('roles and client context cannot grant restricted knowledge or record access',()=>{
  assert.ok(!knowledge.retrieve('admin',{role:'student'}).some(e=>e.id==='staff'));
  assert.equal(knowledge.retrieve('admin',{role:'admin'})[0].id,'staff');
  const context=knowledge.validateContext({context:{screen:'../../admin',role:'admin',language:'xx',appVersion:'<script>',flags:{englishEnabled:'true'}}});
  assert.equal(context.screen,null);assert.equal(context.language,null);assert.equal(context.appVersion,null);assert.equal(context.englishEnabled,false);assert.equal(context.role,undefined);
  assert.notEqual(scope.classify('What is the status of my support ticket?').kind,'personal');
  assert.notEqual(scope.classify('حالة طلبي لخدمة السكن').kind,'personal');
});
test('disabled features and incompatible knowledge versions cannot invent navigation',()=>{
  const theme=scope.classify('dark mode').candidates[0];
  assert.equal(theme.availability,'unavailable');assert.equal(theme.action,null);
  assert.match(theme.en,/no standalone theme toggle/);
  const stale=scope.classify('upload documents',{context:{knowledgeVersion:'old-unreviewed'}});
  assert.notEqual(stale.kind,'help');assert.equal(stale.candidates,undefined);
  assert.equal(scope.validateSelection('{"id":"imaginary-screen"}',knowledge.entries),null);
});
test('build-time change detection flags changed, removed and new sources plus affected help',()=>{
  const expected=[{path:'mobile:lib/screens/a.dart',sha256:'one'},{path:'gone',sha256:'old'}];
  const current=[{path:'mobile:lib/screens/a.dart',sha256:'two'},{path:'new',sha256:'new'}];
  const changed=compare(expected,current);
  assert.deepEqual(new Set(changed),new Set(['mobile:lib/screens/a.dart','gone','new']));
  assert.deepEqual(affectedEntries({entries:[{id:'a',sources:['mobile:lib/screens/a.dart']},{id:'b',sources:['same']}]},changed),['a']);
  assert.deepEqual(compare(current,current),[]);
  assert.deepEqual(affectedEntries({entries:[{id:'a',sources:['route']}]},['controller'],[{path:'route',dependencies:['controller']}]),['a']);
});
