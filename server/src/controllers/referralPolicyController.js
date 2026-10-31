const run = require('../utils/asyncHandler');
const mongoose = require('mongoose');
const Policy = require('../models/ReferralPolicy');
const User = require('../models/User');
const { legacyAmount } = require('../utils/referralPolicy');
const { logActivity } = require('../utils/logActivity');
const fail = (res, status, message) => { res.status(status); throw new Error(message); };
exports.students = run(async(req,res)=>res.json(await User.find({role:'student',isActive:true}).select('name email').sort({name:1}).lean()));
exports.list = run(async (req,res) => {
  if(!await Policy.exists({scope:'default'})){
    try { await Policy.create({scope:'default',amount:legacyAmount(),enabled:true}); }
    catch(error) { if(error.code!==11000)throw error; }
  }
  const rows=await Policy.find().populate('student','name email').sort({scope:1}).lean();
  res.json(rows.map(row=>({...row,name:row.scope==='default'?'المكافأة الافتراضية':row.student?.name || 'Student override',currency:'USD'})));
});
exports.save = run(async (req,res) => {
  const {amount,enabled,expectedVersion,studentId:student}=req.body;
  if(typeof amount!=='number'||!Number.isFinite(amount)||amount<0||amount>10000||Math.abs(amount*100-Math.round(amount*100))>0.000001||typeof enabled!=='boolean')fail(res,400,'Enter an amount from 0 to 10000 USD with at most two decimals and an enabled flag');
  let row;
  if(req.params.id){
    if(!mongoose.isValidObjectId(req.params.id))fail(res,400,'Invalid policy');
    if(!Number.isSafeInteger(expectedVersion)||expectedVersion<0)fail(res,428,'Refresh the policy before saving');
    row=await Policy.findOneAndUpdate({_id:req.params.id,__v:expectedVersion},{$set:{amount,enabled,updatedBy:req.user._id},$inc:{__v:1}},{new:true,runValidators:true});
    if(!row)fail(res,409,'Policy changed; refresh and review before saving');
  }else{
    if(!mongoose.isObjectIdOrHexString(student)||!await User.exists({_id:student,role:'student',isActive:true}))fail(res,400,'Choose an active student who owns the referral code');
    try{row=await Policy.create({scope:String(student),student,amount,enabled,updatedBy:req.user._id});}
    catch(error){if(error.code===11000)fail(res,409,'This student already has an override');throw error;}
  }
  await logActivity(req,req.user._id,'referral-policy.updated','Referral reward policy updated',{policyId:row._id,amount,enabled,currency:'USD',version:row.__v});
  res.json(row);
});
exports.remove = run(async(req,res)=>{
  const {expectedVersion}=req.body;
  if(!mongoose.isValidObjectId(req.params.id)||!Number.isSafeInteger(expectedVersion)||expectedVersion<0)fail(res,400,'Refresh the policy before deleting');
  const row=await Policy.findOneAndDelete({_id:req.params.id,scope:{$ne:'default'},__v:expectedVersion});
  if(!row)fail(res,409,'Policy changed or the default policy cannot be removed');
  await logActivity(req,req.user._id,'referral-policy.removed','Student referral override removed',{policyId:row._id});
  res.json({success:true});
});
