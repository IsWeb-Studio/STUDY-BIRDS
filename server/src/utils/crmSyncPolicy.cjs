const { digest, canonical } = require('./syncMerge.cjs');
// Private CRM extensions. Website-owned accounts/catalog/finance stay on their validated APIs.
const resources = ['tasks','reminders','callSchedules','responseScripts','dailyReports','attendance','leaveRequests','receptionLogs','leads','broadcasts','executiveActions','studentWorkspace','employeeWorkspace','applicationWorkspace','invoiceWorkspace'];
const fail = (status,message) => {throw Object.assign(new Error(message),{status});};
const validId = value => typeof value === 'string' && /^[\w-]{1,100}$/.test(value);
const sensitive = /^(password|passwordHash|token|accessToken|refreshToken|secret|apiKey|portalPassword|authorization|oauthStates|credentials)$/i;
function validateValue(value, depth=0) {
  if(depth>15)fail(400,'CRM data is too deeply nested');
  if(value===null || ['string','number','boolean'].includes(typeof value)) {
    if(typeof value==='number' && !Number.isFinite(value))fail(400,'Invalid numeric value');
    return;
  }
  if(Array.isArray(value)){value.forEach(item=>validateValue(item,depth+1));return;}
  if(!value || typeof value!=='object')fail(400,'Invalid CRM data');
  for(const [key,item] of Object.entries(value)) {
    if(sensitive.test(key) || ['__proto__','constructor','prototype'].includes(key) || key.startsWith('$') || key.includes('.'))fail(400,'Sensitive or unsafe CRM field');
    validateValue(item,depth+1);
  }
}
function validateOperation(body) {
  if(!body || Object.keys(body).some(key=>!['operationId','expectedRevision','value'].includes(key)) || !validId(body.operationId) || !Number.isSafeInteger(body.expectedRevision) || body.expectedRevision<0 || !body.value || typeof body.value!=='object' || Array.isArray(body.value))fail(400,'Invalid sync operation');
  validateValue(body.value); canonical(body.value);
  if(Buffer.byteLength(JSON.stringify(body.value))>256*1024)fail(413,'CRM record exceeds sync size limit');
}
const recordId = (owner,companyId,resource,entityId) => digest([String(owner),companyId,resource,entityId]);
module.exports = {resources,validId,validateValue,validateOperation,recordId};
