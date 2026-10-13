const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const { sync } = require('./sync-assignment-source.cjs');
const hash = text => crypto.createHash('sha256').update(text).digest('hex');

test('source sync dry-run, conflict protection, apply and rerun', () => {
  const base = fs.mkdtempSync(path.join(os.tmpdir(), 'studybirds-assignment-sync-'));
  const source = path.join(base, 'assignment-release');
  const target = path.join(base, 'website');
  fs.mkdirSync(source); fs.mkdirSync(target);
  fs.writeFileSync(path.join(source, 'existing.js'), 'new');
  fs.writeFileSync(path.join(source, 'added.js'), 'added');
  fs.writeFileSync(path.join(target, 'existing.js'), 'old');
  const entries = [
    { path: 'added.js', before: null, after: hash('added') },
    { path: 'existing.js', before: hash('old'), after: hash('new') },
  ];
  const manifest = path.join(base, 'assignment-sync-manifest.json');
  fs.writeFileSync(manifest, JSON.stringify(entries));
  assert.equal(sync({ base, target }).length, 2);
  assert.equal(fs.existsSync(path.join(target, 'added.js')), false);
  fs.writeFileSync(path.join(target, 'existing.js'), 'user edits');
  assert.throws(() => sync({ base, target, apply: true }), /refusing overwrite/);
  assert.equal(fs.existsSync(path.join(target, 'added.js')), false);
  fs.writeFileSync(path.join(target, 'existing.js'), 'old');
  fs.writeFileSync(path.join(source, 'added.js'), 'unreviewed');
  assert.throws(() => sync({ base, target, apply: true }), /source changed/);
  fs.writeFileSync(path.join(source, 'added.js'), 'added');
  assert.equal(sync({ base, target, apply: true }).length, 2);
  assert.equal(fs.readFileSync(path.join(target, 'existing.js'), 'utf8'), 'new');
  assert.deepEqual(sync({ base, target, apply: true }), []);
  fs.writeFileSync(manifest, JSON.stringify([{ path: '../escape.js', before: null, after: hash('escape') }]));
  assert.throws(() => sync({ base, target, apply: true }), /outside source\/target/);
});
