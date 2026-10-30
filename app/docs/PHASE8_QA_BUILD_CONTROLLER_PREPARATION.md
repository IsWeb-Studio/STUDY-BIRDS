# Phase 8 — diagnostic controller safety-core preparation

2026-10-22. Controlling review: `PHASE8_FINAL_QA_BUILD_APPROVAL_REVIEW.md`.

**NO-GO. Preparation core implemented and isolated tests pass; an executable build controller is deliberately not enabled or wired into Gradle.** Unresolved network/filesystem/process observation makes a permissive gate unsafe. Stage A and Stage B were not executed, and no actual permission/consumption file was issued or activated.

## Scope and recovery preconditions

The abbreviated task names in the request were resolved only from the controlling review:

- A: exactly `:app:compileQaDebugKotlin`, then `:app:compileQaDebugJavaWithJavac`, in one requested-root list.
- B: exactly `:app:assembleQaDebug`, with separate approval and verified A evidence.

Before editing, checked **139/139 protected hashes** and HEAD/index/worktree registrations against the C-storage checkpoint. No unexpected differences. Created and read back `docs/PHASE8_CONTROLLER_RECOVERY.json`, recording that both new tool files were absent, the unchanged gate hash, existing status/HEAD records and baseline-checkpoint provenance. No previous source, untracked file or recovery record was overwritten.

## Exact files added; existing configuration unchanged

1. `D:\work\studybirds_session_release\app\tool\qa_diagnostic_controller.cjs` — preparation library and status-only CLI.
2. `D:\work\studybirds_session_release\app\tool\qa_diagnostic_controller.test.cjs` — isolated Node tests, all permission/receipt I/O in memory.
3. `docs/PHASE8_CONTROLLER_RECOVERY.json` — verified narrow recovery record.
4. This preparation report.

**No Gradle gate edit was made.** The smallest safe gate change at this time is none: the existing default-deny gate remains the final backstop until real host adapters and permission authentication are reviewed. There is no token/property override, alternate launcher, Gradle command or subprocess-launch implementation in the new CLI. Its output is unconditionally `decision=NO-GO`, `launchEnabled=false`, native exit code **2**, regardless of caller-provided flags. The existing QA gate still contains `check(!apkWork)` and the release-variant filter.

This is not a claim that a complete runnable controller or monitored gate handshake has been delivered. The core implements and tests the validation/consumption semantics separately; host enforcement and activation remain explicit blockers rather than fabricated capabilities.

## Implemented safety semantics

- Exact fully qualified roots, stage ordering, fixed canonical C root and exact pending defines; reject abbreviations, extra roots, release/install/other stage, other output paths, verified-resources=true, altered CA/API and extra defines.
- Exact source/config hash-map equality; reject changed/missing/unreviewed hash entries. Test maps are synthetic fixtures, **not approval of the real project**. A trusted actual-source sampler and authenticated reviewed manifest still need integration.
- Exact reviewed task-graph equality; reject absent graph, unexpected tasks/order, duplicates, release/install/bundle/publish/deploy tasks and production app compilation. Only the historical internal `:app:cleanMergeQaDebugAssets` clean-name prerequisite is representable, subject to exact graph approval. Nothing auto-learns task names.
- Legacy policy remains the default: **D>=8 GiB**, including conservative monitoring. The proposed C>=16/D>=6 GiB start and C>=8/D>=4 GiB monitor rules are implemented for explicit **test simulation** only; no owner-approved policy selection exists in the CLI and no policy was changed.
- Disk samples require nonnegative safe integers; missing/invalid samples fail. Sensor observations must be healthy and <=2 seconds old. Missing/stale sensors, low space, paths outside reviewed roots, unreviewed process identities/parentage and any external network event fail closed.
- Path checks use canonical Windows paths and component boundaries, not string-prefix acceptance. They are **lexical**, not a substitute for actual file identity, ACL and reparse-point inspection at execution time.

## One-use permissions: prepared mechanics, not activation

`PermissionModel` is explicitly a **model**, not an authenticated token issuer. It binds each stage permission to the request and reviewed source/config hashes. B requires its own stage permission plus matching A hash evidence and manifest/telemetry pass markers. These markers are model inputs; a trusted evidence verifier is still absent, so no real execution can rely on them yet.

`ReceiptLedger` defines the future consumption primitive: fixed receipt filename `C:\Users\Abood\AppData\Local\StudyBirds\qa-diagnostic-phase8\diagnostics\qa-spent-<32-hex-id>.json`, atomic exclusive `wx` creation, write and `fsync`, with no replacement, deletion, mkdir or retry. In-memory permission state is marked spent before persistence; persistence failure disarms the model. A second modeled process sharing the receipt store cannot reuse the ID. The receipt status is consumption, never permission to launch.

**Actual ledger disk operations were not called.** Tests use an injected in-memory filesystem; prepared C directories remain empty. A write failure/partial receipt is retained and must never be interpreted as reusable. Windows metadata durability/power-loss semantics, ACLs, reparse races, tampering and recovery of controller state are not proven by these unit tests.

Before any future build, owner approval would need to cover:

1. An authenticated owner-authority/issuance mechanism selecting an immutable reviewed request/hash/graph manifest and approved capacity policy. No issuance endpoint exists now.
2. Separate permission IDs for A and B. Consume each irreversibly before launch; failure consumes the attempt. A single permission must never cover both stages or a retry.
3. Trusted A result verification against newly generated C manifest/native evidence before B issuance; a caller Boolean is not evidence.
4. A reviewed gate/controller handshake and bounded process launcher with guaranteed disarm/restoration on success, exception, interruption and restart. The core has no launcher; `disarm()` and receipt semantics alone do not establish OS crash safety.
5. On failure, deny subsequent launch/packaging, retain partial evidence and require a new review; never auto-delete receipts, rebaseline hashes, clean outputs, kill unrelated processes or silently retry.

## Actual tests and integrity results

Command executed: `node --test D:\work\studybirds_session_release\app\tool\qa_diagnostic_controller.test.cjs`.

**11 tests passed; 0 failed/skipped.** Cases cover:

- unconditional default denial and absence of subprocess-launch code;
- unchanged Gradle deny/release filter;
- exact roots and negative variants/abbreviations/extra tasks;
- fixed output and fail-closed diagnostic config;
- source/config hash mismatch/missing inventory;
- legacy policy and proposed-policy threshold boundary simulations, invalid samples;
- exact graph and negative unexpected/production tasks;
- exclusive consumption, modeled restart/replay rejection;
- receipt write failure, spent state and disarming;
- separate B permission, absent/mismatched A evidence and post-disarm refusal;
- stale/future observations, missing sensors, disk failure, unexpected paths/process tree and DNS/network events.

The status-only CLI was run: it reported the unresolved adapters and native exit **2**, as expected. This was not a test failure or an attempted stage launch. Neither tests nor CLI invoked Gradle, Flutter, JVM compilation, Android outputs, network access or actual receipt storage.

Post-validation: **139/139 protected hashes still match**; gate hash remains `2fa29230bac7cb3795ae577e5dc1a627e57e39365f34549ec4f15f63b12b0390`; original APK remains `9638b98f111bf25b4079555f4a48029d40a4892dc12f48f407b3894b61b9ce23`. Primary/deployment/retained-web HEADs, index hashes and worktree registrations match; previous status/untracked entries remain. Production output branch, pending config/CA, QA identity/manifests/telemetry source, old D evidence and QA resources were not edited. Four prepared C directories are still empty.

Free-space snapshot: C **33,785,823,232 bytes**, D **7,832,768,512 bytes**. The existing **8 GiB D** minimum remains unmet; the proposed lower D threshold is not approved.

## Observation limitations and unresolved gaps

The monitor logic consumes observations; it does **not collect or enforce real host events**. No network sensor, filesystem write observer, process tracker, disk-sampling scheduler, approved-process stop adapter or OS containment is installed. Synthetic negative tests cannot certify these missing host capabilities.

`--offline` does not contain Flutter/Dart analytics or arbitrary build-plugin/subprocess network use. A TCP connection snapshot alone misses short-lived traffic, DNS, UDP and attribution; an empty snapshot does not prove containment. PID/parent matching needs creation-time/image/command identity to resist reuse, and unfamiliar children must stop rather than extend the allowlist. Native staging and shared cache writers still require reviewed path observations. Polling can miss brief writes/egress and disk spikes.

Because reliable external-egress control/observation is unavailable, readiness is **hard-coded NO-GO**. No caller flags can assert missing adapters into existence. No firewall, global environment or external provider changes were made or proposed as an automatic fix.

## Readiness checklist and rollback

- [x] Verified narrow recovery record; protected/Git preconditions pass.
- [x] Default-deny production/QA gate retained; no permission issued or launch capability enabled.
- [x] Core static/isolated negative tests pass without Android output or network.
- [ ] Real owner-authentication, durable permission lifecycle and trusted source/evidence verification reviewed.
- [ ] Complete A/B task graphs and exact invocation context approved; no graph was obtained by running Gradle here.
- [ ] Reliable host disk/path/process/network observation and fail-closed stop/disarm adapters implemented and verified.
- [ ] Owner approves the proposed volume-aware policy instead of the still-active D>=8 GiB rule.
- [ ] Separately reviewed minimal gate handshake and launcher implementation, with single-attempt recovery/disarm tests.
- [ ] Owner explicitly approves A, then separately approves B only after new C evidence passes; neither approval exists now.

Rollback of this preparation needs no production restore: no existing gate/config/source file was changed. Keep the new files and recovery record pending review; removing them later requires separate approval. If a future gate patch is approved, reverse only that new hunk against its verified recovery record and preserve all unrelated local work. No reset/stash/clean, receipt deletion or old-evidence movement is part of rollback.

**NO-GO remains mandatory.** The owner must approve further implementation/review of unresolved controls and the capacity-policy decision before even considering separate stage permissions. This report authorizes no compilation, packaging, assembly, installation or deployment.
