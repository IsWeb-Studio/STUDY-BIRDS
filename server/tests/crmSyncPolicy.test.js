const test=require('node:test');
const assert=require('node:assert/strict');
const {validateOperation,recordId,resources}=require('../src/utils/crmSyncPolicy.cjs');
test('operations reject secrets and unknown envelope fields',()=>{
  const base={operationId:'op1',expectedRevision:0,value:{title:'Task'}};
  assert.doesNotThrow(()=>validateOperation(base));
  assert.throws(()=>validateOperation({...base,value:{profile:{password:'secret'}}}));
  assert.throws(()=>validateOperation({...base,role:'admin'}));
  assert.throws(()=>validateOperation({...base,expectedRevision:-1}));
});
test('identities are isolated by owner, tenant and resource',()=>{
  const a=recordId('u1','c1','tasks','1');
  for(const args of [['u2','c1','tasks','1'],['u1','c2','tasks','1'],['u1','c1','leads','1']])assert.notEqual(a,recordId(...args));
  assert.ok(!resources.includes('users'));assert.ok(!resources.includes('payments'));
});
