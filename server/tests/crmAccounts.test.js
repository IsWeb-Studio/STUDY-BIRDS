const {test} = require('node:test');
const assert = require('node:assert/strict');
const {accountPayload,safeAccount} = require('../src/utils/crmAccountPolicy');
const create = {kind:'student',companyId:'company-default',recordId:'crm-123',name:' Student ',email:'STUDENT@example.test',password:'UniquePass!42',profile:{phone:'123',nationality:'Turkey'}};
test('CRM provisioning accepts a login and student profile but never a requested privileged role', () => {
  assert.equal(accountPayload(create,{create:true}).email,'student@example.test');
  for (const extra of [{role:'admin'},{emailVerified:true},{tokenVersion:0},{permissions:['students']}]) assert.throws(()=>accountPayload({...create,...extra},{create:true}));
});
test('provisioning enforces website passwords and rejects injected profile permissions', () => {
  assert.throws(()=>accountPayload({...create,password:'123456'},{create:true}));
  assert.throws(()=>accountPayload({...create,profile:{role:'admin'}},{create:true}));
  assert.throws(()=>accountPayload({...create,recordId:'../other'},{create:true}));
});
test('employee permissions are explicit valid sections and updates cannot change account kind', () => {
  const result = accountPayload({employeeRole:'educational_consultant',permissions:['students','applications']},{employee:true});
  assert.equal(result.employeeRole,'educational_consultant');
  assert.throws(()=>accountPayload({role:'admin'},{employee:true}));
  assert.throws(()=>accountPayload({permissions:['all']},{employee:true}));
});
test('responses never include credentials, tokens, or CRM identity', () => {
  const safe = safeAccount({_id:'id',name:'Test',password:'hash',refreshTokenHash:'refresh',crmIdentity:{recordId:'crm'}});
  assert.equal(safe.password,undefined); assert.equal(safe.refreshTokenHash,undefined); assert.equal(safe.crmIdentity,undefined);
});
