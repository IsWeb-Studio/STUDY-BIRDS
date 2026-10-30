const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('community posts support eligible authors and staff moderation, keeping hidden content private', async () => {
  process.env.JWT_SECRET = 'community-isolated-test';
  const mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const CommunityPost = require('../src/models/CommunityPost');
    const author = await User.create({ name: 'Author', email: 'author@example.test' });
    const other = await User.create({ name: 'Other', email: 'other@example.test' });
    const moderator = await User.create({ name: 'Moderator', email: 'moderator@example.test', role: 'employee', permissions: ['community'] });
    const outsiderStaff = await User.create({ name: 'Support', email: 'support@example.test', role: 'employee', permissions: ['support'] });
    server = await new Promise(resolve => { const s = require('../src/app').listen(0, '127.0.0.1', () => resolve(s)); });
    const token = user => jwt.sign({ userId: user._id }, process.env.JWT_SECRET);
    async function call(method, endpoint, user, body, expected = 200) {
      const response = await fetch(`http://127.0.0.1:${server.address().port}/api${endpoint}`, { method,
        headers: { 'Content-Type': 'application/json', ...(user ? { Authorization: `Bearer ${token(user)}` } : {}) },
        body: body ? JSON.stringify(body) : undefined });
      const data = await response.json(); assert.equal(response.status, expected, JSON.stringify(data)); return data;
    }

    // Eligible staff can post too; unauthenticated requests remain refused.
    await call('POST', '/community/posts', null, { title: 'T', body: 'B' }, 401);
    const staffPost = await call('POST', '/community/posts', moderator, { title: 'T', body: 'B' }, 201);
    await call('DELETE', `/community/posts/${staffPost._id}`, moderator);
    for (const invalid of [{ title: [], body: 'B' }, { title: 'T', body: '' }, { title: 'x'.repeat(151), body: 'B' }]) {
      await call('POST', '/community/posts', author, invalid, 400);
    }
    const created = await call('POST', '/community/posts', author, { title: 'أفضل جامعات تركيا؟', body: 'حدا يعرف يرشحلي جامعة؟' }, 201);
    assert.equal(created.author.name, 'Author');

    const list = await call('GET', '/community/posts', other);
    const authorFeed = await call('GET', `/community/posts?author=${author._id}`, other);
    assert.equal(authorFeed.length, 1);
    assert.equal(String(authorFeed[0].author._id), String(author._id));
    assert.deepEqual(await call('GET', `/community/posts?author=${moderator._id}`, other), []);
    await call('GET', '/community/posts?author=invalid', other, null, 400);
    await call('GET', `/community/posts?author=${author._id}&mine=1`, other, null, 400);
    assert.equal(list.length, 1);

    // Comments: one from another student, isolation of unrelated post IDs.
    await call('POST', `/community/posts/${created._id}/comments`, other, { body: 'جامعة إسطنبول ممتازة!' }, 201);
    const thread = await call('GET', `/community/posts/${created._id}`, other);
    assert.equal(thread.comments.length, 1);
    assert.equal(thread.comments[0].author.name, 'Other');
    assert.equal((await call('GET', '/community/posts', author))[0].commentCount, 1);

    // A student can delete their own post but not someone else's.
    await call('DELETE', `/community/posts/${created._id}`, other, null, 404);

    // Staff without the 'community' section cannot moderate; the assigned moderator can.
    await call('GET', '/admin/community-posts', outsiderStaff, null, 403);
    await call('PATCH', `/admin/community-posts/${created._id}`, outsiderStaff, { status: 'hidden' }, 403);
    await call('PATCH', `/admin/community-posts/${created._id}`, moderator, { status: 'invented' }, 400);
    const hidden = await call('PATCH', `/admin/community-posts/${created._id}`, moderator, { status: 'hidden', moderationNote: 'رسالة مكررة' });
    assert.equal(hidden.status, 'hidden');

    // Hidden posts disappear from the student feed and can't be opened or commented on.
    assert.equal((await call('GET', '/community/posts', other)).length, 0);
    assert.deepEqual(await call('GET', `/community/posts?author=${author._id}`, other), []);
    await call('GET', `/community/posts/${created._id}`, other, null, 404);
    await call('POST', `/community/posts/${created._id}/comments`, other, { body: 'still here?' }, 404);

    // The moderator's admin view still sees hidden posts, with a note and moderator identity recorded.
    const adminList = await call('GET', '/admin/community-posts', moderator);
    assert.equal(adminList.length, 1);
    assert.equal(adminList[0].moderationNote, 'رسالة مكررة');
    assert.equal(adminList[0].moderatedBy.name, 'Moderator');

    // Un-hiding restores visibility.
    await call('PATCH', `/admin/community-posts/${created._id}`, moderator, { status: 'published' });
    assert.equal((await call('GET', '/community/posts', other)).length, 1);

    // The author can delete their own post; it and its comments disappear.
    await call('DELETE', `/community/posts/${created._id}`, author);
    assert.equal(await CommunityPost.countDocuments(), 0);
    assert.equal((await call('GET', '/community/posts', other)).length, 0);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});

test('community topics and filters, student reports, audited moderation and author notices', async () => {
  process.env.JWT_SECRET = 'community-isolated-test';
  const mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const Country = require('../src/models/Country');
    const University = require('../src/models/University');
    const StudyField = require('../src/models/StudyField');
    const Notification = require('../src/models/Notification');
    const CommunityPost = require('../src/models/CommunityPost');
    const CommunityReport = require('../src/models/CommunityReport');
    const CommunityModerationLog = require('../src/models/CommunityModerationLog');
    const author = await User.create({ name: 'Author', email: 'author@example.test' });
    const reader = await User.create({ name: 'Reader', email: 'reader@example.test' });
    const third = await User.create({ name: 'Third', email: 'third@example.test' });
    const moderator = await User.create({ name: 'Moderator', email: 'moderator@example.test', role: 'employee', permissions: ['community'] });
    const secondModerator = await User.create({ name: 'Second', email: 'second@example.test', role: 'employee', permissions: ['community'] });
    const outsiderStaff = await User.create({ name: 'Support', email: 'support@example.test', role: 'employee', permissions: ['support'] });
    const turkey = await Country.create({ name: 'Turkey', code: 'TR' });
    const university = await University.create({ name: 'Istanbul University', country: turkey._id });
    const medicine = await StudyField.create({ name: 'Medicine' });
    const engineering = await StudyField.create({ name: 'Engineering' });
    server = await new Promise(resolve => { const s = require('../src/app').listen(0, '127.0.0.1', () => resolve(s)); });
    const token = user => jwt.sign({ userId: user._id }, process.env.JWT_SECRET);
    async function call(method, endpoint, user, body, expected = 200) {
      const response = await fetch(`http://127.0.0.1:${server.address().port}/api${endpoint}`, { method,
        headers: { 'Content-Type': 'application/json', ...(user ? { Authorization: `Bearer ${token(user)}` } : {}) },
        body: body ? JSON.stringify(body) : undefined });
      const data = await response.json(); assert.equal(response.status, expected, JSON.stringify(data)); return data;
    }

    // Topics and study fields: invalid values and unknown references are refused.
    await call('POST', '/community/posts', author, { title: 'T', body: 'B', topic: 'politics' }, 400);
    await call('POST', '/community/posts', author, { title: 'T', body: 'B', studyField: String(new mongoose.Types.ObjectId()) }, 400);
    await call('POST', '/community/posts', author, { title: 'T', body: 'B', country: 'not-an-id' }, 400);
    const housing = await call('POST', '/community/posts', author, { title: 'سكن قريب من الجامعة', body: 'أين أجد سكنًا؟', topic: 'housing',
      country: String(turkey._id), university: String(university._id), studyField: String(medicine._id) }, 201);
    assert.equal(housing.topic, 'housing');
    assert.equal(housing.studyField.name, 'Medicine');
    assert.equal(housing.reportCount, undefined);
    const tips = await call('POST', '/community/posts', reader, { title: 'نصيحة للهندسة', body: 'ابدأ بالرياضيات مبكرًا', topic: 'tips', studyField: String(engineering._id) }, 201);
    const untagged = await call('POST', '/community/posts', third, { title: 'سؤال عام', body: 'مرحبا' }, 201);
    assert.equal(untagged.topic, 'other');

    // Filters by topic, study field, country and university.
    assert.deepEqual((await call('GET', '/community/posts?topic=housing', reader)).map(p => p._id), [housing._id]);
    assert.deepEqual((await call('GET', `/community/posts?studyField=${engineering._id}`, reader)).map(p => p._id), [tips._id]);
    assert.deepEqual((await call('GET', `/community/posts?country=${turkey._id}&university=${university._id}`, reader)).map(p => p._id), [housing._id]);
    assert.equal((await call('GET', '/community/posts', reader)).length, 3);
    await call('GET', '/community/posts?topic=politics', reader, null, 400);
    await call('GET', '/community/posts?studyField=bad', reader, null, 400);

    // Reporting: reasons validated, own content refused, one report per student.
    await call('POST', `/community/posts/${housing._id}/report`, author, { reason: 'spam' }, 400);
    await call('POST', `/community/posts/${housing._id}/report`, reader, { reason: 'boring' }, 400);
    await call('POST', `/community/posts/${housing._id}/report`, reader, { reason: 'spam', details: 'إعلان متكرر' }, 201);
    await call('POST', `/community/posts/${housing._id}/report`, reader, { reason: 'abuse' }, 409);
    await call('POST', `/community/posts/${housing._id}/report`, third, { reason: 'misinformation' }, 201);
    const comment = await call('POST', `/community/posts/${tips._id}/comments`, third, { body: 'تعليق مسيء' }, 201);
    await call('POST', `/community/comments/${comment._id}/report`, author, { reason: 'abuse' }, 201);
    await call('POST', `/community/comments/${comment._id}/report`, third, { reason: 'abuse' }, 400);
    await call('POST', `/community/comments/${new mongoose.Types.ObjectId()}/report`, author, { reason: 'abuse' }, 404);
    // Report counts are for staff only, never exposed to students.
    assert.equal((await call('GET', `/community/posts/${housing._id}`, reader)).post.reportCount, undefined);

    // Staff outside the community section cannot see reports or the log.
    await call('GET', '/admin/community-reports', outsiderStaff, null, 403);
    await call('GET', '/admin/community-moderation-log', outsiderStaff, null, 403);
    await call('GET', `/admin/community-posts/${housing._id}`, outsiderStaff, null, 403);
    await call('POST', '/community/posts/x/report', moderator, { reason: 'spam' }, 404);

    // The moderator sees the reported queue with per-post open report counts.
    const openReports = await call('GET', '/admin/community-reports', moderator);
    assert.equal(openReports.length, 3);
    const reported = await call('GET', '/admin/community-posts?reported=1', moderator);
    assert.deepEqual(reported.map(p => [p._id, p.openReports]).sort(), [[housing._id, 2], [tips._id, 1]].sort());

    // Hiding requires a reason; it resolves the reports, logs the decision and tells the author.
    await call('PATCH', `/admin/community-posts/${housing._id}`, moderator, { status: 'hidden' }, 400);
    await call('PATCH', `/admin/community-posts/${housing._id}`, moderator, { status: 'hidden', moderationNote: 'إعلان تجاري' });
    assert.equal(await CommunityReport.countDocuments({ post: housing._id, status: 'resolved', reviewedBy: moderator._id }), 2);
    assert.equal((await CommunityPost.findById(housing._id)).reportCount, 0);
    const notice = await Notification.findOne({ user: author._id });
    assert.match(notice.message, /إعلان تجاري/);
    assert.equal(notice.type, 'warning');

    // The author still sees their hidden post, with the reason, under "mine"; nobody else does.
    const mine = await call('GET', '/community/posts?mine=1', author);
    assert.equal(mine.length, 1);
    assert.equal(mine[0].status, 'hidden');
    assert.equal(mine[0].moderationNote, 'إعلان تجاري');
    assert.equal((await call('GET', '/community/posts?mine=1', reader)).some(p => p._id === housing._id), false);
    await call('POST', `/community/posts/${housing._id}/report`, author, { reason: 'spam' }, 404);

    // Keeping a reported comment published dismisses its report; hiding it adjusts the visible count.
    await call('PATCH', `/admin/community-comments/${comment._id}`, moderator, { status: 'published', moderationNote: 'لا مخالفة' });
    assert.equal(await CommunityReport.countDocuments({ target: comment._id, status: 'dismissed' }), 1);
    assert.equal((await call('GET', `/community/posts/${tips._id}`, reader)).post.commentCount, 1);
    await call('PATCH', `/admin/community-comments/${comment._id}`, moderator, { status: 'hidden', moderationNote: 'ألفاظ مسيئة' });
    const tipsThread = await call('GET', `/community/posts/${tips._id}`, reader);
    assert.equal(tipsThread.comments.length, 0);
    assert.equal(tipsThread.post.commentCount, 0);
    assert.equal(await Notification.countDocuments({ user: third._id, type: 'warning' }), 1);
    // Deleting an already-hidden comment must not push the count below zero.
    await call('DELETE', `/community/comments/${comment._id}`, third);
    assert.equal((await CommunityPost.findById(tips._id)).commentCount, 0);

    // The moderator's post view includes hidden comments, reports and the audit trail.
    const detail = await call('GET', `/admin/community-posts/${housing._id}`, moderator);
    assert.equal(detail.post.status, 'hidden');
    assert.equal(detail.reports.length, 2);
    assert.equal(detail.log.length, 1);
    assert.deepEqual([detail.log[0].fromStatus, detail.log[0].toStatus, detail.log[0].reportsClosed, detail.log[0].actor.name], ['published', 'hidden', 2, 'Moderator']);
    const log = await call('GET', '/admin/community-moderation-log', moderator);
    assert.equal(log.length, 3);

    // A second moderator acting on a stale view cannot silently overwrite the first decision.
    const PostModel = CommunityPost;
    const original = PostModel.findById.bind(PostModel);
    PostModel.findById = function staleRead(id) {
      PostModel.findById = original;
      return original(id).then(async (doc) => { await PostModel.updateOne({ _id: id }, { status: 'hidden' }); return doc; });
    };
    await call('PATCH', `/admin/community-posts/${untagged._id}`, secondModerator, { status: 'hidden', moderationNote: 'x' }, 409);
    PostModel.findById = original;

    // The audit trail survives the author deleting their post.
    await call('DELETE', `/community/posts/${housing._id}`, author);
    assert.equal(await CommunityReport.countDocuments({ post: housing._id }), 0);
    assert.equal(await CommunityModerationLog.countDocuments({ post: housing._id }), 1);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});

test('blocked terms match whole words after Arabic normalisation', () => {
  const { findBlockedTerm } = require('../src/utils/communityTerms');
  assert.equal(findBlockedTerm('هذا نَصّ فيه كلمةٌ ممنوعة', ['كلمه']), 'كلمه');
  assert.equal(findBlockedTerm('إعلان: اشترِ الآن', ['اعلان']), 'اعلان');
  assert.equal(findBlockedTerm('Buy NOW!!', ['buy now']), 'buy now');
  // No match inside a longer word, and blank/oversized terms are ignored.
  assert.equal(findBlockedTerm('classic assessment', ['ass']), null);
  assert.equal(findBlockedTerm('نص عادي', ['', '   ', 'x'.repeat(61)]), null);
});

test('community suspensions and blocked terms are enforced and audited', async () => {
  process.env.JWT_SECRET = 'community-isolated-test';
  const mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User = require('../src/models/User');
    const Notification = require('../src/models/Notification');
    const CommunityModerationLog = require('../src/models/CommunityModerationLog');
    const CommunitySuspension = require('../src/models/CommunitySuspension');
    const student = await User.create({ name: 'Student', email: 'student@example.test' });
    const peer = await User.create({ name: 'Peer', email: 'peer@example.test' });
    const moderator = await User.create({ name: 'Moderator', email: 'moderator@example.test', role: 'employee', permissions: ['community'] });
    const outsiderStaff = await User.create({ name: 'Support', email: 'support@example.test', role: 'employee', permissions: ['support'] });
    server = await new Promise(resolve => { const s = require('../src/app').listen(0, '127.0.0.1', () => resolve(s)); });
    const token = user => jwt.sign({ userId: user._id }, process.env.JWT_SECRET);
    async function call(method, endpoint, user, body, expected = 200) {
      const response = await fetch(`http://127.0.0.1:${server.address().port}/api${endpoint}`, { method,
        headers: { 'Content-Type': 'application/json', ...(user ? { Authorization: `Bearer ${token(user)}` } : {}) },
        body: body ? JSON.stringify(body) : undefined });
      const data = await response.json(); assert.equal(response.status, expected, JSON.stringify(data)); return data;
    }

    // Blocked terms: only community moderators manage them; validated; enforced on posts and comments.
    await call('PUT', '/admin/community-settings', outsiderStaff, { blockedTerms: ['سبام'] }, 403);
    await call('PUT', '/admin/community-settings', moderator, { blockedTerms: ['x'.repeat(61)] }, 400);
    await call('PUT', '/admin/community-settings', moderator, { blockedTerms: 'سبام' }, 400);
    const settings = await call('PUT', '/admin/community-settings', moderator, { blockedTerms: [' سبام ', 'سبام', 'buy now'] });
    assert.deepEqual(settings.blockedTerms, ['سبام', 'buy now']);
    assert.deepEqual((await call('GET', '/admin/community-settings', moderator)).blockedTerms, ['سبام', 'buy now']);
    await call('POST', '/community/posts', student, { title: 'عرض', body: 'BUY NOW من هنا' }, 422);
    const post = await call('POST', '/community/posts', peer, { title: 'سؤال', body: 'نص عادي' }, 201);
    await call('POST', `/community/posts/${post._id}/comments`, student, { body: 'هذا سبام' }, 422);
    await call('POST', `/community/posts/${post._id}/comments`, student, { body: 'تعليق مفيد' }, 201);

    // Suspension: validated, students only, restricted to the community section.
    await call('POST', '/admin/community-suspensions', outsiderStaff, { user: String(student._id), reason: 'x' }, 403);
    await call('POST', '/admin/community-suspensions', moderator, { user: String(student._id), reason: '' }, 400);
    await call('POST', '/admin/community-suspensions', moderator, { user: String(student._id), reason: 'x', days: 0 }, 400);
    await call('POST', '/admin/community-suspensions', moderator, { user: String(moderator._id), reason: 'x' }, 404);
    assert.deepEqual(await call('GET', '/community/status', student), { suspended: false });
    const suspension = await call('POST', '/admin/community-suspensions', moderator, { user: String(student._id), reason: 'إساءة متكررة', days: 7 }, 201);
    assert.equal(suspension.user.name, 'Student');

    // A suspended student can read, but not post, comment or report; others are unaffected.
    const status = await call('GET', '/community/status', student);
    assert.equal(status.suspended, true);
    assert.equal(status.reason, 'إساءة متكررة');
    assert.ok(new Date(status.until) > new Date(Date.now() + 6 * 24 * 3600 * 1000));
    assert.equal((await call('GET', '/community/posts', student)).length, 1);
    await call('POST', '/community/posts', student, { title: 'T', body: 'B' }, 403);
    await call('POST', `/community/posts/${post._id}/comments`, student, { body: 'x' }, 403);
    await call('POST', `/community/posts/${post._id}/report`, student, { reason: 'spam' }, 403);
    await call('POST', `/community/posts/${post._id}/comments`, peer, { body: 'ما زلت أستطيع' }, 201);
    assert.equal(await Notification.countDocuments({ user: student._id, type: 'warning' }), 1);
    assert.deepEqual((await call('GET', '/admin/community-suspensions', moderator)).map(s => s.user.name), ['Student']);

    // An expired suspension no longer applies.
    await CommunitySuspension.updateOne({ user: student._id }, { until: new Date(Date.now() - 1000) });
    assert.deepEqual(await call('GET', '/community/status', student), { suspended: false });
    assert.equal((await call('GET', '/admin/community-suspensions', moderator)).length, 0);

    // Re-suspend until lifted, then lift: every decision is in the log.
    await call('POST', '/admin/community-suspensions', moderator, { user: String(student._id), reason: 'مخالفة جديدة' }, 201);
    assert.equal((await call('GET', '/community/status', student)).until, null);
    await call('DELETE', `/admin/community-suspensions/${student._id}`, moderator, { note: 'بعد التواصل' });
    await call('DELETE', `/admin/community-suspensions/${student._id}`, moderator, null, 404);
    await call('POST', '/community/posts', student, { title: 'عدت', body: 'شكرًا' }, 201);
    const log = await call('GET', `/admin/community-moderation-log?subject=${student._id}`, moderator);
    assert.deepEqual(log.map(e => [e.fromStatus, e.toStatus]), [['suspended', 'active'], ['active', 'suspended'], ['active', 'suspended']]);
    assert.equal(log[0].subject.name, 'Student');
    assert.equal(log[0].note, 'بعد التواصل');
    assert.equal(await CommunityModerationLog.countDocuments({ targetType: 'user' }), 3);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect(); await mongo.stop();
  }
});
