const {test} = require('node:test');
const assert = require('node:assert/strict');
const {randomBytes, createHash} = require('node:crypto');

test('real middleware accepts service credential, preserves JWT auth, and revokes immediately', {skip:!process.env.CATALOG_TEST_URI}, async()=>{
  const mongoose=require('mongoose');
  const express=require('express');
  const jwt=require('jsonwebtoken');
  const User=require('../src/models/User');
  const {protect,authorize}=require('../src/middleware/authMiddleware');
  const keys=['CRM_SERVICE_AUTH_ENABLED','CRM_SERVICE_TOKEN_SHA256','CRM_SERVICE_USER_ID','JWT_SECRET'];
  const previous=Object.fromEntries(keys.map(k=>[k,process.env[k]]));
  assert.match(process.env.CATALOG_TEST_URI,/^mongodb:\/\/127\.0\.0\.1:\d+\//);
  await mongoose.connect(process.env.CATALOG_TEST_URI);
  let server;
  try {
    const admin=await User.create({name:'Integration admin',email:'service-auth@example.test',role:'admin'});
    const token='sbcrm_'+randomBytes(32).toString('hex');
    process.env.CRM_SERVICE_AUTH_ENABLED='true';
    process.env.CRM_SERVICE_TOKEN_SHA256=createHash('sha256').update(token).digest('hex');
    process.env.CRM_SERVICE_USER_ID=String(admin._id);
    process.env.JWT_SECRET='isolated-service-test';
    const app=express();
    app.use('/api',protect,authorize('admin'),(req,res)=>res.json({id:String(req.user._id),service:!!req.crmServiceAuthenticated}));
    app.use((err,req,res,next)=>res.status(err.status||res.statusCode>=400&&res.statusCode||500).json({failed:true}));
    server=await new Promise(resolve=>{const s=app.listen(0,'127.0.0.1',()=>resolve(s));});
    const call=(credential,path='/api/admin/countries',headers={})=>fetch(`http://127.0.0.1:${server.address().port}${path}`,{headers:{Authorization:'Bearer '+credential,...headers}});
    const response=await call(token);
    assert.equal(response.status,200);assert.deepEqual(await response.json(),{id:String(admin._id),service:true});
    assert.equal((await call(jwt.sign({userId:admin._id},process.env.JWT_SECRET))).status,200);
    assert.equal((await call(jwt.sign({userId:admin._id},process.env.JWT_SECRET,{expiresIn:-1}))).status,401);
    assert.equal((await call(token,'/api/auth/login')).status,403);
    assert.equal((await call(token,'/api/admin/countries',{Origin:'https://example.test'})).status,403);
    process.env.CRM_SERVICE_TOKEN_SHA256='0'.repeat(64);
    assert.equal((await call(token)).status,401);
    process.env.CRM_SERVICE_TOKEN_SHA256=createHash('sha256').update(token).digest('hex');
    await User.updateOne({_id:admin._id},{$set:{isActive:false}});
    assert.equal((await call(token)).status,403);
    await User.updateOne({_id:admin._id},{$set:{isActive:true,role:'student'}});
    assert.equal((await call(token)).status,403);
  } finally {
    if(server)await new Promise(resolve=>server.close(resolve));
    await mongoose.disconnect();
    for(const key of keys)if(previous[key]===undefined)delete process.env[key];else process.env[key]=previous[key];
  }
});
