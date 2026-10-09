const express = require('express');
const mongoose = require('mongoose');
const User = require('../models/User');
const Profile = require('../models/StudentProfile');
const run = require('../utils/asyncHandler');
const { protect } = require('../middleware/authMiddleware');
const { hasSection, requireSection } = require('../middleware/employeeAccess');
const { accountPayload, safeAccount } = require('../utils/crmAccountPolicy');
const router = express.Router();
const fail = (status, message) => { throw Object.assign(new Error(message), {status}); };
router.use(protect);
router.get('/support-assignees',requireSection('support'),run(async(req,res)=>{
  const staff=await User.find({isActive:true,$or:[{role:'admin'},{role:'employee',permissions:'support'}]})
    .select('_id name email employeeRole').sort({name:1}).lean();
  res.json(staff);
}));
router.use('/invoices',require('./crmFinanceRoutes'));
router.post('/accounts/link',run(async(req,res)=>{
  const body=req.body || {};
  if(Object.keys(body).some(key=>!['accountId','companyId','recordId','kind','email'].includes(key)) || !mongoose.isValidObjectId(body.accountId) || !['student','employee'].includes(body.kind) || !/^[\w-]{1,100}$/.test(body.companyId || '') || !/^[\w-]{1,100}$/.test(body.recordId || '') || typeof body.email!=='string')fail(400,'Invalid account link');
  if(body.kind==='student' ? !hasSection(req.user,'students') : req.user.role!=='admin')fail(403,'Account linking is not permitted');
  const user=await User.findOne({_id:body.accountId,email:body.email.trim().toLowerCase(),role:body.kind==='student'?'student':{$in:['employee','admin']}});
  if(!user)fail(404,'The selected account does not match this CRM record');
  const identity={owner:req.user._id,companyId:body.companyId,recordId:body.recordId};
  if(user.crmIdentity?.recordId && (String(user.crmIdentity.owner)!==String(identity.owner) || user.crmIdentity.companyId!==identity.companyId || user.crmIdentity.recordId!==identity.recordId))fail(409,'Account already has a different CRM identity');
  const linked=await User.findOneAndUpdate({_id:user._id,$or:[{'crmIdentity.recordId':{$exists:false}},{'crmIdentity.owner':identity.owner,'crmIdentity.companyId':identity.companyId,'crmIdentity.recordId':identity.recordId}]},{$set:{crmIdentity:identity}},{new:true,runValidators:true});
  if(!linked)fail(409,'Account was linked by another request');res.json(safeAccount(linked));
}));
router.post('/workspace-session',run(async(req,res)=>{
  const session=await require('../utils/crmWorkspace').workspaceSession(req.user);
  res.set('Cache-Control','no-store').json(session);
}));
router.post('/applications',requireSection('applications'),run(async(req,res)=>{
  const body=req.body || {};
  if (body.intake !== undefined && (typeof body.intake !== 'string' || body.intake.length > 200)) fail(400,'Invalid intake');
  if (Object.keys(body).some(key=>!['studentId','programId','notes','intake'].includes(key)) || !mongoose.isValidObjectId(body.studentId) || !mongoose.isValidObjectId(body.programId) || (body.notes !== undefined && (typeof body.notes !== 'string' || body.notes.length > 2000))) fail(400,'Invalid application fields');
  const Program=require('../models/Program'),Application=require('../models/Application');
  const student=await User.findOne({_id:body.studentId,role:'student',isActive:{$ne:false}});
  const program=await Program.findById(body.programId).populate('university');
  if (!student || !program?.university) fail(404,'Student or program is unavailable');
  const existing=await Application.findOne({student:student._id,program:program._id});
  if (existing) return res.json(existing);
  const profile=await Profile.findOne({user:student._id});
  const requiredDocumentTypes=require('../utils/applicationRequirements').requiredDocumentTypesFor(program);
  let row;
  try {row=await Application.create({crmCreationKey:`${student._id}:${program._id}`,student:student._id,program:program._id,university:program.university._id,requiredDocumentTypes,documents:[],notes:body.notes || '',detailedStatus:requiredDocumentTypes.length ? 'additional-documents-required' : 'submitted',applicantProfile:{name:student.name,email:student.email,phone:profile?.phone,intake:body.intake || profile?.intake,nationality:profile?.nationality},statusTimeline:[{status:'submitted',note:'Created by CRM staff; documents must be reviewed',changedBy:req.user._id}]});}
  catch(error){if(error.code!==11000)throw error;row=await Application.findOne({crmCreationKey:`${student._id}:${program._id}`});if(!row)throw error;return res.json(row);}
  res.status(201).json(row);
}));
const access = (req, kind) => {
  if (kind === 'student' ? hasSection(req.user,'students') : req.user.role === 'admin') return;
  fail(403,'Account management is not permitted');
};
const profileSave = async (id, fields, createOnly = false) => {
  const existing = await Profile.findOne({user:id});
  if (existing && createOnly) return existing;
  const profile = existing || new Profile({user:id});
  if (fields) Object.assign(profile,fields);
  await profile.save();
  return profile;
};
router.post('/accounts', run(async (req,res) => {
  const body = req.body || {}; access(req,body.kind);
  const values = accountPayload(body,{create:true,employee:body.kind === 'employee'});
  // Validate before creating the login; retry with the same CRM identity repairs a partial profile save.
  const {profile,...account} = values;
  if (profile) await new Profile({user:new mongoose.Types.ObjectId(),...profile}).validate();
  const identity = {owner:req.user._id,companyId:body.companyId,recordId:body.recordId};
  let user = await User.findOne({'crmIdentity.owner':identity.owner,'crmIdentity.companyId':identity.companyId,'crmIdentity.recordId':identity.recordId});
  if (user) {
    if (user.role !== body.kind || user.email !== account.email) fail(409,'CRM identity already belongs to a different account');
  } else {
    if (await User.exists({email:account.email})) fail(409,'Email already exists; link the existing account explicitly instead of overwriting it');
    try { user = await User.create({...account,role:body.kind,crmIdentity:identity,emailVerified:false}); }
    catch (error) { if (error.code === 11000) fail(409,'Account creation conflicted; refresh before retrying'); throw error; }
  }
  const savedProfile = body.kind === 'student' ? await profileSave(user._id,profile,true) : undefined;
  res.status(201).json({...safeAccount(user), ...(savedProfile ? {profile:savedProfile.toObject()} : {})});
}));
router.param('id',(req,res,next,id) => mongoose.isValidObjectId(id) ? next() : res.status(400).json({message:'Invalid account ID'}));
router.patch('/partners/:id',requireSection('agents'),run(async(req,res)=>{
  const body=req.body || {},keys=['name','email','isActive','profile','version'];
  if(Object.keys(body).some(key=>!keys.includes(key)))fail(400,'Unsupported partner fields');
  const profileKeys=['phone','companyName','website','location','taxId','bio','address'];
  if(body.profile !== undefined && (!body.profile || typeof body.profile!=='object' || Array.isArray(body.profile) || Object.entries(body.profile).some(([key,value])=>!profileKeys.includes(key) || typeof value!=='string' || value.length>2000)))fail(400,'Invalid partner profile');
  const values=accountPayload(Object.fromEntries(['name','email','isActive'].filter(key=>Object.hasOwn(body,key)).map(key=>[key,body[key]])));
  const partner=await User.findOne({_id:req.params.id,role:'partner'});if(!partner)fail(404,'Partner not found');
  if(body.version !== undefined && body.version !== partner.__v)fail(409,'Partner changed. Refresh and retry.');
  if(values.email && values.email!==partner.email && await User.exists({email:values.email}))fail(409,'Email already exists');
  if(values.isActive !== undefined && values.isActive!==partner.isActive)partner.tokenVersion=(partner.tokenVersion || 0)+1;
  partner.$where={__v:partner.__v};partner.increment();Object.assign(partner,values);
  try{await partner.save();}catch(error){if(['VersionError','DocumentNotFoundError'].includes(error.name))fail(409,'Partner changed. Refresh and retry.');throw error;}
  const profile=await profileSave(partner._id,body.profile);res.json({...safeAccount(partner),__v:partner.__v,profile:profile.toObject()});
}));
router.post('/service-requests/:id/documents',requireSection('services'),require('../middleware/uploadMiddleware').single('file'),run(async(req,res)=>{
  const ServiceRequest=require('../models/ServiceRequest'),Document=require('../models/Document');
  const row=await ServiceRequest.findById(req.params.id);if(!row)fail(404,'Service request not found');
  if(!req.file)fail(400,'File is required');
  if(row.documents.length >= 20)fail(409,'Document limit reached');
  const storage=await require('../utils/privateDocumentStorage').uploadPrivateDocument(req.file);
  const id=new mongoose.Types.ObjectId();
  const document=await Document.create({_id:id,student:row.student,type:'other',fileName:req.file.originalname,filePath:`/api/documents/${id}/access`,mimeType:req.file.mimetype,size:req.file.size,storage});
  const item={_id:document._id,fileName:document.fileName,filePath:document.filePath,mimeType:document.mimeType,size:document.size};
  // Preserve other attachments and enforce the limit even when uploads race.
  const updated=await ServiceRequest.findOneAndUpdate({_id:row._id,'documents.19':{$exists:false}},{$push:{documents:item},$inc:{__v:1}},{new:true});
  if(!updated)fail(409,'Document limit reached. Refresh the request.');
  res.status(201).json(item);
}));
router.post('/service-requests/:id/documents/:documentId/access',requireSection('services'),run(async(req,res)=>{
  if(!mongoose.isValidObjectId(req.params.documentId))fail(400,'Invalid document ID');
  if(!await require('../models/ServiceRequest').exists({_id:req.params.id,'documents._id':req.params.documentId}))fail(404,'Document not found');
  const doc=await require('../models/Document').findById(req.params.documentId).select('+storage');
  if(!doc?.storage?.publicId)fail(404,'Private document not found');
  res.set('Cache-Control','no-store');res.json(require('../utils/privateDocumentStorage').documentDownloadLink(doc.storage));
}));
router.post('/applications/:id/documents',requireSection('applications'),require('../middleware/uploadMiddleware').single('file'),run(async(req,res)=>{
  const Application=require('../models/Application'),Document=require('../models/Document');
  const row=await Application.findById(req.params.id);if(!row)fail(404,'Application not found');
  if(!req.file)fail(400,'File is required');
  if(typeof req.body.type !== 'string' || !req.body.type.trim() || req.body.type.length > 100)fail(400,'Invalid document type');
  const storage=await require('../utils/privateDocumentStorage').uploadPrivateDocument(req.file);
  const id=new mongoose.Types.ObjectId();
  const document=await Document.create({_id:id,student:row.student,type:req.body.type.trim(),fileName:req.file.originalname,filePath:`/api/documents/${id}/access`,mimeType:req.file.mimetype,size:req.file.size,storage});
  row.documents.push(document._id);await row.save();
  res.status(201).json({_id:document._id,__v:document.__v,applicationVersion:row.__v,fileName:document.fileName,filePath:document.filePath,type:document.type,size:document.size,detailedStatus:document.detailedStatus});
}));
router.delete('/applications/:id/documents/:documentId',requireSection('applications'),run(async(req,res)=>{
  if(!mongoose.isValidObjectId(req.params.documentId))fail(400,'Invalid document ID');
  const Application=require('../models/Application');
  const row=await Application.findById(req.params.id);if(!row)fail(404,'Application not found');
  // Detach from this application; preserve the student's private file and review history.
  row.documents=row.documents.filter(id=>String(id)!==req.params.documentId);await row.save();res.json({detached:true,applicationVersion:row.__v});
}));
router.patch('/applications/:id',requireSection('applications'),run(async(req,res)=>{
  const body=req.body || {},keys=['programId','notes','intake','detailedStatus','crmDetails','version','advisorId'];
  if (Object.keys(body).some(key=>!keys.includes(key))) fail(400,'Unsupported application fields');
  for (const key of ['notes','intake']) if (body[key] !== undefined && (typeof body[key] !== 'string' || body[key].length > 2000)) fail(400,'Invalid application text');
  if (body.detailedStatus && !require('../constants/roles').ALL_APPLICATION_DETAILED_STATUSES.includes(body.detailedStatus)) fail(400,'Invalid application status');
  const fields=['applicationRefNo','portalUrl','portalUsername','offerType','offerConditions','rejectionReason'];
  if (body.crmDetails && (Array.isArray(body.crmDetails) || Object.entries(body.crmDetails).some(([key,value])=>!fields.includes(key) || typeof value !== 'string' || value.length > 2000))) fail(400,'Invalid CRM application details');
  const Application=require('../models/Application');
  const row=await Application.findById(req.params.id);if(!row)fail(404,'Application not found');
  if(body.version !== undefined && (!Number.isInteger(body.version) || body.version < 0)) fail(400,'Invalid application version');
  if(body.version !== undefined && body.version !== row.__v) fail(409,'Application changed. Refresh and retry.');
  // Guard the complete edit, including assignment, with the same source version.
  row.$where={__v:row.__v};row.increment();
  if(Object.hasOwn(body,'advisorId') && String(row.assignedAdvisor || '') !== String(body.advisorId || '')) {
    if(body.advisorId !== null && !mongoose.isValidObjectId(body.advisorId))fail(400,'Invalid advisor');
    if(['rejected','completed'].includes(row.detailedStatus) || ['rejected','file-completed-rejected','file-completed-accepted'].includes(row.status))fail(409,'Closed application cannot be reassigned');
    if(body.advisorId && !await User.exists({_id:body.advisorId,isActive:{$ne:false},$or:[{role:'admin'},{role:'employee',permissions:'applications'}]}))fail(400,'Choose an active admissions staff member');
    row.assignedAdvisor=body.advisorId;row.autoAssignmentEligible=false;
    if(!body.advisorId)row.followUpDueAt=null;
    row.assignmentHistory.push({advisor:body.advisorId,dueAt:row.followUpDueAt,changedBy:req.user._id,changedAt:new Date(),source:'manual'});
  }
  const oldStatus=row.detailedStatus;
  if(body.programId !== undefined){if(!mongoose.isValidObjectId(body.programId))fail(400,'Invalid program');const program=await require('../models/Program').findById(body.programId);if(!program)fail(404,'Program not found');row.program=program._id;row.university=program.university;}
  if(body.notes !== undefined) row.notes=body.notes;
  if(body.intake !== undefined) {row.applicantProfile ||= {};row.applicantProfile.intake=body.intake;}
  if(body.crmDetails) {row.crmDetails ||= {};Object.assign(row.crmDetails,body.crmDetails);}
  if(body.detailedStatus && body.detailedStatus !== oldStatus){row.detailedStatus=body.detailedStatus;row.reviewedBy=req.user._id;row.statusTimeline.push({status:body.detailedStatus,note:body.notes || '',changedBy:req.user._id});}
  try {await row.save();} catch(error) {if(['VersionError','DocumentNotFoundError'].includes(error.name))fail(409,'Application changed. Refresh and retry.');throw error;}
  if(row.detailedStatus !== oldStatus){
    await require('../utils/journeyAutomation').onApplicationStatusChange(row.student,row.detailedStatus);
    await require('../models/Notification').create({user:row.student,...require('../constants/statusCatalog').applicationStatusNotice(row),link:'/student/applications'});
    const populated=await Application.findById(row._id).populate('student','name email').populate('program','title');await require('../utils/applicationEmails').enqueueApplicationEmail(populated,'status');
  }
  res.json(row);
}));
router.patch('/accounts/:id',run(async(req,res) => {
  const user = await User.findById(req.params.id);
  if (!user || !['student','employee','admin'].includes(user.role)) fail(404,'Account not found');
  access(req,user.role);
  const {profile,...account} = accountPayload(req.body,{employee:user.role === 'employee'});
  if (profile) await new Profile({user:user._id,...profile}).validate();
  if (account.email && account.email !== user.email && await User.exists({email:account.email})) fail(409,'Email already exists');
  if(account.isActive===false && String(user._id)===String(req.user._id))fail(409,'Do not deactivate the connected integration account');
  Object.assign(user,account);
  if (account.password) { user.tokenVersion = (user.tokenVersion || 0) + 1; user.passwordChangedAt = new Date(); }
  await user.save();
  const savedProfile = user.role === 'student' ? await profileSave(user._id,profile) : undefined;
  res.json({...safeAccount(user),...(savedProfile ? {profile:savedProfile.toObject()} : {})});
}));
router.delete('/accounts/:id',run(async(req,res) => {
  const user = await User.findById(req.params.id);
  if (!user || !['student','employee'].includes(user.role)) fail(404,'Account not found');
  access(req,user.role);
  user.isActive = false; user.tokenVersion = (user.tokenVersion || 0) + 1;
  await user.save(); res.json({archived:true,_id:user._id});
}));
module.exports = router;
