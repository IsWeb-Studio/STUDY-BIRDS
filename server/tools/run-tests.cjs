const path = require('node:path');
const { readdirSync } = require('node:fs');
const { spawnSync } = require('node:child_process');
(async () => {
  const root = path.resolve(__dirname, '..');
  const toolsRoot = process.env.STUDY_BIRDS_TEST_TOOLS;
  const { MongoBinary } = require(toolsRoot ? path.join(toolsRoot, 'node_modules/mongodb-memory-server-core') : 'mongodb-memory-server-core');
  await MongoBinary.getPath(); // Download before tests disable external traffic.
  const files = readdirSync(path.join(root, 'tests')).filter(name => name.endsWith('.test.js')).map(name => path.join(root, 'tests', name));
  const result = spawnSync(process.execPath, ['--require', path.join(root, 'tests/networkIsolation.cjs'), '--test', '--test-concurrency=2', ...files], { cwd: root, stdio: 'inherit', env: { ...process.env, NODE_ENV: 'test' } });
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
})().catch(error => { console.error(error); process.exitCode = 1; });
