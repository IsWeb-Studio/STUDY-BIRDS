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
    const app=express();app.use(express.json());
    const protect=require('../src/middleware/authMiddleware').protect;
    const financeController=require('../src/controllers/adminStudentModulesController');
    app.patch('/api/crm/guarded-invoices/:id',protect,financeController.updateStudentInvoiceAdmin);
    app.patch('/api/crm/guarded-universities/:id',protect,require('../src/middleware/employeeAccess').requireSection('universities'),require('../src/controllers/universityController').updateUniversity);
    app.delete('/api/crm/guarded-invoices/:id',protect,financeController.deleteStudentInvoiceAdmin);
    const supportController=require('../src/controllers/adminAgentController');
    const section=require('../src/middleware/employeeAccess').requireSection;
    app.get('/api/crm/support/:id',protect,section('support'),supportController.getSupportTicketAdmin);
    app.patch('/api/crm/support/:id/reply',protect,section('support'),supportController.replySupportTicketAdmin);
    app.patch('/api/crm/support/:id/assign',protect,section('support'),supportController.assignSupportTicketAdmin);
    app.get('/api/crm/housing-pages',protect,require('../src/middleware/employeeAccess').requireSection('housing'),require('../src/controllers/accommodationController').getAccommodationBookingsAdmin);
    app.get('/api/crm/visa-pages',protect,require('../src/middleware/employeeAccess').requireSection('visa'),require('../src/controllers/visaCaseController').listVisaCases);
    const community=require('../src/controllers/communityController'),rewards=require('../src/controllers/studentRewardsController');
    app.get('/api/crm/community-posts',protect,section('community'),community.listPostsAdmin);
    app.patch('/api/crm/community-comments/:id',protect,section('community'),community.moderateComment);
    app.post('/api/crm/community-suspensions',protect,section('community'),community.suspendUser);
    app.delete('/api/crm/community-suspensions/:userId',protect,section('community'),community.liftSuspension);
    app.put('/api/crm/community-settings',protect,section('community'),community.updateSettingsAdmin);
    app.post('/api/crm/reward-rules',protect,section('student-financials'),rewards.saveRule);
    app.put('/api/crm/reward-rules/:id',protect,section('student-financials'),rewards.saveRule);
    app.get('/api/crm/wallet-pages',protect,section('student-financials'),require('../src/controllers/studentWalletController').getWalletEntriesAdmin);
    app.get('/api/crm/student-listings',protect,section('community'),require('../src/controllers/studentListingsController').list(true));
    app.post('/api/crm/student-listings',protect,section('community'),require('../src/controllers/studentListingsController').save);
    app.put('/api/crm/student-listings/:id',protect,section('community'),require('../src/controllers/studentListingsController').save);
    const catalogAdmin=require('../src/controllers/adminController'),catalogUniversity=require('../src/controllers/universityController'),catalogProgram=require('../src/controllers/programController'),catalogField=require('../src/controllers/studyFieldController');
    for(const [path,permission,create,update,remove] of [
      ['services','services',catalogAdmin.createOurService,catalogAdmin.updateOurService,catalogAdmin.deleteOurService],
      ['countries','countries',catalogAdmin.createCountry,catalogAdmin.updateCountry,catalogAdmin.deleteCountry],
      ['universities','universities',catalogUniversity.createUniversity,catalogUniversity.updateUniversity,catalogUniversity.deleteUniversity],
      ['programs','programs',catalogProgram.createProgram,catalogProgram.updateProgram,catalogProgram.deleteProgram],
      ['fields','study-fields',catalogField.createStudyField,catalogField.updateStudyField,catalogField.deleteStudyField]
    ]){app.post(`/api/crm/catalog-${path}`,protect,section(permission),create);app.put(`/api/crm/catalog-${path}/:id`,protect,section(permission),update);app.delete(`/api/crm/catalog-${path}/:id`,protect,section(permission),remove);}
    for(const [path,permission,create,update,remove] of [
      ['testimonials','testimonials',catalogAdmin.createTestimonial,catalogAdmin.updateTestimonial,catalogAdmin.deleteTestimonial],
      ['recognitions','recognitions',catalogAdmin.createRecognition,catalogAdmin.updateRecognition,catalogAdmin.deleteRecognition],
      ['exhibitions','exhibitions',catalogAdmin.createExhibitionArticle,catalogAdmin.updateExhibitionArticle,catalogAdmin.deleteExhibitionArticle],
      ['past-events','past-events',catalogAdmin.createPastEvent,catalogAdmin.updatePastEvent,catalogAdmin.deletePastEvent],
      ['faqs','faqs',catalogAdmin.createFaq,catalogAdmin.updateFaq,catalogAdmin.deleteFaq],
      ['knowledge','knowledge-base',supportController.createKnowledgeBaseItemAdmin,supportController.updateKnowledgeBaseItemAdmin,supportController.deleteKnowledgeBaseItemAdmin]
    ]){app.post(`/api/crm/content-${path}`,protect,section(permission),create);app.put(`/api/crm/content-${path}/:id`,protect,section(permission),update);app.delete(`/api/crm/content-${path}/:id`,protect,section(permission),remove);}
    for(const [path,permission,get,save,remove] of [['our-story','our-story',catalogAdmin.getOurStoryAdmin,catalogAdmin.upsertOurStory,catalogAdmin.deleteOurStory],['upcoming-event','upcoming-event',catalogAdmin.getUpcomingEventAdmin,catalogAdmin.upsertUpcomingEvent,catalogAdmin.deleteUpcomingEvent]]){
      app.get(`/api/crm/content-${path}`,protect,section(permission),get);app.put(`/api/crm/content-${path}`,protect,section(permission),save);app.delete(`/api/crm/content-${path}/:id`,protect,section(permission),remove);
    }
    app.use('/api/crm/service-control',require('../src/routes/serviceRequestRoutes'));
    app.use('/api/crm',require('../src/routes/crmRoutes'));app.use(require('../src/middleware/errorMiddleware').errorHandler);
    server=app.listen(0,'127.0.0.1');await new Promise(resolve=>server.once('listening',resolve));
    const base=`http://127.0.0.1:${server.address().port}/api/crm`;
    const token=user=>jwt.sign({userId:String(user._id)},process.env.JWT_SECRET);
    async function request(route,method='GET',body,actor=owner){const response=await fetch(base+route,{method,headers:{Authorization:`Bearer ${token(actor)}`,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});const text=await response.text();let data;try{data=JSON.parse(text);}catch{data=text;}return {status:response.status,body:data};}
    const payload={kind:'student',companyId:'company-default',recordId:'student-one',name:'CRM Student',email:'student@crm.test',password:'StudentUnique!42',profile:{phone:'123'}};
    const created=await request('/accounts','POST',payload);assert.equal(created.status,201);assert.equal(created.body.password,undefined);
    const repeated=await request('/accounts','POST',{...payload,profile:{phone:'456'}});assert.equal(repeated.body._id,created.body._id);assert.equal((await Profile.findOne({user:created.body._id})).phone,'123');
    assert.equal(await User.countDocuments({email:payload.email}),1);
    const student=await User.findById(created.body._id);assert.equal(await student.comparePassword(payload.password),true);
    const changed=await request(`/accounts/${student._id}`,'PATCH',{password:'AnotherUnique!43',profile:{nationality:'Egypt'}});assert.equal(changed.status,200);assert.equal((await User.findById(student._id)).tokenVersion,1);assert.equal((await Profile.findOne({user:student._id})).phone,'123');
    const profileUpdated=await request(`/accounts/${student._id}`,'PATCH',{profile:{otherLanguages:['English','Turkish'],parentInfo:{name:'Parent',phone:'456',relationship:'Father'},englishTest:{exam:'IELTS',score:'7'}}});assert.equal(profileUpdated.status,200);assert.deepEqual((await Profile.findOne({user:student._id})).otherLanguages.toObject(),['English','Turkish']);
    assert.equal((await request(`/accounts/${student._id}`,'PATCH',{profile:{parentInfo:{role:'admin'}}})).status,400);
    assert.equal((await request('/accounts','POST',{...payload,recordId:'other'})).status,409);
    assert.equal((await request('/accounts','POST',{...payload,email:'injected@crm.test',role:'admin'})).status,400);
    const unlinked=await User.create({name:'Existing',email:'existing@crm.test',role:'student',password:'OriginalUnique!42'});
    const linked=await request('/accounts/link','POST',{accountId:String(unlinked._id),companyId:'company-default',recordId:'existing',kind:'student',email:unlinked.email});assert.equal(linked.status,200);assert.equal(await (await User.findById(unlinked._id)).comparePassword('OriginalUnique!42'),true);
    const employee=await User.create({name:'Limited',email:'limited@crm.test',role:'employee',permissions:['applications']});
    assert.equal((await request('/accounts','POST',{...payload,email:'forbidden@crm.test'},employee)).status,403);
    const supportAdvisor=await User.create({name:'Support Advisor',email:'support@crm.test',role:'employee',employeeRole:'educational_consultant',permissions:['support']});
    const assignees=await request('/support-assignees');assert.equal(assignees.status,200);assert.ok(assignees.body.some(row=>row._id===String(supportAdvisor._id)));assert.ok(!assignees.body.some(row=>row._id===String(employee._id)));assert.equal(assignees.body[0].password,undefined);
    assert.equal((await request('/support-assignees','GET',undefined,employee)).status,403);
    const ticket=await require('../src/models/SupportTicket').create({user:student._id,requesterRole:'student',subject:'CRM support',message:'Help'});
    assert.equal((await request(`/support/${ticket._id}/assign`,'PATCH',{assignedTo:String(employee._id)})).status,400);
    assert.equal((await request(`/support/${ticket._id}/assign`,'PATCH',{assignedTo:String(supportAdvisor._id)})).status,200);
    const ticketDetails=await request(`/support/${ticket._id}`);assert.equal(ticketDetails.status,200);assert.equal(ticketDetails.body.assignedTo.name,'Support Advisor');
    assert.equal((await request(`/support/${ticket._id}`,'GET',undefined,employee)).status,403);
    assert.equal((await request(`/support/${ticket._id}/assign`,'PATCH',{assignedTo:'bad'})).status,400);
    assert.equal((await request(`/support/${ticket._id}/reply`,'PATCH',{message:'   '})).status,400);
    assert.equal((await request(`/support/${ticket._id}/reply`,'PATCH',{message:'Bad',status:'invalid'})).status,400);
    const replied=await request(`/support/${ticket._id}/reply`,'PATCH',{message:'Reply from CRM',status:'answered'},supportAdvisor);assert.equal(replied.status,200);assert.equal(replied.body.replies[0].message,'Reply from CRM');
    assert.equal((await request(`/support/${ticket._id}/assign`,'PATCH',{assignedTo:null})).body.assignedTo,null);
    const concurrentReplies=await Promise.all(['First simultaneous reply','Second simultaneous reply'].map(message=>request(`/support/${ticket._id}/reply`,'PATCH',{message,status:'answered'},supportAdvisor)));
    assert(concurrentReplies.every(row=>row.status===200));
    const afterReplies=await request(`/support/${ticket._id}`);assert.equal(afterReplies.body.replies.length,3);assert(afterReplies.body.replies.every(row=>row.user.name==='Support Advisor'));

    const newPartner={companyId:'company-default',recordId:'agent-one',name:'CRM Agency',email:'new-agent@crm.test',password:'AgentUnique!42',profile:{companyName:'New agency'}};
    const agentCreated=await request('/partners','POST',newPartner);assert.equal(agentCreated.status,201);assert.equal(agentCreated.body.password,undefined);assert.equal(agentCreated.body.role,'partner');
    const agentRetry=await request('/partners','POST',{...newPartner,profile:{companyName:'Must not overwrite'}});assert.equal(agentRetry.body._id,agentCreated.body._id);assert.equal(agentRetry.body.profile.companyName,'New agency');
    assert.equal(await User.countDocuments({email:newPartner.email}),1);assert.equal(await (await User.findById(agentCreated.body._id)).comparePassword(newPartner.password),true);
    assert.equal((await request('/partners','POST',{...newPartner,recordId:'different'})).status,409);
    assert.equal((await request('/partners','POST',{...newPartner,email:'bad-agent@crm.test',recordId:'no-password',password:undefined})).status,400);
    assert.equal((await request('/partners','POST',{...newPartner,role:'admin'})).status,400);
    assert.equal((await request('/partners','POST',newPartner,employee)).status,403);
    const Post=require('../src/models/CommunityPost'),Comment=require('../src/models/CommunityComment');
    const posts=await Post.insertMany(Array.from({length:301},(_,i)=>({author:student._id,title:`Post ${i}`,body:'Body',commentCount:i===0?1:0})));
    const postPage=await request('/community-posts?crmPagination=1&page=4&limit=100');assert.equal(postPage.status,200);assert.equal(postPage.body.items.length,1);assert.equal(postPage.body.pagination.total,301);
    const comment=await Comment.create({post:posts[0]._id,author:student._id,body:'Comment'});
    assert.equal((await request(`/community-comments/${comment._id}`,'PATCH',{status:'hidden',moderationNote:'Spam'})).status,200);assert.equal((await Post.findById(posts[0]._id)).commentCount,0);
    assert.equal((await request(`/community-comments/${comment._id}`,'PATCH',{status:'published',moderationNote:'Restored'})).status,200);assert.equal((await Post.findById(posts[0]._id)).commentCount,1);
    assert.equal((await request('/community-settings','PUT',{blockedTerms:['spam','spam']})).body.blockedTerms.length,1);
    assert.equal((await request('/community-settings','PUT',{blockedTerms:['spam']},employee)).status,403);
    assert.equal((await request('/community-suspensions','POST',{user:String(student._id),days:2,reason:'Spam'})).status,201);
    assert.equal((await request(`/community-suspensions/${student._id}`,'DELETE',{note:'Reviewed'})).status,200);
    assert.equal(await User.countDocuments({_id:student._id}),1);
    const offer=await request('/student-listings','POST',{kind:'offer',title:'Student offer',published:false,url:'https://example.test/offer'});assert.equal(offer.status,201);
    assert.equal((await request(`/student-listings/${offer.body._id}`,'PUT',{kind:'offer',title:'Updated offer',published:true})).status,200);
    assert.equal((await request(`/student-listings/${offer.body._id}`,'PUT',{kind:'opportunity',title:'Cannot change kind',published:true})).status,404);
    await require('../src/models/StudentListing').insertMany(Array.from({length:201},(_,i)=>({kind:'opportunity',title:`Opportunity ${i}`,published:false})));
    assert.equal((await request('/student-listings?kind=opportunity&crmPagination=1&page=3&limit=100')).body.items.length,1);
    const Wallet=require('../src/models/StudentWalletEntry');
    await Wallet.insertMany(Array.from({length:301},()=>({student:student._id,direction:'credit',kind:'adjustment',amount:1,notes:'Test'})));
    const walletPage=await request('/wallet-pages?crmPagination=1&page=4&limit=100');assert.equal(walletPage.body.items.length,1);assert.equal(walletPage.body.pagination.total,301);
    const reward=await request('/reward-rules','POST',{event:'application-submitted',title:'Application',points:20,enabled:false});assert.equal(reward.status,201);
    assert.equal((await request(`/reward-rules/${reward.body._id}`,'PUT',{event:'application-submitted',title:'Updated',points:30,enabled:false})).status,200);
    assert.equal((await request(`/reward-rules/${reward.body._id}`,'PUT',{event:'final-admission',title:'Invalid',points:30,enabled:false})).status,409);
    const partner=await User.create({name:'Partner',email:'partner@crm.test',role:'partner'});
    const editedPartner=await request(`/partners/${partner._id}`,'PATCH',{version:partner.__v,name:'Updated Partner',profile:{companyName:'Agency',taxId:'123',phone:'456'}});assert.equal(editedPartner.status,200);assert.equal(editedPartner.body.profile.companyName,'Agency');
    assert.equal((await request(`/partners/${partner._id}`,'PATCH',{version:partner.__v,name:'Stale'})).status,409);
    assert.equal((await request(`/partners/${partner._id}`,'PATCH',{profile:{verificationStatus:'verified'}})).status,400);
    assert.equal((await request(`/partners/${partner._id}`,'PATCH',{name:'Forbidden'},employee)).status,403);
    const university=await require('../src/models/University').create({name:'Website University',country:new mongoose.Types.ObjectId()});
    const universityFields=await request(`/guarded-universities/${university._id}`,'PATCH',{name:university.name,country:String(university.country),requiredDocuments:['Passport'],accreditations:[{name:'QA Accreditation',logo:'https://example.test/logo.png'}]});assert.equal(universityFields.status,200);assert.deepEqual(universityFields.body.requiredDocuments,['Passport']);assert.equal(universityFields.body.accreditations[0].name,'QA Accreditation');
    const preserveUniversity=await request(`/guarded-universities/${university._id}`,'PATCH',{name:university.name,country:String(university.country),city:'Updated city'});assert.equal(preserveUniversity.status,200);assert.deepEqual(preserveUniversity.body.requiredDocuments,['Passport']);assert.equal(preserveUniversity.body.accreditations[0].name,'QA Accreditation');
    assert.equal((await request(`/guarded-universities/${university._id}`,'PATCH',{name:'Forbidden'},employee)).status,403);
    const program=await require('../src/models/Program').create({university:university._id,title:'Engineering',degreeLevel:'Bachelor',fieldOfStudy:'Engineering',requiredDocumentTypes:[]});
    const Booking=require('../src/models/AccommodationBooking');
    await Booking.insertMany(Array.from({length:501},(_,i)=>({student:student._id,listing:new mongoose.Types.ObjectId(),notes:`Booking ${i}`})));
    const bookings1=await request('/housing-pages?crmPagination=1&page=1&limit=100');const bookings6=await request('/housing-pages?crmPagination=1&page=6&limit=100');
    assert.equal(bookings1.status,200);assert.equal(bookings1.body.items.length,100);assert.equal(bookings1.body.pagination.total,501);assert.equal(bookings6.body.items.length,1);assert.equal(bookings6.body.pagination.hasNextPage,false);
    assert.equal((await request('/housing-pages')).body.length,500);assert.equal((await request('/housing-pages?crmPagination=1','GET',undefined,employee)).status,403);
    const PageApplication=require('../src/models/Application');
    await PageApplication.insertMany(Array.from({length:503},(_,i)=>({student:student._id,program:program._id,university:university._id,status:'submitted',detailedStatus:i<3?'final-admission':'submitted',updatedAt:new Date(Date.now()+i*1000)})));
    const visa1=await request('/visa-pages?crmPagination=1&page=1&limit=2'),visa2=await request('/visa-pages?crmPagination=1&page=2&limit=2');
    assert.equal(visa1.status,200);assert.equal(visa1.body.pagination.total,3);assert.equal(visa1.body.items.length,2);assert.equal(visa2.body.items.length,1);assert.equal(visa2.body.pagination.hasNextPage,false);
    assert.equal(new Set([...visa1.body.items,...visa2.body.items].map(row=>row.applicationId)).size,3);
    await PageApplication.deleteMany({});

    const application=await request('/applications','POST',{studentId:String(student._id),programId:String(program._id),notes:'CRM application'});assert.equal(application.status,201);
    const repeatApplication=await request('/applications','POST',{studentId:String(student._id),programId:String(program._id)});assert.equal(repeatApplication.body._id,application.body._id);
    assert.equal(await require('../src/models/Application').countDocuments({student:student._id,program:program._id}),1);
    await require('../src/models/Application').init();
    const variant=await require('../src/models/Program').create({university:university._id,title:'Engineering',degreeLevel:'Bachelor',fieldOfStudy:'Engineering',language:'Turkish',requiredDocumentTypes:[]});
    const concurrent=await Promise.all(Array.from({length:3},()=>request('/applications','POST',{studentId:String(student._id),programId:String(variant._id)})));
    assert.ok(concurrent.every(result=>[200,201].includes(result.status)));assert.equal(new Set(concurrent.map(result=>result.body._id)).size,1);
    const updateApplication=await request(`/applications/${application.body._id}`,'PATCH',{notes:'Updated',intake:'Autumn 2026',crmDetails:{applicationRefNo:'CRM-APP-1'}});assert.equal(updateApplication.status,200);assert.equal(updateApplication.body.crmDetails.applicationRefNo,'CRM-APP-1');
    const Application=require('../src/models/Application');
    for(const detailedStatus of ['payment-required','payment-verification','visa-preparation','completed']){
      await Application.updateOne({_id:application.body._id},{$set:{detailedStatus}});
      const current=await Application.findById(application.body._id);
      const saved=await request(`/applications/${current._id}`,'PATCH',{version:current.__v,notes:`Keep ${detailedStatus}`});
      assert.equal(saved.status,200);assert.equal(saved.body.detailedStatus,detailedStatus);assert.equal(saved.body.__v,current.__v+1);
      assert.equal((await request(`/applications/${current._id}`,'PATCH',{version:current.__v,notes:'stale'})).status,409);
    }
    await Application.updateOne({_id:application.body._id},{$set:{detailedStatus:'under-review',status:'under-review'}});
    const assigned=await Application.findById(application.body._id);
    const assignment=await request(`/applications/${assigned._id}`,'PATCH',{version:assigned.__v,advisorId:String(employee._id),notes:'Assigned from native CRM'});
    assert.equal(assignment.status,200);assert.equal(assignment.body.assignedAdvisor,String(employee._id));assert.equal(assignment.body.assignmentHistory.length,1);
    const parallelVersion=assignment.body.__v;
    const raced=await Promise.all([request(`/applications/${assigned._id}`,'PATCH',{version:parallelVersion,notes:'Staff one'}),request(`/applications/${assigned._id}`,'PATCH',{version:parallelVersion,notes:'Staff two'})]);
    assert.deepEqual(raced.map(result=>result.status).sort(),[200,409]);
    const storage=require('../src/utils/privateDocumentStorage'),originalUpload=storage.uploadPrivateDocument;storage.uploadPrivateDocument=async()=>({publicId:'isolated-document',resourceType:'raw',deliveryType:'authenticated'});
    try{
      const form=new FormData();form.set('type','passport');form.set('file',new Blob(['%PDF-1.4\nIsolated document\n'],{type:'application/pdf'}),'passport.pdf');
      const upload=await fetch(`${base}/applications/${application.body._id}/documents`,{method:'POST',headers:{Authorization:`Bearer ${token(owner)}`},body:form});assert.equal(upload.status,201);const document=await upload.json();
      const saved=await require('../src/models/Document').findById(document._id);assert.equal(String(saved.student),String(student._id));assert.equal(document.storage,undefined);
      const detached=await request(`/applications/${application.body._id}/documents/${document._id}`,'DELETE');assert.equal(detached.status,200);assert.ok(await require('../src/models/Document').exists({_id:document._id}));
      const service=await require('../src/models/ServiceRequest').create({student:student._id,service:new mongoose.Types.ObjectId(),serviceTitle:'Translation'});
      const serviceForm=new FormData();serviceForm.set('file',new Blob(['%PDF-1.4\nService file\n'],{type:'application/pdf'}),'service.pdf');
      const serviceUpload=await fetch(`${base}/service-requests/${service._id}/documents`,{method:'POST',headers:{Authorization:`Bearer ${token(owner)}`},body:serviceForm});assert.equal(serviceUpload.status,201);
      const serviceDocument=await serviceUpload.json();assert.equal(serviceDocument.storage,undefined);assert.ok(await require('../src/models/ServiceRequest').exists({_id:service._id,'documents._id':serviceDocument._id}));
      assert.equal((await request(`/service-requests/${service._id}/documents/${new mongoose.Types.ObjectId()}/access`,'POST')).status,404);
      const countryCreated=await request('/catalog-countries','POST',{name:'QA Catalog Country',code:'QA'});assert.equal(countryCreated.status,201);
    const cid=countryCreated.body._id;
    assert.equal((await request(`/catalog-countries/${cid}`,'PUT',{name:'Updated Catalog Country',code:'QA'})).status,200);
    const fieldCreated=await request('/catalog-fields','POST',{name:'QA Catalog Field',featured:true});assert.equal(fieldCreated.status,201);
    const fid=fieldCreated.body._id;
    assert.equal((await request(`/catalog-fields/${fid}`,'PUT',{name:'QA Catalog Field',description:'Updated',featured:true})).status,200);
    const uniCreated=await request('/catalog-universities','POST',{name:'QA Catalog University',country:cid,city:'QA City'});assert.equal(uniCreated.status,201);
    const uid=uniCreated.body._id;
    assert.equal((await request(`/catalog-universities/${uid}`,'PUT',{name:'Updated Catalog University',country:cid,city:'Updated City'})).status,200);
    const programBody={title:'QA Program',university:uid,degreeLevel:'Bachelor',fieldOfStudy:'QA Catalog Field',language:'English',tuition:100};
    const programCreated=await request('/catalog-programs','POST',programBody);assert.equal(programCreated.status,201);const pid=programCreated.body._id;
    assert.equal((await request(`/catalog-programs/${pid}`,'PUT',{...programBody,title:'Updated QA Program',tuition:200})).status,200);
    assert.equal((await request(`/catalog-countries/${cid}`,'DELETE')).status,409);
    assert.equal((await request(`/catalog-universities/${uid}`,'DELETE')).status,409);
    assert.equal((await request(`/catalog-fields/${fid}`,'DELETE')).status,409);
    assert.equal((await request('/catalog-countries','POST',{name:'Forbidden',code:'XX'},employee)).status,403);
    assert.equal((await request(`/catalog-programs/${pid}`,'DELETE')).status,200);
    assert.equal((await request(`/catalog-fields/${fid}`,'DELETE')).status,200);
    assert.equal((await request(`/catalog-universities/${uid}`,'DELETE')).status,200);
    assert.equal((await request(`/catalog-countries/${cid}`,'DELETE')).status,200);
  }finally{storage.uploadPrivateDocument=originalUpload;}
    {
    const serviceCreated=await request('/catalog-services','POST',{title:'QA Service',price:250,durationDays:3,journeyStage:'arrival'});
    assert.equal(serviceCreated.status,201);assert.equal(serviceCreated.body.price,250);assert.equal(serviceCreated.body.durationDays,3);
    const serviceId=serviceCreated.body._id;
    const serviceChanged=await request(`/catalog-services/${serviceId}`,'PUT',{title:'QA Service Updated',price:300,durationDays:4,journeyStage:'registration'});
    assert.equal(serviceChanged.status,200);assert.equal(serviceChanged.body.price,300);assert.equal(serviceChanged.body.journeyStage,'registration');
    const preserved=await request(`/catalog-services/${serviceId}`,'PUT',{title:'QA Service Updated',detailBody:'Updated text'});
    assert.equal(preserved.body.price,300);assert.equal(preserved.body.durationDays,4);assert.equal(preserved.body.journeyStage,'registration');
    assert.equal((await request(`/catalog-services/${serviceId}`,'PUT',{price:-1})).status,400);
    assert.equal((await request(`/catalog-services/${serviceId}`,'PUT',{durationDays:1.5})).status,400);
    const serviceStaff=await User.create({name:'Service Staff',email:'service-staff@crm.test',role:'employee',permissions:['services'],isActive:true});
    const inactiveStaff=await User.create({name:'Inactive Staff',email:'service-inactive@crm.test',role:'employee',permissions:['services'],isActive:false});
    const assignees=await request('/service-assignees');assert.equal(assignees.status,200);assert(assignees.body.some(row=>row._id===String(serviceStaff._id)));assert(!assignees.body.some(row=>row._id===String(inactiveStaff._id)));assert(assignees.body.every(row=>!row.password));
    assert.equal((await request('/service-assignees','GET',undefined,employee)).status,403);
    const serviceRequest=await require('../src/models/ServiceRequest').create({student:student._id,service:serviceId,serviceTitle:'QA Service Updated',price:300});
    const servicePath=`/service-control/${serviceRequest._id}`;
    const assigned=await request(servicePath,'PATCH',{status:'assigned',assignedTo:String(serviceStaff._id),staffNote:'Follow up',expectedVersion:0},serviceStaff);
    assert.equal(assigned.status,200);assert.equal(assigned.body.assignedTo._id,String(serviceStaff._id));assert.equal(assigned.body.__v,1);
    assert.equal((await request(servicePath,'PATCH',{status:'in-progress',expectedVersion:0})).status,409);
    assert.equal((await request(servicePath,'PATCH',{assignedTo:String(inactiveStaff._id),expectedVersion:1})).status,400);
    assert.equal((await request(servicePath,'PATCH',{assignedTo:String(student._id),expectedVersion:1})).status,400);
    const unassigned=await request(servicePath,'PATCH',{assignedTo:null,status:'in-progress',expectedVersion:1});assert.equal(unassigned.status,200);assert.equal(unassigned.body.assignedTo,null);
    assert.equal((await request(servicePath+'/driver','PATCH',{name:'Driver',phone:'123',etaMinutes:15})).status,200);
    assert.equal((await request(`/catalog-services/${serviceId}`,'DELETE')).status,409);
    await require('../src/models/ServiceRequest').deleteOne({_id:serviceRequest._id});
    assert.equal((await request(`/catalog-services/${serviceId}`,'DELETE')).status,200);
    }
    {
    const contentFixtures={testimonials:{studentName:'QA Student',quote:'QA quote'},recognitions:{title:'QA Recognition'},exhibitions:{title:'QA Article',summary:'QA summary',body:'QA Body',articleHeadings:['First'],articleBodies:['First body'],seoTitle:'QA SEO',published:false},'past-events':{title:'QA Past Event',mediaItems:[{type:'image',url:'https://example.test/image.jpg'}]},faqs:{question:'QA Question',answer:'QA Answer'},knowledge:{title:'QA Knowledge',body:'QA Body',resourceType:'pdf',fileUrl:'https://example.test/resource.pdf',targetRole:'student',published:false}};
    for(const [path,body] of Object.entries(contentFixtures)){
      const created=await request(`/content-${path}`,'POST',body);assert.equal(created.status,201,`${path}: ${JSON.stringify(created.body)}`);const recordId=created.body._id;
      const updated=await request(`/content-${path}/${recordId}`,'PUT',{...created.body,...body,...(path==='testimonials'?{quote:'Updated quote'}:path==='faqs'?{answer:'Updated answer'}:{title:'Updated content'})});assert.equal(updated.status,200);
      if(path==='exhibitions'){assert.equal(updated.body.seoTitle,'QA SEO');assert.deepEqual(updated.body.articleBodies,['First body']);}
      if(path==='past-events')assert.equal(updated.body.mediaItems.length,1);
      if(path==='knowledge'){assert.equal(updated.body.resourceType,'pdf');assert.equal(updated.body.targetRole,'student');}
      assert.equal((await request(`/content-${path}/${recordId}`,'DELETE',undefined,employee)).status,403);
      assert.equal((await request(`/content-${path}/${recordId}`,'DELETE')).status,200);
    }
    const storyBody={heroTitle:'QA Story',founders:[{name:'Founder',role:'Director'}],timelineItems:[{year:'2026',title:'Started',body:'Story'}],impactStats:[{value:'100',label:'Students'}],isPublished:true};
    assert.equal((await request('/content-our-story')).body._id,undefined);
    const story=await request('/content-our-story','PUT',storyBody);assert.equal(story.status,201);assert.equal(story.body.founders[0].name,'Founder');
    const storyUpdate=await request('/content-our-story','PUT',{...storyBody,heroTitle:'Updated story'});assert.equal(storyUpdate.status,200);assert.equal(storyUpdate.body._id,story.body._id);assert.equal(storyUpdate.body.timelineItems.length,1);
    assert.equal((await request(`/content-our-story/${story.body._id}`,'DELETE')).status,200);assert.equal((await request('/content-our-story')).body._id,undefined);
    const upcoming=await request('/content-upcoming-event','PUT',{title:'QA Upcoming',isPublished:true});assert.equal(upcoming.status,201);
    const registration=await require('../src/models/EventRegistration').create({name:'Registrant',phone:'123',fieldOfInterest:'Engineering',currentCountry:'Egypt',desiredStudyCountry:'Turkey',upcomingEvent:upcoming.body._id});
    assert.equal((await request(`/content-upcoming-event/${upcoming.body._id}`,'DELETE')).status,409);
    assert.equal((await request('/content-upcoming-event','PUT',{title:'QA Upcoming',isPublished:false})).status,200);
    await require('../src/models/EventRegistration').deleteOne({_id:registration._id});
    assert.equal((await request(`/content-upcoming-event/${upcoming.body._id}`,'DELETE')).status,200);assert.equal((await request('/content-upcoming-event')).body._id,undefined);
    }
    const invoice=await request('/invoices','POST',{studentId:String(student._id),companyId:'company-default',recordId:'INV-100',invoiceNumber:'INV-100',description:'Education',amount:1000,currency:'USD'});assert.equal(invoice.status,201);
    const same=await request('/invoices','POST',{studentId:String(student._id),companyId:'company-default',recordId:'INV-100',invoiceNumber:'INV-100',description:'Education',amount:1000,currency:'USD'});assert.equal(same.body._id,invoice.body._id);
    const partial=await request(`/invoices/${invoice.body._id}/payments`,'PATCH',{paidAmount:300,version:invoice.body.__v});assert.equal(partial.status,200);assert.equal(partial.body.crmPaidAmount,300);assert.equal(partial.body.status,'unpaid');
    assert.equal((await request(`/invoices/${invoice.body._id}/payments`,'PATCH',{paidAmount:400,version:invoice.body.__v})).status,409);
    assert.equal((await request(`/invoices/${invoice.body._id}`,'DELETE')).status,409);
    assert.equal((await request(`/guarded-invoices/${invoice.body._id}`,'PATCH',{amount:200,version:partial.body.__v})).status,409);
    assert.equal((await request(`/guarded-invoices/${invoice.body._id}`,'PATCH',{status:'rejected',version:partial.body.__v})).status,409);
    assert.equal((await request(`/guarded-invoices/${invoice.body._id}`,'DELETE')).status,409);
    const financialNotes=await request(`/guarded-invoices/${invoice.body._id}`,'PATCH',{adminNote:'Preserve partial payment',version:partial.body.__v});assert.equal(financialNotes.status,200);assert.equal(financialNotes.body.crmPaidAmount,300);
    assert.equal((await request(`/guarded-invoices/${invoice.body._id}`,'PATCH',{adminNote:'Stale',version:partial.body.__v})).status,409);
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
    const reconciliation=await request(`/invoices/${proofInvoice._id}/reconciliation`);assert.equal(reconciliation.status,200);assert.equal(reconciliation.body.proofs.length,1);assert.equal(reconciliation.body.proofs[0].filePath,undefined);
    assert.equal((await request(`/invoices/${invoice.body._id}/reconciliation`,'GET',undefined,anotherOwner)).status,404);
  }finally{if(server)await new Promise(resolve=>server.close(resolve));await mongoose.disconnect();await mongo.stop();}
});
