# Phase 8 — approved QA-only C: storage preparation

2026-10-22. **Storage preparation completed; QA compilation/packaging/assembly remains blocked and unauthorized.** No Gradle or Flutter task, JVM transport harness, Android compiler, ADB, emulator, installer, download, cleanup or deployment was run.

## Safety preconditions and recovery

Before editing, C free was **34,286,448,640 bytes (~31.93 GiB)** and D free **7,833,108,480 bytes (~7.30 GiB)**. The exact destination was absent; its canonical absolute path matched the approved path. Every existing ancestor was checked and had no reparse point. The immediate parent was owned by `DESKTOP-BI43VHU\Abood`, with explicit FullControl for that user, SYSTEM and Administrators and no deny ACE. No ACL or environment variable was changed.

Created and read back a verified recovery record: `docs/PHASE8_QA_C_STORAGE_CHECKPOINT.json`. It contains original bytes/SHA-256 for the three edited files, pre-edit Git HEAD/index/status/worktree snapshots, and 139 protected file hashes (including preserved D merged-manifest evidence, QA native source/manifests, pending configuration, gate and existing APK). It does not contain signing-key or backend credential contents. No previous checkpoint was overwritten.

## Exactly what changed

Created only these ordinary directories, all owned by `DESKTOP-BI43VHU\Abood`, without links:

- `C:\Users\Abood\AppData\Local\StudyBirds\qa-diagnostic-phase8`
- `C:\Users\Abood\AppData\Local\StudyBirds\qa-diagnostic-phase8\gradle-build`
- `C:\Users\Abood\AppData\Local\StudyBirds\qa-diagnostic-phase8\project-cache`
- `C:\Users\Abood\AppData\Local\StudyBirds\qa-diagnostic-phase8\tmp`
- `C:\Users\Abood\AppData\Local\StudyBirds\qa-diagnostic-phase8\diagnostics`

All four child directories were verified empty after validation. No artifact/cache was moved, copied or removed.

1. Deployment `app\android\build.gradle.kts`: **one string replacement only**, inside `if (qaPreparation)`, from `D:/work/studybirds_qa_phase7/android-build` to `C:/Users/Abood/AppData/Local/StudyBirds/qa-diagnostic-phase8/gradle-build`. The entire file equals the checkpoint bytes with exactly that replacement; this verifies the production `else` branch **byte-for-byte unchanged** and preserves all prior local edits. Root/subproject output selection code is otherwise unchanged.
2. Deployment `app\tool\qa_android_preparation.test.cjs`: updated only the existing QA output-path assertion to require the fixed C path in the QA branch. Production-output and security assertions remain. No test was disabled or weakened.
3. `docs/PHASE8_BUILD_APPROVAL.md`: added a storage-only status note and updated the current proposed QA APK path. Historical D evidence remains historical. Existing commands stay explicitly unauthorized; no capacity precondition or gate policy was relaxed.

No additional test implementation needed a hard-coded-path change: merged-manifest consumers already require an explicitly supplied `QA_MERGED_MANIFEST`; they have no automatic D fallback. This variable was not set here. Existing `PHASE8_VALIDATION.json` historical records were not rewritten to pretend C evidence exists.

## New output/evidence paths

Expected future APK:

`C:\Users\Abood\AppData\Local\StudyBirds\qa-diagnostic-phase8\gradle-build\app\outputs\flutter-apk\app-qa-debug.apk`

Expected future merged manifest:

`C:\Users\Abood\AppData\Local\StudyBirds\qa-diagnostic-phase8\gradle-build\app\intermediates\merged_manifest\qaDebug\processQaDebugMainManifest\AndroidManifest.xml`

These files **do not exist yet**. After an independently approved generation step, tests must explicitly inspect the actual new C manifest. Do not silently substitute the old D manifest or call the new output validated from old evidence. The complete existing `D:\work\studybirds_qa_phase7\android-build` evidence tree remains intact and hash-matched.

`project-cache`, `tmp` and `diagnostics` are **prepared only**: no project-cache CLI option, JVM dump/temp setting or process environment override was applied. Directory existence is not proof that those tools will use them.

## Actual validation

- `node --test D:\work\studybirds_session_release\app\tool\qa_android_preparation.test.cjs`: **9 passed, 0 failed, 0 skipped**. Source/XML assertions only; no Android task or compilation. This checks QA output-path selection, production manifest identity/links, QA identity/launcher/cleartext/provider exclusions, the existing gate and local-plugin registration.
- Independent byte comparison confirms the root Gradle file changed only the approved literal; production branch and all other bytes match the recovery record.
- **139/139 protected SHA-256 checks passed**. The protected APK remains `9638b98f111bf25b4079555f4a48029d40a4892dc12f48f407b3894b61b9ce23`.
- App Gradle gate/signing/identity file remains `2fa29230bac7cb3795ae577e5dc1a627e57e39365f34549ec4f15f63b12b0390`.
- Pending QA config remains `a398ee5cde8131c1b75ab4abab244420ff99866a19bf13a642ba7c99e92bf3aa`; `QA_RESOURCES_VERIFIED=false`, pending CA and provider settings unchanged.
- HEADs, index hashes and Git worktree registrations match pre-edit snapshots for primary app, deployment and retained web repositories. Every previous porcelain-status entry remains; no previous untracked file disappeared. The only newly observed status entry before writing this report was the new checkpoint. This report is another expected new document. No Git history/index operation occurred.
- Final measured free space before this report: **C 34,131,066,880 bytes (31.787 GiB); D 7,833,018,368 bytes (7.295 GiB)**. Differences across snapshots are volume observations, not attribution to these empty directories. Both drives require fresh checks before future work.

## Remaining D writes and blockers

- Installed Flutter assemble still uses `D:\work\studybirds_session_release\app\.dart_tool\flutter_build`; source-adjacent package/plugin metadata can remain on D.
- Gradle project state still defaults to `app\android\.gradle` until a separately reviewed invocation selects the prepared C project-cache directory. No shared Gradle/Pub/SDK cache was changed.
- TEMP/TMP remain the original C Windows TEMP. Dedicated temp/heap-dump routing and included-build/native `.cxx` placement remain unverified. No filesystem-link workaround was introduced.
- The production `app\build` tree and APK path remain untouched. The old QA evidence/resources are preserved rather than relocated.
- Source assertions do not prove AGP runtime output placement. No Gradle configuration, manifest generation or merged-manifest/native revalidation against C output occurred.
- The unchanged `taskGraph.whenReady` gate still rejects QA compile/package/assemble/install tasks. No bypass property, task exclusion or relaxation was added.
- D remains below the previously requested 8 GiB. Storage preparation does not waive that criterion or authorize a different volume-aware budget. Capacity policy and a narrow gate-policy change require separate review/approval before an exact diagnostic build command can run. Device/network/TLS runtime requirements remain separate.

## Reversible rollback, without destructive commands

If rollback is later requested, first compare current files with this preparation and the verified checkpoint. Reverse only the new QA output literal back to `D:/work/studybirds_qa_phase7/android-build`, restore the corresponding single test assertion, and revert the storage-only documentation changes. Preserve all unrelated local work; do not blindly restore whole files if subsequent edits exist. Leave C directories/artifacts in place for separate owner review. No delete, clean, reset, stash, production change or movement of evidence is part of rollback.
