// Read-only BSON export, including GridFS and index definitions. Never imports app startup.
const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');
const { MongoClient, BSON } = require('mongodb');
const dotenv = require('dotenv');

async function verify(directory) {
  const manifest = JSON.parse(await fs.readFile(path.join(directory, 'manifest.json'), 'utf8'));
  for (const item of manifest.collections) {
    const bytes = await fs.readFile(path.join(directory, item.file));
    if (crypto.createHash('sha256').update(bytes).digest('hex') !== item.sha256) throw new Error('Backup checksum mismatch');
    let count = 0, offset = 0;
    while (offset < bytes.length) {
      const size = bytes.readInt32LE(offset);
      if (size < 5 || offset + size > bytes.length) throw new Error('Invalid BSON framing');
      BSON.deserialize(bytes.subarray(offset, offset + size)); offset += size; count++;
    }
    if (count !== item.count) throw new Error('Backup document count mismatch');
  }
  return manifest;
}

async function backup(envFile, output) {
  const env = dotenv.parse(await fs.readFile(envFile));
  if (!env.MONGODB_URI) throw new Error('MongoDB configuration missing');
  await fs.mkdir(output, { recursive: true });
  const client = new MongoClient(env.MONGODB_URI, { serverSelectionTimeoutMS: 15000 });
  try {
    await client.connect();
    const db = client.db(env.MONGODB_DB_NAME || undefined);
    const collections = await db.listCollections({}, { nameOnly: false }).toArray();
    const session = client.startSession({ snapshot: true });
    const manifest = { format: 'study-birds-bson-v1', createdAt: new Date().toISOString(), database: db.databaseName, consistentSnapshot: true, collections: [] };
    try {
      for (const [index, collection] of collections.entries()) {
        if (collection.type !== 'collection') continue;
        const file = `${index}.bson`, destination = path.join(output, file);
        const handle = await fs.open(destination, 'wx');
        const hash = crypto.createHash('sha256'); let count = 0;
        try {
          for await (const row of db.collection(collection.name).find({}, { session, promoteLongs: false, promoteValues: false })) {
            const bytes = BSON.serialize(row); await handle.writeFile(bytes); hash.update(bytes); count++;
          }
        } finally { await handle.close(); }
        manifest.collections.push({ name: collection.name, file, count, sha256: hash.digest('hex'), options: collection.options, indexes: await db.collection(collection.name).listIndexes().toArray() });
      }
    } finally { await session.endSession(); }
    await fs.writeFile(path.join(output, 'manifest.json'), JSON.stringify(manifest, null, 2), { flag: 'wx' });
    await verify(output);
    await fs.writeFile(path.join(output, 'VERIFIED'), manifest.createdAt, { flag: 'wx' });
    console.log(JSON.stringify({ verified: true, collections: manifest.collections.length, documents: manifest.collections.reduce((n, c) => n + c.count, 0), directory: output }));
  } finally { await client.close(); }
}
if (require.main === module) {
  const [envFile, output, crmDirectory, receiptFile] = process.argv.slice(2);
  const createReceipt=async()=>{
    const receipt={createdAt:new Date().toISOString()};
    for(const [side,directory] of [['website',output],['crm',crmDirectory]]){
      await verify(directory);await fs.access(path.join(directory,'VERIFIED'));
      receipt[side]={directory:path.resolve(directory),manifestHash:crypto.createHash('sha256').update(await fs.readFile(path.join(directory,'manifest.json'))).digest('hex')};
    }
    await fs.writeFile(receiptFile,JSON.stringify(receipt,null,2),{flag:'wx'});console.log('Verified backup receipt created');
  };
  (envFile === '--receipt' ? createReceipt() : envFile === '--verify' ? verify(output).then(() => console.log('Backup verified')) : backup(envFile, output))
    .catch(() => { console.error('Backup failed; no database changes made. Check connectivity, snapshot-read permission and output directory.'); process.exitCode = 1; });
}
module.exports = { backup, verify };
