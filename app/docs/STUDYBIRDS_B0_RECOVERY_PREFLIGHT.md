# Study Birds — B0 recovery backup final preflight

2026-10-22. Controlling plan: `STUDYBIRDS_PHYSICAL_MIGRATION_PLAN.md`.

**B0 EXECUTION: NO-GO.** No recovery directory, backup, restore, snapshot, copy or migration was created/executed. No service/process, environment, Git/index/worktree, source/configuration, security gate, database or artifact changed. Only this report was created. Measurements below are a live read-only census, **not a consistent/frozen backup manifest or permission to copy**.

## Capacity decision

Measured C free: **33,785,663,488 bytes (~31.46 GiB)**. D free: **7,832,539,136 bytes (~7.295 GiB)**. Both are NTFS with **4,096-byte allocation units**. Partition inspection confirms C is Disk **0**, partition 3; D is Disk **0**, partition 5. A C backup cannot protect against Disk 0 failure, controller loss, ransomware/admin compromise or theft of the same device. No partition operation is proposed.

The full proposed recovery scope is larger than the original D-only estimate because it also covers three registered C worktrees, five existing APKs behind the primary C build junction and the original debug keystore. With metadata/temporary/restore reserves, C cannot hold this conservative complete backup **and** preserve the proposed 16 GiB C start capacity for future QA building. That 16 GiB is a planning reservation from the build review, not a newly activated build policy; D's existing 8 GiB requirement also remains unmet.

**Preferred:** a separately approved private encrypted destination on a genuinely different device with **>=32 GiB free**, plus verified restore scratch and independent encryption recovery. No such destination is verified. The previously proposed “25 GiB free on C” condition is insufficient for this expanded full scope plus future build headroom.

## Exact proposed path allowlist and live measurements

Rules: include every ordinary file/directory under each explicit recursive root, including hidden/ignored files, `.git` stores, raw indexes, untracked work, private configuration and existing artifacts. Capture links as metadata without traversal. Do not back up the nested mobile repository twice: it is already inside the `studybirds_app` root. Do not deduplicate similar APKs, archives or Git stores by name/content without separate review.

### A. D: recursive roots

| Exact root | Default-stream logical bytes | Files | Directories |
|---|---:|---:|---:|
| `D:\work\studybirds_app` | 8,675,833,682 | 79,127 | 13,282 |
| `D:\work\studybirds_web` | 1,497,085,802 | 66,871 | 10,834 |
| `D:\work\studybirds_session_release` | 759,637,995 | 5,057 | 3,958 |
| `D:\work\studybirds-stories-release` | 24,542,462 | 1,124 | 202 |
| `D:\work\studybirds_islam_google_password_fix` | 322,432,486 | 20,832 | 2,464 |
| `D:\work\study-birds` | 785,960,445 | 19,918 | 10,397 |
| `D:\work\studybirds-security-release-20261017-mobile` | 741,451,210 | 17,210 | 8,692 |
| `D:\work\studybirds-security-release-20261017-web` | 330,261,306 | 22,940 | 2,944 |
| `D:\work\studybirds_qa_phase7` | 217,481,969 | 579 | 471 |
| `D:\work\_git-backup-20261013` | 34,503,108 | 23 | 3 |
| `D:\work\.studybirds-email-cdp` | 78,870,824 | 903 | 413 |
| `D:\work\.studybirds-email-preview-profile` | 9,569,532 | 170 | 81 |
| `D:\work\.studybirds-email-preview-profile-desktop` | 6,424,254 | 171 | 81 |
| `D:\work\.studybirds-email-preview-profile-mobile` | 11,681,368 | 192 | 81 |
| `D:\work\.studybirds-email-preview-profile-mobile2` | 6,424,243 | 171 | 81 |

Browser profiles are included in the **proposed full B0 scope only subject to explicit private-data owner approval and session quiescence**. If their backup is declined, defer their migration too; do not silently relabel them disposable. QA DB/TLS/account data is private, not ordinary public source backup material.

### B. D: exact loose files (not a wildcard)

| Exact file | Bytes |
|---|---:|
| `D:\work\.studybirds-mobile-audit-release.log` | 16,694 |
| `D:\work\.studybirds-security-backend-release.log` | 316,222 |
| `D:\work\.studybirds-security-files.json` | 2,456 |
| `D:\work\.studybirds-security-mobile.patch` | 40,641 |
| `D:\work\.studybirds-security-uploads-extra.patch` | 2,159 |
| `D:\work\.studybirds-security-web.patch` | 133,761 |

**A+B total: 13,502,672,619 bytes.** This includes source, staged/index/object stores, unique ignored/private files, checkpoints, D APKs and historical backups once. It is intentionally conservative: ordinary dependency/output files inside these exact roots remain included rather than silently excluding a file that could be tracked/modified/unique.

### C. Registered external worktree roots, recursively, no link following

| Exact root | Bytes | Files | Directories |
|---|---:|---:|---:|
| `C:\Users\Abood\studybirds-claude` | 14,412,195 | 986 | 190 |
| `C:\Users\Abood\studybirds-email-refresh` | 14,406,505 | 983 | 190 |
| `C:\Users\Abood\studybirds-wink` | 14,463,743 | 997 | 191 |

Total **43,282,443 bytes**. Their Git object/ref owner and raw indexes are already under D `studybirds_web\.git`; the C `.git` backlink files and working/private ignored files must still be preserved. These are not additional full copies of the common object store.

### D. Exact C: artifact/signing-file additions

Base for the first five relative paths below: **`C:\Users\Abood\AppData\Local\StudyBirds\build-cache\study_birds_app-main\build`**. This is an explicitly selected ordinary target root, not permission to follow the source junction recursively.

| Exact suffix / exact standalone file | Bytes |
|---|---:|
| `app\outputs\apk\debug\app-debug.apk` | 375,364,592 |
| `app\outputs\apk\release\app-release.apk` | 215,634,926 |
| `app\outputs\flutter-apk\app-debug.apk` | 375,364,592 |
| `app\outputs\flutter-apk\app-release.apk` | 215,634,926 |
| `app\outputs\flutter-apk\studybirds-1.0.8.apk` | 215,354,190 |
| `C:\Users\Abood\.android\debug.keystore` | 2,618 |

Total **1,397,355,844 bytes**. Private signing material requires explicit encrypted-backup approval; contents were not printed. Project release key/config are already within D roots (`android\key.properties`, `android\app\studybirds-release.jks` in the authoritative app). No deployment `android\key.properties` exists at the checked path. Do not add unrelated user signing stores or global credentials automatically.

### E. Metadata-only additions, not payload traversal

Record volume identifiers/allocation units, approved source/destination ACL/owner/stream inventories, link targets, Git versions/configuration paths without credential values, worktree registrations and installed toolchain/version locations. Capture empty-directory/ACL state for `C:\Users\Abood\AppData\Local\StudyBirds\qa-diagnostic-phase8` and its four prepared children; do not activate tokens or manufacture output. Unexpected new files there require an updated manifest/approval.

**Grand measured payload: 14,943,310,906 bytes (~13.917 GiB), 238,266 ordinary files and 54,555 enumerated directories**, excluding link nodes/metadata-only empty QA directories. No inaccessible entry was reported and no hard-linked ordinary file was detected in the measured selected payload. The report itself was created after the census: execution must freeze a fresh exact leaf inventory, including newly approved documentation, before copying. No “all of D:\work” or user-profile wildcard is authorized.

## Git, checkpoint and dependency coverage

Included `.git` contents total **5,837,269,798 bytes**, including **4,306,618,645 bytes in object stores**. These are subsets of the payload, not extra additions. Seven independent object-store owners and six linked worktrees yield **13 raw indexes totaling 1,555,823 bytes**:

- `D:\work\study-birds\.git\index`
- `D:\work\studybirds-security-release-20261017-mobile\.git\index`
- `D:\work\studybirds-security-release-20261017-web\.git\index`
- `D:\work\studybirds_app\.git\index`
- `D:\work\studybirds_app\study_birds_app-main\.git\index`
- `D:\work\studybirds_web\.git\index`
- `D:\work\studybirds_web\.git\worktrees\studybirds-claude\index`
- `D:\work\studybirds_web\.git\worktrees\studybirds-email-refresh\index`
- `D:\work\studybirds_web\.git\worktrees\studybirds-stories-release\index`
- `D:\work\studybirds_web\.git\worktrees\studybirds-wink\index`
- `D:\work\studybirds_web\.git\worktrees\studybirds_islam_google_password_fix\index`
- `D:\work\studybirds_web\.git\worktrees\studybirds_session_release\index`
- `D:\work\studybirds_web\monorepo\.git\index`

Copy the complete approved stores, refs, reflogs, per-worktree metadata, configs and raw indexes after quiescence; a bundle or a diff alone cannot preserve staged-only/unreachable/index state. Preserve nested repository boundaries and the staged mode-160000 `monorepo` gitlink. Raw index/stage/working/untracked manifests are separate recovery evidence; do not use `git add`, reset, checkout, stash, GC/prune or commits to simplify the snapshot.

Checkpoint examples inside the already-included primary `.git`: Phase 7 **561,776 B**; Phase 8 base **262,520 B**, local transport **621,099 B**, native **5,134,695 B**, prebuild **349,951 B**, transport investigation **932,501 B**. Router recovery/dependency area **267,259,478 B** includes the active website installation and a preserved junction. Phase 2 evidence **49,093,593 B** is also included. All other files in the allowlisted root, not only these examples, remain in scope.

Six discovered junctions must be captured as nodes, never traversed automatically:

| Link | Target / treatment |
|---|---|
| `D:\work\studybirds-stories-release\server\node_modules` | `D:\work\studybirds_web\server\node_modules`; owner payload already included once |
| `D:\work\studybirds_session_release\server\node_modules` | same shared owner; no second traversal |
| `D:\work\studybirds_session_release\client\node_modules` | primary `.git\router-20261021\candidate\node_modules`; already included once |
| primary `.git\router-20261021\previous-client-node_modules-junction` | `D:\work\studybirds_web\client\node_modules`; owner included once |
| primary `build` | C build-cache target; only five explicitly selected APKs added above |
| primary `.dart_tool\flutter_build` | C compilation-cache target; metadata only, no generated-cache payload addition |

The C build target totals **5,919,917,879 bytes / 23,893 files**, but only its explicitly listed APKs are selected. Other reproducible intermediates are not needed for source/index recovery and remain untouched. Global C Gradle/Pub/Flutter/SDK caches are **excluded**, not deleted. Shared dependencies physically inside allowlisted D roots are included once because they may be modified or active; no blanket `node_modules` exclusion is safe here.

Unrelated Quantis, other C projects/VMs/downloads/browser profiles, Windows/system/recycle folders, global credential stores and all non-allowlisted drive contents are excluded. No external link target is implicitly added to scope.

## Storage budget: physical estimate, temporary space and QA reserve

Observed sizes are exact default-stream logical lengths during enumeration, not an application-consistent point-in-time snapshot. ADS/EFS/compression, full ACL/EA metadata, destination encryption/container overhead and final directory allocation have not been exhaustively measured. The execution manifest must enumerate streams/metadata without exposing values; unexplained growth/unsupported metadata means stop. No compression/deduplication savings are assumed.

| Budget component | Bytes |
|---|---:|
| Selected files rounded individually to verified 4 KiB allocation units | 15,581,392,896 |
| Directory allowance, 54,555 × 4 KiB (estimate) | 223,457,280 |
| Manifest/hash/ACL/stream/container-metadata allowance | 536,870,912 |
| 10% growth/uncertainty reserve on those components | 1,634,172,109 |
| Streaming/temp allowance (no second full staged archive) | 536,870,912 |
| **Backup peak planning allowance** | **18,512,764,109 (~17.241 GiB)** |
| Representative sequential restore scratch | **3,221,225,472 (3 GiB)** |

Using the measured C free space, backup peak leaves **15,272,899,379 bytes (~14.224 GiB)**; during representative restore it leaves **12,051,673,907 bytes (~11.224 GiB)**. Neither preserves the **16 GiB C** future-build planning reserve. A same-C workflow would require at least **38,913,858,765 bytes (~36.24 GiB) free initially**, a **5,128,195,277-byte (~4.776 GiB) shortfall** at this snapshot. These calculations assume streaming backup directly into approved encrypted storage, not plaintext staging plus encrypted duplicate. A full restore or a backup tool requiring a second full image needs substantially more space and a new budget.

An independent destination starting with >=32 GiB free can cover this bounded backup/restore estimate while retaining >=8 GiB there; keep host C>=16 GiB free for future-build planning and D>=4 GiB during B0 metadata operations. These are proposed B0 stop/start conditions, not a waiver of the existing D>=8 GiB build rule. No build is authorized, and a future VM strategy has a separate, larger storage budget.

## Consistency and downtime

**Must be gracefully quiesced through separately approved lifecycle controls:**

- QA API Node **PID 23368**, then QA MongoDB **PID 21696**. API can write DB/storage/mail; MongoDB is live under `studybirds_qa_phase7\db`. Cold backup requires verified clean shutdown and no writers/locks, preserving all DB files/keyfiles/metadata. A live directory copy is not adequate recovery. No shutdown/probe/dump happened here.
- Editors, Git clients/watchers, terminals/automation and build/test writers across all D and three C worktrees. Code, Java, Dart and Node processes were observed; do not classify arbitrary PIDs as safe to kill. Owner identifies and closes the affected tools, with Git locks absent and stable indexes/refs/files verified twice.
- Browser instances using the five private profiles. Chrome/Edge processes exist but profile ownership/use was not established. Explicit owner confirmation and clean session closure are required; no generic browser termination or copying live cookie stores.

**Possible without QA service downtime, in independent scopes:** static historical checkouts, loose old patches/logs/backups, closed artifact files and idle Git stores/working trees can be captured after confirming no writers and stable hashes. Git still needs writer quiescence even when the DB need not stop. A warm pre-copy may reduce downtime only under a separately reviewed reconciliation protocol; it is not a final consistent backup and may not silently overwrite earlier data.

Final all-scope B0 approval remains blocked while the included QA database/profile/worktree state is live. Restart QA DB then API only under the approved maintenance procedure after verifying backup consistency; do not leave services stopped unintentionally. Snapshot/VSS/provider availability and MongoDB application-consistent snapshot support were not validated; no VSS shortcut is assumed.

## Private destination, ACLs and encryption

Proposed C fallback path: **`C:\Users\Abood\AppData\Local\StudyBirds\migration-recovery-20261022`**, absent and canonical at inspection. Existing ancestors have no reparse points. Immediate parent is owned by `DESKTOP-BI43VHU\Abood`; its ACL gives that user, SYSTEM and Administrators FullControl. This does not prove a future child is encrypted or sufficiently restricted.

For execution, owner must approve a fresh, non-shared, non-synced destination outside every Git repository/worktree, with inheritance reviewed and a destination-specific allowlist for the owner and SYSTEM (administrator recovery rights explicitly decided). Preserve original source ACLs/owners/streams as protected metadata; do not broaden source permissions. Administrative compromise is not prevented by a private folder ACL.

At-rest encryption status could **not** be verified: BitLocker status was unavailable to this non-elevated inspection; no recovery-key/protector contents were requested or printed. Do not infer encryption from cmdlet presence or use an unsupported Windows Home EFS/BitLocker procedure. Prefer an owner-provided verified encrypted external volume or reviewed encrypted container/tool already available, with recovery key stored independently and a proven owner-only unlock/restore path. No encryption tool, keys, container or global security setting was created/changed. Do not stage plaintext secrets in a public/temp folder or put recovery material into Git/cloud sync.

For the preferred independent device, exact drive/volume identity and full destination path must be supplied and approved before execution; no unverified drive letter is selected here. C fallback additionally requires capacity remedy and explicit acceptance of same-disk failure risk.

## Verification, representative restore and failure handling

Before copying: freeze a fresh **exact leaf allowlist** under A–D, deleted-path records, link nodes, streams/ACL metadata, every HEAD/ref/raw index SHA-256, staged object IDs and working/untracked/ignored file hashes. Reject unknown links, new files outside scope, active locks, missing data, destinations within source trees or changed Git/metadata. Current report and later approved docs change the leaf count; this live census is not reusable as an immutable authorization token.

During an approved backup: stream only allowed paths without following links, maintain a per-file result/hash log privately, preserve all binary/metadata content and verify source stability. Monitor destination capacity; abort on remaining reserve breach, lock/read/hash error, changed source, encryption failure or unsupported streams/ACLs. Do not continue with skipped files and declare success. No auto-clean, deletion, permission widening, source repair or silent retry into an existing backup.

After copying: verify **100% file hashes and metadata/link inventories**, counts/bytes, all 13 raw indexes, refs/object accessibility and protected artifact/config hashes. Protect the backup manifest itself with a SHA-256 and retain independent provenance. Successful backup creation or a zip listing is not restore proof.

Representative tests in a separate approved **private isolated restore area**, sequentially within the 3 GiB budget:

1. Restore the largest tracked ZIP/recovery sample and one existing APK; hash against the frozen source/backup and verify binary length, without executing/extracting APKs. Preserve duplicates/provenance.
2. Verify staged-only index entries/blobs and an `MM`/`AM` example, unstaged file, untracked source, ignored private configuration/signing sample and Phase 7/8 checkpoint. Do not print sensitive content or replace an index with re-staged files.
3. Verify Git objects/refs/raw-index integrity in restored stores. **Never run Git in an untouched restored linked worktree whose `.git` file still points to the live D common owner**: it could inspect the original instead of the backup. Use an explicitly isolated restore mapping/context or reviewed restore-only metadata repair, with live trees inaccessible and no Git mutation of original stores. No such tests were run now.
4. Restore link metadata as inert records or isolated test links pointing only within the restore sandbox; never reconnect restored writers to live dependency owners/QA data.
5. With separate explicit permission, perform a QA DB restore validation on an isolated copy using distinct local data/ports/accounts, no production access and no original storage path. It may require a supported DB lifecycle test beyond hash checks. Source-code builds/ADB are not restore validation and remain unauthorized.
6. Prove the encrypted backup can be unlocked/restored with the independently held recovery method and appropriate private ACLs. Record results without credentials.

Failure: mark the run **INCOMPLETE**, stop only the approved backup/restore activity, preserve partial destination and logs privately, maintain original files/indexes, and restore approved service availability if appropriate. No automatic deletion or overwrite of partial recovery. A new attempt needs owner review, a new absent destination and a fresh manifest. B0 rollback itself has no project-path changes to reverse; private destination removal and temporary-restore cleanup need explicitly scoped approval and never target the live workspace. Migration batches remain blocked until full B0 verification and owner sign-off.

## GO / NO-GO conditions and approvals

- [x] Explicit scope measured; links/nested Git stores identified without traversal/double counting.
- [x] **139/139 protected hashes** still match. No current source/config/artifact mutation by this preflight.
- [ ] Exact encrypted destination independently verified and approved; external >=32 GiB free, or C>=38,913,858,765 bytes under this conservative full-scope model, plus acceptance of same-disk limitation.
- [ ] Private ACL/encryption/recovery-key ownership verified without secret disclosure.
- [ ] Explicit inclusion/privacy approval for browser profiles, signing keys and QA credentials/resources, and three C worktrees/artifacts.
- [ ] Owner-approved Git/editor/browser/QA API/DB quiescence and restart procedure; fresh frozen manifest with all streams/ACLs and stable Git object/index state.
- [ ] Exact backup mechanism supports no-follow links, raw indexes, private streams/ACLs, streaming budget and no-source-write operation.
- [ ] Approved isolated restore destination/tests and their resource/lifecycle/cleanup limits, including no backlink access to live repositories.
- [ ] Owner explicitly authorizes **B0 backup only** with these exact scope/destination/downtime/verification conditions. No migration or build permission is included.

**Final: NO-GO for B0 now.** The C fallback fails the conservative capacity-plus-future-build-reserve test; independent storage/encryption and a consistent snapshot window are unverified. No backup or migration is authorized by this request or this report.
