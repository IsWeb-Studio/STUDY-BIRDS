const test=require('node:test');
const assert=require('node:assert/strict');
const path=require('node:path');
const express=require('express');
const mongoose=require('mongoose');
const jwt=require('jsonwebtoken');
const {MongoMemoryServer}=require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS,'node_modules/mongodb-memory-server-core'));

test('CRM accounts, explicit links, applications and invoice balances use real website records safely',async()=>{
  process.env.JWT_SECRET='crm-isolated-test-secret';
  const mongo=await MongoMemoryServer.create({instance:{ip:'127.0.0.1'}});
  let server;
  try{
    await mongoose.connect(mongo.getUri());
    const User=require('../src/models/User');
    const Profile=require('../src/models/StudentProfile');
    const Invoice=require('../src/models/Invoice');
    const owner=await User.create({name:'Admin',email:'admin@crm.test',role:'admin',password:'AdminUnique!42'});
    const app=express();app.use(express.json());app.use('/api/crm',require('../src/routes/crmRoutes'));app.use(require('../src/middleware/errorMiddleware').errorHandler);
    server=app.listen(0,'127.0.0.1');await new Promise(resolve=>server.once('listening',resolve));
    const base=`http://127.0.0.1:${server.address().port}/api/crm`;
    const token=user=>jwt.sign({userId:String(user._id)},process.env.JWT_SECRET);
    async function request(route,method='GET',body,actor=owner){const response=await fetch(base+route,{method,headers:{Authorization:`Bearer ${token(actor)}`,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});return {status:response.status,body:await response.json()};}
    const payload={kind:'student',companyId:'company-default',recordId:'student-one',name:'CRM Student',email:'student@crm.test',password:'StudentUnique!42',profile:{phone:'123'}};
    const created=await request('/accounts','POST',payload);assert.equal(created.status,201);assert.equal(created.body.password,undefined);
    const repeated=await request('/accounts','POST',{...payload,profile:{phone:'456'}});assert.equal(repeated.body._id,created.body._id);assert.equal((await Profile.findOne({user:created.body._id})).phone,'123');
    assert.equal(await User.countDocuments({email:payload.email}),1);
    const student=await User.findById(created.body._id);assert.equal(await student.comparePassword(payload.password),true);
    const changed=await request(`/accounts/${student._id}`,'PATCH',{password:'AnotherUnique!43',profile:{nationality:'Egypt'}});assert.equal(changed.status,200);assert.equal((await User.findById(student._id)).tokenVersion,1);assert.equal((await Profile.findOne({user:student._id})).phone,'123');
    assert.equal((await request('/accounts','POST',{...payload,recordId:'other'})).status,409);
    assert.equal((await request('/accounts','POST',{...payload,email:'injected@crm.test',role:'admin'})).status,400);
    const unlinked=await User.create({name:'Existing',email:'existing@crm.test',role:'student',password:'OriginalUnique!42'});
    const linked=await request('/accounts/link','POST',{accountId:String(unlinked._id),companyId:'company-default',recordId:'existing',kind:'student',email:unlinked.email});assert.equal(linked.status,200);assert.equal(await (await User.findById(unlinked._id)).comparePassword('OriginalUnique!42'),true);
    const employee=await User.create({name:'Limited',email:'limited@crm.test',role:'employee',permissions:['applications']});
    assert.equal((await request('/accounts','POST',{...payload,email:'forbidden@crm.test'},employee)).status,403);
    const university=await require('../src/models/University').create({name:'Website University',country:new mongoose.Types.ObjectId()});
    const program=await require('../src/models/Program').create({university:university._id,title:'Engineering',degreeLevel:'Bachelor',fieldOfStudy:'Engineering',requiredDocumentTypes:[]});
    const application=await request('/applications','POST',{studentId:String(student._id),programId:String(program._id),notes:'CRM application'});assert.equal(application.status,201);
    const repeatApplication=await request('/applications','POST',{studentId:String(student._id),programId:String(program._id)});assert.equal(repeatApplication.body._id,application.body._id);
    assert.equal(await require('../src/models/Application').countDocuments({student:student._id,program:program._id}),1);
    await require('../src/models/Application').init();
    const variant=await require('../src/models/Program').create({university:university._id,title:'Engineering',degreeLevel:'Bachelor',fieldOfStudy:'Engineering',language:'Turkish',requiredDocumentTypes:[]});
    const concurrent=await Promise.all(Array.from({length:3},()=>request('/applications','POST',{studentId:String(student._id),programId:String(variant._id)})));
    assert.ok(concurrent.every(result=>[200,201].includes(result.status)));assert.equal(new Set(concurrent.map(result=>result.body._id)).size,1);
    const updateApplication=await request(`/applications/${application.body._id}`,'PATCH',{notes:'Updated',intake:'Autumn 2026',crmDetails:{applicationRefNo:'CRM-APP-1'}});assert.equal(updateApplication.status,200);assert.equal(updateApplication.body.crmDetails.applicationRefNo,'CRM-APP-1');
    const storage=require('../src/utils/privateDocumentStorage'),originalUpload=storage.uploadPrivateDocument;storage.uploadPrivateDocument=async()=>({publicId:'isolated-document',resourceType:'raw',deliveryType:'authenticated'});
    try{
      const form=new FormData();form.set('type','passport');form.set('file',new Blob(['%PDF-1.4\nIsolated document\n'],{type:'application/pdf'}),'passport.pdf');
      const upload=await fetch(`${base}/applications/${application.body._id}/documents`,{method:'POST',headers:{Authorization:`Bearer ${token(owner)}`},body:form});assert.equal(upload.status,201);const document=await upload.json();
      const saved=await require('../src/models/Document').findById(document._id);assert.equal(String(saved.student),String(student._id));assert.equal(document.storage,undefined);
      const detached=await request(`/applications/${application.body._id}/documents/${document._id}`,'DELETE');assert.equal(detached.status,200);assert.ok(await require('../src/models/Document').exists({_id:document._id}));
    }finally{storage.uploadPrivateDocument=originalUpload;}
    const invoice=await request('/invoices','POST',{studentId:String(student._id),companyId:'company-default',recordId:'INV-100',invoiceNumber:'INV-100',description:'Education',amount:1000,currency:'USD'});assert.equal(invoice.status,201);
    const same=await request('/invoices','POST',{studentId:String(student._id),companyId:'company-default',recordId:'INV-100',invoiceNumber:'INV-100',description:'Education',amount:1000,currency:'USD'});assert.equal(same.body._id,invoice.body._id);
    const partial=await request(`/invoices/${invoice.body._id}/payments`,'PATCH',{paidAmount:300,version:invoice.body.__v});assert.equal(partial.status,200);assert.equal(partial.body.crmPaidAmount,300);assert.equal(partial.body.status,'unpaid');
    assert.equal((await request(`/invoices/${invoice.body._id}/payments`,'PATCH',{paidAmount:400,version:invoice.body.__v})).status,409);
    assert.equal((await request(`/invoices/${invoice.body._id}`,'DELETE')).status,409);
    const anotherOwner=await User.create({name:'Other',email:'other@crm.test',role:'admin'});assert.equal((await request(`/invoices/${invoice.body._id}`,'GET',undefined,anotherOwner)).status,404);
    assert.equal(await Invoice.countDocuments(),1);
    const websiteInvoice=await Invoice.create({student:student._id,invoiceNumber:'WEB-ORIGINAL',description:'Original website invoice',amount:500});
    const importedPayment=await request(`/invoices/${websiteInvoice._id}/payments`,'PATCH',{paidAmount:125,version:websiteInvoice.__v});
    assert.equal(importedPayment.status,200);assert.equal(importedPayment.body.crmPaidAmount,125);
    assert.equal((await request(`/invoices/${websiteInvoice._id}/payments`,'PATCH',{paidAmount:126,version:websiteInvoice.__v})).status,409);
    const paidElsewhere=await Invoice.create({student:student._id,invoiceNumber:'WEB-PAID',description:'Paid externally',amount:500,status:'paid'});
    assert.equal((await request(`/invoices/${paidElsewhere._id}/payments`,'PATCH',{paidAmount:100,version:paidElsewhere.__v})).status,409);
    const proofInvoice=await Invoice.create({student:student._id,invoiceNumber:'WEB-PROOF',description:'Under review',amount:500});
    await require('../src/models/PaymentProof').create({student:student._id,invoice:proofInvoice._id,amount:100,filePath:'https://example.test/proof.pdf',fileName:'proof.pdf'});
    assert.equal((await request(`/invoices/${proofInvoice._id}/payments`,'PATCH',{paidAmount:100,version:proofInvoice.__v})).status,409);
  }finally{if(server)await new Promise(resolve=>server.close(resolve));await mongoose.disconnect();await mongo.stop();}
});
