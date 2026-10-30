# Study Birds — practical low-space B0 design

2026-10-22. Design only, controlled by `STUDYBIRDS_B0_RECOVERY_PREFLIGHT.md`, `STUDYBIRDS_PHYSICAL_MIGRATION_PLAN.md` and `STUDYBIRDS_C_CAPACITY_CANDIDATES.md`.

**Decision: GO for further preparation of this bounded design; NO-GO for B0 execution or migration today.** A packed, encrypted backup may fit without deleting anything and without reducing the Android reserve. This is a plausible budget, not measured archive output or a verified backup implementation. Encryption/metadata tooling, consistent snapshot approval and sequential restore capacity remain execution blockers. No deletion-candidate search was performed.

Only this report was created. No backup directory/file, compression experiment, copy, database operation, service stop, Git mutation, build or migration was executed. No secret contents were read. Read-only checks sampled free space and tool locations.

## What changes from the earlier budget

The earlier 17.241 GiB backup allowance modelled individually allocated destination files plus metadata, growth and temporary reserves. It was appropriately conservative for a filesystem copy. A packed archive stores file byte streams without allocating a separate NTFS cluster for each of the 238,266 source files or creating all 54,555 directories in the backup destination. That structural saving is distinct from compression. Actual archive headers, additional streams and encryption overhead still count and must be measured.

Use a **fresh, immutable archive set written directly into private encrypted storage**, with bounded metadata and per-entry compression; never create a full plaintext staging tree, a temporary full ZIP, or a second encrypted copy. Never update an existing archive in place: some tools rewrite it and temporarily need another archive-sized allocation. Small independently readable shards bound retries and support sequential verification; a large source file may span container volumes while retaining its complete length and hash. Shard boundaries must not split away required metadata or make the manifest ambiguous.

Do not reduce the preservation scope to make the budget fit. All exact B0 allowlisted roots/files remain covered, including ignored/private material, all seven Git owners and six linked worktrees, every object/ref/reflog/raw index, staged-only and unreachable content, checkpoints, duplicate APK paths, signing material, private profiles and QA resources. Preserve all 13 raw indexes byte-for-byte. A bundle, patch, fresh clone, exported source tree or restaging files is not a substitute. No deduplication or dependency omission is assumed.

## Proposed conservative operating envelope

Fresh sampled free space: **C 33,858,093,056 bytes (31.533 GiB); D 8,053,747,712 bytes (7.501 GiB)**. These live values changed since discovery; no recovery action is attributed to this variation. Recheck immediately before any approved execution.

| Component | Proposed hard envelope | Treatment |
|---|---:|---|
| Entire final encrypted backup set, including encrypted inventory, stream/security/link metadata and QA cold DB component | **14.25 GiB = 15,300,820,992 bytes** | Must be demonstrated, not assumed |
| C working spill/manifest/encryption overhead outside that set | **0.25 GiB** | No full temporary archive; count any spill/pagefile growth against free space |
| C background growth/abort margin | **0.50 GiB** | Additional to build reserve; stop before it is exhausted |
| C minimum retained QA build reserve | **16 GiB** | Unchanged |
| Required initial C free for this envelope | **31.00 GiB** | Current sample exceeds by ~0.533 GiB |
| C remaining after all 15 GiB of backup/work/margin allocation | **16.533 GiB** | Not an Android build authorization |
| D isolated sequential restore workspace | **Up to 3 GiB** | Includes restored allocation, ACL metadata, Git test overhead and DB runtime growth |
| D remaining with full scratch allowance | **4.501 GiB** | Above proposed migration-only 4 GiB floor, below existing build threshold |

The earlier logical payload is **14,943,310,906 bytes (13.917 GiB)**. The 14.25 GiB final-set cap permits only **357,510,086 bytes (~341 MiB)** beyond that historical default-stream payload. Packing alone could therefore fit, but complete ADS/security metadata, new files, database growth and container overhead could exceed it. This report claims **zero measured compression savings**. If measured all-in output exceeds 14.25 GiB, this particular envelope is NO-GO; re-budget explicitly, preserving C >=16 GiB plus measured transient/background needs. Do not drop files or silently consume the build reserve.

The 0.25/0.50 GiB allowances are proposed measurable caps, not proof that an arbitrary backup tool fits. A tool needing more spill, memory-induced paging or a larger safety margin requires a revised budget. Keep compression memory bounded (e.g. reviewed <=64 MiB dictionary, limited workers) and account for actual host RAM before approval. Stop on resource pressure rather than assuming RAM is disk-free storage.

For migration itself retain **D >=4 GiB before each approved batch**, with the existing **<=256 MiB** batch-growth allowance and monitoring. Three GiB scratch and a migration batch must not overlap without a fresh combined budget. The real minimum is the approved batch's measured peak plus rollback overhead and the 4 GiB floor, not an assertion that renames cost zero. Source-sized copy fallbacks remain prohibited. Restore scratch is removed only by a separately approved exact-path operation after verification; until then that batch capacity is occupied.

**Android policies remain unchanged:** QA gate DENY, resources=false/pending CA, C reserve16 GiB and existing D >=8 GiB requirement. D currently fails the build threshold even before restore work. Migration-only floor4 GiB does not authorize compilation or assembly.

## Measuring compression without guessing

Future approved preparation should measure the **whole frozen selection**, not extrapolate from a few text files. A reviewed encoder may stream losslessly compressed/encrypted output to a byte-counting sink that discards output, using bounded RAM and no disk spill. This reads protected data and performs compression, so it is **not authorized or executed now**. Validate that the encoder supports this mode; otherwise use an explicitly approved bounded encrypted trial shard, retaining it and charging its bytes to the final set. Do not make a plaintext sample or duplicate full archive.

Record input lengths, exact format/options, per-shard output lengths, encryption/metadata overhead and the frozen inventory digest. Already-compressed ZIP/APK/Git pack files may save almost nothing or expand. Prefer store mode for such entries when measured beneficial, ordinary lossless compression for others, with no cross-file deduplication or altered file contents. Count complete metadata and stream records. A count pass is predictive only: actual final allocated size and continuing free-space monitoring decide acceptance. Changed inputs invalidate the count.

No suitable complete toolchain was established. `7z`, `7za`, `mongodump` and `mongorestore` were not found on PATH; checked conventional `C:\Program Files\7-Zip\7z.exe` and MongoDB Tools `100\bin` locations were absent. This is not an exhaustive installation search. Built-in ZIP is not accepted as an encrypted, metadata-complete backup solution. A reviewed available tool must prove capabilities before execution; new installation/download requires separate approval.

## Exact future workflow — separately approved operations

1. **Approve scope and mechanism.** Reuse the B0 report's exact A–E allowlist, not an unrestricted drive wildcard. Review a backup writer/reader supporting Unicode/long paths, binary content, empty directories, alternate streams, owner/DACL and required security metadata, timestamps/attributes and link records without traversal. Record unsupported EFS/EA/reparse/security data as blockers, not silent exclusions. Verify destination canonical ancestry, absence, ACLs, encryption, cap enforcement and no temporary full-image behavior. Proposed C root remains `C:\Users\Abood\AppData\Local\StudyBirds\migration-recovery-20261022`; absent status must be rechecked.
2. **Approve consistency window.** Owner closes Git/editor/automation writers across every relevant worktree and browsers using the five private profiles. Stop QA writers/API gracefully, then MongoDB through its documented approved lifecycle, verifying clean shutdown. Do not infer current PIDs from old reports. Take no final snapshot while writers remain active. Restart order and failure recovery must be agreed before downtime.
3. **Freeze exact inventory.** Record every relative path, length, SHA-256 for every file/stream, deleted working-path records, directory/security metadata, link target/type without traversal, repository ownership, refs, raw indexes, staged entries, object stores and worktree backlinks. Resolve alternate object-store dependencies explicitly; external required content must be included or block. Hash source before/after reading to detect changes; quiescence is still necessary. Protect inventory and Git configs as private data.
4. **Measure and admit.** Confirm whole-scope packed size <=14.25 GiB including the cold DB and metadata; C >=31 GiB at start; verify the largest sequential restore unit and its test overhead fit D scratch without crossing D4 GiB. Stop if not. No preservation requirement is traded away.
5. **Write once.** Stream allowlisted ordinary files and explicit link/metadata records directly into the fresh encrypted set. Hash input while reading; never follow source links or stage plaintext. Count final allocation and every transient byte. Monitor C/D free space; stop before C16 GiB or approved working/background caps are breached. A failed/incomplete set is labelled incomplete, retained privately and never counts as recovery. No automatic deletion/retry/overwrite; retained failed data must be included in a new budget.
6. **Verify every byte.** Close/finalize output and reopen through an independent read/decrypt path. Decode all members sequentially into hash sinks; compare path/stream counts, lengths and SHA-256 with the frozen manifest, validate directory/link/security inventories and final encrypted-volume hashes. Test wrong-key failure and a bounded corruption case only on separately approved disposable test data, never corrupt the recovery set. CRC/archive test alone is insufficient.
7. **Restore sequential representatives and Git stores.** Use a fresh private isolated D scratch root, proposed `D:\work\StudyBirds-B0-restore-test-20261022` (not created or verified absent today). Restore one complete Git owner/store with its relevant index/worktree samples at a time, within the measured 3 GiB ceiling. All owners must be tested, not just one easy repository. Largest unit and filesystem allocation are not yet measured: if any owner plus required test data exceeds the ceiling, stop for a bounded alternate restore design. Verify object integrity (`fsck` without repair/lost-found), refs, raw-index hashes and staged blob accessibility, including staged/working disagreement and untracked/ignored samples. Isolate restored Git metadata so no backlink, alternates file or configuration can reach a live repository; original metadata remains archived unchanged. Disable hooks, external filters and lazy network fetching; offline missing objects are a failure. Never run Git on a restored `.git` backlink still targeting the original tree.
8. **Exercise metadata and binary recovery.** Materialize a largest-file sample, APK, signing/config sample, checkpoint, empty directory, link record, stream/ACL example and private-profile sample sequentially. Hash without printing secrets; do not execute APKs, import keys or launch recovered browsers. Large binaries need no full extraction for 100% byte verification, but actual selected materializations prove the reader can write/restore metadata. Sequential reuse needs explicit scratch-only cleanup approval and receipts; no source/backup deletion authority follows.
9. **Accept B0, then seek batch approval.** Require all members verified, all Git-owner restore checks passed, DB consistency/restore evidence, recoverable encryption key and unchanged source/index/protected hashes. A private signed/HMAC-authenticated manifest or independently trusted integrity receipt binds volumes and inventory; key must not live solely in the same archive. Retain the completed set throughout migration. No migration batch starts merely because backup writing succeeded. A QA restart/new writes require a new batch-specific snapshot or reviewed delta preserving the baseline before QA data is moved.

Streaming verification proves stored content, not filesystem restore permissions, Git operational recovery, DB recovery or browser credential portability. Those require the bounded actual restore tests above. If repeated test cleanup is not approved, scratch accumulates and this low-space model fails.

## QA database — a separate consistency component

Recommended here: **cold filesystem backup after approved clean shutdown**, separately inventoried inside the encrypted set, retaining the complete original QA DB directory, journals, configuration, keys, storage/mail/TLS and relevant version metadata. Do not copy live WiredTiger files and call them consistent. The historical 217,481,969-byte QA root is already in the payload, not an extra DB allowance or current size. Measure its frozen size and test-growth requirements anew.

After backup, restore the cold DB into private isolated scratch and use the compatible existing MongoDB version under a separate runtime-test authorization. Explicitly private binding, no original dbPath, no application writers, no production connection, and access control/network constraints must be reviewed before starting it. Verify representative collections, indexes and application/account relationships against the frozen source evidence without exposing personal data. Runtime journal/preallocation growth counts against scratch. If safe isolated operation cannot be established, DB restore testing remains blocked and B0 is not fully accepted.

Logical `mongodump --archive` streamed into encryption is an alternative only with compatible verified tools and all writers paused, including non-API writers. A standalone deployment cannot assume replica-set oplog consistency. Preserve users/roles/options and external storage consistently; a logical dump does not replace required raw private/Git state or, under this unchanged scope, eliminate the original cold DB preservation. An additional logical dump costs extra bytes and must be budgeted. MongoDB documents filesystem and tool-based backup methods and warns concurrent changes can affect dump consistency. [MongoDB backup methods](https://www.mongodb.com/docs/manual/core/backups/), [mongodump documentation](https://www.mongodb.com/docs/database-tools/mongodump/).

## Privacy and encryption acceptance

Encrypt payload **and filenames/inventories** before persistent output; no plaintext secret-bearing list in TEMP, shell history, process arguments or Git. Owner approves destination-specific private ACLs and safe interactive key entry. Credentials, signing keys, TLS material, DB data and browser profiles are explicitly in the private approval scope. Keep an independently recoverable owner-controlled key, with tested unlock; a key stored only inside its own archive is unusable.

7z supports AES-256, but that fact alone does not prove a particular installed writer preserves NTFS metadata or provides authenticated integrity. Require reviewed cryptographic integrity in addition to confidential storage and hashes bound to a trusted receipt. No custom encryption scheme is proposed. [Official 7z format documentation](https://www.7-zip.org/7z.html).

Browser session stores may depend on Windows/user-bound key protection; copying a closed profile preserves its bytes but does not guarantee login portability. Preserve profile security context metadata without exporting unrelated global credentials. If more key material is needed, obtain separate scoped privacy approval or keep the profiles unmoved; never claim portable credential recovery from a hash test.

Both partitions are on Disk 0. This is recovery from migration mistakes, **not independent protection against disk failure, theft or host compromise**. Owner must explicitly accept that limitation; no external drive is assumed.

## Final approval checklist

- [ ] Verified encrypted, metadata-complete tool and independent reader; no full staging/rewrite; bounded spill/RAM and safe key handling.
- [ ] Owner accepts same-disk risk, exact private-data scope, planned service/browser/editor downtime and restart.
- [ ] Fresh frozen scope, measured <=14.25 GiB final set and all resource caps; no assumed compression ratio.
- [ ] C>=31 GiB initial with C16 GiB retained; D>=4 GiB throughout; largest complete Git/DB restore units proven to fit scratch.
- [ ] Separately authorized backup creation, isolated restore/runtime tests and exact scratch-only lifecycle/cleanup. No backup pruning.
- [ ] Full stream/hash/metadata verification, every Git owner restored and DB recovery demonstrated before migration sign-off.
- [ ] Separate reviewed B1–B8 approvals; Android gate and capacity policies unchanged.

**Current outcome: technically plausible low-space envelope, execution NO-GO until these conditions are met.** No measured archive size, encryption recovery, actual Git restore or DB restore success is claimed.

## خلاصة عربية

التصميم المقترح يكتب نسخة مشفّرة مباشرة على C دون أرشيف مؤقت كامل، ويتحقق من جميع الملفات عبر القراءة والبصمات، ثم يختبر الاستعادة بالتتابع على D. سقف النسخة 14.25 GiB، وإجمالي ميزانية C الإضافية 15 GiB، مع إبقاء احتياطي 16 GiB للبناء. هذا قد يناسب المساحة الحالية، لكن حجم الأرشيف الفعلي وأداة التشفير وحفظ البيانات الوصفية لم تُثبت بعد. يلزم اعتماد توقف منظم لقاعدة QA ونسخة باردة واختبار استعادة مستقل. القرار الآن NO-GO للتنفيذ؛ لم تُنشأ نسخة ولم تُضغط أو تُنقل أو تُحذف أي ملفات، وسياسة بناء Android لم تتغير.
