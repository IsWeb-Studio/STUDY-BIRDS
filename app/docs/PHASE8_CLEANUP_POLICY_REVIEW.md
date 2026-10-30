# Phase 8 — execution-policy block and owner-only cleanup proposal

Update, 2026-10-22: the filesystem type fix and its actual validation are recorded in `PHASE8_OWNER_CLEANUP_FIX_VALIDATION.md`. With explicit later authorization, the agent ran the default dry-run only; it stopped at the preserved Dart-process guard. The original “not run” statements below describe preparation time. No deletion or `-Execute` invocation occurred.

## Evidence and supported approval path

The previous execution log, `PHASE8_LIMITED_CLEANUP_RESULT.json`, records `BLOCKED_BY_AUTOMATIC_APPROVAL_POLICY_NO_DELETIONS` and `blocked by policy; no detailed reason supplied`. All nine targets were skipped, their recorded file hashes remained unchanged, and no deletion occurred.

Available tool diagnostics show `exec_command` process creation was rejected before the proposed PowerShell command ran. The combined verification/deletion request and the later independent target-1 deletion request were both rejected. This establishes an execution-tool approval/policy denial, not a demonstrated Windows ACL error, PowerShell execution-policy error, Git protection, antivirus decision or locked-file failure. The responsible rule identifier, classifier decision and detailed rationale are not exposed. It would be inaccurate to claim that `-Recurse`, command length or any particular filename caused it.

The current session's execution approval policy is `never`; no supported escalation or user-approval override tool is exposed for this rejection. Written user authorization establishes intended scope but does not override the execution guard. No new deletion request was made in this task. No security setting, permissions profile, allow rule, shell, encoding or alternate executor was used to circumvent the denial.

Official OpenAI documentation was consulted via [the security documentation entry point](https://developers.openai.com/codex/security/) (redirecting to ChatGPT Learn). The retrieved page did not establish a session-specific approval procedure for this denial. No undocumented UI button, CLI flag or configuration change is proposed as an approval solution. If an organization-managed restriction also applies to the owner's terminal, stop and use the organization's approved review process; this script is not permission to override it.

## Reviewable manual artifact

`PHASE8_OWNER_CLEANUP.ps1` is a standalone PowerShell 5.1+ script for **OWNER REVIEW AND MANUAL EXECUTION ONLY**. The agent has not run it, including its dry-run mode.

- Exactly targets 1–9 are hard-coded, including target 9 as a single file. It accepts no target, inventory or path override parameter.
- An embedded readable JSON inventory freezes all **266 files**, exact directory inventories, byte lengths and SHA-256 values from the prior no-deletion execution log. It records that log's and the approval report's SHA-256 provenance. No automatic inventory refresh is available.
- Default mode checks only; actual deletion additionally requires `-Execute` and typing an exact interactive confirmation phrase. There is no noninteractive confirmation switch.
- Checks include canonical absolute paths, all ancestor and descendant reparse points, actual Windows hard-link counts, protected/generated filename rules, file/directory counts, content hashes, Git tracking, exclusive file access and build-related processes.
- The process check is intentionally stricter than the original audit: **all Dart processes, including editor analysis servers and daemons, block the script**. The owner must close that tooling manually before retrying. Java/Gradle/Flutter processes also block it. Nothing is killed automatically.
- All nine targets pass a preflight before any confirmation or deletion; every target is rechecked immediately before its operation. Missing, changed, locked or uncertain contents cause failure and stop subsequent operations. A partially completed failure is logged for review, never silently retried or rebaselined.
- Actual deletion uses only inventory-exact files and empty directories; no recursive deletion, wildcard deletion or parent cleanup. Quantis and QA resources are absent from the deletion allowlist.
- An owner-executed deletion run creates a uniquely named audit JSON beside the script. It records per-target D free space before/after, observed byte deltas, skipped/failed operations, final capacity, Git HEAD/index/status/worktree snapshots, and protected APK/gate/config hashes. Free-space deltas can include unrelated concurrent disk activity; they are measurements, not exact file-allocation attribution.
- Dry-run writes no audit file and deletes nothing. Loading the Windows hard-link metadata helper uses `Add-Type`; this is utility compilation inside the owner's PowerShell process, not Android compilation. Existing Git and Windows/.NET are required; no downloads are performed.

The owner must keep project writers idle throughout. Path/hash/lock checks are point-in-time checks and cannot eliminate every race with another process changing directories during cleanup. Do not run while other work writes these paths. If interrupted or partially completed, retain the audit and request a fresh review instead of modifying the frozen inventory or rerunning against missing targets.

## Owner review and dry-run commands

In the owner's own PowerShell terminal, inspect the script and its embedded inventory first:

```powershell
Set-Location D:\work\studybirds_app\study_birds_app-main\docs
Get-Content -LiteralPath .\PHASE8_OWNER_CLEANUP.ps1
Get-FileHash -LiteralPath .\PHASE8_OWNER_CLEANUP.ps1 -Algorithm SHA256
```

After manually closing build tools/Dart editor tooling, run the default dry-run:

```powershell
.\PHASE8_OWNER_CLEANUP.ps1
```

Expected: nine `DRY-RUN VERIFIED` messages, current free space and `DRY RUN ONLY`. Any error means stop and review; do not edit inventories or weaken checks. If Windows or organizational policy blocks the script, stop there: no `ExecutionPolicy Bypass`, elevation workaround or policy changes are prescribed.

Only after reviewing a successful dry-run and deciding to perform the previously approved manual cleanup:

```powershell
.\PHASE8_OWNER_CLEANUP.ps1 -Execute
```

It requires typing `DELETE ONLY STUDY BIRDS TARGETS 1-9` interactively. This command has **not** been run by the agent.

## Validation performed here and remaining QA build blockers

- PowerShell parser-only AST inspection: **zero syntax errors**. This does not execute the script, invoke its functions, compile its helper, run a dry-run or validate runtime deletion behavior.
- Embedded inventory was compared structurally against the previous execution log; all nine paths and 266 file records match. The script remains an owner-reviewed proposal, not an executed cleanup result.
- No cleanup, build, ADB, emulator, installer, dependency download, provider operation or Git mutation was performed. New script and this explanatory repository document are the intended changes.
- Previous measured D free space was about **5.52 GiB**. Approved targets 1–9 were estimated to raise it only to **7.30 GiB**. Even if the owner later deletes them successfully, the **8 GiB build threshold is not expected to be met**. Quantis remains unapproved and excluded.
- Direct agent deletion remains blocked. Before any QA APK: measure actual capacity, resolve the remaining capacity shortfall with separately approved means, then obtain separate approval for the narrowly reviewed Gradle gate-policy change and exact offline diagnostic `qaDebug` compile/assemble sequence. The gate remains enabled and `QA_RESOURCES_VERIFIED=false`; installation/runtime testing requires its own isolation checks and authorization.
