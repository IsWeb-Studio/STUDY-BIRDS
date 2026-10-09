const { test } = require('node:test');
const assert = require('node:assert/strict');
const { studentJourneys } = require('../src/utils/studentJourney');
const app = { _id: 'a', program: { title: 'Medicine' }, status: 'under-review', requiredDocumentTypes: ['passport'], documents: ['d'] };
const doc = { _id: 'd', type: 'passport', status: 'pending', detailedStatus: 'under-review' };
test('attached documents await review; no invoice is not paid; paid invoice does not grant admission', () => {
 const [j] = studentJourneys({ applications: [app], documents: [doc] });
 assert.equal(j.stages[0].status, 'waiting'); assert.equal(j.stages[1].status, 'waiting'); assert.equal(j.stages[2].status, 'not-issued');
 const [paid] = studentJourneys({ applications: [app], documents: [{...doc,status:'verified',detailedStatus:'approved'}], invoices:[{application:'a',status:'paid',amount:100}] });
 assert.equal(paid.stages[0].status,'completed'); assert.equal(paid.stages[2].status,'completed'); assert.equal(paid.stages[1].status,'waiting');
});
test('files and invoices cannot complete or delay another application', () => {
 const rows = studentJourneys({ applications: [app,{...app,_id:'b',documents:[]}], documents:[doc], invoices:[{application:'b',status:'unpaid',dueDate:'2020-01-01'}] });
 assert.equal(rows[0].stages[2].status,'not-issued'); assert.equal(rows[1].stages[2].status,'overdue'); assert.deepEqual(rows[1].missingDocumentTypes,['passport']);
 assert.equal(rows[1].nextAction.code,'payment-required');
});
test('revision and additional requests reopen requirements even after earlier approval', () => {
 const [j] = studentJourneys({ applications:[{...app, documentRequests:[{status:'requested',note:'Updated passport'}]}],documents:[{...doc,status:'verified'}] });
 assert.equal(j.stages[0].status,'action-required'); assert.equal(j.nextAction.code,'additional-document-request');
 const [expired] = studentJourneys({applications:[app],documents:[{...doc,status:'verified',detailedStatus:'expired'}]});
 assert.equal(expired.stages[0].status,'action-required');
});
test('rejected applications remain archived with no active next action', () => {
 const [j] = studentJourneys({ applications:[{...app,status:'rejected',detailedStatus:'final-admission'}] });
 assert.equal(j.closed,true); assert.equal(j.stages[1].status,'rejected'); assert.equal(j.nextAction,null);
});
test('empty requirements and payment review are represented explicitly', () => {
 const [j] = studentJourneys({applications:[{...app,requiredDocumentTypes:[]}],invoices:[{application:'a',status:'pending-confirmation'}]});
 assert.equal(j.stages[0].status,'completed'); assert.equal(j.stages[2].status,'waiting');
 assert.deepEqual(studentJourneys({}),[]);
});
