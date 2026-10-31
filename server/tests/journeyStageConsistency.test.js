const { test } = require('node:test');
const assert = require('node:assert/strict');
const { postAdmissionStages } = require('../src/utils/postAdmissionJourney');
const { studentJourneys } = require('../src/utils/studentJourney');
test('finished travel services do not wait for university registration', () => {
  const app = { status: 'accepted', postAdmission: Object.fromEntries(
    ['housing', 'arrival', 'residence'].map(key => [key, { status: 'completed' }])) };
  const stages = postAdmissionStages(app);
  const travel = stages.find(stage => stage.key === 'travel');
  assert.equal(travel.status, 'completed');
  assert.equal(travel.completedSubCount, 3); assert.equal(travel.totalSubCount, 3);
  assert.equal(stages.find(stage => stage.key === 'registration').status, 'not-started');
});
test('explicit staff travel completion is preserved with unselected services', () => {
  const travel = postAdmissionStages({ status: 'accepted', postAdmission: {
    travel: { status: 'completed' }, arrival: { status: 'completed' },
  } }).find(stage => stage.key === 'travel');
  assert.equal(travel.status, 'completed');
  assert.equal(travel.totalSubCount, undefined);
});
test('legacy accepted status matches the application detail and post-admission journey', () => {
  const [journey] = studentJourneys({ applications: [{ _id: 'a', status: 'final-accepted', requiredDocumentTypes: [] }] });
  assert.equal(journey.applicationStatus, 'final-admission');
  assert.equal(journey.stages.find(stage => stage.key === 'admission').status, 'completed');
  assert.ok(journey.stages.find(stage => stage.key === 'registration'));
});
