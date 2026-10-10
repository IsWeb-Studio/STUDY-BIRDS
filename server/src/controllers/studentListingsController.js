const {crmPagination,crmPage}=require('../utils/crmPagination');
const mongoose = require('mongoose');
const run = require('../utils/asyncHandler');
const Listing = require('../models/StudentListing');
const validKind = kind => ['offer', 'opportunity'].includes(kind);
const list = (staff = false) => run(async (req, res) => {
  const kind = req.query.kind;
  if (!validKind(kind)) return res.status(400).json({ message: 'نوع غير صالح' });
  const query = { kind };
  if (!staff) Object.assign(query, { published: true, $and: [
    { $or: [{ validFrom: null }, { validFrom: { $lte: new Date() } }] },
    { $or: [{ expiresAt: null }, { expiresAt: { $gt: new Date() } }] },
  ] });
  const pagination=staff?crmPagination(req.query):null;
  const items=await Listing.find(query).select(staff ? '' : '-updatedBy').sort({ createdAt: -1, _id:-1 }).skip(pagination?.skip || 0).limit(pagination?.limit || 200).lean();
  res.json(pagination?crmPage(items,await Listing.countDocuments(query),pagination):items);
});
const save = run(async (req, res) => {
  if (!validKind(req.body.kind) || typeof req.body.published !== 'boolean') return res.sendStatus(400);
  const value = { kind: req.body.kind, published: req.body.published, updatedBy: req.user._id };
  for (const [key, limit] of Object.entries({ title: 200, organization: 200, country: 100, description: 5000, terms: 3000, url: 1000 })) {
    const text = req.body[key] ?? '';
    if (typeof text !== 'string' || text.length > limit) return res.status(400).json({ message: `Invalid field: ${key}` });
    value[key] = text.trim();
  }
  if (!value.title) return res.status(400).json({ message: 'العنوان مطلوب' });
  if (value.url) {
    try {
      const url = new URL(value.url);
      if (url.protocol !== 'https:' || url.username || url.password) throw new Error();
    } catch { return res.status(400).json({ message: 'أدخل رابطًا صالحًا يبدأ بـ https' }); }
  }
  for (const key of ['validFrom', 'expiresAt']) {
    const raw = req.body[key];
    if (raw != null && raw !== '' && (typeof raw !== 'string' || !/^\d{4}-\d{2}-\d{2}(T.*)?$/.test(raw) || !Number.isFinite(Date.parse(raw)))) {
      return res.status(400).json({ message: 'التاريخ غير صالح؛ استخدم YYYY-MM-DD' });
    }
    value[key] = raw ? new Date(raw) : null;
  }
  if (value.expiresAt && value.validFrom && value.expiresAt <= value.validFrom) return res.status(400).json({ message: 'تاريخ الانتهاء يجب أن يلي البداية' });
  if (req.params.id && !mongoose.isValidObjectId(req.params.id)) return res.sendStatus(404);
  const row = req.params.id
    ? await Listing.findOneAndUpdate({ _id: req.params.id, kind: value.kind }, { $set: value }, { new: true, runValidators: true })
    : await Listing.create(value);
  if (!row) return res.sendStatus(404);
  res.status(req.params.id ? 200 : 201).json(row);
});
module.exports = { list, save };
