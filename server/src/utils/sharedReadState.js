const mongoose = require('mongoose');
const registry = require('../constants/readableResources.json');
const { hasSection } = require('../middleware/employeeAccess');
const Receipt = require('../models/SharedReadReceipt');
const countsCache = require('./readSummaryCache');
const fail = (status, message) => Object.assign(new Error(message), { status });

function definition(user, resource) {
  if (!Object.hasOwn(registry, resource)) throw fail(404, 'نوع السجل غير مدعوم');
  const def = registry[resource];
  if (user?.role !== 'admin' && !(def.section && hasSection(user, def.section))) throw fail(403, 'غير مصرح بقراءة هذا القسم');
  return def;
}
function sourceModel(def) {
  if (!mongoose.models[def.model]) {
    if (def.model.startsWith('Consultation')) require('../models/Consultation');
    else if (def.model === 'MobileMessage') require('../models/MobileWorkspace');
    else if (def.model.startsWith('Scholarship')) require('../routes/scholarshipRoutes');
    else require(`../models/${def.model}`);
  }
  return mongoose.model(def.model);
}
const revision = row => `${new Date(row.updatedAt || row.createdAt || row._id.getTimestamp()).toISOString()}:${String(row.__v || 0).padStart(10, '0')}`;
async function matchFor(def, user) {
  if (def.model !== 'MobileMessage') return { ...def.filter };
  const { contactFilter } = require('../routes/mobileMessagingRoutes');
  const User = require('../models/User');
  const contacts = await User.find(await contactFilter(user)).select('_id').lean();
  return { recipient: new mongoose.Types.ObjectId(String(user._id)), sender: { $in: contacts.map(row => row._id) } };
}
function metadataStages(def) {
  if (def.model === 'MobileMessage') return [{ $set: { updatedAt: '$createdAt', __v: 0 } }];
  if (def.model !== 'User') return [];
  const Profile = require('../models/StudentProfile');
  return [
    { $lookup: { from: Profile.collection.name, localField: '_id', foreignField: 'user', pipeline: [{ $project: { updatedAt: 1, __v: 1 } }], as: '_profileRead' } },
    { $set: { _profileRead: { $arrayElemAt: ['$_profileRead', 0] } } },
    { $set: {
      __v: { $cond: [{ $gt: ['$_profileRead.updatedAt', '$updatedAt'] }, { $ifNull: ['$_profileRead.__v', 0] }, { $ifNull: ['$__v', 0] }] },
      updatedAt: { $max: ['$updatedAt', '$_profileRead.updatedAt'] },
    } },
  ];
}
function revisionExpression() {
  const value = { $toString: { $ifNull: ['$__v', 0] } };
  return { $concat: [
    { $dateToString: { date: { $ifNull: ['$updatedAt', { $ifNull: ['$createdAt', { $toDate: '$_id' }] }] }, format: '%Y-%m-%dT%H:%M:%S.%LZ', timezone: 'UTC' } }, ':',
    { $substrBytes: [{ $concat: ['0000000000', value] }, { $strLenBytes: value }, 10] },
  ] };
}
async function states(user, resource, ids) {
  const def = definition(user, resource);
  if (!Array.isArray(ids) || ids.length > 100 || ids.some(id => typeof id !== 'string' || !/^[a-f0-9]{24}$/i.test(id))) throw fail(400, 'معرفات السجلات غير صالحة');
  if (!ids.length) return {};
  const rows = await sourceModel(def).aggregate([
    { $match: { ...await matchFor(def, user), _id: { $in: ids.map(id => new mongoose.Types.ObjectId(id)) } } },
    { $project: { updatedAt: 1, createdAt: 1, __v: 1 } }, ...metadataStages(def),
  ]);
  const receipts = await Receipt.find({ resource: def.model, entity: { $in: rows.map(row => row._id) } }).lean();
  const seen = new Map(receipts.map(row => [String(row.entity), row]));
  return Object.fromEntries(rows.map(row => {
    const previous = seen.get(String(row._id)), version = revision(row);
    return [String(row._id), { resource, canonical: def.model, id: String(row._id), version, unread: !previous || previous.revision < version, readAt: previous?.readAt || null }];
  }));
}
async function markRead(user, resource, id, version) {
  const def = definition(user, resource);
  if (typeof version !== 'string' || version.length > 100) throw fail(400, 'نسخة السجل مطلوبة');
  const state = (await states(user, resource, [id]))[id];
  if (!state) throw fail(404, 'السجل غير موجود أو غير متاح');
  if (state.version !== version) throw fail(409, 'وصل تحديث جديد؛ أعد فتح التفاصيل قبل اعتبارها مقروءة');
  // $max prevents a delayed acknowledgement from undoing a newer read.
  const filter = { resource: def.model, entity: id };
  const update = { $max: { revision: version }, $set: { readAt: new Date(), readBy: user._id } };
  await Receipt.init();
  try { await Receipt.updateOne(filter, update, { upsert: true }); }
  catch (error) { if (error.code !== 11000) throw error; await Receipt.updateOne(filter, update); }
  if (def.model === 'MobileMessage') await sourceModel(def).updateOne({ _id: id, recipient: user._id, readAt: null }, { $set: { readAt: new Date() } }, { timestamps: false });
  countsCache.clear();
  return { ...state, unread: false };
}
async function summary(user, requested) {
  const keys = requested || Object.keys(registry).filter(key => { try { definition(user, key); return true; } catch { return false; } });
  if (!Array.isArray(keys) || keys.length > 60) throw fail(400, 'قائمة الأقسام غير صالحة');
  keys.forEach(key => definition(user, key));
  const resources = {}, errors = {};
  // Limit database concurrency; counts never download source documents or file contents.
  for (let offset = 0; offset < keys.length; offset += 4) await Promise.all(keys.slice(offset, offset + 4).map(async key => {
    try {
      const def = definition(user, key);
      const match = await matchFor(def, user);
      const cacheKey = JSON.stringify([key, match]), cached = countsCache.get(cacheKey), stamp = countsCache.generation();
      if (cached) { resources[key] = cached; return; }
      const rows = await sourceModel(def).aggregate([
        { $match: match },
        ...metadataStages(def),
        { $project: { version: revisionExpression(), sender: 1 } },
        { $lookup: { from: Receipt.collection.name, let: { entity: '$_id' }, pipeline: [{ $match: { resource: def.model, $expr: { $eq: ['$entity', '$$entity'] } } }, { $project: { revision: 1 } }], as: 'receipt' } },
        { $group: { _id: def.model === 'MobileMessage' ? '$sender' : null, total: { $sum: 1 }, unread: { $sum: { $cond: [{ $gt: ['$version', { $ifNull: [{ $arrayElemAt: ['$receipt.revision', 0] }, ''] }] }, 1, 0] } } } },
      ]);
      resources[key] = { canonical: def.model, total: rows.reduce((sum, row) => sum + row.total, 0), unread: rows.reduce((sum, row) => sum + row.unread, 0), ...(def.model === 'MobileMessage' ? { contacts: Object.fromEntries(rows.map(row => [String(row._id), row.unread])) } : {}) };
      countsCache.set(cacheKey, resources[key], stamp);
    } catch (error) { errors[key] = 'تعذر تحديث عداد القسم'; }
  }));
  return { shared: true, resources, errors, checkedAt: new Date().toISOString() };
}
async function unread(user, resource) {
  const def = definition(user, resource);
  const items = await sourceModel(def).aggregate([
    { $match: await matchFor(def, user) }, ...metadataStages(def),
    { $project: { version: revisionExpression(), title: { $ifNull: ['$title', '$name', '$subject', '$invoiceNumber', { $toString: '$_id' }] } } },
    { $lookup: { from: Receipt.collection.name, let: { entity: '$_id' }, pipeline: [{ $match: { resource: def.model, $expr: { $eq: ['$entity', '$$entity'] } } }], as: 'receipt' } },
    { $match: { $expr: { $gt: ['$version', { $ifNull: [{ $arrayElemAt: ['$receipt.revision', 0] }, ''] }] } } },
    { $sort: { _id: -1 } }, { $limit: 100 }, { $project: { title: 1, version: 1 } },
  ]);
  return { items, limit: 100 };
}
async function detail(user, resource, id) {
  const def = definition(user, resource);
  if (!/^[a-f0-9]{24}$/i.test(id)) throw fail(400, 'معرف غير صالح');
  // Explicit safe display fields: no passwords, tokens, storage credentials or payroll.
  const record = await sourceModel(def).findOne({ ...await matchFor(def, user), _id: id })
    .select('name email role employeeRole isActive title subject description message body status detailedStatus amount invoiceNumber currency dueDate category notes adminNote reviewNote university program country language degreeLevel fieldOfStudy duration tuition partnerTuition summary overview code replies createdAt updatedAt __v').lean();
  if (!record) throw fail(404, 'السجل غير موجود');
  if (['students', 'agents'].includes(resource)) {
    record.profile = await require('../models/StudentProfile').findOne({ user: id }).select('-__v -user').lean();
    if (record.profile?.updatedAt > record.updatedAt) record.updatedAt = record.profile.updatedAt;
  }
  return { record, state: (await states(user, resource, [id]))[id] };
}
module.exports = { registry, definition, revision, states, markRead, summary, unread, detail };
