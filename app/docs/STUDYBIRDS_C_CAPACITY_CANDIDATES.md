# Study Birds — C: recovery capacity discovery

2026-10-22. Controlling reports: `STUDYBIRDS_B0_RECOVERY_PREFLIGHT.md` and `STUDYBIRDS_PHYSICAL_MIGRATION_PLAN.md`.

**NO-GO: an additional 5 GiB of safely disposable C: data has not been demonstrated. No cleanup plan is recommended for execution.** This report authorizes no cleanup, backup, migration or Android build. Only this new report was written. No file contents were inspected during capacity discovery; no services, settings, repositories or artifacts were changed.

## Measurements and scope

Initial C: free: **33,703,047,168 bytes (31.388 GiB)**. Final sampled C: free: **33,686,585,344 bytes (31.373 GiB)**. D: **7,832,477,696 bytes (7.295 GiB)**. The approximately 15.7 MiB C: variation occurred while other processes remained running; it is not cleanup or reclaimed capacity.

This was a bounded discovery, not a whole-volume census: root metadata, selected user-local temporary/output roots, and immediate local-app directory names. The metadata walker used lstat, skipped links, and had 45-second/180,000-entry/depth-18 limits. Selected walks completed without reported traversal errors or truncated totals. Browser profiles, personal documents, VMs, Windows/system trees, unrelated source projects, credentials and dependency stores were not recursively inventoried. Some temporary directory ownership became identifiable only after metadata enumeration; those trees are excluded below, not proposed for cleanup. No link target was followed.

Actual allocated size was **not obtained**. All sizes below are default-stream logical lengths, not guaranteed physical recovery; sparse/compressed files, allocation sharing, streams, directory metadata and changing files can alter actual recovery. No compression savings are assumed. No parent and child totals are added together.

## Small review leads — not an approved deletion list

Owner `Abood` below means `DESKTOP-BI43VHU\Abood`. Exclusive read-open probes did not read contents or alter files. A successful probe is point-in-time evidence only; it does not establish absence of future use or prove the data is disposable.

| Exact path | Logical bytes / GiB | Owner | Links / file-access evidence | Classification and caveat |
|---|---:|---|---|---|
| `C:\Users\Abood\AppData\Local\NVIDIA\DXCache` | 17,645,568 / 0.0164 | Abood | Metadata walk: no links; **1 of 132 files locked or access denied** | Shader-format `.bin`, `.toc`, `.nvph` metadata is consistent with graphics cache, but regeneration and producer were not independently established. **Do not approve while use is uncertain.** |
| `C:\Users\Abood\AppData\Local\NVIDIA\GLCache` | 37,331,981 / 0.0348 | Abood | No links; 18/18 exclusive read probes succeeded | Possible generated graphics cache. Producer/rebuild behavior still requires confirmation; no content inspection or application shutdown was performed. Conditional lead only. |
| `C:\Users\Abood\AppData\Local\SquirrelTemp` | 1,264 / 0.0000012 | Abood | No links; 1/1 probe succeeded | Contains only `Squirrel-Install.log` by filename. Installer-log retention/producer unconfirmed; no meaningful capacity benefit. Not disposable merely because of its name. |

These three leads total only **54,978,813 logical bytes (0.0512 GiB)** before exclusions/locks, not verified recoverable space. Confirmed safe recovery credited to the B0 budget: **0 bytes**. No evidence supports a narrowly scoped >=5 GiB cleanup approval list.

## Large consumers identified and excluded

TEMP overall observed logical size: **10,074,263,232 bytes (9.382 GiB)** across 461 immediate children. **Do not delete TEMP as a directory.** Its large total is misleading because it mixes protected projects, databases, build/test material, installer payloads and unknown data.

| Exact path | Logical bytes | Decision / evidence |
|---|---:|---|
| `C:\Users\Abood\AppData\Local\Temp\studybirds-email-onboarding-1.0.9` | 3,212,357,235 | Study Birds material, 18,920 files. Excluded; no assumption it is redundant or reproducible. |
| `C:\Users\Abood\AppData\Local\Temp\chc3y2pp` | 3,168,015,279 | 736 files; immediate package directories identify Microsoft.Build, CodeAnalysis and Visual Studio setup components. Owner Abood; ordinary directory/no descendant links in metadata walk. Dependency/setup payload, potentially needed for repair or offline installation: excluded, not safe cache recovery. No lock clearance claimed. |
| `C:\Users\Abood\AppData\Local\Temp\DockerDesktopInstallers` | 622,243,993 | Owner Abood; four files, no links, four exclusive read probes succeeded. Includes installer executable, extraction tool and `.d4w`/VM-related payloads. Reproducibility/offline retention unverified; VM/tooling exclusion applies. Not a cleanup candidate. |
| `C:\Users\Abood\AppData\Local\Temp\wsl.3.0.3.0.x64.msi` | 367,575,040 | Owner BUILTIN\Administrators; ordinary file; read probe succeeded. System/VM platform installer: excluded. |
| `C:\Users\Abood\AppData\Local\Temp\mongo-mem-gVqUXZ` | 209,913,265 | Database/test data: excluded. No data contents inspected or lock clearance claimed. |
| `C:\Users\Abood\AppData\Local\Temp\mongo-mem-a5PEQM` | 209,763,188 | Database/test data: excluded; no assumption stale or disposable. |
| `C:\Users\Abood\AppData\Local\Temp\flutter_tools.45aa31fd` | 188,879,490 | Flutter build/tool output: excluded under active-build-cache protection; activity not resolved. |
| `C:\Users\Abood\AppData\Local\Temp\flutter_tools.a701a509` | 188,809,696 | Same exclusion. |
| `C:\Users\Abood\AppData\Local\Temp\flutter_tools.6514d9f0` | 93,368,064 | Same exclusion. |
| `C:\Users\Abood\AppData\Local\Temp\studybirds-test-cache-backup` | 188,796,504 | Study Birds backup/test evidence: excluded. |
| `C:\Users\Abood\AppData\Local\Temp\DiagOutputDir` | 105,394,176 | Unknown diagnostic output/retention; excluded rather than inferred disposable. |
| `C:\Users\Abood\AppData\Local\Temp\3lwqlhof.iea` | 88,007,582 | 468 files; language, Assets and PrecheckTools directory names suggest installer/tool payload. Provenance insufficient; excluded. Similar-size siblings were not presumed duplicates. |

Docker and WSL payloads together are only 0.922 GiB, and are **not credited**. `CrashDumps` was empty. `D3DSCache` had 2,899,968 logical bytes, but its system attribute excludes it from a proposed cleanup scope.

Previously measured large Gradle, Pub, Flutter SDK, Android SDK and Study Birds build-cache trees remain protected dependencies/build resources; their historical sizes are not fresh cleanup estimates. C: registered Study Birds worktrees, Git stores, signing material, existing APKs, migration checkpoints and `StudyBirds\qa-diagnostic-phase8` remain excluded. No private browser or VM contents were opened. No Windows cleanup utility was invoked.

Running-process inspection found Node/MongoDB, Java and Dart processes. No Docker/msiexec/setup-named process was observed in that filtered sample, but absence of a process name does not prove a directory is unused. Process command lines and credentials were not disclosed. No process was stopped. Open-file probes above are not a comprehensive kernel-handle census.

## B0 recalculation

Use the controlling preflight's conservative unchanged scope; it is a prior measured live census, not a fresh frozen backup inventory:

| Requirement | Bytes |
|---|---:|
| Logical selected payload, informational subset of budget | 14,943,310,906 |
| Estimated backup peak including allocation, metadata, growth and temporary reserves | **18,512,764,109** |
| Representative restore scratch | **3,221,225,472** |
| Future QA C: build reserve, 16 GiB | **17,179,869,184** |
| Required initial C: free | **38,913,858,765** |
| Final sampled C: free | **33,686,585,344** |
| Shortfall | **5,227,273,421 (4.8683 GiB)** |

An actual additional **5 GiB** would leave only **141,435,699 bytes (~134.9 MiB)** beyond this conservative budget. After backup peak plus restore scratch, C: would have **16.132 GiB** remaining. That is a narrow margin against changing files and background growth, not a durable capacity guarantee. No such recovery has been established. With no cleanup, C: after backup peak and restore scratch would be about **11.132 GiB**, below the 16 GiB reserve. D: also remains below the existing 8 GiB build policy; no threshold is relaxed by this report.

## Existing-disk alternatives and approvals

1. **Keep B0 paused.** Preserve all sources and QA preparation; defer migration and builds. The owner may identify an expendable non-project application/download or provide provenance for an uncertain item, followed by a separately scoped review. No personal-data relocation or application removal is proposed as automatically safe.
2. **Review a split C:/D: recovery design**, not execute it. This cannot solve the current conservative simultaneous reserve budget by itself: combined free space is approximately 38.668 GiB; backup peak + 3 GiB restore + 16 GiB C reserve + the migration plan's 4 GiB D floor require approximately 40.241 GiB, a gap of approximately 1.574 GiB. Even that D floor is below the existing 8 GiB build threshold. Do not move data between partitions and call it recovered total capacity.
3. A separately approved **sequential B0/restore schedule or revised backup format/scope** could be evaluated, preserving every unique source/index/object/checkpoint and private resource. It must prove capacity and restore fidelity explicitly and cannot assume compression, deduplication or omission of protected data. Temporarily borrowing the QA reserve would need an explicit owner decision; it is not consistent with the current requirement to preserve it and is not recommended as an implicit workaround.

C: and D: are partitions on the **same physical Disk 0** according to the controlling preflight. A backup on either partition does not protect against physical-disk failure, loss or compromise. The owner's existing-disks-only choice is respected; no external destination is assumed.

**Required next approval:** none requested for execution, because no sufficiently safe capacity plan is demonstrated. Any future cleanup needs a new exact-path, owner-reviewed approval after provenance, link/hard-link, protected-content and live-use checks. Backup, restore scratch creation/removal, service quiescence, migration and any build remain separate approvals. Current decision: **NO-GO for B0 capacity preparation execution; discovery complete, no cleanup performed.**
