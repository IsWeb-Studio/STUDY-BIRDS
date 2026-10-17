const mongoose = require('mongoose');
const FinancialLock = require('../models/FinancialLock');

async function financialTransaction(keys, work) {
  const ordered = [...new Set(keys)].sort();
  // Initialize outside the transaction to avoid concurrent upsert collisions.
  for (const key of ordered) {
    try { await FinancialLock.updateOne({ _id: key }, { $setOnInsert: { revision: 0 } }, { upsert: true }); }
    catch (error) { if (error.code !== 11000) throw error; }
  }
  try {
    return await mongoose.connection.transaction(async session => {
      // This write serializes readers of the same wallet. Merely aggregating
      // independent ledger rows in a snapshot transaction would allow write skew.
      for (const key of ordered) {
        await FinancialLock.updateOne({ _id: key }, { $inc: { revision: 1 } }, { session });
      }
      return work(session);
    }, { readConcern: { level: 'snapshot' }, writeConcern: { w: 'majority' }, maxCommitTimeMS: 15000 });
  } catch (error) {
    if (error.code === 20 || error.codeName === 'IllegalOperation') {
      throw Object.assign(new Error('Financial writes require MongoDB replica-set transactions'), { statusCode: 503 });
    }
    // Never compensate a failed/ambiguous commit with an independent deletion.
    throw error;
  }
}
module.exports = { financialTransaction };
