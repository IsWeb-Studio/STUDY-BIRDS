const Entry = require('../models/AgentWalletEntry');
const Payout = require('../models/PayoutRequest');
const { financialTransaction } = require('./financialTransaction');
const { minorUnits, fail } = require('./financialPolicy');
function walletSummary(entries, payouts) {
  const sum = rows => rows.reduce((total, row) => total + minorUnits(row.amount), 0);
  const approved = sum(entries.filter(e => e.direction === 'credit' && e.status === 'approved'));
  const spent = sum(entries.filter(e => e.direction === 'debit' && ['approved', 'paid'].includes(e.status)));
  const reserved = sum(payouts.filter(p => ['pending', 'approved'].includes(p.status)));
  return {
    availableBalance: Math.max(0, approved - spent - reserved) / 100,
    reservedBalance: reserved / 100,
    pendingBalance: sum(entries.filter(e => e.direction === 'credit' && e.status === 'pending')) / 100,
    receivedBalance: sum(entries.filter(e => e.status === 'paid' && (e.direction === 'debit' || e.direction === 'credit'))) / 100,
  };
}
async function readWallet(agent, session) {
  const entries = await Entry.find({ agent }).session(session || null).sort({ createdAt: -1 });
  const payouts = await Payout.find({ agent }).session(session || null).sort({ createdAt: -1 });
  return { entries, payouts, summary: walletSummary(entries, payouts) };
}
async function reservePayout(agent, payload, key) {
  const cents = minorUnits(payload.amount);
  if (cents < 100) fail(400, 'Minimum payout is 1 USD');
  if (!['bank-account', 'usdt', 'wise', 'other'].includes(payload.method) ||
      typeof payload.payoutDetails !== 'string' || !payload.payoutDetails.trim() || payload.payoutDetails.length > 2000 ||
      typeof payload.notes !== 'string' || payload.notes.length > 2000) fail(400, 'Valid payout method and details are required');
  return financialTransaction([`agent-wallet:${agent}`], async session => {
    const previous = key && await Payout.findOne({ operationKey: key }).session(session);
    if (previous) {
      if (String(previous.agent) !== String(agent) || previous.amount !== payload.amount || previous.method !== payload.method || previous.payoutDetails !== payload.payoutDetails.trim() || previous.notes !== payload.notes) fail(409, 'Payout key already used for different details');
      return previous;
    }
    const wallet = await readWallet(agent, session);
    if (cents > minorUnits(wallet.summary.availableBalance)) fail(409, 'Insufficient available balance; pending payouts are already reserved');
    const [payout] = await Payout.create([{ agent, ...payload, operationKey: key, payoutDetails: payload.payoutDetails.trim() }], { session });
    return payout;
  });
}
async function reviewPayout(id, status, note, reviewer) {
  if (!['pending', 'approved', 'rejected', 'paid'].includes(status)) fail(400, 'Invalid payout status');
  const original = await Payout.findById(id);
  if (!original) fail(404, 'Payout request not found');
  return financialTransaction([`agent-wallet:${original.agent}`], async session => {
    const payout = await Payout.findById(id).session(session);
    if (payout.status === status) return payout;
    if (['paid', 'rejected'].includes(payout.status)) fail(409, 'This payout is final; create a new request if needed');
    const wallet = await readWallet(payout.agent, session);
    const sum = rows => rows.reduce((total, row) => total + minorUnits(row.amount), 0);
    const availableForThis = sum(wallet.entries.filter(e => e.direction === 'credit' && e.status === 'approved'))
      - sum(wallet.entries.filter(e => e.direction === 'debit' && ['approved', 'paid'].includes(e.status)))
      - sum(wallet.payouts.filter(p => ['pending', 'approved'].includes(p.status) && String(p._id) !== String(payout._id)));
    if (['approved', 'paid'].includes(status) && minorUnits(payout.amount) > availableForThis) fail(409, 'Insufficient wallet balance');
    payout.status = status; payout.reviewNote = note; payout.reviewedBy = reviewer; payout.reviewedAt = new Date();
    await payout.save({ session });
    if (status === 'paid') await Entry.create([{
      agent: payout.agent, direction: 'debit', kind: 'payout', amount: payout.amount, status: 'paid',
      method: payout.method, details: payout.payoutDetails, notes: payout.notes, paidAt: new Date(),
    }], { session });
    return payout;
  });
}
module.exports = { walletSummary, readWallet, reservePayout, reviewPayout };
