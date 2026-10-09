const express=require('express');
const mongoose=require('mongoose');
const {createHash}=require('node:crypto');
const Invoice=require('../models/Invoice');
const User=require('../models/User');
const run=require('../utils/asyncHandler');
const {requireSection}=require('../middleware/employeeAccess');
const {invoicePayload,paymentPayload}=require('../utils/crmFinancePolicy');
const router=express.Router();
const fail=(status,message)=>{throw Object.assign(new Error(message),{status});};
router.use(requireSection('student-financials'));
const owned=async(req)=>{
  if(!mongoose.isValidObjectId(req.params.id))fail(400,'Invalid invoice ID');
  // Authorized finance staff also manage invoices originally created by the
  // website. An invoice claimed by another integration remains inaccessible.
  const row=await Invoice.findOne({_id:req.params.id,$or:[{'crmIdentity.owner':req.user._id},{'crmIdentity.owner':{$exists:false}}]});
  if(!row)fail(404,'Linked invoice not found');return row;
};
router.post('/',run(async(req,res)=>{
  const body=invoicePayload(req.body);
  if(!mongoose.isValidObjectId(body.studentId) || !await User.exists({_id:body.studentId,role:'student'}))fail(400,'Student not found');
  const identity={owner:req.user._id,companyId:body.companyId,recordId:body.recordId};
  let row=await Invoice.findOne({'crmIdentity.owner':identity.owner,'crmIdentity.companyId':identity.companyId,'crmIdentity.recordId':identity.recordId});
  if(row){if(String(row.student)!==body.studentId || row.amount!==body.amount || row.currency!==body.currency)fail(409,'Invoice identity has different financial data');return res.json(row);}
  const prefix=createHash('sha256').update(`${identity.owner}:${identity.companyId}`).digest('hex').slice(0,12);
  row=await Invoice.create({student:body.studentId,invoiceNumber:`CRM-${prefix}-${body.invoiceNumber}`,description:body.description,amount:body.amount,currency:body.currency,dueDate:body.dueDate || null,crmIdentity:identity});
  await require('../models/Notification').create({user:row.student,title:'فاتورة جديدة',message:`أضيفت فاتورة ${body.invoiceNumber} إلى حسابك.`,type:'info',link:'/student/payments'});
  res.status(201).json(row);
}));
router.get('/:id',run(async(req,res)=>res.json(await owned(req))));
router.get('/:id/reconciliation',run(async(req,res)=>{
  const invoice=await owned(req);
  const [proofs,wallet]=await Promise.all([
    require('../models/PaymentProof').find({invoice:invoice._id}).select('_id student invoice amount status reviewedAt createdAt reviewNote').lean(),
    require('../models/StudentWalletEntry').find({relatedInvoice:invoice._id}).select('_id direction amount kind createdAt notes').lean(),
  ]);
  res.set('Cache-Control','no-store');res.json({invoice,proofs,wallet});
}));
router.patch('/:id/payments',run(async(req,res)=>{
  const row=await owned(req),body=paymentPayload(req.body,row.amount);
  if(row.__v!==body.version)fail(409,'Invoice changed; refresh before recording payment');
  if((row.walletCreditApplied || 0)>0 || (row.stripeCheckoutExpiresAt && row.stripeCheckoutExpiresAt>new Date()) || await require('../models/PaymentProof').exists({invoice:row._id,status:{$ne:'rejected'}}))fail(409,'A website payment is in progress; reconcile it before changing the CRM balance');
  if(row.status==='paid' && row.crmPaidAmount<row.amount)fail(409,'Invoice was paid through another channel; reconcile before changing the CRM balance');
  if(row.crmPaidAmount===body.paidAmount)return res.json(row);
  const result=await Invoice.findOneAndUpdate({_id:row._id,__v:body.version},{$set:{crmPaidAmount:body.paidAmount,status:body.status,reviewedBy:req.user._id,reviewedAt:new Date()},$inc:{__v:1},$push:{crmPaymentHistory:{amount:body.paidAmount,changedBy:req.user._id}}},{new:true,runValidators:true});
  if(!result)fail(409,'Invoice changed; refresh before recording payment');
  if(result.status==='paid')require('../utils/journeyAutomation').onPaymentApproved(result.student).catch(()=>{});
  res.json(result);
}));
router.delete('/:id',run(async(req,res)=>{
  const row=await owned(req);
  if(row.status==='paid' || row.crmPaidAmount>0 || row.walletCreditApplied>0 || row.crmPaymentHistory.length || row.stripeCheckoutExpiresAt>new Date() || await require('../models/PaymentProof').exists({invoice:row._id}))fail(409,'Invoice has payment history; preserve it and reconcile payments first');
  const deleted=await Invoice.deleteOne({_id:row._id,__v:row.__v,status:row.status,crmPaidAmount:row.crmPaidAmount,walletCreditApplied:row.walletCreditApplied});
  if(!deleted.deletedCount)fail(409,'Invoice changed; refresh before deleting');res.json({deleted:true});
}));
module.exports=router;
