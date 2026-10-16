const {test} = require('node:test');
const assert = require('node:assert/strict');
const {createHash, randomBytes} = require('node:crypto');
const {authenticateCrmService: auth} = require('../src/utils/crmServiceAuth');
const token = 'sbcrm_' + randomBytes(32).toString('hex');
const env = {CRM_SERVICE_AUTH_ENABLED:'true', CRM_SERVICE_TOKEN_SHA256:createHash('sha256').update(token).digest('hex'), CRM_SERVICE_USER_ID:'a'.repeat(24)};
const request = (path='/api/admin/countries', method='POST', headers={}) => ({originalUrl:path, method, headers});
const admin = {_id:env.CRM_SERVICE_USER_ID, role:'admin', isActive:true};

test('permanent credential resolves current admin without depending on login JWT expiry', async()=>{
  const req=request();
  assert.equal(await auth(req,token,env,async id=>{assert.equal(id,admin._id);return admin;}),admin);
  assert.equal(req.crmServiceAuthenticated,true);
  assert.equal(await auth(request('/api/auth/me','GET'),token,env,async()=>admin),admin);
  assert.equal(await auth(request(),'ordinary.login.jwt',env,async()=>assert.fail()),null);
});
test('disable, rotate, missing configuration and malformed credentials fail closed', async()=>{
  for (const config of [{...env,CRM_SERVICE_AUTH_ENABLED:'false'}, {...env,CRM_SERVICE_TOKEN_SHA256:'0'.repeat(64)}, {...env,CRM_SERVICE_TOKEN_SHA256:''}, {...env,CRM_SERVICE_USER_ID:''}]) {
    await assert.rejects(auth(request(),token,config,async()=>assert.fail()),{status:401});
  }
  await assert.rejects(auth(request(),'sbcrm_invalid',env,async()=>assert.fail()),{status:401});
});
test('browser use, login/session endpoints, unrelated APIs and inactive/demoted users are rejected', async()=>{
  for (const req of [request('/api/auth/me','POST'),request('/api/auth/login'),request('/api/mobile-security/sessions'),request('/api/admin/countries','GET',{origin:'https://site.test'}),request('/api/admin/users','GET',{'x-study-birds-client':'web'})]) {
    await assert.rejects(auth(req,token,env,async()=>assert.fail()),{status:403});
  }
  for (const user of [null,{...admin,isActive:false},{...admin,role:'student'}]) {
    await assert.rejects(auth(request(),token,env,async()=>user),{status:403});
  }
});
