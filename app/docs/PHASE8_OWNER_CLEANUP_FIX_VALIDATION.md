# Owner cleanup script — filesystem type fix

Date: 2026-10-22. No cleanup target changed; no deletion or `-Execute` invocation.

## Reproduced cause

The original `Assert-PlainAncestors` accessed `$item.PSIsContainer` on each ancestor. `Get-Item` returns a provider-decorated `System.IO.FileInfo` / `System.IO.DirectoryInfo` with that property. Its native `.Directory` and `.Parent` properties return raw `System.IO.DirectoryInfo` objects without the provider property. Under `Set-StrictMode -Version Latest`, the next iteration throws `PropertyNotFoundStrict`.

The startup path reaches this while verifying the first protected file, the existing deployment APK, before target preflight: FileInfo -> DirectoryInfo from `.Directory` -> missing property. Read-only inspection reproduced these exact types and property-presence differences in Windows PowerShell 5.1.26100.9711.

## Fix and related review

- Added `Assert-FileSystemObject`: explicitly accepts only `System.IO.FileInfo` or `System.IO.DirectoryInfo`, rejecting null and other object types.
- Replaced every `PSIsContainer` use in ancestor traversal, tree walking, target classification/filtering and the deletion file check with concrete type tests. Added an explicit directory type check before empty-directory removal.
- Preserved StrictMode, all link/hard-link/lock/protected-file checks, process guards, Git checks, interactive confirmation, exact allowlist and frozen inventory.
- Replaced the Git tracked-files check's scalar `.Length` assumption with `String.IsNullOrEmpty`; explicitly validated the repository-root string. Reviewed other Count/Length access: filesystem lengths are typed FileInfo values, counts use explicit arrays/collections, and path lengths are strings.
- No execution-policy or security setting changed. No processes stopped. No production or QA configuration changed.

## Actual validation

- PowerShell parser: **zero syntax errors**.
- Focused read-only tests in Windows PowerShell 5.1 with StrictMode: raw DirectoryInfo accepted; protected APK ancestor traversal passed; directory-target ancestor traversal passed; synthetic non-filesystem object rejected.
- Frozen embedded JSON SHA-256 unchanged: `c9fa2b9672f97d27eb7e931e1555a26533682bc90241e374e307f715f10bb5a0`.
- Embedded nine paths, 266 file records and directory inventories still match the previous execution log. Independent read-only SHA-256 checks of all 266 original files match the frozen values. This is not a completed full nine-target safety preflight.
- PowerShell 7 executable was not found in PATH; compatibility uses shared .NET filesystem types and PowerShell 5.1 syntax, but no PowerShell 7 runtime success is claimed.
- Default script dry-run **was invoked without `-Execute`**. The execution tool permitted it. It passed the previous failing protected-file ancestor path, then stopped as designed at the existing process guard: `Dart process present, PID 6228; close tooling manually and retry.` Exit code 1. No `DRY-RUN VERIFIED` target completed; **all nine targets are not yet fully verified by the script**.
- This was a process-safety refusal, not a new execution-policy rejection or a recurrence of the property error. The process check was not bypassed to obtain a successful run.
- No files deleted, moved or modified inside targets. The only intended writes are the repaired script and repository validation notes. No Android compilation/build, ADB, emulator or Git mutation.

## Owner next step

Close Dart/editor/build tooling manually, then run only the default dry-run from the project root:

```powershell
.\docs\PHASE8_OWNER_CLEANUP.ps1
```

Do not disable guards or change frozen inventory if another check fails. Review its exact error. No deletion is required to validate this fix.

D free remains approximately **5.52 GiB**, below **8 GiB**. The existing gate and `QA_RESOURCES_VERIFIED=false` remain unchanged; this fix does not authorize a QA APK build.
