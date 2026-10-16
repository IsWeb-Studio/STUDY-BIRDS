// Writes private setup values outside the repository; never prints credentials.
const fs = require('node:fs');
const path = require('node:path');
const {randomBytes, createHash} = require('node:crypto');
const args = process.argv.slice(2);
const value = key => args[args.indexOf(key)+1];
const output = args.includes('--output') ? value('--output') : '';
const userId = args.includes('--user-id') ? value('--user-id') : '';
if (!output || !path.isAbsolute(output) || !/^[a-f\d]{24}$/i.test(userId)) {
  throw new Error('Use --user-id <existing website admin ID> --output <absolute private file outside repository>');
}
const repo = path.resolve(__dirname,'../..');
const relative = path.relative(repo,path.resolve(output));
if (!relative.startsWith('..'+path.sep) && !path.isAbsolute(relative)) throw new Error('Credential output must be outside the repository');
const token = 'sbcrm_' + randomBytes(32).toString('hex');
fs.writeFileSync(output, JSON.stringify({
  website:{CRM_SERVICE_AUTH_ENABLED:'true',CRM_SERVICE_TOKEN_SHA256:createHash('sha256').update(token).digest('hex'),CRM_SERVICE_USER_ID:userId},
  crm:{STUDY_BIRDS_API_TOKEN:token},
},null,2)+'\n',{flag:'wx',mode:0o600});
console.log('Private credential file created. No database changes made.');
