const {test}=require('node:test');
const assert=require('node:assert/strict');
const uri=process.env.CATALOG_TEST_URI;

test('catalog writes preserve fields and reject stale edits and deletions', {skip:!uri}, async()=>{
  assert.match(uri,/^mongodb:\/\/127\.0\.0\.1:\d+\//);
  const mongoose=require('mongoose');
  await mongoose.connect(uri);
  let server;
  try{
    process.env.JWT_SECRET='isolated-catalog-revision-test';
    const jwt=require('jsonwebtoken');
    const User=require('../src/models/User');
    const Country=require('../src/models/Country');
    const University=require('../src/models/University');
    const Program=require('../src/models/Program');
    const Field=require('../src/models/StudyField');
    const actor=await User.create({name:'Catalog admin',email:'catalog@example.test',role:'admin'});
    const limited=await User.create({name:'Support',email:'limited@example.test',role:'employee',permissions:['support']});
    server=await new Promise(resolve=>{const s=require('../src/app').listen(0,'127.0.0.1',()=>resolve(s));});
    async function call(path,body,method='PUT',user=actor){
      const result=await fetch(`http://127.0.0.1:${server.address().port}/api${path}`,{method,headers:{'Content-Type':'application/json',Authorization:`Bearer ${jwt.sign({userId:user._id},process.env.JWT_SECRET)}`},body:body===undefined?undefined:JSON.stringify(body)});
      return {status:result.status,body:await result.json()};
    }
    const country=await Country.create({name:'Revision Country',code:'RC',description:'Keep description',nameAr:'Keep Arabic',visaRequirements:[{docKey:'passport',label:'Passport'}]});
    const university=await University.create({name:'Revision University',country:country._id,overviewEn:'Keep English',logo:'Keep logo',tuitionRange:{min:100,max:200}});
    const program=await Program.create({title:'Revision Program',university:university._id,degreeLevel:'Bachelor',fieldOfStudy:'Medicine',language:'Turkish',summaryEn:'Keep English',requiredDocumentTypes:['passport']});
    const field=await Field.create({name:'Revision Field',description:'Keep description',image:'Keep image',featured:true});
    for(const [path,record,key,value] of [
      ['/admin/countries',country,'name','Updated country'],
      ['/universities',university,'city','Updated city'],
      ['/programs',program,'tuition',300],
      ['/admin/study-fields',field,'sortOrder',5],
    ]){
      const id=String(record._id);
      assert.equal((await call(`${path}/${id}`,{[key]:value})).status,428);
      const results=await Promise.all([call(`${path}/${id}`,{[key]:value,expectedVersion:0}),call(`${path}/${id}`,{[key]:value,expectedVersion:0})]);
      assert.deepEqual(results.map(row=>row.status).sort(),[200,409]);
      assert.equal(results.find(row=>row.status===200).body.__v,1);
      assert.equal((await call(`${path}/${id}`,{[key]:value,expectedVersion:0})).status,409);
      assert.equal((await call(`${path}/${id}`,{[key]:value,expectedVersion:1},'PUT',limited)).status,403);
    }
    const savedCountry=await Country.findById(country._id).lean();
    assert.equal(savedCountry.nameAr,'Keep Arabic');assert.equal(savedCountry.description,'Keep description');assert.equal(savedCountry.visaRequirements[0].docKey,'passport');
    const savedUniversity=await University.findById(university._id).lean();assert.equal(savedUniversity.overviewEn,'Keep English');assert.equal(savedUniversity.logo,'Keep logo');assert.equal(savedUniversity.tuitionRange.max,200);
    assert.equal((await call(`/universities/${university._id}`,{tuitionRange:{min:150},expectedVersion:1})).status,200);
    assert.equal((await University.findById(university._id)).tuitionRange.max,200);
    const savedProgram=await Program.findById(program._id).lean();assert.equal(savedProgram.summaryEn,'Keep English');assert.deepEqual(savedProgram.requiredDocumentTypes,['passport']);
    const savedField=await Field.findById(field._id).lean();assert.equal(savedField.description,'Keep description');assert.equal(savedField.image,'Keep image');assert.equal(savedField.featured,true);
    assert.equal((await call(`/programs/${program._id}`,{tuition:400,expectedVersion:-1})).status,400);
    assert.equal((await call(`/programs/${program._id}`,{$set:{tuition:400},expectedVersion:1})).status,400);
    const list=await call('/programs',undefined,'GET');assert.equal(list.body.find(row=>row._id===String(program._id)).__v,1);
    const page=await call('/programs?page=1&limit=20',undefined,'GET');
    assert.equal(page.status,200);
    assert.deepEqual(page.body.items,list.body);
    assert.equal(page.body.pagination.total,list.body.length);
    for(const filter of [`university=${university._id}`,`country=${country._id}`,'language=Turkish','tuitionMin=250&tuitionMax=350','degreeLevel=Bachelor','keyword=Revision&adminSearch=true']) {
      const filtered=await call(`/programs?page=1&limit=20&${filter}`,undefined,'GET');
      assert.equal(filtered.status,200);assert.equal(filtered.body.pagination.total,1,filter);
      assert.deepEqual(filtered.body.items,page.body.items);
    }
    assert.equal((await call('/programs?page=99&limit=20',undefined,'GET')).body.items.length,0);
    assert.equal((await call('/programs?page=1&keyword=absent-program',undefined,'GET')).body.pagination.total,0);
    assert.equal((await call('/programs?page=1&university=invalid',undefined,'GET')).status,400);
    const preflight=await fetch(`http://127.0.0.1:${server.address().port}/api/programs`,{method:'OPTIONS',headers:{Origin:'https://studybirds.net','Access-Control-Request-Method':'GET','Access-Control-Request-Headers':'authorization'}});
    assert.equal(preflight.status,204);assert.equal(preflight.headers.get('access-control-max-age'),'600');
    assert.equal((await call(`/programs/${program._id}`,{expectedVersion:0},'DELETE')).status,409);
    assert.ok(await Program.exists({_id:program._id}));
    assert.equal((await call(`/programs/${program._id}`,{expectedVersion:1},'DELETE')).status,200);
    assert.equal((await call(`/programs/${program._id}`,{expectedVersion:1},'DELETE')).status,404);
    // The production Vercel frontend predates revision payloads on DELETE.
    const legacyProgram=await Program.create({title:'Legacy delete',university:university._id,degreeLevel:'Bachelor',fieldOfStudy:'Medicine'});
    assert.equal((await call(`/programs/${legacyProgram._id}`,undefined,'DELETE')).status,200);
    assert.equal(await Program.exists({_id:legacyProgram._id}),null);
    // Old records without a version are upgraded by a successful CAS write.
    await Field.collection.updateOne({_id:field._id},{$unset:{__v:''}});
    assert.equal((await call(`/admin/study-fields/${field._id}`,{sortOrder:8,expectedVersion:0})).body.__v,1);
    assert.equal((await call(`/admin/study-fields/${field._id}`,{expectedVersion:1},'DELETE')).status,200);
  }finally{if(server)await new Promise(resolve=>server.close(resolve));await mongoose.disconnect();}
});
