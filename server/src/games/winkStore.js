const Room = require('../models/WinkRoom');
const engine = require('./winkEngine');
const practice = require('./winkPractice');

async function mutate(code, update, attempts = 20) {
  for (let i = 0; i < attempts; i++) {
    const doc = await Room.findOne({ code, expiresAt: { $gt: new Date() } }).select('+state').lean();
    if (!doc) engine.fail('room-not-found');
    const now = Date.now();
    practice.advance(doc.state, now);
    let actionError;
    try { update(doc.state, now); practice.advance(doc.state, now); } catch (error) {
      if (!error.gameCode) throw error;
      actionError = error;
    }
    const saved = await Room.findOneAndUpdate({ _id: doc._id, revision: doc.revision }, {
      $set: { state: doc.state, expiresAt: new Date(now + 86400000) }, $inc: { revision: 1 },
    }, { new: true }).select('+state').lean();
    if (saved) { if (actionError) throw actionError; return saved; }
  }
  engine.fail('busy');
}
function startWinkScheduler() {
  let running = false;
  const timer = setInterval(async () => {
    if (running) return;
    running = true;
    try {
      // A database-backed sweep survives restarts and works across server replicas.
      const cursor = Room.find({ 'state.phase': { $in: ['lobby', 'reveal', 'playing', 'voting', 'finished'] },
        expiresAt: { $gt: new Date() } }).select('code').lean().cursor();
      for await (const room of cursor) {
        await mutate(room.code, () => {}).catch(() => {});
      }
    } catch (_) { /* database reconnect will retry on the next tick */ }
    finally { running = false; }
  }, 1000);
  timer.unref(); return () => clearInterval(timer);
}
module.exports = { mutate, startWinkScheduler };
