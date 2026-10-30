const express=require('express');
const mongoose=require('mongoose');
const {protect}=require('../middleware/authMiddleware');
const scope=require('../utils/assistantScope');
const Application=require('../models/Application');
const knowledge=require('../utils/assistantKnowledge');
const run=require('../utils/asyncHandler');
const {rateLimit}=require('express-rate-limit');
const {ready}=require('../utils/assistantProvider');
const threadSchema=new mongoose.Schema({user:{type:mongoose.Schema.Types.ObjectId,required:true,index:true},title:String,lockedUntil:{type:Date,default:()=>new Date(0)},messages:[{role:{type:String,enum:['user','assistant']},content:String,details:String,topicId:String,knowledgeVersion:String,knowledgeRevision:String,actions:[{_id:false,id:String,label:String}],createdAt:{type:Date,default:Date.now}}]},{timestamps:true});
const Thread=mongoose.model('AssistantThread',threadSchema);
const Generation=mongoose.model('AssistantGeneration',new mongoose.Schema({user:mongoose.Schema.Types.ObjectId,thread:mongoose.Schema.Types.ObjectId,model:String,inputTokens:Number,outputTokens:Number,response:String,status:{type:String,enum:['pending','complete','failed']}},{timestamps:true}));
const Quota=mongoose.model('AssistantQuota',new mongoose.Schema({key:{type:String,unique:true},count:{type:Number,default:0},expiresAt:{type:Date,expires:0}}));
const contract={scopePolicy:'studybirds-only-v1',responseFormat:'verified-help-v1',knowledgeVersion:knowledge.catalog.version,knowledgeRevision:knowledge.catalog.revision};
function safeMessages(messages){return messages.map(message=>{
 const row=typeof message.toObject==='function'?message.toObject():message;
 if(row.role==='assistant'&&(!row.knowledgeVersion||row.knowledgeRevision!==knowledge.catalog.revision))return {...row,content:'إجابة من دليل سابق. أعد سؤالك للحصول على إرشاد COVEY المحدّث. / Reply from an older guide. Ask again for current COVEY help.',details:'',actions:[]};
 return row;
});}
const router=express.Router();router.use(protect);
router.get('/config',(req,res)=>res.json({enabled:knowledge.verified,...contract,providerAvailable:ready()}));
router.get('/help-catalog',(req,res)=>res.json({version:knowledge.catalog.version,revision:knowledge.catalog.revision,entries:knowledge.entries.filter(e=>e.roles.includes(req.user.role)).map(e=>({id:e.id,name:e.name,availability:e.availability}))}));
router.get('/suggested-questions',run(async(req,res)=>{
  if(req.user.role!=='student')return res.json([]);
  const ar=req.query.language!=='en';
  res.json(ar?['كيف أتابع طلباتي؟','كيف أرفع المستندات؟','كيف أبحث عن جامعة داخل التطبيق؟','كيف أغير تفضيلات الإشعارات؟','كيف أتواصل مع الدعم؟']:['How do I track my applications?','How do I upload documents?','How do I find a university in the app?','How do I change notification preferences?','How do I contact support?']);
}));
router.get('/threads',run(async(req,res)=>res.json(await Thread.find({user:req.user._id}).select('_id title updatedAt').sort({updatedAt:-1}).limit(50).lean())));
router.get('/threads/:id',run(async(req,res)=>{if(!mongoose.isValidObjectId(req.params.id))return res.status(400).json({message:'Invalid thread'});const row=await Thread.findOne({_id:req.params.id,user:req.user._id}).select('-lockedUntil').lean();if(!row)return res.status(404).json({message:'Conversation not found'});res.json({...row,...contract,messages:safeMessages(row.messages)});}));
router.post('/message',rateLimit({windowMs:60000,limit:5,keyGenerator:req=>String(req.user._id),standardHeaders:'draft-7',legacyHeaders:false,handler:(req,res)=>res.status(429).json({message:scope.isArabic(String(req.body?.message||''))?'وصلت للحد المؤقت. انتظر دقيقة ثم حاول مجددًا.':'Too many requests. Wait a minute and try again.'})}),run(async(req,res)=>{

 if(!req.body||typeof req.body.message!=='string'||!req.body.message.trim()||req.body.message.length>2000)return res.status(400).json({message:'اكتب رسالة بين حرف و2000 حرف.'});
 const context=knowledge.validateContext(req.body);
 const decision=scope.classify(req.body.message.trim(),{role:req.user.role,context});
 if(decision.kind==='clarify'&&(!context.knowledgeVersion||context.knowledgeVersion===knowledge.catalog.version))decision.text=scope.screenContext(context.screen,decision.ar)||decision.text;

 let thread;
 if(req.body.threadId){if(!mongoose.isValidObjectId(req.body.threadId))return res.status(400).json({message:'Invalid thread'});thread=await Thread.findOne({_id:req.body.threadId,user:req.user._id});if(!thread)return res.status(404).json({message:'Conversation not found'});}
 else thread=await Thread.create({user:req.user._id,title:req.body.message.slice(0,80)});
 const previous=[...thread.messages].reverse().find(row=>row.role==='assistant');
 const followup=knowledge.followup(req.body.message,previous,req.user.role,context);
 if(followup){decision.kind='help';decision.candidates=[followup];}
 // Topic IDs alone cannot convey intent to a model. Ask for clarification.
 if(decision.kind==='help' && decision.candidates.length>1){
   decision.kind='clarify';
   const names=decision.candidates.map(item=>item.name[decision.ar?'ar':'en']);
   decision.text=decision.ar?'تقصد أي موضوع: '+names.join('، ')+'؟ اكتب اسم الموضوع أو وضح سؤالك.':'Which topic do you mean: '+names.join(', ')+'? Please name it or clarify your question.';
 }
 const locked=await Thread.findOneAndUpdate({_id:thread._id,user:req.user._id,lockedUntil:{$lt:new Date()}},{$set:{lockedUntil:new Date(Date.now()+60000)}},{new:true});
 if(!locked)return res.status(409).json({message:'انتظر اكتمال الرد السابق.'});
 let released = false;
 try{
  const quota=await Quota.findOneAndUpdate({key:`${req.user._id}:${new Date().toISOString().slice(0,10)}`},{$inc:{count:1},$setOnInsert:{expiresAt:new Date(Date.now()+48*60*60*1000)}},{upsert:true,new:true});
  const limit=Math.min(100,Math.max(1,Number(process.env.AI_DAILY_LIMIT)||20));
  if(quota.count>limit){res.status(429);throw new Error('وصلت للحد اليومي للمساعد. حاول غدًا.');}
  let answer=decision.text;
  let selected=null;
  let details='';
  if(decision.kind==='personal'){
    if(req.user.role!=='student') answer=scope.decline(decision.ar);
    else {
      const applications=await Application.find({student:req.user._id}).select('status detailedStatus').sort({createdAt:-1}).limit(10).lean();
      const statuses=applications.map((row,index)=>`${index+1}. ${scope.applicationStatus(row.detailedStatus||row.status,decision.ar)}`);
      answer=decision.ar?(statuses.length?'حالات أحدث طلباتك المسجلة الآن (افتح طلباتك لعرض التفاصيل):\n'+statuses.join('\n'):'لا توجد طلبات مسجلة لحسابك.'):(statuses.length?'Your latest recorded application statuses (open your applications for details):\n'+statuses.join('\n'):'There are no applications recorded for your account.');
      if(statuses.length>3){
        details=answer;
        answer=(decision.ar?'أحدث 3 طلبات مسجلة لحسابك:\n':'Your 3 latest recorded applications:\n')+statuses.slice(0,3).join('\n');
      }
    }
  } else if(decision.kind==='help'){
    if(decision.candidates.length===1)selected=decision.candidates[0];
    answer=selected?knowledge.answer(selected,context,decision.ar):(decision.ar?'لا أستطيع تأكيد إجابة موثوقة لهذا السؤال. افتح مركز الدعم من حسابي وأرسل تذكرة.':'I cannot verify a reliable answer. Open Support Center from My Account and create a ticket.');
  }
  if(selected){const response=knowledge.presentation(selected,context,decision.ar);answer=response.content;details=response.details;}
  const allowedActions=new Set(['applications','documents','universities','programs','countries','compare','favorites','profile','passport','settings','security','notifications','support','community','friends','game','journey','payments','services','scholarships','events','alumni','rewards']);
  const action=selected?.availability!=='unavailable'&&selected?.roles.includes(req.user.role)&&allowedActions.has(selected?.action)?selected.action:null;
  const alreadyHere=action===context.screen || (action==='profile' && context.screen==='account');
  const actions=action&&!alreadyHere&&req.user.role==='student'?[{id:action,label:decision.ar?'فتح الشاشة':'Open screen'}]:[];
  const updated=await Thread.findByIdAndUpdate(thread._id,{$set:{lockedUntil:new Date(0)},$push:{messages:{$each:[{role:'user',content:req.body.message.trim()},{role:'assistant',content:answer,details,topicId:selected?.id,actions,knowledgeVersion:knowledge.catalog.version,knowledgeRevision:knowledge.catalog.revision}],$slice:-100}}},{new:true});
  released = true;
  res.json({threadId:thread._id,...contract,messages:safeMessages(updated.messages)});
 }catch(e){if(res.statusCode===200)res.status(502);throw new Error(res.statusCode===429?e.message:'تعذر الحصول على رد من المساعد. حاول لاحقًا.');}
 finally{try{if(!released)await Thread.updateOne({_id:thread._id},{$set:{lockedUntil:new Date(0)}});}catch(e){console.error('Failed to release assistant thread lock',e.message);}}
}));
// Reviewed help and local clarification remain available without a provider.
module.exports={router,ready:()=>knowledge.verified};
