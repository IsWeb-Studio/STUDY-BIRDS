const { passwordError } = require('./passwordPolicy');
const { validPermissions } = require('../middleware/employeeAccess');
const PROFILE_FIELDS = ['phone', 'englishFullName', 'passportNumber', 'dateOfBirth', 'nationality', 'currentEducation', 'currentEducationLevel', 'currentResidenceCountry', 'currentResidenceRegion', 'gpa', 'intake', 'bio', 'address', 'nativeLanguage', 'otherLanguages', 'targetCountries', 'parentInfo', 'emergencyContact'];
const fail = message => { throw Object.assign(new Error(message), { status:400 }); };
function accountPayload(body, { create = false, employee = false } = {}) {
  const allowed = ['name','email','password','isActive','profile', ...(employee ? ['employeeRole','permissions'] : []), ...(create ? ['companyId','recordId','kind'] : [])];
  if (!body || Array.isArray(body) || Object.keys(body).some(key => !allowed.includes(key))) fail('Unsupported account fields');
  const result = {};
  if (create || body.name !== undefined) {
    if (typeof body.name !== 'string' || !body.name.trim() || body.name.length > 160) fail('Name is required');
    result.name = body.name.trim();
  }
  if (create || body.email !== undefined) {
    if (typeof body.email !== 'string' || body.email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(body.email.trim())) fail('Valid email is required');
    result.email = body.email.trim().toLowerCase();
  }
  if (create || body.password !== undefined) {
    const error = passwordError(body.password); if (error) fail(error);
    result.password = body.password;
  }
  if (body.isActive !== undefined) { if (typeof body.isActive !== 'boolean') fail('Invalid account status'); result.isActive = body.isActive; }
  if (body.profile !== undefined) {
    if (employee || !body.profile || Array.isArray(body.profile) || Object.keys(body.profile).some(key => !PROFILE_FIELDS.includes(key))) fail('Invalid student profile fields');
    result.profile = body.profile;
  }
  if (employee) {
    const roles = require('../constants/roles').ALL_EMPLOYEE_ROLES;
    if (body.employeeRole !== undefined && !roles.includes(body.employeeRole)) fail('Invalid employee role');
    if (body.permissions !== undefined && !validPermissions(body.permissions)) fail('Invalid employee permissions');
    if (body.employeeRole !== undefined) result.employeeRole = body.employeeRole;
    if (body.permissions !== undefined) result.permissions = [...new Set(body.permissions)];
  }
  if (create) {
    if (!['student','employee'].includes(body.kind) || typeof body.companyId !== 'string' || !/^[\w-]{1,100}$/.test(body.companyId) || typeof body.recordId !== 'string' || !/^[\w-]{1,100}$/.test(body.recordId)) fail('Valid CRM identity is required');
  }
  return result;
}
function safeAccount(user) {
  const row = user.toObject ? user.toObject() : user;
  return Object.fromEntries(['_id','name','email','role','employeeRole','permissions','isActive','createdAt'].map(key => [key,row[key]]));
}
module.exports = { accountPayload, safeAccount, PROFILE_FIELDS };
