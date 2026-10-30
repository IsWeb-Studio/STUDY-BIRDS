# Phase 8 — narrow AOT filename-validation correction

Date: 2026-10-22. No cleanup/deletion, Android compilation, build or `-Execute` invocation.

## Exact evidence and cause

Target 4 file inspected:

`D:\work\studybirds-security-release-20261017-mobile\.dart_tool\flutter_build\34387cda8c1192f48cb6bb1f629b771d\flutter_android_aot_release_android-x64.d`

- Regular generated Flutter Android release AOT dependency file, 2 bytes, text `: ` (empty dependency rule).
- SHA-256: `45822f54a0d0e030f75698c9252f1345982e743c9466806048f542467b3ca4f9`.
- Exact path, length and SHA-256 match the existing frozen inventory. No inventory entry was edited or regenerated.
- Installed Flutter source at `C:\src\flutter\packages\flutter_tools\lib\src\build_system\targets\android.dart` declares AOT dependency files as `flutter_$name.d`; `build_system\depfile.dart` writes outputs, `: ` and inputs. These are compiler dependency records, not signing/configuration files. Inspection did not execute Flutter.
- Previous filename expression `^[a-z0-9_]+\.(d|stamp)$` excludes the hyphen in platform names. This also rejects the existing AOT bundle depfiles and AOT stamp names in targets 4 and 5. Target 4 has two compilation directories with these names; target 5 has one. Every affected record was checked against its frozen length and SHA-256.

## Minimal change

Preserved the existing filename rules. Added only two explicit release-AOT patterns, only for target IDs 4 and 5:

```text
^flutter_android_aot_(bundle_)?release_android-(arm|arm64|x64)\.d$
^android_aot_(bundle_)?release_android-(arm|arm64|x64)\.stamp$
```

No general acceptance of hyphens, arbitrary depfiles, other platforms, debug/profile names or extensions was added. Existing exact inventory membership, path/type/link/hard-link/lock/process checks, Git checks, protected filenames, hashes, StrictMode, dry-run default and interactive deletion confirmation remain intact.

## Actual test results

- PowerShell 5.1 parser: **0 syntax errors**.
- Focused tests of the actual `Assert-GeneratedName` function: **all 266 frozen filenames accepted**, including targets 4–9. Five negative cases rejected: unrelated hyphenated depfile, unreviewed architecture, debug AOT name, release AOT name in target 2, and private-key PEM name. No test file was created and no full safety guard was bypassed.
- Frozen JSON SHA-256 remains `c9fa2b9672f97d27eb7e931e1555a26533682bc90241e374e307f715f10bb5a0`; all nine paths, file records and directory inventories match the prior execution log.
- Independent read-only checks: all **266 original file lengths and SHA-256 values** still match. No target files changed.
- Default script dry-run executed without `-Execute`; tool execution was permitted. It stopped at the unchanged safety guard: **`Build-related process present: java.exe, PID 30208`**, exit 1. Processes were not stopped. This is not an execution-policy denial or another filename failure.
- Therefore **full nine-target dry-run success is not demonstrated** in this run. The owner's earlier pass for targets 1–3 is user-reported evidence, not a new full preflight here. No remaining filename-validation error appeared in the focused inventory tests; later full-preflight outcomes are not assumed.
- PowerShell 7 was not executed. No deletion or Android operation occurred. D free snapshot: **5,917,818,880 bytes (~5.51 GiB)**, below 8 GiB.

## Owner rerun

Close Java/Gradle/Flutter/Dart tooling manually and wait for it to stop, then run only:

```powershell
.\docs\PHASE8_OWNER_CLEANUP.ps1
```

Do not weaken process checks or modify the frozen inventory if validation stops. No `-Execute` is needed to test this correction.
