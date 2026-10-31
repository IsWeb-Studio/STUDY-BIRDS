const {test}=require('node:test');
const assert=require('node:assert/strict');
const path=require('node:path');
const mongoose=require('mongoose');
const jwt=require('jsonwebtoken');
const {MongoMemoryServer}=require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS,'node_modules/mongodb-memory-server-core'));

test('reviewed assistant: clarification, persistence, ownership, quota and failed-read lock recovery',async()=>{
 process.env.JWT_SECRET='isolated-assistant-test';
 process.env.AI_DAILY_LIMIT='2';
 delete process.env.AI_API_KEY;
 const mongo=await MongoMemoryServer.create({instance:{ip:'127.0.0.1'}});
 let server;
 try {
  await mongoose.connect(mongo.getUri());
  const app=require('../src/app');
  const User=require('../src/models/User');
  const Application=require('../src/models/Application');
  await Promise.all(Object.values(mongoose.models).map(m=>m.init()));
  const [a,b,c]=await User.create(['a','b','c'].map(n=>({name:n,email:n+'@example.test'})));
  server=await new Promise(resolve=>{const s=app.listen(0,'127.0.0.1',()=>resolve(s));});
  const origin=`http://127.0.0.1:${server.address().port}/api/assistant`;
  async function call(route,user,body,status=200){
   const response=await fetch(origin+route,{method:body?'POST':'GET',headers:{'Content-Type':'application/json',...(user?{Authorization:'Bearer '+jwt.sign({userId:user._id},process.env.JWT_SECRET)}:{})},body:body?JSON.stringify(body):undefined});
   const data=await response.json();assert.equal(response.status,status,JSON.stringify(data));return data;
  }
  await call('/threads',null,null,401);
  await call('/message',b,{message:'x'.repeat(2001)},400);
  const config=await call('/config',a);
  assert.equal(config.enabled,true);
  assert.equal(config.knowledgeRevision,'2026.10.31.5');
  const answer=await call('/message',a,{message:'How do I upload documents and apply?'});
  assert.match(answer.messages.at(-1).content,/Which topic/);
  assert.equal(answer.messages.at(-1).actions.length,0);
  assert.equal(answer.messages.at(-1).knowledgeRevision,config.knowledgeRevision);
  assert.equal((await call('/threads',a)).length,1);
  assert.equal((await call('/threads',b)).length,0);
  await call('/threads/'+answer.threadId,b,null,404);
  await call('/message',b,{threadId:answer.threadId,message:'upload documents'},404);
  const docs=await call('/message',a,{threadId:answer.threadId,message:'upload documents'});
  assert.match(docs.messages.at(-1).content,/Open your documents/);
  await call('/message',a,{message:'upload documents'},429);
  assert.equal((await call('/threads/'+answer.threadId,a)).messages.length,4);
  const Thread=mongoose.model('AssistantThread');
  const thread=await Thread.create({user:c._id,title:'Failure recovery'});
  const originalFind=Application.find;
  try {
   Application.find=()=>{throw new Error('Synthetic database failure');};
   await call('/message',c,{threadId:String(thread._id),message:'What is my application status?'},502);
  } finally {Application.find=originalFind;}
  const failed=await Thread.findById(thread._id);
  assert.equal(failed.lockedUntil.getTime(),0);
  assert.equal(failed.messages.length,0);
  await call('/message',c,{threadId:String(thread._id),message:'upload documents'});
  assert.equal(await mongoose.model('AssistantGeneration').countDocuments(),0);
 } finally {
  if(server)await new Promise(resolve=>server.close(resolve));
  await mongoose.disconnect();await mongo.stop();
 }
});
