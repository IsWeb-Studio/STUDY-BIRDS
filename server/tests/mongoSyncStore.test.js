const test=require('node:test');
const assert=require('node:assert/strict');
const uri=process.env.SYNC_TEST_REPLICA_URI;
test('Mongo outbox survives recreation and one worker holds the distributed lease',{skip:!uri},async()=>{
  assert.match(uri,/^mongodb:\/\/(localhost|127\.0\.0\.1):\d+\//);
  const {MongoClient}=require('mongodb');
  const {createMongoSyncStore}=require('../src/utils/mongoSyncStore.cjs');
  const client=new MongoClient(uri);await client.connect();
  try{
    const db=client.db('sync-store-test');
    const a=createMongoSyncStore({db,client,namespace:'company:one'}),b=createMongoSyncStore({db,client,namespace:'company:one'});
    const lease=await a.acquire();assert.ok(lease);assert.equal(await b.acquire(),null);
    const job={operationId:'op',key:'tasks:t',expectedRevision:0,value:{title:'A'},push:true,pull:false};
    await a.enqueue(job);await a.enqueue(job);assert.equal(await db.collection('two_way_sync_jobs').countDocuments(),1);
    assert.equal(await b.hasOpenConflict(job.key),true);
    assert.equal((await b.pending())[0].operationId,'op');
    await a.markRemoteApplied('op',{revision:1,value:job.value});
    await a.complete('op',{key:job.key,revision:1,value:job.value});
    assert.equal((await b.pending()).length,0);assert.equal((await b.checkpoints())[job.key].revision,1);
    assert.equal((await db.collection('two_way_sync_jobs').findOne({})).remoteResult.revision,1);
    await a.saveReviews([{key:job.key,local:{title:'A'},remote:{title:'B'}}],[]);assert.equal(await b.hasOpenConflict(job.key),true);
    const foreign=createMongoSyncStore({db,client,namespace:'company:two'});assert.equal(await foreign.hasOpenConflict(job.key),false);
    await a.release(lease);assert.ok(await b.acquire());await assert.rejects(a.assertLease(lease));
  }finally{await client.close();}
});
