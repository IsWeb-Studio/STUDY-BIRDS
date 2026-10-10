const test=require('node:test');
const assert=require('node:assert/strict');
const uri=process.env.SYNC_TEST_REPLICA_URI;
test('transactional sync endpoint preserves identities, revisions and operation history',{skip:!uri},async()=>{
  assert.match(uri,/^mongodb:\/\/(localhost|127\.0\.0\.1):\d+\//,'Only an isolated local replica set may run this test');
  const express=require('express'),mongoose=require('mongoose');
  const fs=require('node:fs/promises'),path=require('node:path'),os=require('node:os');
  const {MongoClient}=require('mongodb');
  const {createHash}=require('node:crypto');
  const {backup}=require('../scripts/backup-database.cjs');
  const directory=await fs.mkdtemp(path.join(os.tmpdir(),'sync-api-test-'));
  const old={enabled:process.env.CRM_TWO_WAY_SYNC_ENABLED,company:process.env.CRM_SYNC_COMPANY_ID,receipt:process.env.SYNC_BACKUP_RECEIPT_FILE};
  const client=new MongoClient(uri);let server;
  try{
    await client.connect();await mongoose.connect(uri);
    const owner=new mongoose.Types.ObjectId();
    const app=express();app.use(express.json());
    app.use((req,res,next)=>{req.user={_id:owner,role:req.headers['x-role'] || 'admin'};next();});
    app.use('/api/crm/sync/:companyId',require('../src/routes/crmSyncRoutes'));
    app.use((error,req,res,next)=>res.status(error.status || (res.statusCode>=400?res.statusCode:500)).json({message:error.message}));
    server=app.listen(0,'127.0.0.1');await new Promise(resolve=>server.once('listening',resolve));
    const base=`http://127.0.0.1:${server.address().port}/api/crm/sync`;
    const request=(company,path,body,role)=>fetch(`${base}/${company}${path}`,{method:body?'PUT':'GET',headers:{'Content-Type':'application/json',...(role?{'x-role':role}:{})},...(body?{body:JSON.stringify(body)}:{})});
    process.env.CRM_TWO_WAY_SYNC_ENABLED='false';
    assert.equal((await request('c1','/records')).status,503);
    process.env.CRM_TWO_WAY_SYNC_ENABLED='true';process.env.CRM_SYNC_COMPANY_ID='c1';
    assert.equal((await request('c1','/records')).status,503);
    const receipt={};
    for(const side of ['website','crm']){
      const dbName=`sync-backup-${side}`;await client.db(dbName).collection('original').insertOne({side});
      const envFile=path.join(directory,`${side}.env`);await fs.writeFile(envFile,`MONGODB_URI=${uri}\nMONGODB_DB_NAME=${dbName}`);
      const destination=path.join(directory,side);await backup(envFile,destination);
      receipt[side]={directory:destination,manifestHash:createHash('sha256').update(await fs.readFile(path.join(destination,'manifest.json'))).digest('hex')};
    }
    process.env.SYNC_BACKUP_RECEIPT_FILE=path.join(directory,'receipt.json');await fs.writeFile(process.env.SYNC_BACKUP_RECEIPT_FILE,JSON.stringify(receipt));
    const create={operationId:'create-1',expectedRevision:0,value:{title:'First'}};
    const first=await request('c1','/records/tasks/t1',create);assert.equal(first.status,200);const initial=await first.json();assert.equal(initial.revision,1);
    assert.equal((await request('c1','/records/tasks/t1',create)).status,200);
    assert.equal((await request('c1','/records/tasks/t1',{...create,value:{title:'Different'}})).status,409);
    const update={operationId:'update-1',expectedRevision:1,value:{title:'Second'}};
    const results=await Promise.all([request('c1','/records/tasks/t1',update),request('c1','/records/tasks/t1',{...update,operationId:'update-2',value:{title:'Other'}})]);
    assert.deepEqual(results.map(row=>row.status).sort(),[200,409]);
    const list=await (await request('c1','/records')).json();assert.equal(list.rows.length,1);assert.equal(list.rows[0].revision,2);
    assert.equal((await request('c2','/records')).status,403);
    assert.equal((await request('c1','/records',undefined,'student')).status,403);
    assert.equal(await mongoose.connection.db.collection('crmsyncoperations').countDocuments(),2);
    const deleted=await fetch(`${base}/c1/records/tasks/t1`,{method:'DELETE'});assert.equal(deleted.status,409);
    assert.equal(await mongoose.connection.db.collection('crmsyncrecords').countDocuments(),1);
  }finally{
    await new Promise(resolve=>server ? server.close(resolve):resolve());await mongoose.disconnect();await client.close();
    for(const [key,value] of [['CRM_TWO_WAY_SYNC_ENABLED',old.enabled],['CRM_SYNC_COMPANY_ID',old.company],['SYNC_BACKUP_RECEIPT_FILE',old.receipt]]){if(value===undefined)delete process.env[key];else process.env[key]=value;}
    await fs.rm(directory,{recursive:true,force:true});
  }
});
