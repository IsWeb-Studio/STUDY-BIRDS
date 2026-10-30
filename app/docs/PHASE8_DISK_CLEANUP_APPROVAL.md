# Phase 8 — proposed disk cleanup and diagnostic build approvals

Date: 2026-10-22. **PROPOSAL ONLY: nothing deleted, moved, compressed, built or installed.** Only this requested report was created. Existing build gate and QA configuration were not edited.

## Capacity and decision

- Initial D free: **5,922,045,952 bytes (5.515 GiB)**.
- Latest pre-report D free: **5,922,164,736 bytes (5.516 GiB)**. Background disk usage can change independently; the difference is not cleanup performed by this task.
- Target: **8,589,934,592 bytes (8 GiB)**; current shortfall **2,667,769,856 bytes**.
- Study Birds candidates 1–9: logical **1,916,571,896 bytes (1.785 GiB)**; projected free **7,838,736,632 bytes (7.300 GiB)**. These alone do **not** meet the target.
- Additional, separately identified Quantis candidates 10–11: **864,284,635 bytes (0.805 GiB)**.
- All eleven: estimated reclaim **2,780,856,531 bytes (2.590 GiB)**; projected free **8,703,021,267 bytes (8.105 GiB)**. This meets 8 GiB only in the estimate, by about **108 MiB**. It is not comfortable headroom and is not a guarantee of build success.

Logical file lengths were measured recursively without traversing links. Reclaim estimates below use those lengths: no hard-linked, compressed or sparse files were found in the candidates. Physical allocation, filesystem metadata and concurrent activity can differ; allocated-cluster space was not independently measured. Actual recovery must be measured after a separately approved cleanup. Do not authorize a build solely from these projections.

## Fresh verification shared by the numbered candidates

All candidate owners: `DESKTOP-BI43VHU\Abood`. Exact paths and every ancestor were inspected: no reparse point. No descendant reparse points or hard-linked files were found. No APK/AAB, keystore/JKS, PEM/PFX/P12, certificate, environment file, ZIP or backup file was found in these candidates. No original signing/configuration file was identified. Generated Dart registrants, stamps, dependency files and compiler JSON are rebuildable outputs, not original application configuration.

Every candidate file could be opened read-only with exclusive sharing at the inspection instant: zero failures. No Java/Gradle build process appeared in the process inventory. Four Dart processes were classified as an analysis server, tooling process and two Flutter daemons; none referenced a candidate path and no Dart build/test process was identified. Node processes remain running, including the local QA backend; they were not stopped or queried for secrets. This is a point-in-time check, not proof that a daemon cannot start work later. Recheck processes, links, file contents and locks immediately before any future deletion; skip anything uncertain. Never terminate processes automatically.

Git tracking was checked using `git ls-files` for each Study Birds candidate: **zero tracked files**. Quantis has no enclosing Git repository, so it has no enclosing Git tracking evidence; its original `pubspec.yaml`, `lib` and `android` folders exist. Nested `.git` files/directories were not found in the candidate contents.

## Exact proposed targets

Each size below is logical bytes and the corresponding approximate reclaim estimate, subject to the allocation caveat above. Every entry inherits the link, lock and ownership results above. No parent directory is a proposed target.

1. **`D:\work\studybirds_session_release\app\build\test_cache`**
   - Logical / estimated reclaim: **566,904,920 bytes** (~540.64 MiB); six `.dill` files.
   - Generated Flutter test compilation cache; reproducible from retained source and installed toolchain. Untracked in deployment worktree.
   - Recommendation: **SAFE TO APPROVE after fresh checks**. Next tests recompile, increasing time and temporarily consuming disk. Does not contain the QA backend, QA manifest evidence or APK.

2. **`D:\work\studybirds_session_release\app\.dart_tool\flutter_build`**
   - Logical / estimated reclaim: **102,746,163 bytes** (~97.99 MiB); 22 files.
   - Generated compiler snapshot, dependency/stamp/JSON outputs and generated Dart plugin registrant. Reproducible; untracked in deployment worktree.
   - Recommendation: **SAFE TO APPROVE after fresh checks**. Deployment Flutter compilation regenerates these; expect a colder next build. Preserve the enclosing `.dart_tool`, package configuration and QA output root.

3. **`D:\work\studybirds_web\app\.dart_tool\flutter_build`**
   - Logical / estimated reclaim: **496,786,307 bytes** (~473.77 MiB); 106 files, including five compilation hash directories.
   - Generated Flutter compilation caches and registrant; reproducible, untracked in retained web repository.
   - Recommendation: **SAFE TO APPROVE after fresh checks**. Retained app rebuild becomes colder; no direct QA resource effect.

4. **`D:\work\studybirds-security-release-20261017-mobile\.dart_tool\flutter_build`**
   - Logical / estimated reclaim: **226,102,961 bytes** (~215.63 MiB); 75 files.
   - Generated Flutter snapshots, native compiled `.so` outputs, stamps/dependencies and registrant; reproducible, untracked.
   - Recommendation: **SAFE TO APPROVE after fresh checks**. Old release checkout loses incremental compilation reuse; source and dependencies remain. No QA runtime data here.

5. **`D:\work\study-birds\app\.dart_tool\flutter_build`**
   - Logical / estimated reclaim: **188,786,953 bytes** (~180.04 MiB); 51 files.
   - Generated Flutter compiler/native outputs and registrant; reproducible, untracked.
   - Recommendation: **SAFE TO APPROVE after fresh checks**. Older checkout rebuild cost increases; no direct QA impact.

6. **`D:\work\studybirds-security-release-20261017-mobile\build\test_cache`**
   - Logical / estimated reclaim: **94,379,064 bytes** (~90.01 MiB); one `.dill` file.
   - Generated test compilation cache; reproducible, untracked.
   - Recommendation: **SAFE TO APPROVE after fresh checks**. Subsequent tests recompile.

7. **`D:\work\studybirds-security-release-20261017-web\app\build\test_cache`**
   - Logical / estimated reclaim: **94,379,248 bytes** (~90.01 MiB); one `.dill` file.
   - Generated test compilation cache; reproducible, untracked.
   - Recommendation: **SAFE TO APPROVE after fresh checks**. Subsequent tests recompile.

8. **`D:\work\studybirds-security-release-20261017-mobile\build\app\generated`**
   - Logical / estimated reclaim: **51,906,264 bytes** (~49.50 MiB); exactly three generated `libapp.so` files.
   - Compiled Flutter application libraries, not original native source or signing files; reproducible, untracked.
   - Recommendation: **SAFE TO APPROVE after fresh checks**. Old release compilation must regenerate native outputs. Preserve sibling `outputs` and all APKs.

9. **`D:\work\study-birds\app\build\89a6598c8854ed031dfc25d83c80860e.cache.dill.track.dill`**
   - Logical / estimated reclaim: **94,580,016 bytes** (~90.20 MiB); **one exact regular file, not a directory**.
   - Generated Dart incremental compiler snapshot; reproducible, untracked.
   - Recommendation: **SAFE TO APPROVE after fresh checks**, explicitly as this single file only. Older checkout loses this incremental cache; preserve its parent and siblings.

10. **`D:\flutter projects\Quantis\quantis\build\app\intermediates`**
    - Logical / estimated reclaim: **730,577,794 bytes** (~696.73 MiB); 727 files.
    - Generated Android release intermediates; not Study Birds. No enclosing Git repository. No APK/AAB or original key/config detected; all ancestors and descendants are ordinary files/directories, no links.
    - Includes generated `app-metadata.properties`, `dex-metadata-map.properties`, two `compile-file-map.properties` files and `signing_config_versions\release\writeReleaseSigningConfigVersions\signing-config-versions.json`. The latter has exactly four Boolean properties (`enableV1Signing` through `enableV4Signing`), with no key, credential or path property. Values were not printed. These describe generated signing-version metadata, not the original signing configuration.
    - Recommendation: **CONDITIONAL — requires explicit owner approval covering Quantis and these generated release metadata files**. Rebuildable with that project's retained source, toolchain and dependencies; a successful offline Quantis rebuild was not attempted or proven. Its next Android release build will regenerate intermediates and take longer. No direct Study Birds QA integration uses this directory.

11. **`D:\flutter projects\Quantis\quantis\.dart_tool\flutter_build`**
    - Logical / estimated reclaim: **133,706,841 bytes** (~127.51 MiB); 35 files.
    - Generated Flutter compilation cache; no enclosing Git repository. No link, protected file or lock failure found.
    - Recommendation: **CONDITIONAL — explicit Quantis owner approval required**. Regenerates during Quantis compilation; do not delete the enclosing `.dart_tool` or its package configuration. Offline rebuild availability was not tested.

“Reproducible” describes generated output provenance, not permission to download dependencies or a promise that every old project builds offline today. No dependency retrieval was attempted.

## Exclusions and duplicate artifacts

- All APKs/AABs, including duplicate copies in `outputs\apk` and `outputs\flutter-apk`, are excluded. No duplicate-APK savings are counted. Similar `.dill` sizes are not proof of duplicate content; no deduplication savings are counted.
- Deployment `app\build\app` is ~642 MB, of which ~642 MB is `outputs`; retained web app `build\app` is ~620 MB, predominantly deliverables. These parents are not candidates.
- Primary application `build` is a junction to `C:\Users\Abood\AppData\Local\StudyBirds\build-cache\study_birds_app-main\build`. It cannot reclaim D capacity; target was not traversed for this proposal. Shared cache targets and dependency junctions are excluded.
- Excluded all `.git` metadata, recovery checkpoints, backups, repositories/worktrees, original configuration/signing files, `node_modules`, SDKs, Gradle dependency caches, browser profiles and system/recycle directories. Project-local `android\.gradle` caches were inventoried but not nominated: small savings and unnecessary invalidation of active preparation state.
- Entire `D:\work\studybirds_qa_phase7` is protected, including MongoDB data, accounts, storage, TLS material, captured mail and `android-build` merged-manifest evidence. No savings from these are counted.
- Generated test assets containing copied certificates were not nominated. Plugin build subtrees were inventoried but are not implicitly approved or included in the numbered list.

## Diagnostic QA command review — not executed

Reviewed latest `PHASE8_BUILD_APPROVAL.md`, `PHASE8_VALIDATION.json`, `ANDROID_QA_RUNTIME_TEST_PLAN.md`, deployment `android\app\build.gradle.kts` and pending Android configuration. Current gate still rejects QA compile/assemble graphs; no Gradle invocation was made in this audit.

Working directory for a future approved invocation: `D:\work\studybirds_session_release\app\android`. The reviewed sequence remains:

```powershell
# NOT AUTHORIZED TO RUN. qaEncodedDefines must come from the strictly validated
# qa_android.pending.json using the encoding procedure in PHASE8_BUILD_APPROVAL.md.
# Proposed replacement capacity precondition for the future approved script:
if ((Get-PSDrive D).Free -lt 8GB) { throw 'At least 8 GiB D workspace required' }
& .\gradlew.bat --offline --no-daemon --max-workers=1 -PstudybirdsQa=true '-Ptarget=lib/main.dart' '-Ptarget-platform=android-x64' "-Pdart-defines=$qaEncodedDefines" :app:compileQaDebugKotlin :app:compileQaDebugJavaWithJavac
if ($LASTEXITCODE -ne 0) { throw 'Compilation failed; stop' }
& .\gradlew.bat --offline --no-daemon --max-workers=1 -PstudybirdsQa=true '-Ptarget=lib/main.dart' '-Ptarget-platform=android-x64' "-Pdart-defines=$qaEncodedDefines" :app:assembleQaDebug
if ($LASTEXITCODE -ne 0) { throw 'QA assembly failed; stop' }
```

The existing document's historical capacity check is 6GB. This report proposes **8GB (PowerShell GiB)** for the next approval; the existing script/document and gate have not been edited. Monitor D free capacity during future work; expected additional workspace remains an unmeasured **2–4 GiB plus 2 GiB reserve**, not a completed QA build measurement. Cache removal can increase regeneration costs. The projected 8.105 GiB margin is narrow; remeasure immediately before compilation and assembly. No new emulator storage budget is included.

### Minimal reviewed gate-policy change requiring separate approval

Current `taskGraph.whenReady` rejects any app task matching QA compile/package/assemble/install. Merely authorizing a build cannot make it run. A future reviewed change must retain default denial and allow **only the exact diagnostic root requests above**, with their necessary `qaDebug` compilation/resource/packaging dependencies. It must validate requested tasks and the complete graph, not just match a permissive `Qa` substring. Keep release, bundle, install, production variants, unrelated requested tasks, and manual clean tasks denied. The previously observed internal `cleanMergeQaDebugAssets` prerequisite needs explicit review as generated QA asset processing; it is not authorization for `flutter clean`, `Gradle clean` or general cleanup.

Retain checks for QA identity, local-only CCT backend binding, reviewed source/manifest hashes, independent QA output path, existing APK preservation and exact diagnostic defines. Do not add a bypass property, skip guards with `-x`, or change production behavior. Exact implementation and tests must be reviewed before execution; no gate patch is applied or claimed tested here.

Pending config remains `APP_ENV=qa`, `QA_API_BASE_URL=https://localhost:5448/api`, **`QA_RESOURCES_VERIFIED=false`**, empty `QA_CA_CERT_BASE64`, `SENTRY_ENABLED=false`, empty `POSTHOG_API_KEY`. First artifact is diagnostic, with Dart startup intentionally blocked. Expected output remains `D:\work\studybirds_qa_phase7\android-build\app\outputs\flutter-apk\app-qa-debug.apk`; no installation or runtime-isolation claim follows from compilation.

## Integrity and approvals

Read-only Git snapshot (tracked change counts exclude untracked files; not an assertion that other work is committed):

- Primary app HEAD `3e31e19c5343170056e6d7559c59bfb891f2c624`: 16 tracked changes.
- Deployment HEAD `e9060536e8dc7a70150da9c42d6dfac901713553`: 49 tracked changes.
- Retained web HEAD `f42dc7a0edb9630a8d24f1800191a9de06856cea`: 9 tracked changes.
- Old mobile HEAD `fa75e05910ae1ef003acdd9303bb8b22dfde8aaa`: zero tracked changes.
- `study-birds` HEAD `a1da3390c797f485141b1aabf79cb200d43231d4`: zero tracked changes.
- Old web release HEAD `a6f722636dbf48b25baef6e041ca0c44f62a05d4`: zero tracked changes.

Existing deployment debug APK SHA-256 still **9638b98f111bf25b4079555f4a48029d40a4892dc12f48f407b3894b61b9ce23**. No source/configuration/signing/Git mutation was performed; this report is the sole intended write. Production sources, QA resources and worktree relationships were not changed. This is not a new complete source-hash audit.

Separate approvals required:

1. **Cleanup:** owner selects exact numbered targets. Approval must explicitly include Quantis 10–11 and generated release metadata if those are desired. Revalidate before each independent deletion, preserve parents, skip changed/linked/locked/protected contents, and measure actual free space. Prior cleanup approvals do not authorize this list.
2. **Build:** after actual capacity reaches at least 8 GiB, approve the narrow reviewed Gradle gate-policy change **and** the exact offline diagnostic qaDebug compile/assemble sequence. Keep `QA_RESOURCES_VERIFIED=false`; no install, ADB, emulator, network-policy change or production access. Build approval does not authorize further cleanup.
3. **Runtime:** later, separate approval and verified isolated device/network/TLS/resources are required under `ANDROID_QA_RUNTIME_TEST_PLAN.md`. No real-device QA or production-readiness success is asserted.

No deletion approval or build approval has been inferred from this preparation request.
