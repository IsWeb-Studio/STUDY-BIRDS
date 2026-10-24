const { test } = require('node:test');
const assert = require('node:assert/strict');
const router = require('../src/routes/storyRoutes');
const {
  COMMUNITY_ROLES,
  audienceFilter,
  publicationAudienceFor,
} = require('../src/utils/storyAudience');

function runAuthorization(middleware, role) {
  let status = 200;
  let nextCalled = false;
  let thrown;
  const response = { status(value) { status = value; return this; } };
  try {
    middleware({ user: { role } }, response, () => { nextCalled = true; });
  } catch (error) {
    thrown = error;
  }
  return { status, nextCalled, thrown };
}

function publisherAuthorization(path) {
  const layer = router.stack.find(item => item.route?.path === path && item.route.methods.post);
  assert.ok(layer, `POST ${path} exists`);
  return layer.route.stack[0].handle;
}

test('community story routes allow supported roles and exclude agents', () => {
  const communityAuthorization = router.stack[1].handle;
  for (const role of COMMUNITY_ROLES) {
    const result = runAuthorization(communityAuthorization, role);
    assert.equal(result.status, 200, `${role} can access community stories`);
    assert.equal(result.nextCalled, true);
    assert.equal(result.thrown, undefined);
  }
  const denied = runAuthorization(communityAuthorization, 'agent');
  assert.equal(denied.status, 403);
  assert.equal(denied.nextCalled, false);
  assert.ok(denied.thrown);
});

test('admins can publish story text and media; agents remain denied', () => {
  for (const path of ['/image', '/video', '/']) {
    const authorizePublisher = publisherAuthorization(path);
    const admin = runAuthorization(authorizePublisher, 'admin');
    assert.equal(admin.status, 200, `admin can use POST ${path}`);
    assert.equal(admin.nextCalled, true);
    assert.equal(admin.thrown, undefined);

    const agent = runAuthorization(authorizePublisher, 'agent');
    assert.equal(agent.status, 403, `agent cannot use POST ${path}`);
    assert.equal(agent.nextCalled, false);
    assert.ok(agent.thrown);
  }
});

test('admin publication defaults to students and rejects invalid or spoofed audiences', () => {
  const body = { text: 'Official update', operationId: 'story-op-12345678' };
  assert.equal(publicationAudienceFor('admin', body), 'students');
  assert.equal(publicationAudienceFor('admin', { ...body, audience: 'employees' }), 'employees');
  assert.equal(publicationAudienceFor('admin', { ...body, audience: 'agents' }), null);
  assert.equal(publicationAudienceFor('student', body), 'allEligible');
  assert.equal(publicationAudienceFor('student', { ...body, audience: 'employees' }), null);
  assert.equal(publicationAudienceFor('agent', body), null);
});

test('story feeds are audience-scoped and old stories remain visible', () => {
  const student = audienceFilter({ _id: 'student-id', role: 'student' });
  assert.ok(student.$or.some(item => item.audience === 'students'));
  assert.ok(student.$or.some(item => item.audience === 'allEligible'));
  assert.ok(student.$or.some(item => item.audience?.$exists === false));

  const admin = audienceFilter({ _id: 'admin-id', role: 'admin' });
  assert.ok(admin.$or.some(item => item.author === 'admin-id'));
  assert.ok(admin.$or.some(item => item.audience === 'allEligible'));
  assert.equal(audienceFilter({ _id: 'agent-id', role: 'agent' })._id, null);
});
