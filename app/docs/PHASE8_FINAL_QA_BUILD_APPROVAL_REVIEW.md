# Phase 8 — final diagnostic build approval review

2026-10-22. **NO-GO now. This is a proposal, not owner approval or an executable build script.** Only this document was created. No gate/config/source/test edit, Gradle/Flutter invocation, Android-output generation, JVM test compilation, ADB, installer or artifact operation occurred.

## Verified state and smallest gate change

Inspected deployment `app\android\app\build.gradle.kts`: inside `if (qaPreparation)`, non-debug variants are disabled. `taskGraph.whenReady` rejects an app task matching `^(assemble|bundle|package|install|compileFlutterBuild|compile).*Qa`, via `check(!apkWork)`. The C storage patch does not alter this rejection. App gate/signing/identity file still hashes to `2fa29230bac7cb3795ae577e5dc1a627e57e39365f34549ec4f15f63b12b0390`.

The smallest acceptable **future** edit is confined to that QA gate: preserve denial by default and permit only the two exact requested-task sets below, with a reviewed complete dependency graph and reviewed configuration/source hashes. Keep the existing variant filter and all non-QA behavior unchanged. A permissive substring regex, `check(true)`, `-x`, arbitrary property/define override or blanket `qaDebug` exemption is unacceptable.

- Stage A roots, together: `:app:compileQaDebugKotlin`, `:app:compileQaDebugJavaWithJavac`.
- Stage B root, after Stage A plus intermediate checks succeed: `:app:assembleQaDebug`.
- Deny root requests for release, install, bundle, clean, other variants, unrelated tasks, abbreviated/unqualified alternatives and appended root requests. Transitive plugin tasks legitimately named `compileDebug...` must be checked by exact project/task identity, not rejected or allowed solely by their suffix. Included Flutter Gradle tooling compilation is distinct from production-app compilation.
- Historical task graph evidence exists in `.git\phase8-prebuild-20261022\compile-task-graph.log`, including internal `:app:cleanMergeQaDebugAssets`. Review this QA asset prerequisite specifically; it grants no permission for manual cache cleaning or `clean` tasks. There is no reviewed post-relocation full assembly graph yet: unexpected tasks must stop the attempt, not extend the allowlist automatically.

**One-build scope requires enforcement beyond a permanent allowlist.** Before approval, implement/review a bounded invocation controller/permission record tied to exact roots, hashes, output root and one attempt per stage. Consume each permission before launching that stage; failure consumes the attempt. Disarm/restore the deny gate after success or failure; do not silently re-arm or retry. A process-local flag alone cannot enforce one build across separate Gradle invocations. The precise controller/gate patch remains unimplemented and requires review and explicit owner approval; this document does not claim its safeguards already exist.

## Proposed volume-aware capacity policy — requires approval

Current snapshot: **C 33,807,560,704 bytes (~31.486 GiB); D 7,832,952,832 bytes (~7.295 GiB)**. Four prepared C child directories are empty.

- Before Stage A **and again before Stage B**: **C >=16 GiB; D >=6 GiB**.
- During either stage: monitor at most every **2 seconds**, stop the approved process tree if **C <8 GiB or D <4 GiB**, if monitoring fails, or if output growth leaves the expected paths/budget. A poll is not an atomic reservation; sharp growth can overrun a threshold between samples.
- Planning allowance: up to **8 GiB C** for fresh Gradle/app/plugin outputs, copies, temporary/project state and existing cache growth, retaining 8 GiB headroom at the start minimum. Allow up to **2 GiB D** before the stop threshold, for Flutter's source-local compilation cache and remaining metadata. These are conservative initial budgets, not measured peak guarantees.
- Native CMake staging may still use `jni-1.0.3`'s source-adjacent `.cxx` in the C Pub cache; included builds/shared Gradle transforms can grow outside the dedicated root. Inspect approved staging and measure both volume totals. No SDK installation/cache refill/download is permitted; a missing offline dependency is a stop.
- Route JVM temporary files and potential OOM heap dump to the prepared C directories using the proposed invocation-only JVM arguments below. Child Flutter/Dart TEMP remains inherited Windows TEMP on C unless a separately approved process-scoped override is added. No global environment change is proposed.

This policy explicitly replaces the earlier **8 GiB D** pre-build requirement **only if approved by the owner**. Current capacity meets the proposed start thresholds but does not meet the old D rule. No waiver or threshold change has been applied.

## Exact proposed command and output

Working directory: `D:\work\studybirds_session_release\app\android`.

Pending defines must contain **exactly** the following keys/typed values (missing keys, extra keys, nulls or altered types fail):

```json
{"APP_ENV":"qa","QA_API_BASE_URL":"https://localhost:5448/api","QA_RESOURCES_VERIFIED":false,"QA_CA_CERT_BASE64":"","SENTRY_ENABLED":false,"POSTHOG_API_KEY":""}
```

Validate `app\config\qa_android.pending.json` against these values and its SHA-256 `a398ee5cde8131c1b75ab4abab244420ff99866a19bf13a642ba7c99e92bf3aa`. Construct `$qaEncodedDefines` as UTF-8 base64 of each `KEY=value`, comma-separated, with lowercase Boolean strings. No server credentials, new CA, API substitution or `QA_RESOURCES_VERIFIED=true`.

The approved controller must perform the preflight/monitoring/checkpoints in this review; these command fragments **alone do not implement those controls**. Do not execute them now.

Stage A proposal:

```powershell
$qaBase = 'C:\Users\Abood\AppData\Local\StudyBirds\qa-diagnostic-phase8'
$qaJvm = '-Xmx3G -XX:MaxMetaspaceSize=1G -XX:ReservedCodeCacheSize=256m -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=C:/Users/Abood/AppData/Local/StudyBirds/qa-diagnostic-phase8/diagnostics -Djava.io.tmpdir=C:/Users/Abood/AppData/Local/StudyBirds/qa-diagnostic-phase8/tmp'
& .\gradlew.bat --offline --no-daemon --max-workers=1 --project-cache-dir "$qaBase\project-cache" "-Dorg.gradle.jvmargs=$qaJvm" -PstudybirdsQa=true '-Ptarget=lib/main.dart' '-Ptarget-platform=android-x64' "-Pdart-defines=$qaEncodedDefines" :app:compileQaDebugKotlin :app:compileQaDebugJavaWithJavac
if ($LASTEXITCODE -ne 0) { throw 'Diagnostic compile failed; consume attempt and stop' }
```

**Mandatory pause/checkpoint before packaging:** inspect newly generated C manifest and plugin/native outputs; run the approved strict tests described below, verify no APK already exists, protected hashes unchanged and start capacity thresholds still met. Do not treat compile success as permission to proceed when checks are incomplete.

Stage B proposal, using exactly the same reviewed `$qaBase`, `$qaJvm`, `$qaEncodedDefines`:

```powershell
& .\gradlew.bat --offline --no-daemon --max-workers=1 --project-cache-dir "$qaBase\project-cache" "-Dorg.gradle.jvmargs=$qaJvm" -PstudybirdsQa=true '-Ptarget=lib/main.dart' '-Ptarget-platform=android-x64' "-Pdart-defines=$qaEncodedDefines" :app:assembleQaDebug
if ($LASTEXITCODE -ne 0) { throw 'Diagnostic assembly failed; consume attempt and stop' }
```

Gradle's documented `--project-cache-dir` selects project state separately from shared dependency caches ([Gradle CLI](https://docs.gradle.org/current/userguide/command_line_interface.html#sec:command_line_environment_options)). The installed wrapper is 8.14; no invocation with this option has been tested here. No newer `--task-graph` option, refresh/dependency-download flag or dependency-validation bypass is included. `--no-daemon` can still fork a single-use daemon to satisfy JVM settings; the controller must track its child process tree.

Variant: **qaDebug**, independent package `com.studybirds.app.qa`, x86_64 only for this proposal. Expected Flutter APK:

`C:\Users\Abood\AppData\Local\StudyBirds\qa-diagnostic-phase8\gradle-build\app\outputs\flutter-apk\app-qa-debug.apk`

AGP may also write its duplicate in `gradle-build\app\outputs\apk\qa\debug`; verify the actual metadata/name rather than guessing a filename. No overwrite of any existing APK in either location is allowed. No copy to D production outputs, no installation and no ARM/device support claim.

## Checks before, during and after

**Before:** recheck both capacities, idle project writers, canonical/ordinary C directories and ancestor ACLs/links, expected empty roots, missing QA APK, available offline toolchain/dependencies, exact hashes and defines, one-use permission scope, task requests, fixed C root and unchanged production branch. Snapshot Git HEAD/index/status/worktree registrations and protected source/config/signing hashes without printing secrets. Use the existing preparation checkpoint as reference but create any new evidence only in explicitly approved destinations; never overwrite old checkpoints.

Protect existing APK at `D:\work\studybirds_session_release\app\build\app\outputs\flutter-apk\app-debug.apk`, SHA-256 **9638b98f111bf25b4079555f4a48029d40a4892dc12f48f407b3894b61b9ce23**. Revalidate the 139 preparation-protected files; add original signing/config hashes and production output inventory to the run record. The intentionally edited gate must have separately reviewed before/after hashes, not be silently exempted.

**During:** monitor capacity, task graph/task starts and newly written paths; capture logs without secrets to approved diagnostics. Expected D writes are the Flutter `.dart_tool\flutter_build` cache and documented small project metadata; unexpected writes to production `app\build`, signing/config/source, old D QA evidence or QA database/storage are stop conditions. Do not use a stale D manifest as fallback. Shared SDK/Pub/Gradle staging is not private to QA; document any normal approved writes there before allowing them. Disk monitoring alone does not detect all path or network events; a reviewed observation mechanism is a prerequisite, not a claimed feature of the command.

**After Stage A and after Stage B:** record exit status and per-volume deltas/peaks, compare output inventories and protected hashes/Git relationships, inspect exact artifact manifest/package/variant/debug status and x86_64 native entries using existing offline inspection tools only, then SHA-256/name/size of the new APK. Post-package manifest must agree with reviewed merged XML. Availability of an APK inspector and actual APK findings remain unverified; missing tools mean stop, not download. Disarm the one-use authorization and restore denial even when a check fails.

## Required new C-output isolation evidence

New merged XML must be selected explicitly:

`C:\Users\Abood\AppData\Local\StudyBirds\qa-diagnostic-phase8\gradle-build\app\intermediates\merged_manifest\qaDebug\processQaDebugMainManifest\AndroidManifest.xml`

Rerun strict checks against this file, not the preserved historical D XML:

- QA package/label/HTTPS-only flags; only `QaMainActivity` launcher; no production entry point, deep links, Google sign-in activities or forbidden provider exports.
- OneSignal/Firebase/Credentials/Sentry/PostHog exclusions, AndroidX initializer metadata and transitive components; no unexpected new entry points.
- ML Kit initialization/discovery, exact OCR registrars and PassportScanner registration preserved; local Flutter registration still excludes provider plugins.
- Exactly one `cct` discovery binding to the approved local QA factory; vendor CCT backend and unknown/duplicate bindings rejected.
- Reaudit actual QA backend source/compiled bytecode and vendor routing, scheduler/retry/ForcedSender/cold-start model tests. Existing suites are `qa_android_preparation.test.cjs`, `qa_android_merged_manifest.test.cjs` and `qa_transport_evidence.test.cjs`; they must retain negative tests.

Important boundary: the merged-manifest suite calls `qa_transport_jvm/verify.cjs`, which **compiles Java and writes harness evidence**, currently only under an explicitly selected `.git` checkpoint. It is not a read-only XML test. Rerunning it requires separate explicit approval for a fresh harness-evidence checkpoint and its existing JDK/classpath inputs, without overwriting prior evidence or changing Git history/index. No harness was run now, and its output restriction must not be weakened to make C storage convenient.

Passing static/JVM tests does not prove OCR recognition, native Android boot, SQLite queues, OS deferred jobs, provider network silence or TLS/device behavior. `QA_RESOURCES_VERIFIED=false` intentionally blocks Dart startup; native providers can precede Dart. This diagnostic artifact is not runtime-ready.

## Failure and rollback

Compile/test failure, missing offline dependency, capacity-monitor failure, threshold breach, unexpected paths/tasks or protected-file change: stop the approved build's own process tree, record partial evidence, consume permission and deny Stage B/retries. Do not kill unrelated processes, clean caches, delete partial artifacts, install dependencies, reset/stash or auto-repair configuration. Owner review is required for a new attempt.

`--offline` prevents dependency resolution downloads; it is **not network containment** for Gradle plugins, Flutter/Dart tool analytics or arbitrary subprocesses. Host-tool egress observation/suppression must be independently reviewed without changing global credentials/provider settings; unknown/unobserved build-time network behavior is a NO-GO prerequisite. If unexpected external contact/provider activity is observed, stop and retain evidence; no production endpoint probes. No firewall policy change is authorized here.

Rollback preserves all Git/uncommitted work: disarm permission and reverse only the newly approved gate/controller hunk against its recovery record, comparing later edits before restoration. Keep the approved C storage preparation unless separately asked to revert it. Leave partial C artifacts and all D evidence in place for owner review; no automatic cleanup. Verify production branch, protected APK/config/signing hashes, HEAD/index/worktree relationships and previous untracked files again.

## GO / NO-GO checklist and owner boundaries

- [x] QA C output configuration exists; production output branch preserved; current protected APK/gate/pending-config hashes match; prepared C directories empty.
- [x] Current capacity meets the **proposed**, not approved, volume-aware thresholds.
- [ ] Owner explicitly approves replacing the old D minimum with C>=16/D>=6 GiB start and C>=8/D>=4 GiB stop thresholds.
- [ ] Exact narrow gate/controller patch reviewed, negative-tested and approved; one attempt per stage, default denial and rollback/disarm enforced. No permanent bypass.
- [ ] Complete graph/output/native-staging observation and disk/network monitoring mechanisms reviewed and approved; no unexpected production/release tasks or external contact.
- [ ] Exact command, x86_64 variant, per-invocation JVM/project-cache settings, new artifact paths and evidence destinations approved.
- [ ] Fresh protected-file/Git/ACL/link/source/config preflight passes immediately before execution.
- [ ] New C manifest/native/telemetry evidence passes before packaging; strict JVM harness writes/compilation have their own explicit approval.
- [ ] Owner explicitly authorizes the single two-stage diagnostic attempt after these conditions; no install/runtime/deploy permission included.

**Final decision: NO-GO until the unchecked items are resolved and explicitly approved.** This review authorizes neither a gate change nor compilation/assembly. Production readiness and Android runtime success remain unproven.
