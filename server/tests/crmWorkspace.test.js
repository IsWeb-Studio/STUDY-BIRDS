const {test}=require('node:test');
const assert=require('node:assert/strict');
const jwt=require('jsonwebtoken');
const {crmWorkspaceConfig,workspaceSession}=require('../src/utils/crmWorkspace');
const env={CRM_API_URL:'https://crm.example.test/api',CRM_WEB_URL:'https://crm-web.example.test',STUDY_BIRDS_SSO_SECRET:'x'.repeat(64)};
test('workspace refuses unsafe URLs and unlinked or student identities',async()=>{
  assert.throws(()=>crmWorkspaceConfig({...env,CRM_API_URL:'http://crm.example.test/api'}));
  assert.throws(()=>crmWorkspaceConfig({...env,CRM_WEB_URL:'https://user:password@crm.example.test'}));
  await assert.rejects(workspaceSession({role:'student',crmIdentity:{companyId:'one'}},{env}));
  await assert.rejects(workspaceSession({role:'employee'},{env}));
});
test('workspace proof uses authenticated identity, expires quickly and is never in a URL',async()=>{
  const user={_id:'site-id',role:'employee',crmIdentity:{companyId:'one'}};
  const result=await workspaceSession(user,{env,fetchImpl:async(url,options)=>{
    assert.equal(url,'https://crm.example.test/api/integrations/website/sso');
    const claims=jwt.verify(JSON.parse(options.body).proof,env.STUDY_BIRDS_SSO_SECRET,{algorithms:['HS256'],issuer:'study-birds',audience:'study-birds-crm'});
    assert.equal(claims.sub,'site-id');assert.equal(claims.companyId,'one');assert.equal(claims.exp-claims.iat,60);assert.ok(claims.jti);
    return {ok:true,json:async()=>({token:'session',user:{id:'crm-id'}})};
  }});
  assert.equal(result.webOrigin,'https://crm-web.example.test');
});
