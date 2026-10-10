const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs/promises');
const path=require('node:path');
const os=require('node:os');
const {createHash}=require('node:crypto');
const {BSON}=require('mongodb');
const {verify}=require('../scripts/backup-database.cjs');
const {assertBackups}=require('../src/utils/syncBackupGate.cjs');
test('both complete backups are required and corruption blocks activation',async()=>{
  const directory=await fs.mkdtemp(path.join(os.tmpdir(),'sync-backup-test-'));
  try {
    const bytes=BSON.serialize({_id:new BSON.ObjectId(),big:BSON.Long.fromString('9223372036854775807'),binary:new BSON.Binary(Buffer.from('test'),4),date:new Date(0)});
    const manifest={format:'study-birds-bson-v1',consistentSnapshot:true,collections:[{name:'test',file:'0.bson',count:1,sha256:createHash('sha256').update(bytes).digest('hex')}]};
    await fs.writeFile(path.join(directory,'0.bson'),bytes);
    await fs.writeFile(path.join(directory,'manifest.json'),JSON.stringify(manifest));
    await fs.writeFile(path.join(directory,'VERIFIED'),'test');
    await verify(directory);
    const item={directory,manifestHash:createHash('sha256').update(JSON.stringify(manifest)).digest('hex')};
    const crmDirectory=path.join(directory,'crm');await fs.mkdir(crmDirectory);
    for(const file of ['manifest.json','VERIFIED','0.bson'])await fs.copyFile(path.join(directory,file),path.join(crmDirectory,file));
    const crmItem={...item,directory:crmDirectory};
    const receiptFile=path.join(directory,'receipt.json');
    await fs.writeFile(receiptFile,JSON.stringify({website:item,crm:crmItem}));
    await assertBackups({SYNC_BACKUP_RECEIPT_FILE:receiptFile});
    await fs.writeFile(receiptFile,JSON.stringify({website:item}));await assert.rejects(assertBackups({SYNC_BACKUP_RECEIPT_FILE:receiptFile}));
    await fs.writeFile(receiptFile,JSON.stringify({website:item,crm:crmItem}));
    await fs.appendFile(path.join(directory,'0.bson'),'corrupt');await assert.rejects(verify(directory));
    await assert.rejects(assertBackups({SYNC_BACKUP_RECEIPT_FILE:receiptFile}));
  }finally{await fs.rm(directory,{recursive:true,force:true});}
});
