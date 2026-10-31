const mongoose = require('mongoose');
const User = require('../models/User');
const Entry = require('../models/AgentWalletEntry');
const { readWallet } = require('../utils/agentWallet');
const { financialTransaction } = require('../utils/financialTransaction');
const { minorUnits, operationKey, fail } = require('../utils/financialPolicy');
const asyncHandler = require('../utils/asyncHandler');
exports.list = asyncHandler(async (req, res) => {
  const agent = req.query.student;
  if (agent && !mongoose.isValidObjectId(agent)) fail(400, 'Invalid agent ID');
  res.json(await Entry.find(agent ? { agent } : {}).populate('agent', 'name email').sort({ createdAt: -1 }).limit(200));
});
exports.adjust = asyncHandler(async (req, res) => {
  const { studentId: agent, amount, direction, notes } = req.body;
  if (!mongoose.isValidObjectId(agent) || !['credit', 'debit'].includes(direction) ||
      typeof notes !== 'string' || !notes.trim() || notes.length > 500 || minorUnits(amount) < 1) fail(400, 'Valid agent, amount and adjustment reason are required');
  if (!await User.exists({ _id: agent, role: 'partner', isActive: true })) fail(404, 'Active agent not found');
  const key = operationKey(req, `agent-adjustment:${req.user._id}`);
  const result = await financialTransaction([`agent-wallet:${agent}`], async session => {
    const previous = await Entry.findOne({ operationKey: key }).session(session);
    if (previous) {
      if (String(previous.agent) !== agent || previous.amount !== amount || previous.direction !== direction || previous.notes !== notes.trim()) fail(409, 'Adjustment key already used');
      return previous;
    }
    const wallet = await readWallet(agent, session);
    if (direction === 'debit' && minorUnits(amount) > minorUnits(wallet.summary.availableBalance)) fail(409, 'Insufficient available agent balance');
    const [entry] = await Entry.create([{ agent, amount, direction, notes: notes.trim(), status: 'approved', kind: 'adjustment', recordedBy: req.user._id, operationKey: key }], { session });
    return entry;
  });
  res.status(201).json(result);
});
