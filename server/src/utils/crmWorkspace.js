const jwt=require('jsonwebtoken');
const {randomUUID}=require('node:crypto');
function crmWorkspaceConfig(env=process.env) {
  if (!env.CRM_API_URL || !env.CRM_WEB_URL || !env.STUDY_BIRDS_SSO_SECRET || env.STUDY_BIRDS_SSO_SECRET.length < 32) throw Object.assign(new Error('CRM workspace is not configured'),{status:503});
  const api=new URL(env.CRM_API_URL),web=new URL(env.CRM_WEB_URL);
  for (const url of [api,web]) if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash) throw Object.assign(new Error('CRM URLs must use HTTPS without credentials'),{status:503});
  if (web.pathname !== '/' || !api.pathname.replace(/\/$/,'').endsWith('/api')) throw Object.assign(new Error('Invalid CRM API or web URL'),{status:503});
  return {api:api.href.replace(/\/$/,''),web:web.origin,secret:env.STUDY_BIRDS_SSO_SECRET};
}
async function workspaceSession(user,{env=process.env,fetchImpl=fetch}={}) {
  const companyId=user.crmIdentity?.companyId || env.CRM_COMPANY_ID;
  if (!['admin','employee'].includes(user.role) || !companyId) throw Object.assign(new Error('Link this staff account to CRM first'),{status:403});
  const config=crmWorkspaceConfig(env);
  const proof=jwt.sign({companyId},config.secret,{subject:String(user._id),issuer:'study-birds',audience:'study-birds-crm',algorithm:'HS256',expiresIn:60,jwtid:randomUUID()});
  const response=await fetchImpl(`${config.api}/integrations/website/sso`,{method:'POST',redirect:'error',signal:AbortSignal.timeout(15000),headers:{'Content-Type':'application/json'},body:JSON.stringify({proof})});
  const data=await response.json();
  if (!response.ok) throw Object.assign(new Error(data.message || 'CRM sign in failed'),{status:response.status >= 400 && response.status < 500 ? response.status : 502});
  if (!data.token || !data.user) throw Object.assign(new Error('Invalid CRM session response'),{status:502});
  return {...data,webOrigin:config.web};
}
module.exports={crmWorkspaceConfig,workspaceSession};
