// Run after the release native libraries have been merged. This validates ELF
// LOAD segments; APK/AAB zip alignment and real 16 KB device QA are separate.
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.argv[2] ||
  'build/app/intermediates/merged_native_libs/release/mergeReleaseNativeLibs/out/lib');
if (!fs.existsSync(root)) throw new Error(`Build native libraries first: ${root}`);
const results = [];
for (const abi of ['arm64-v8a', 'x86_64']) {
  const folder = path.join(root, abi);
  if (!fs.existsSync(folder)) continue;
  for (const file of fs.readdirSync(folder).filter(file => file.endsWith('.so'))) {
    const elf = fs.readFileSync(path.join(folder, file));
    if (elf.subarray(0, 4).toString('hex') !== '7f454c46' || elf[4] !== 2 || elf[5] !== 1) {
      throw new Error(`Expected a little-endian 64-bit ELF: ${abi}/${file}`);
    }
    const phoff = Number(elf.readBigUInt64LE(32));
    const size = elf.readUInt16LE(54), count = elf.readUInt16LE(56);
    const segments = [];
    for (let index = 0; index < count; index++) {
      const base = phoff + size * index;
      if (elf.readUInt32LE(base) !== 1) continue; // PT_LOAD
      const offset = elf.readBigUInt64LE(base + 8);
      const address = elf.readBigUInt64LE(base + 16);
      const alignment = elf.readBigUInt64LE(base + 48);
      segments.push({ alignment: Number(alignment),
        compatible: alignment >= 16384n && offset % 16384n === address % 16384n });
    }
    results.push({ library: `${abi}/${file}`, compatible: segments.length > 0 && segments.every(segment => segment.compatible),
      minimumAlignment: Math.min(...segments.map(segment => segment.alignment)) });
  }
}
if (!results.length) throw new Error('No 64-bit native libraries found');
const failures = results.filter(result => !result.compatible);
console.log(JSON.stringify({ checked: results.length, failures, passed: failures.length === 0 }, null, 2));
process.exitCode = failures.length ? 1 : 0;
