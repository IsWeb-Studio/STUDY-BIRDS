const test = require('node:test');
const assert = require('node:assert/strict');
const Program = require('../src/models/Program');
const University = require('../src/models/University');
const { getPrograms } = require('../src/controllers/programController');
const { getUniversities } = require('../src/controllers/universityController');
function chain(rows, calls) {
  const q={lean:async()=>rows};
  for(const method of ['select','populate','sort','skip','limit'])q[method]=(...args)=>{calls.push([method,...args]);return q;};
  return q;
}
function response(){return {set(){},json(data){this.data=data;}};}
test('program admin pages remain bounded and preserve search, filter, and revision metadata',async()=>{
  const oldFind=Program.find,oldCount=Program.countDocuments,oldUniversity=University.find;
  const oldAggregate=Program.aggregate;
  Program.aggregate=async()=>[{_id:'p',__v:9}];
  const calls=[];let filter;
  Program.find=query=>{filter=query;return chain([{_id:'p',__v:9}],calls);};
  Program.countDocuments=async()=>3751;
  University.find=()=>chain([{_id:'u'}],[]);
  try{
    const res=response();await getPrograms({query:{page:'2',limit:'20',keyword:'C++',adminSearch:'true',fieldOfStudy:'Science'}},res,error=>{throw error;});
    assert(calls.some(c=>c[0]==='skip'&&c[1]===20));assert(calls.some(c=>c[0]==='limit'&&c[1]===20));
    assert(calls.find(c=>c[0]==='select')[1].includes('__v'));
    assert.equal(filter.$and[0].$or[0].title.$regex,'C\\+\\+');
    assert.equal(filter.$or[0].fieldOfStudy,'Science');
    assert.equal(res.data.pagination.total,3751);assert.equal(res.data.pagination.totalPages,188);
    assert.equal(res.data.items[0].__v,9);
    calls.length=0;await getPrograms({query:{}},response(),error=>{throw error;});
    assert(!calls.some(c=>c[0]==='limit'),'legacy CRM reads must not silently become a partial page');
  }finally{Program.find=oldFind;Program.countDocuments=oldCount;University.find=oldUniversity;Program.aggregate=oldAggregate;}
});
test('university selectors return all names without loading articles or populating countries',async()=>{
  const old=University.find,calls=[];
  University.find=()=>chain([{_id:'u',name:'University',slug:'uni'}],calls);
  try{
    const res=response();await getUniversities({query:{options:'true'}},res,error=>{throw error;});
    assert.equal(calls.find(c=>c[0]==='select')[1],'name nameEn slug');
    assert(!calls.some(c=>['populate','limit'].includes(c[0])));
    assert.equal(res.data[0].name,'University');
  }finally{University.find=old;}
});
