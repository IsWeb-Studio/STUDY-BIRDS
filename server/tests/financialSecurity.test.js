const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const express = require('express');
const mongoose = require('mongoose');
const { createHmac } = require('node:crypto');
const { MongoMemoryReplSet, MongoMemoryServer } = require(path.join(process.env.STUDY_BIRDS_TEST_TOOLS, 'node_modules/mongodb-memory-server-core'));

test('financial transactions, failure recovery, referrals and Stripe boundaries', async t => {
  Object.assign(process.env, { JWT_SECRET:'financial-security-tests', STRIPE_SECRET_KEY:'sk_test_local_only', STRIPE_WEBHOOK_SECRET:'whsec_local_only' });
  const mongo = await MongoMemoryReplSet.create({ replSet:{count:1}, instanceOpts:[{ip:'127.0.0.1'}] });
  const originalFetch = global.fetch;
  let server;
  try {
    await mongoose.connect(mongo.getUri());
    const User=require('../src/models/User'), Invoice=require('../src/models/Invoice');
    const Entry=require('../src/models/StudentWalletEntry'), Referral=require('../src/models/StudentReferral');
    const Application=require('../src/models/Application'), Outbox=require('../src/models/FinancialOutbox');
    const Receipt=require('../src/models/StripePaymentReceipt'), Notification=require('../src/models/Notification');
    const wallet=require('../src/utils/studentWallet'), outbox=require('../src/utils/financialOutbox');
    await Promise.all([User.init(),Invoice.init(),Entry.init(),Referral.init(),Receipt.init(),Outbox.init()]);
    const app=express();
    app.use(express.json({verify:(req,res,buffer)=>{if(req.originalUrl==='/api/payments/stripe/webhook')req.rawBody=Buffer.from(buffer);}}));
    app.use('/api/students',require('../src/routes/studentRoutes'));
    app.use('/api/admin',require('../src/routes/adminRoutes'));
    app.use('/api/payments/stripe',require('../src/routes/stripeRoutes'));
    app.use(require('../src/middleware/errorMiddleware').errorHandler);
    server=await new Promise(resolve=>{const s=app.listen(0,'127.0.0.1',()=>resolve(s));});
    const base=`http://127.0.0.1:${server.address().port}/api`;
    const token=user=>require('../src/utils/generateToken')(user._id,0);
    let counter=0;
    async function seed(balance=10) {
      const n=++counter;
      const user=await User.create({name:`User ${n}`,email:`u${n}@example.test`});
      if(balance)await Entry.create({student:user._id,direction:'credit',kind:'adjustment',amount:balance});
      const invoice=await Invoice.create({student:user._id,invoiceNumber:`INV-${n}`,description:'Test',amount:10});
      return {user,invoice};
    }
    const admin=await User.create({name:'Admin',email:'admin@example.test',role:'admin'});
    async function call(route,user,body={},key) {
      const response=await originalFetch(base+route,{method:'POST',headers:{'Content-Type':'application/json',...(user?{Authorization:`Bearer ${token(user)}`}:{}) ,...(key?{'Idempotency-Key':key}:{})},body:JSON.stringify(body)});
      return {status:response.status,body:await response.json()};
    }
    const redeem=(user,invoice,amount=10,key)=>call('/students/wallet/redeem',user,{invoiceId:String(invoice._id),amount},key);
    const remoteByKey=new Map(), remoteById=new Map();let networkLoss=false, stripeCreates=0;
    global.fetch=async (input,options={})=>{
      const url=String(input);if(!url.startsWith('https://api.stripe.com/v1/'))return originalFetch(input,options);
      const route=url.slice('https://api.stripe.com/v1/'.length);
      if(route==='checkout/sessions') {
        const key=options.headers['Idempotency-Key'];assert.ok(key);
        const params=Object.fromEntries(new URLSearchParams(options.body));
        let checkout=remoteByKey.get(key);
        if(!checkout){stripeCreates++;checkout={id:`cs_test_${stripeCreates}`,url:`https://checkout.stripe.com/c/pay/test${stripeCreates}`,status:'open',payment_status:'unpaid',amount_total:Number(params['line_items[0][price_data][unit_amount]']),currency:params['line_items[0][price_data][currency]'],metadata:{invoiceId:params['metadata[invoiceId]'],studentId:params['metadata[studentId]'],checkoutKey:params['metadata[checkoutKey]']},params};remoteByKey.set(key,checkout);remoteById.set(checkout.id,checkout);}
        else assert.deepEqual(params,checkout.params,'retries preserve exact Stripe parameters');
        if(networkLoss){networkLoss=false;throw new Error('simulated lost Stripe response');}
        return new Response(JSON.stringify(checkout),{status:200});
      }
      const match=route.match(/^checkout\/sessions\/(cs_test_\d+)(\/expire)?$/);assert.ok(match,route);
      const checkout=remoteById.get(match[1]);assert.ok(checkout);
      if(match[2]){if(checkout.status==='complete')return new Response('{}',{status:400});checkout.status='expired';}
      return new Response(JSON.stringify(checkout),{status:200});
    };
    async function hook(payment,{secret=process.env.STRIPE_WEBHOOK_SECRET,age=0,tamper=false}={}) {
      const event={id:`evt_${payment.id}`,type:'checkout.session.completed',data:{object:{...payment,payment_status:'paid'}}};
      let raw=JSON.stringify(event);const stamp=Math.floor(Date.now()/1000)-age;
      const signature=createHmac('sha256',secret).update(`${stamp}.${raw}`).digest('hex');if(tamper)raw+=' ';
      const response=await originalFetch(base+'/payments/stripe/webhook',{method:'POST',headers:{'Content-Type':'application/json','Stripe-Signature':`t=${stamp},v1=${signature}`},body:raw});
      return {status:response.status,body:await response.json()};
    }
    await t.test('simultaneous redemptions across different invoices cannot overspend',async()=>{
      const {user,invoice}=await seed();const invoices=[invoice];
      for(let n=0;n<7;n++)invoices.push(await Invoice.create({student:user._id,invoiceNumber:`burst-${n}`,description:'B',amount:10}));
      const results=await Promise.all(invoices.map(i=>redeem(user,i)));
      assert.equal(results.filter(r=>r.status===200).length,1,JSON.stringify(results));
      assert.ok(results.every(r=>[200,409].includes(r.status)),JSON.stringify(results));
      assert.equal(await wallet.getWalletBalance(user._id),0);
    });
    await t.test('a wallet operation paused beyond the old 15-second lease cannot overspend',async()=>{
      const {user,invoice}=await seed();const other=await Invoice.create({student:user._id,invoiceNumber:'slow-B',description:'B',amount:10});
      const originalAggregate=Entry.aggregate;let release,reached,first=true;
      const ready=new Promise(resolve=>reached=resolve);
      Entry.aggregate=function(...args){const query=originalAggregate.apply(this,args),exec=query.exec.bind(query);query.exec=async()=>{const result=await exec();if(first){first=false;reached();await new Promise(resolve=>release=resolve);}return result;};return query;};
      try {
        const slow=redeem(user,invoice);await ready;const second=redeem(user,other);
        await new Promise(resolve=>setTimeout(resolve,15300));release();
        const results=await Promise.all([slow,second]);assert.deepEqual(results.map(r=>r.status).sort(),[200,409]);
        assert.equal(await wallet.getWalletBalance(user._id),0);
      } finally {Entry.aggregate=originalAggregate;release?.();}
    });
    await t.test('an exception after the invoice write rolls back both debit and invoice',async()=>{
      const {user,invoice}=await seed();const save=Invoice.prototype.save;
      Invoice.prototype.save=async function(options){const result=await save.call(this,options);if(String(this._id)===String(invoice._id))throw new Error('lost write acknowledgement');return result;};
      try{assert.equal((await redeem(user,invoice)).status,500);}finally{Invoice.prototype.save=save;}
      assert.equal(await wallet.getWalletBalance(user._id),10);
      assert.equal((await Invoice.findById(invoice._id)).walletCreditApplied,0);
      assert.equal(await Entry.countDocuments({relatedInvoice:invoice._id}),0);
    });
    await t.test('ambiguous successful commit retries commit without deleting or duplicating money',async()=>{
      const {user,invoice}=await seed();const start=mongoose.connection.startSession.bind(mongoose.connection);let inject=true,commits=0;
      mongoose.connection.startSession=async(...args)=>{const session=await start(...args),commit=session.commitTransaction.bind(session);session.commitTransaction=async(...params)=>{commits++;const result=await commit(...params);if(inject){inject=false;const error=new mongoose.mongo.MongoNetworkError('lost commit acknowledgement');error.addErrorLabel('UnknownTransactionCommitResult');throw error;}return result;};return session;};
      try{assert.equal((await redeem(user,invoice)).status,200);}finally{mongoose.connection.startSession=start;}
      assert.ok(commits>=2);assert.equal(await wallet.getWalletBalance(user._id),0);
      assert.equal(await Entry.countDocuments({relatedInvoice:invoice._id}),1);
      assert.equal((await Invoice.findById(invoice._id)).status,'paid');
    });
    await t.test('financial idempotency survives retries and rejects altered data, fractions and foreign invoices',async()=>{
      const {user,invoice}=await seed();const other=await seed();
      assert.equal((await redeem(user,other.invoice)).status,404);
      assert.equal((await redeem(user,invoice,0.001)).status,400);
      assert.equal((await redeem(user,invoice,4,'redeem-retry')).status,200);
      assert.equal((await redeem(user,invoice,4,'redeem-retry')).status,200);
      assert.equal((await redeem(user,invoice,3,'redeem-retry')).status,409);
      assert.equal(await wallet.getWalletBalance(user._id),6);
      const payload={studentId:String(user._id),direction:'credit',amount:2,notes:'Adjustment'};
      assert.equal((await call('/admin/student-financials/wallet-entries',admin,payload,'adjust-retry')).status,201);
      assert.equal((await call('/admin/student-financials/wallet-entries',admin,payload,'adjust-retry')).status,201);
      assert.equal(await wallet.getWalletBalance(user._id),8);
    });
    async function referralFixture(status='pending') {
      const {user:referrer}=await seed(0),{user:referred}=await seed(0);
      await Application.create({student:referred._id,program:new mongoose.Types.ObjectId(),university:new mongoose.Types.ObjectId()});
      const referral=await Referral.create({referrer:referrer._id,referredUser:referred._id,code:'test',status});
      return {referrer,referred,referral};
    }
    await t.test('wallet arithmetic is in cents and malformed historical entries fail closed',async()=>{
      const {user,invoice}=await seed(0);
      await Entry.create([{student:user._id,direction:'credit',kind:'adjustment',amount:0.1},{student:user._id,direction:'credit',kind:'adjustment',amount:0.2}]);
      assert.equal(await wallet.getWalletBalance(user._id),0.3);
      assert.equal((await redeem(user,invoice,0.3)).status,200);
      assert.equal(await wallet.getWalletBalance(user._id),0);
      await assert.rejects(Entry.create({student:user._id,direction:'credit',kind:'adjustment',amount:0.001}));
      await Entry.collection.insertOne({student:user._id,direction:'credit',kind:'adjustment',amount:0.001});
      await assert.rejects(wallet.getWalletBalance(user._id),error=>error.statusCode===503);
    });
    await t.test('failed referral ledger writes roll back and concurrent retry awards exactly once',async()=>{
      const {referrer,referred,referral}=await referralFixture();const create=Entry.create;
      Entry.create=async function(docs,...args){if((Array.isArray(docs)?docs:[docs]).some(d=>d.kind==='referral-reward'))throw new Error('ledger unavailable');return create.call(this,docs,...args);};
      try{await assert.rejects(wallet.qualifyReferral(referred._id));}finally{Entry.create=create;}
      assert.equal((await Referral.findById(referral._id)).status,'pending');
      await Promise.all(Array.from({length:6},()=>wallet.qualifyReferral(referred._id)));
      assert.equal(await Entry.countDocuments({relatedReferral:referral._id}),1);
      assert.equal(await wallet.getWalletBalance(referrer._id),wallet.REFERRAL_REWARD_AMOUNT);
    });
    await t.test('legacy qualified referrals and undelivered notices are recoverable',async()=>{
      const {referred,referral}=await referralFixture('qualified');const update=Notification.updateOne;
      Notification.updateOne=async()=>{throw new Error('notification unavailable');};
      try{await wallet.reconcileReferralRewards();}finally{Notification.updateOne=update;}
      assert.equal(await Entry.countDocuments({relatedReferral:referral._id}),1);
      assert.equal((await Outbox.findById(`referral:${referral._id}`)).done,false);
      await outbox.drainFinancialOutbox();await outbox.drainFinancialOutbox();
      const item=await Outbox.findById(`referral:${referral._id}`);assert.equal(item.done,true);
      assert.equal(await Notification.countDocuments({_id:item.notificationId}),1);
      await wallet.qualifyReferral(referred._id);assert.equal(await Entry.countDocuments({relatedReferral:referral._id}),1);
    });
    await t.test('checkout uses server amounts and a stable Stripe key across network failures and concurrent retries',async()=>{
      const {user,invoice}=await seed();const before=stripeCreates;networkLoss=true;
      assert.equal((await call('/payments/stripe/checkout',user,{invoiceId:String(invoice._id),amount:1})).status,500);
      assert.ok((await Invoice.findById(invoice._id)).stripeCheckoutKey);
      const results=await Promise.all(Array.from({length:4},()=>call('/payments/stripe/checkout',user,{invoiceId:String(invoice._id)})));
      assert.ok(results.every(r=>r.status===200),JSON.stringify(results));assert.equal(stripeCreates,before+1);
      const session=remoteById.get(results[0].body.sessionId);assert.equal(session.amount_total,1000);
      assert.equal((await redeem(user,invoice)).status,409);
      const edit=await originalFetch(base+`/admin/student-financials/invoices/${invoice._id}`,{method:'PATCH',headers:{'Content-Type':'application/json',Authorization:`Bearer ${token(admin)}`},body:JSON.stringify({amount:20})});
      assert.equal(edit.status,409);
    });
    await t.test('old signed payments cannot mark resized invoices paid; receipt and review survive replay',async()=>{
      const {user,invoice}=await seed();const checkout=await call('/payments/stripe/checkout',user,{invoiceId:String(invoice._id)});
      const payment=remoteById.get(checkout.body.sessionId);
      await Invoice.updateOne({_id:invoice._id},{$set:{amount:20}}); // Simulate a legacy/pre-fix edit.
      assert.equal((await hook(payment)).status,200);
      assert.equal((await Invoice.findById(invoice._id)).status,'unpaid');
      assert.equal((await Invoice.findById(invoice._id)).stripeReconciliationRequired,true);
      assert.equal((await Receipt.findById(payment.id)).state,'reconciliation');
      assert.equal((await hook(payment)).status,200);assert.equal(await Receipt.countDocuments({_id:payment.id}),1);
    });
    await t.test('signature checks and duplicate webhooks preserve one receipt and one notification',async()=>{
      const {user,invoice}=await seed();const checkout=await call('/payments/stripe/checkout',user,{invoiceId:String(invoice._id)});const payment=remoteById.get(checkout.body.sessionId);
      assert.equal((await hook(payment,{secret:'wrong'})).status,400);
      assert.equal((await hook(payment,{tamper:true})).status,400);
      assert.equal((await hook(payment,{age:600})).status,400);
      const responses=await Promise.all(Array.from({length:5},()=>hook(payment)));assert.ok(responses.every(r=>r.status===200));
      await outbox.drainFinancialOutbox();assert.equal((await Invoice.findById(invoice._id)).status,'paid');
      assert.equal(await Receipt.countDocuments({_id:payment.id}),1);
      const item=await Outbox.findById(`stripe:${payment.id}`);assert.equal(await Notification.countDocuments({_id:item.notificationId}),1);
    });
    await t.test('local expiry cannot release card reservations; confirmed Stripe expiration can',async()=>{
      const {user,invoice}=await seed();const checkout=await call('/payments/stripe/checkout',user,{invoiceId:String(invoice._id)});
      await Invoice.updateOne({_id:invoice._id},{$set:{stripeCheckoutExpiresAt:new Date(0)}});
      assert.equal((await redeem(user,invoice)).status,409);
      assert.equal((await call('/payments/stripe/cancel-checkout',user,{invoiceId:String(invoice._id)})).status,200);
      assert.equal(remoteById.get(checkout.body.sessionId).status,'expired');
      assert.equal((await redeem(user,invoice)).status,200);
    });
  } finally {
    global.fetch=originalFetch;if(server)await new Promise(resolve=>server.close(resolve));
    await mongoose.disconnect();await mongo.stop();
  }
});

test('standalone MongoDB rejects financial writes without an unsafe fallback',async()=>{
  const mongo=await MongoMemoryServer.create({instance:{ip:'127.0.0.1'}});
  try{
    await mongoose.connect(mongo.getUri());
    const {financialTransaction}=require('../src/utils/financialTransaction');let changed=false;
    await assert.rejects(financialTransaction(['standalone-test'],async()=>{changed=true;}),error=>error.statusCode===503);
    assert.equal(changed,false);
  } finally {await mongoose.disconnect();await mongo.stop();}
});
