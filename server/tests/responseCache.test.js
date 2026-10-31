const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { cacheRoute, clearResponseCache } = require('../src/utils/responseCache');

beforeEach(clearResponseCache);

function read(url = '/api/content/countries') {
  const headers = {};
  let queried = false;
  const res = {
    statusCode: 200,
    set(key, value) { headers[key] = value; return this; },
    get(key) { return headers[key]; },
    status(code) { this.statusCode = code; return this; },
    send(body) { this.body = body; return this; },
  };
  cacheRoute(60_000)({ method: 'GET', originalUrl: url }, res, () => { queried = true; });
  return { res, headers, get queried() { return queried; } };
}

test('public lists revalidate in browsers while repeated reads use the server cache', () => {
  const first = read();
  first.res.send('[{"name":"Country"}]');
  assert.equal(first.headers['Cache-Control'], 'public, max-age=0, must-revalidate');
  const second = read();
  assert.equal(second.queried, false);
  assert.equal(second.res.body, first.res.body);
  assert.equal(second.headers['X-Cache'], 'HIT');
  assert.equal(second.headers['Cache-Control'], first.headers['Cache-Control']);
});

test('a successful deletion invalidates all cached list variants and the next read omits the record', () => {
  for (const url of ['/api/content/countries', '/api/content/countries?page=2', '/api/programs']) read(url).res.send('[{"_id":"deleted"}]');
  clearResponseCache();
  for (const url of ['/api/content/countries', '/api/content/countries?page=2', '/api/programs']) {
    const next = read(url);
    assert.equal(next.queried, true);
    next.res.send('[]');
    assert.equal(read(url).res.body, '[]');
  }
});

test('a delayed pre-deletion read cannot put the deleted record back into the cache', () => {
  const oldRead = read();
  clearResponseCache();
  const freshRead = read();
  freshRead.res.send('[]');
  oldRead.res.send('[{"_id":"deleted"}]');
  assert.equal(read().res.body, '[]');
});

test('simultaneous public reads share one query but never reuse failures', async () => {
  const first=read('/concurrent');const second=read('/concurrent');
  assert.equal(first.queried,true);assert.equal(second.queried,false);
  first.res.send('fresh');await Promise.resolve();
  assert.equal(second.res.body,'fresh');assert.equal(second.queried,false);
  const failed=read('/failure');const retry=read('/failure');
  failed.res.status(500).send('failed');await Promise.resolve();
  assert.equal(retry.queried,true);retry.res.send('recovered');
  assert.equal(read('/failure').res.body,'recovered');
});

test('waiting readers refresh after invalidation and distinct URLs stay separate', async () => {
  const first=read('/race');const waiter=read('/race');
  const other=read('/other');assert.equal(other.queried,true);other.res.send('other');
  clearResponseCache();read('/race').res.send('new');
  first.res.send('old');await Promise.resolve();
  assert.equal(waiter.res.body,'new');assert.equal(read('/race').res.body,'new');
});

test('bounded cache evicts old URLs and bypasses oversized legacy exports', () => {
  read('/old').res.send('old');
  for(let i=0;i<256;i++)read(`/bounded/${i}`).res.send('value');
  assert.equal(read('/old').queried,true);
  read('/large').res.send('x'.repeat(2*1024*1024+1));
  assert.equal(read('/large').queried,true);
});

test('real concurrent HTTP responses share work and preserve each request CORS headers', async () => {
  const express=require('express');const app=express();let queries=0;
  app.use((req,res,next)=>{res.set('Access-Control-Allow-Origin',req.get('Origin'));next();});
  app.get('/catalog',cacheRoute(),async(req,res)=>{
    queries++;await new Promise(resolve=>setTimeout(resolve,25));res.json({version:queries});
  });
  const server=await new Promise(resolve=>{const s=app.listen(0,'127.0.0.1',()=>resolve(s));});
  try {
    const url=`http://127.0.0.1:${server.address().port}/catalog`;
    const replies=await Promise.all(Array.from({length:10},async(_,i)=>{
      const origin=`https://site${i}.example`;const res=await fetch(url,{headers:{Origin:origin}});
      assert.equal(res.headers.get('access-control-allow-origin'),origin);return res.json();
    }));
    assert.equal(queries,1);assert(replies.every(row=>row.version===1));
    clearResponseCache();assert.equal((await(await fetch(url,{headers:{Origin:'https://site.example'}})).json()).version,2);
  } finally {server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}
});
