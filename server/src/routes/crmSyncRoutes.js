const express = require('express');
const mongoose = require('mongoose');
const run = require('../utils/asyncHandler');
let Record, Operation;
const {authorize} = require('../middleware/authMiddleware');
const {resources,validId,validateOperation,recordId} = require('../utils/crmSyncPolicy.cjs');
const {digest} = require('../utils/syncMerge.cjs');
const {assertBackups}=require('../utils/syncBackupGate.cjs');
const router=express.Router({mergeParams:true});
const fail=(status,message)=>{throw Object.assign(new Error(message),{status});};
// Entirely server-side and private. No browser secrets or automatic role grants.
let backupVerification;
router.use(authorize('admin'),run(async(req,res,next)=>{
  res.set('Cache-Control','no-store');
  if(process.env.CRM_TWO_WAY_SYNC_ENABLED!=='true')return res.status(503).json({message:'Two-way sync is disabled'});
  if(!process.env.SYNC_BACKUP_RECEIPT_FILE)return res.status(503).json({message:'Verified backups are required before sync activation'});
  if(!validId(process.env.CRM_SYNC_COMPANY_ID) || req.params.companyId!==process.env.CRM_SYNC_COMPANY_ID)return res.status(403).json({message:'Sync company is not configured'});
  if(!backupVerification)backupVerification=assertBackups().catch(error=>{backupVerification=null;throw Object.assign(new Error('Backup verification failed; sync remains disabled'),{status:503});});
  await backupVerification;
  Record ||= require('../models/CrmSyncRecord');
  Operation ||= require('../models/CrmSyncOperation');
  await Promise.all([Record.init(),Operation.init()]);
  next();
}));
router.get('/records',run(async(req,res)=>{
  const after=req.query.after || '';
  if(after && !/^[a-f\d]{64}$/.test(after))fail(400,'Invalid sync cursor');
  const rows=await Record.find({owner:req.user._id,companyId:process.env.CRM_SYNC_COMPANY_ID,...(after?{_id:{$gt:after}}:{})}).sort({_id:1}).limit(101).lean();
  res.json({rows:rows.slice(0,100),next:rows.length>100?rows[99]._id:null,complete:rows.length<=100});
}));
router.put('/records/:resource/:entityId',run(async(req,res)=>{
  const {resource,entityId}=req.params,companyId=process.env.CRM_SYNC_COMPANY_ID;
  if(!resources.includes(resource) || !validId(entityId))fail(400,'Unsupported CRM resource');
  validateOperation(req.body);
  const id=recordId(req.user._id,companyId,resource,entityId);
  const operationId=recordId(req.user._id,companyId,'operation',req.body.operationId);
  const requestDigest=digest({id,body:req.body});
  const session=await mongoose.startSession();let result;
  try {
    await session.withTransaction(async()=>{
      const previous=await Operation.findById(operationId).session(session).lean();
      if(previous){if(previous.digest!==requestDigest)fail(409,'Operation ID reused with different data');result=previous.after;return;}
      const existing=await Record.findById(id).session(session).lean();
      if((existing?.revision || 0)!==req.body.expectedRevision)fail(409,'Sync conflict: refresh both versions');
      if(existing?.deleted)fail(409,'Deleted records require explicit restoration');
      result={_id:id,owner:req.user._id,companyId,resource,entityId,revision:req.body.expectedRevision+1,value:req.body.value,deleted:false,updatedAt:new Date()};
      if(existing) {
        const updated=await Record.replaceOne({_id:id,revision:existing.revision},result,{session});
        if(updated.modifiedCount!==1)fail(409,'Concurrent sync conflict');
      } else await Record.create([result],{session});
      await Operation.create([{_id:operationId,recordId:id,digest:requestDigest,before:existing || null,after:result,actor:req.user._id,createdAt:new Date()}],{session});
    });
  } catch(error) {if(error.code===11000)fail(409,'Concurrent sync operation; retry with the same operation ID');throw error;}
  finally{await session.endSession();}
  res.json(result);
}));
// Deletion is deliberately a proposal: no missing row or DELETE request removes data.
router.delete('/records/:resource/:entityId',(req,res)=>res.status(409).json({message:'Deletion requires relationship review on both systems; no data deleted'}));
module.exports=router;
