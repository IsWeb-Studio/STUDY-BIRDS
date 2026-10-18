const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const express = require('express');
const mongoose = require('mongoose');
const { EventEmitter } = require('node:events');
const { MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));
Object.assign(process.env, { JWT_SECRET: 'upload-security-test', CLOUDINARY_CLOUD_NAME: 'test-cloud', CLOUDINARY_API_KEY: 'test', CLOUDINARY_API_SECRET: 'test-secret' });
const { cloudinary } = require('../src/config/cloudinary');
const { checkFile } = require('../src/utils/fileSafety');
const { uploadFileToCloudinary } = require('../src/utils/uploadToCloudinary');
const { legacyAsset } = require('../src/utils/legacyDocumentStorage');
const { migrateVerificationDocument } = require('../src/utils/verificationDocumentMigration');
const file = { originalname: 'identity.pdf', mimetype: 'application/pdf', buffer: Buffer.from('%PDF-1.7\nfixture'), size: 16 };

test('Office/ZIP containers fail closed regardless of MIME and forged signature', () => {
  for (const [ext, mime] of [['doc','application/msword'], ['docx','application/vnd.openxmlformats-officedocument.wordprocessingml.document'], ['xlsx','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'], ['pptx','application/vnd.openxmlformats-officedocument.presentationml.presentation'], ['xls','application/vnd.ms-excel'], ['ppt','application/vnd.ms-powerpoint'], ['zip','application/zip']]) {
    for (const signature of ['504b0304','d0cf11e0a1b11ae1']) {
      assert.throws(() => checkFile({ originalname: `payload.${ext}`, mimetype: mime, buffer: Buffer.from(signature,'hex') }), { statusCode: 415 });
    }
  }
});

test('public upload IDs are unique under a frozen clock, prevent overwrite and reject unsafe direct callers', async () => {
  const original = cloudinary.uploader.upload_stream, now = Date.now;
  const options = [];
  try {
    Date.now = () => 123456;
    cloudinary.uploader.upload_stream = (opts, callback) => ({ end() {
      options.push(opts);
      callback(null, { public_id: opts.public_id, resource_type: opts.resource_type, secure_url: 'https://example.invalid/file', bytes: file.size });
    } });
    await Promise.all(Array.from({length: 50}, () => uploadFileToCloudinary(file,'test-folder')));
    assert.equal(new Set(options.map(o => o.public_id)).size, 50);
    for (const opts of options) { assert.equal(opts.overwrite,false); assert.match(opts.public_id,/^[a-f0-9-]{36}$/); }
    await assert.rejects(uploadFileToCloudinary({...file,originalname:'a.exe'},'test-folder'), {statusCode:415});
    await assert.rejects(uploadFileToCloudinary(file,'study-birds/agent-verification'), /private storage/);
    cloudinary.uploader.upload_stream = (opts, callback) => ({ end() { callback(null,{public_id:opts.public_id, existing:true}); } });
    await assert.rejects(uploadFileToCloudinary(file,'test-folder'), /new asset/);
    cloudinary.uploader.upload_stream = () => { const stream = new EventEmitter(); stream.end=()=>stream.emit('error',new Error('transport failed')); return stream; };
    await assert.rejects(uploadFileToCloudinary(file,'test-folder'), /transport failed/);
  } finally { cloudinary.uploader.upload_stream=original; Date.now=now; }
});

test('verification migration handles signed URLs, retries and refuses a still-public original or foreign assets', async () => {
  const document={filePath:'https://res.cloudinary.com/test-cloud/image/upload/s--signature--/study-birds/agent-verification/old.pdf'};
  const source=legacyAsset(document.filePath,'test-cloud');
  assert.equal(source.publicId,'study-birds/agent-verification/old');
  let moved=false, remainsPublic=false;
  const provider={ uploader:{async rename(from,to,options){
    assert.equal(from,source.publicId);assert.equal(options.to_type,'authenticated');assert.equal(options.invalidate,true);
    if(moved)throw new Error('already moved');moved=true;
    return {public_id:to,type:'authenticated'};
  }},api:{async resource(id,options){
    if(options.type==='authenticated')return {public_id:source.target,type:'authenticated'};
    if(remainsPublic)return {public_id:id,type:'upload'};
    throw Object.assign(new Error('not found'),{http_code:404});
  }}};
  assert.equal((await migrateVerificationDocument(document,provider,'test-cloud')).deliveryType,'authenticated');
  assert.equal((await migrateVerificationDocument(document,provider,'test-cloud')).deliveryType,'authenticated');
  remainsPublic=true;
  await assert.rejects(migrateVerificationDocument(document,provider,'test-cloud'),/still accessible/);
  await assert.rejects(migrateVerificationDocument({filePath:'https://res.cloudinary.com/other/image/upload/test.pdf'},provider,'test-cloud'));
  await assert.rejects(migrateVerificationDocument({filePath:'https://res.cloudinary.com/test-cloud/image/upload/banners/test.pdf'},provider,'test-cloud'),/folder/);
});

test('verification upload and download enforce private storage and account/section boundaries', async () => {
  const mongo=await MongoMemoryServer.create({instance:{ip:'127.0.0.1'}});
  const original=cloudinary.uploader.upload_stream;
  let server, writes=0;
  try {
    await mongoose.connect(mongo.getUri());
    cloudinary.uploader.upload_stream=(options,cb)=>({end(buffer){
      writes++;assert.equal(options.type,'authenticated');assert.equal(options.overwrite,false);
      cb(null,{public_id:options.public_id,type:'authenticated',bytes:buffer.length});
    }});
    const User=require('../src/models/User');
    const VerificationDocument=require('../src/models/VerificationDocument');
    const token=user=>require('../src/utils/generateToken')(user._id,0);
    const owner=await User.create({name:'Owner',email:'owner@example.test',role:'partner'});
    const other=await User.create({name:'Other',email:'other@example.test',role:'partner'});
    const admin=await User.create({name:'Admin',email:'admin@example.test',role:'admin'});
    const verifier=await User.create({name:'Verifier',email:'verifier@example.test',role:'employee',permissions:['verification']});
    const unrelated=await User.create({name:'Unrelated',email:'unrelated@example.test',role:'employee',permissions:['agents']});
    const app=express();app.use(express.json());
    app.use('/api/partners',require('../src/routes/partnerRoutes'));
    app.use('/api/admin',require('../src/routes/adminRoutes'));
    app.use('/api/verification-documents',require('../src/routes/verificationDocumentAccessRoutes'));
    app.use(require('../src/middleware/errorMiddleware').errorHandler);
    server=await new Promise(resolve=>{const s=app.listen(0,'127.0.0.1',()=>resolve(s));});
    const base=`http://127.0.0.1:${server.address().port}`;
    async function upload(name='identity.pdf',mime='application/pdf',bytes=file.buffer,type='identity'){
      const form=new FormData();form.append('type',type);form.append('file',new Blob([bytes],{type:mime}),name);
      return fetch(base+'/api/partners/verification/documents',{method:'POST',headers:{Authorization:`Bearer ${token(owner)}`},body:form});
    }
    const uploaded=await upload();assert.equal(uploaded.status,201);
    const document=await uploaded.json();assert.equal(writes,1);
    assert.equal(document.filePath,`/api/verification-documents/${document._id}/access`);
    assert.equal(document.storage,undefined);assert.equal(document.legacyFilePath,undefined);
    const saved=await VerificationDocument.findById(document._id).select('+storage');assert.equal(saved.storage.deliveryType,'authenticated');
    for(const [user,status] of [[null,401],[owner,200],[other,404],[admin,200],[verifier,200],[unrelated,404]]){
      const response=await fetch(base+document.filePath,{method:'POST',headers:user?{Authorization:`Bearer ${token(user)}`}:{}});
      assert.equal(response.status,status);
      if(status===200){
        assert.equal(response.headers.get('cache-control'),'no-store');
        const link=await response.json(),url=new URL(link.url);
        assert.equal(url.searchParams.get('type'),'authenticated');assert.equal(url.searchParams.get('attachment'),'true');
        assert.ok(link.expiresAt>Date.now()/1000+110&&link.expiresAt<=Date.now()/1000+120);
      }
    }
    for(const [name,mime,bytes] of [['fake.docx','application/vnd.openxmlformats-officedocument.wordprocessingml.document',Buffer.from('PK')],['a.php','application/pdf',file.buffer],['large.txt','text/plain',Buffer.alloc(5*1024*1024+1,65)]]){
      const response=await upload(name,mime,bytes);assert.ok([413,415].includes(response.status));
    }
    assert.equal((await upload('identity.pdf','application/pdf',file.buffer,'unknown-type')).status,400);
    assert.equal(writes,1,'rejected files never reach Cloudinary');
    const legacy=await VerificationDocument.create({agent:owner._id,type:'identity',fileName:'old.pdf',filePath:'https://res.cloudinary.com/test-cloud/image/upload/old.pdf'});
    assert.equal(legacy.toJSON().filePath,`/api/verification-documents/${legacy._id}/access`);
    assert.equal(VerificationDocument.clientView({...legacy.toObject({transform:false}),storage:{publicId:'secret'},legacyFilePath:'secret'}).storage,undefined);
    const listed=await fetch(base+'/api/partners/verification',{headers:{Authorization:`Bearer ${token(owner)}`}});
    const listing=await listed.json();assert.ok(listing.documents.every(d=>d.filePath.startsWith('/api/verification-documents/')));
    assert.equal((await fetch(base+legacy.toJSON().filePath,{method:'POST',headers:{Authorization:`Bearer ${token(owner)}`}})).status,409);
    for (const route of [`/api/admin/partners/${owner._id}`, '/api/admin/verification-documents']) {
      const response = await fetch(base+route, {headers:{Authorization:`Bearer ${token(admin)}`}});
      assert.equal(response.status,200);
      const body = await response.json();
      const documents = Array.isArray(body) ? body : body.verificationDocuments;
      assert.ok(documents.length >= 2);
      for (const item of documents) {
        assert.ok(item.filePath.startsWith('/api/verification-documents/'));
        assert.equal(item.storage,undefined);assert.equal(item.legacyFilePath,undefined);
      }
    }

  } finally {
    cloudinary.uploader.upload_stream=original;
    if(server)await new Promise(resolve=>server.close(resolve));
    await mongoose.disconnect();await mongo.stop();
  }
});
