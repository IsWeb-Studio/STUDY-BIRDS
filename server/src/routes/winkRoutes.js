const router = require('express').Router();
const { rateLimit } = require('express-rate-limit');
const { protect } = require('../middleware/authMiddleware');
const Room = require('../models/WinkRoom');
const engine = require('../games/winkEngine');
const practice = require('../games/winkPractice');
const { mutate } = require('../games/winkStore');

router.use(protect);
router.use(rateLimit({ windowMs: 60000, limit: 150, keyGenerator: (req) => String(req.user._id),
  standardHeaders: 'draft-7', legacyHeaders: false }));
router.use((req, res, next) => { res.set('Cache-Control', 'no-store'); next(); });
const identity = (req) => ({ id: String(req.user._id), name: String(req.user.name || 'Player').slice(0, 70),
  avatar: typeof req.user.avatar === 'string' && req.user.avatar.startsWith('https://') ? req.user.avatar : null });
const handle = (fn) => async (req, res, next) => {
  try { await fn(req, res); } catch (error) {
    if (error.gameCode) res.status(error.gameCode === 'not-member' ? 403 : 409).json({ code: error.gameCode, message: 'تعذر تنفيذ إجراء اللعبة. حدّث الغرفة وحاول مجددًا.' });
    else next(error);
  }
};
const send = (res, doc, id) => res.json({ code: doc.code, revision: doc.revision, ...engine.view(doc.state, id) });
router.get('/current', handle(async (req, res) => {
  const id = identity(req).id;
  const room = await Room.findOne({ 'state.players': { $elemMatch: { id, left: false } },
    'state.phase': { $ne: 'closed' }, expiresAt: { $gt: new Date() } }).sort({ updatedAt: -1 }).select('code').lean();
  res.json({ code: room?.code || null });
}));
router.post('/', rateLimit({ windowMs: 3600000, limit: 20, keyGenerator: (req) => String(req.user._id) }), handle(async (req, res) => {
  const user = identity(req);
  const existing = await Room.exists({ 'state.players': { $elemMatch: { id: user.id, left: false } },
    'state.phase': { $ne: 'closed' }, expiresAt: { $gt: new Date() } });
  if (existing) engine.fail('already-in-room');
  const doc = await Room.create({ code: engine.code(), state: engine.newRoom(user), expiresAt: new Date(Date.now() + 86400000) });
  send(res, doc, user.id);
}));
router.param('code', (req, res, next, code) => {
  if (!/^[A-F0-9]{8}$/.test(code)) return res.status(400).json({ code: 'invalid-code', message: 'كود الغرفة غير صحيح.' });
  next();
});
router.post('/practice', handle(async (req, res) => {
  const user = identity(req);
  const existing = await Room.findOne({ 'state.players': { $elemMatch: { id: user.id, left: false } },
    'state.phase': { $ne: 'closed' }, expiresAt: { $gt: new Date() } }).select('+state').lean();
  if (existing) {
    if (existing.state.practice?.owner !== user.id) engine.fail('already-in-room');
    const doc = await mutate(existing.code, (state, now) => engine.apply(state, user, 'heartbeat', {}, now));
    return send(res, doc, user.id);
  }
  const state = practice.create(user, req.body?.role || 'player');
  const doc = await Room.create({ code: engine.code(), state, expiresAt: new Date(Date.now() + 86400000) });
  send(res, doc, user.id);
}));
router.post('/:code/join', handle(async (req, res) => {
  const user = identity(req);
  const doc = await mutate(req.params.code, (state, now) => {
    if (state.practice) engine.fail('practice-private');
    engine.join(state, user, now);
  });
  send(res, doc, user.id);
}));
router.get('/:code', handle(async (req, res) => {
  const user = identity(req);
  const doc = await mutate(req.params.code, (state, now) => engine.apply(state, user, 'heartbeat', {}, now));
  send(res, doc, user.id);
}));
router.post('/:code/actions', handle(async (req, res) => {
  const user = identity(req);
  const { action, payload = {}, operationId, round } = req.body || {};
  if (typeof operationId !== 'string' || !/^[a-zA-Z0-9-]{8,100}$/.test(operationId)
    || typeof action !== 'string' || !payload || typeof payload !== 'object' || Array.isArray(payload)) engine.fail('invalid-action');
  const doc = await mutate(req.params.code, (state, now) => {
    // Replays return the current authorized view, never execute twice.
    const key = `${user.id}:${operationId}`;
    if (!state.players.some((p) => p.id === user.id && !p.left)) engine.fail('not-member');
    if (state.receipts.includes(key)) return;
    if (round !== undefined && (!Number.isInteger(round) || round !== state.round)) engine.fail('stale-round');
    practice.apply(state, user, action, payload, now);
    state.receipts = [...state.receipts.slice(-199), key];
  });
  if (action === 'leave') return res.json({ left: true });
  send(res, doc, user.id);
}));
module.exports = router;
