const FinancialOutbox = require('../models/FinancialOutbox');
const Notification = require('../models/Notification');
async function enqueueFinancialNotice(id, notice, session) {
  await FinancialOutbox.updateOne({ _id: id }, { $setOnInsert: notice }, { upsert: true, session });
}
let draining = false;
async function drainFinancialOutbox() {
  if (draining) return;
  draining = true;
  try {
    for (const item of await FinancialOutbox.find({ done: false }).sort({ createdAt: 1 }).limit(50)) {
      try {
        const delivery = await Notification.updateOne({ _id: item.notificationId }, { $setOnInsert: {
          user: item.user, title: item.title, message: item.message, type: 'success', link: item.link,
        } }, { upsert: true });
        if (delivery.upsertedCount) {
          require('./pushNotifications').sendPushToUser(item.user, { title: item.title, body: item.message, link: item.link }).catch(() => {});
        }
        if (item.advancePayment) await require('./journeyAutomation').onPaymentApproved(item.user);
        await FinancialOutbox.updateOne({ _id: item._id }, { $set: { done: true } });
      } catch { /* Durable pending item is retried on the next pass. */ }
    }
  } finally { draining = false; }
}
function startFinancialOutbox() {
  let running = false;
  const run = async () => {
    if (running) return;
    running = true;
    try {
      await drainFinancialOutbox();
      await require('./studentWallet').reconcileReferralRewards();
    } catch { /* Database outages are retried by the next pass. */ }
    finally { running = false; }
  };
  const timer = setInterval(run, 30000); timer.unref(); run();
  return () => clearInterval(timer);
}
module.exports = { enqueueFinancialNotice, drainFinancialOutbox, startFinancialOutbox };
