const fail = (status, message) => { throw Object.assign(new Error(message), { status }); };

function expectedVersion(body) {
  if (body?.expectedVersion === undefined) fail(428, 'حدّث القائمة وافتح السجل مجددًا قبل الحفظ أو الحذف.');
  if (!Number.isSafeInteger(body.expectedVersion) || body.expectedVersion < 0) fail(400, 'نسخة السجل غير صالحة.');
  return body.expectedVersion;
}

// Missing __v is the initial revision for legacy records; no migration is needed.
function revisionFilter(id, version) {
  return { _id: id, ...(version === 0 ? { $or: [{ __v: 0 }, { __v: { $exists: false } }] } : { __v: version }) };
}

function explicitFields(body, payload) {
  if (!body || Object.keys(body).some(key => key.startsWith('$') || key.includes('.'))) fail(400, 'حقول غير مسموحة.');
  const fields = {};
  for (const [key, value] of Object.entries(payload)) {
    if (!Object.hasOwn(body, key) || ['_id', '__v', 'expectedVersion', 'createdAt', 'updatedAt', 'slug'].includes(key)) continue;
    if (value && typeof value === 'object' && !Array.isArray(value) && body[key] && typeof body[key] === 'object') {
      for (const [child, item] of Object.entries(explicitFields(body[key], value))) fields[`${key}.${child}`] = item;
    } else fields[key] = value;
  }
  return fields;
}

async function requireResult(Model, id, result) {
  if (result) return result;
  if (!await Model.exists({ _id: id })) fail(404, 'السجل غير موجود.');
  fail(409, 'تغير هذا السجل بواسطة مستخدم آخر. حدّث البيانات وراجع التغييرات قبل المحاولة مجددًا.');
}

async function updateCatalog(Model, id, body, payload = body) {
  const version = expectedVersion(body);
  const fields = explicitFields(body, payload);
  if (!Object.keys(fields).length) fail(400, 'لا توجد حقول لتحديثها.');
  const result = await Model.findOneAndUpdate(revisionFilter(id, version), { $set: fields, $inc: { __v: 1 } }, { new: true, runValidators: true });
  return requireResult(Model, id, result);
}

async function deleteCatalog(Model, id, body) {
  const result = await Model.findOneAndDelete(revisionFilter(id, expectedVersion(body)));
  return requireResult(Model, id, result);
}

module.exports = { expectedVersion, revisionFilter, explicitFields, updateCatalog, deleteCatalog };
