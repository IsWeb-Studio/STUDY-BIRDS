// Local source synchronization only: never deploys, starts a server, or reads .env.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

function digest(file) {
  return fs.existsSync(file) ? crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex') : null;
}
function inside(root, file) {
  const relative = path.relative(root, file);
  return relative !== '' && relative !== '..' && !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative);
}
function safePath(root, relative) {
  const file = path.resolve(root, relative);
  if (!inside(root, file)) throw new Error(`Path outside source/target: ${relative}`);
  let existing = file;
  while (!fs.existsSync(existing)) existing = path.dirname(existing);
  const resolved = fs.realpathSync(existing);
  if (resolved !== root && !inside(root, resolved)) throw new Error(`Link outside source/target: ${relative}`);
  return file;
}
function sync({ target, apply = false, base = __dirname, bundle = 'assignment' }) {
  if (!['assignment', 'journey', 'consultation'].includes(bundle)) throw new Error('Unknown reviewed bundle');
  const source = fs.realpathSync(path.join(base, `${bundle}-release`));
  const destination = fs.realpathSync(target);
  const entries = JSON.parse(fs.readFileSync(path.join(base, `${bundle}-sync-manifest.json`), 'utf8'));
  const pending = [];
  for (const entry of entries) {
    const src = safePath(source, entry.path), dst = safePath(destination, entry.path);
    if (digest(src) !== entry.after) throw new Error(`Reviewed source changed: ${entry.path}`);
    const current = digest(dst);
    if (current === entry.after) continue;
    if (current !== entry.before) throw new Error(`Target has other edits; refusing overwrite: ${entry.path}`);
    pending.push({ src, dst, entry });
  }
  // Validate the entire bundle before any writes, then recheck each file immediately before copying.
  if (apply) for (const { src, dst, entry } of pending) {
    if (digest(dst) !== entry.before) throw new Error(`Target changed during sync: ${entry.path}`);
    fs.mkdirSync(path.dirname(dst), { recursive: true });
    fs.copyFileSync(src, dst);
  }
  return pending.map(({ entry }) => entry.path);
}
if (require.main === module) {
  try {
    const args = process.argv.slice(2);
    const apply = args.includes('--apply');
    const bundleIndex = args.indexOf('--bundle');
    const bundle = bundleIndex < 0 ? 'assignment' : args[bundleIndex + 1];
    if (bundleIndex >= 0) args.splice(bundleIndex, 2);
    const remaining = args.filter(arg => arg !== '--apply');
    if (remaining.length !== 2 || remaining[0] !== '--target') {
      throw new Error('Usage: node integration/sync-assignment-source.cjs --target <website-root> [--bundle assignment|journey|consultation] [--apply]');
    }
    const files = sync({ target: remaining[1], apply, bundle });
    console.log(`${apply ? 'Synced' : 'Ready to sync'} ${files.length} files. No deployment performed.`);
    for (const file of files) console.log(file);
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
module.exports = { sync };
