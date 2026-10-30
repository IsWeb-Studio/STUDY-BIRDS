# Phase 8 — QA diagnostic build storage feasibility

2026-10-22. **Feasible for most build outputs, subject to separate implementation approval; not a zero-write-on-D solution.** Investigation was read-only except this requested report. No directories, junctions or environment variables were created/changed; no Gradle/Flutter command, build or installer ran.

## Recommendation

Keep source, original APK and protected QA resources on D. Change only the already opt-in QA output branch in deployment `app\android\build.gradle.kts` to a fresh, fixed C directory. Keep its production `else` branch, signing, identity and app security gate unchanged. Use direct Gradle for the future diagnostic invocation, as already proposed; avoid global Flutter build-directory configuration and repository/build junctions.

Snapshot free: **C: 34,279,665,664 bytes (31.925 GiB); D: 7,833,137,152 bytes (7.295 GiB)**. These are independent filesystem capacities even though the owner reports both volumes on Disk 0. No repartitioning or change to the intervening Recovery partition is needed for output placement. No performance improvement from moving between partitions is promised.

## Where the installed tools write

Deployment source remains `D:\work\studybirds_session_release\app`; versions inspected: Gradle wrapper **8.14**, AGP **8.11.1**, Kotlin **2.2.20**.

- **QA Gradle root/subprojects now:** `D:\work\studybirds_qa_phase7\android-build` and `<root>\app`, `<root>\jni`, `<root>\camera_android_camerax`, etc. Root script explicitly assigns each subproject's `layout.buildDirectory` when `studybirdsQa=true`.
- **Production Gradle outputs now:** `D:\work\studybirds_session_release\app\build` and `build\app`, etc., via the unchanged non-QA branch. Existing protected APK: `build\app\outputs\flutter-apk\app-debug.apk`.
- **AGP/Java/Kotlin normal intermediates:** under the app/subproject build directory, e.g. `app\intermediates\javac\qaDebug`, `app\tmp\kotlin-classes\qaDebug`, `app\kotlin` and resource/dex/packaging outputs. Exact task subpaths can vary; root redirection does not prove every plugin follows it.
- **Flutter Gradle task output:** installed `FlutterPlugin.kt` sets `intermediates\flutter\qaDebug` relative to `project.layout.buildDirectory`; `BaseFlutterTaskHelper.kt` invokes Flutter assemble with that `--output` and a depfile there. APK copying goes to `project.layout.buildDirectory\outputs\flutter-apk`. These should follow the QA C output branch.
- **Flutter's internal compiler cache remains on D:** installed `C:\src\flutter\packages\flutter_tools\lib\src\commands\assemble.dart` explicitly uses `<source>\.dart_tool\flutter_build`. Gradle output redirection does **not** redirect this cache. Package configuration and other small generated project metadata may also remain project-local. Do not claim no D writes.
- **Gradle project state:** normally `D:\work\studybirds_session_release\app\android\.gradle`; distinct from build outputs. A future invocation can request a separate project cache via documented `--project-cache-dir` ([Gradle CLI](https://docs.gradle.org/current/userguide/command_line_interface.html#sec:command_line_environment_options)). Included builds may retain their own local state; the main project's option is not proof of global redirection.
- **Shared Gradle dependency/transformation/wrapper caches:** current default `C:\Users\Abood\.gradle`; `GRADLE_USER_HOME` is unset. Keep existing owner/caches in place; a fresh Gradle user home could require dependencies unavailable offline. These are separate from project state ([Gradle directory layout](https://docs.gradle.org/current/userguide/directory_layout.html)). Current docs were retrieved; version-specific 8.14 web retrieval failed, so validate the proposed CLI option against the installed wrapper during an approved preparation step, not by assuming newer flags exist.
- **Pub/Flutter/Android SDK:** existing `C:\Users\Abood\AppData\Local\Pub\Cache`, `C:\src\flutter\bin\cache`, and `C:\Users\Abood\AppData\Local\Android\Sdk`. Do not relocate/duplicate them or remove cache entries. Offline operation may still update tool state.
- **Temporary files:** inherited `TEMP` and `TMP` both point to `C:\Users\Abood\AppData\Local\Temp`. JVM temp is normally derived from the process environment; no `java.io.tmpdir` override was found in project Gradle properties and no user Gradle properties file was present at the checked default path. The running build JVM was not queried. A future dedicated temp directory needs process-scoped configuration and JVM/child-process verification, not a machine-wide change.
- **Native exception:** cached `jni-1.0.3\android\build.gradle` declares `externalNativeBuild` with `../src/CMakeLists.txt` and no explicit `buildStagingDirectory`. AGP CMake staging may be project-local `.cxx` in that plugin's C-based Pub directory rather than the redirected build root. Inspect/verify during preparation; changing `buildDirectory` alone is not complete native-staging isolation. No dependency source edit is proposed.

## Exact proposed C layout — absent, not created

Base: `C:\Users\Abood\AppData\Local\StudyBirds\qa-diagnostic-phase8`

- `gradle-build` — QA root `layout.buildDirectory` only.
- `gradle-build\app\intermediates\flutter\qaDebug` — Flutter task outputs.
- `gradle-build\app\outputs\flutter-apk\app-qa-debug.apk` — expected future diagnostic deliverable; also expect AGP's APK copy under `outputs\apk\qa\debug`. Budget both copies; do not overwrite any existing artifact.
- `project-cache` — future QA invocation's project-state cache.
- `tmp` — optional process-scoped Windows/JVM temporary files.
- `diagnostics` — optional logs/JVM heap dumps. Current JVM options include heap dumps on OOM without an explicit dump path: a dump could otherwise land in the D working directory. Any future QA JVM options must preserve existing memory options while explicitly routing dumps here, and be reviewed separately.

Target base does not currently exist. Existing ancestors through `C:\Users\Abood\AppData\Local\StudyBirds` were checked: no reparse points. This is not a successful write/access/ACL test because none was allowed. Verify volume, owner/ACL, all ancestors and exact canonical target again before approved creation; stop on an existing/nonempty or linked target. Do not reuse the primary app's `build-cache` tree.

Unchanged D paths: source; `app\.dart_tool\flutter_build` if regenerated; original production `app\build`; QA database/storage/TLS/configuration and the existing `D:\work\studybirds_qa_phase7\android-build` manifest evidence. Do not move or clean the old QA output/evidence tree. Consumers must explicitly select the new C manifest/output paths after approval; never silently read stale D evidence.

## Constraints, alternatives and production risk

- Deployment `app\build`, `.dart_tool`, `android\.gradle` and reviewed ancestors are ordinary directories. The **primary** app separately has `build` and `.dart_tool\flutter_build` junctions to C; these are not deployment settings and must not be reused or changed.
- Windows cross-drive paths are a known Kotlin incremental-cache risk. Existing `kotlin.incremental=false` and `kotlin.compiler.execution.strategy=in-process` must stay unchanged. Reusing old absolute-path caches can produce stale results; start a fresh QA output root without moving caches.
- The installed Flutter CLI's global `build-dir` setting requires a relative path (`build_info.dart`); it is not an absolute-C storage solution. CLI artifact discovery may assume its normal tree. Prefer the reviewed direct Gradle flow and inspect the actual C artifact; do not add a copy back into production `app\build` just to satisfy discovery.
- A deployment `.dart_tool\flutter_build` junction could move the remaining compiler cache, but that filesystem link would also affect subsequent production invocations. It is **not inherently QA-only**, requires additional link/lifecycle approval and is not recommended here. Modifying Flutter SDK internals is also not recommended. No full C-only solution is demonstrated under current constraints.
- Changing only the QA branch should preserve ordinary production output paths. Risks are accidental shared-branch edits, plugin outputs ignoring the new directory, stale inspection paths, concurrent builds, native staging, OOM dumps and copies overwriting existing APKs. Keep the original APK hash `9638b98f111bf25b4079555f4a48029d40a4892dc12f48f407b3894b61b9ce23` as an explicit before/after check.

## Reversible plan and approval boundaries

1. **Approve preparation separately:** exact C root/subdirectories, a minimal QA-only root Gradle patch, project-cache/temp/dump invocation settings and updates to manifest-test/evidence path consumers. No production defaults or shared dependency owners change. Save verified recovery copies only after approval; preserve all other local edits and Git relationships.
2. Verify capacity/ACL/links and absent destination; then create the approved directories. Change the hard-coded QA output location only (or a strictly validated QA-only fixed allowlist); reject any override outside QA. Retain the production branch byte-for-byte. Do not use arbitrary environment/property path overrides or junctions.
3. Review static tests for QA vs production path selection and artifact/evidence consumers. Any Gradle configuration/manifest processing itself writes files and needs explicit approval; it was not run here. Record actual task output paths, plugin native staging and JVM temp/dump settings before claiming complete placement.
4. Roll back by reversing only the new reviewed configuration hunk and invocation settings, preserving pre-existing local changes. Leave new C outputs for separate owner review; no cleanup/reset/stash/move of existing evidence is part of rollback.
5. **Separate build decision:** capacity criteria, exact diagnostic command and the narrow gate-policy change need explicit approval after preparation evidence. Output relocation is not permission to relax the existing D minimum automatically. No build is authorized by this report.

## Capacity budget and gate

Planning estimates, **not measured QA build peaks**: reserve **4–8 GiB incremental C** for fresh Gradle/app/plugin outputs, project state, temporary copies and cache growth; retain at least another **4 GiB C headroom**. With 31.925 GiB free, the normal estimate leaves roughly **23.9–27.9 GiB**, before unrelated activity or abnormal heap dumps. Recheck both volumes throughout any future authorized run.

Allow **0.3–1.5 GiB incremental D** for the hard-coded Flutter compilation cache and remaining project metadata as a conservative initial budget, leaving roughly **5.8–7.0 GiB D**. This range is uncertain and not proof of a hard upper bound; a volume-aware capacity policy needs reviewed measurements. Relocation does not increase D free space to 8 GiB; it changes where most future growth occurs.

**The current QA gate still blocks compilation/assembly.** Its app `taskGraph.whenReady` rejects QA compile/package/assemble/install tasks regardless of output location. It was neither changed nor exercised. `QA_RESOURCES_VERIFIED=false`, empty pending CA and production/provider protections remain unchanged. No QA diagnostic APK or runtime success is claimed.
