# Study Birds — workspace organization audit

2026-10-22. **AUDIT ONLY. No migration or archive operation is authorized.** The only intended write is this requested report. No project directory, Git/index/worktree/source/configuration/link, environment variable, service or database was changed. No build, cleanup, deployment, installer or network operation was performed.

## Findings that control any organization plan

The authoritative application is **`D:\work\studybirds_app\study_birds_app-main`**, independent `aboodsiaj2/fsfs` repository. Current selected website and backend are **`D:\work\studybirds_session_release\client`** and **`...\server`**, within **one shared Git worktree**, not independent repositories. Deployment `...\app` is the separately maintained Phase 7/8 QA/release Flutter input and must remain protected; it is not interchangeable with the authoritative app.

Three obstacles make ordinary folder consolidation unsafe:

1. `studybirds_app` is itself an older repository on `abood-changes` and tracks **515 paths under the nested active app**. The nested app has its own `.git`. Parent staging/unstaged work overlaps the active filesystem. Moving the child away or archiving the parent would change the parent's tracked tree and could strand unique staged work.
2. `studybirds_web\.git` owns multiple D **and C** worktrees. It also owns the shared backend dependencies. It is an active Git/dependency owner even though its source checkout is not the selected website/backend.
3. Active website `node_modules` points into the authoritative app's **`.git\router-20261021\candidate\node_modules`**. That private-looking checkpoint is an active dependency owner. Moving/archiving it or its owning app breaks the website.

The safest immediate organizational target is **one multi-root workspace view with five clear labels**, while preserving physical paths. A physical five-folder structure needs a separate Git-ownership decision and staged migration; it cannot be achieved by simply moving the two selected web/API subdirectories.

## Method and limits

Inventoried all **22 Study Birds-related top-level items** under `D:\work`, including hidden files. Collected metadata/sizes without following junctions/symlinks. Read Git HEAD/branch/status/common-directory/worktree relationships with optional locks disabled. Compared selected source-tree relative paths and SHA-256 values, including uncommitted working files; no secrets or credential values are reported.

Source comparison scope: Flutter `lib`, `test`, `integration`, `tool`, `tools`, Android app source, pubspec/lock; backend/frontend `src`, `tests`, `scripts`, package manifest/lock. Skipped dependency/build/Git folders, links and fixture folders; excluded secret/provider-credential filenames. This is not every asset/platform file, nor proof of semantic equivalence or archive completeness. “Different” means bytes differ, not necessarily unique functionality; “only here” means path absent in the selected comparator, not proof the feature is absent elsewhere.

Reference discovery examined 4,763 bounded text/config/doc files across selected roots and protected QA setup, reporting path references only. Historical docs/checkpoint references are distinguished from operational links. A bounded local scan cannot prove absence of external editor sessions, scheduled tasks, hosted deployment settings or references on another computer. No hosted configuration was accessed.

## Every top-level item: purpose, classification and future placement

All paths below are directly under `D:\work`. Sizes are logical bytes, including ordinary descendant Git/output files but **excluding linked targets**. Nested app contents are already included in its parent's size; do not count them twice. Live QA sizes may vary. Future locations are proposals, not permission to move.

| Current absolute path | Logical size | Purpose / evidence | Safety classification | Proposed future location and hold |
|---|---:|---|---|---|
| `D:\work\studybirds_app` | 8,675,761,710 B | Legacy parent repository; contains active nested app, staged work, release APK, tracked ZIP and checkpoints | SHARED OR EXTERNALLY REFERENCED | Keep now. Eventually retain parent history/unique work in `archive/legacy-parent-repository`; extract `mobile-app` only after overlapping Git ownership is resolved |
| `D:\work\studybirds_session_release` | 759,637,995 B | Selected website/backend plus protected QA Flutter input; detached shared worktree | ACTIVE / REQUIRED | Keep now. Future web/API repository container plus separately preserved QA Flutter; no raw subfolder moves |
| `D:\work\studybirds_web` | 1,497,085,802 B | Common Git owner, shared backend dependencies, nested gitlink, old APKs | SHARED OR EXTERNALLY REFERENCED | Keep now. Future managed repository/dependency infrastructure; not an obsolete folder |
| `D:\work\studybirds_qa_phase7` | 217,452,817 B | Running isolated MongoDB/backend resources, storage/mail/TLS and old manifest evidence | ACTIVE / REQUIRED | Keep exact path now. Future logical `qa-testing`; any physical move requires controlled service/data migration and separate approval |
| `D:\work\studybirds-stories-release` | 24,542,462 B | Detached worktree with 3 dirty backend files | SHARED OR EXTERNALLY REFERENCED | Preserve as active pending-work worktree; possible `archive/pending-work/stories` only after source recovery and Git-aware relocation approval |
| `D:\work\studybirds_islam_google_password_fix` | 322,432,486 B | Registered worktree; 104 tracked changes, 51 untracked files and unique source paths | SHARED OR EXTERNALLY REFERENCED | Preserve as pending-work worktree; future `archive/pending-work/google-auth` only after owner triage/integration |
| `D:\work\study-birds` | 785,960,445 B | Clean older independent STUDY-BIRDS checkout; differing source and four APK copies | HISTORICAL / ARCHIVE CANDIDATE | `archive/checkouts/study-birds`; conditional whole-repository preservation, no deletion or artifact omission |
| `D:\work\studybirds-security-release-20261017-mobile` | 741,451,210 B | Clean older fsfs release checkout; two release APK copies | HISTORICAL / ARCHIVE CANDIDATE | `archive/releases/20261017-mobile`; retain source/history/signing context and APK provenance |
| `D:\work\studybirds-security-release-20261017-web` | 330,261,306 B | Clean older STUDY-BIRDS release checkout, own dependencies/nested historical copies | HISTORICAL / ARCHIVE CANDIDATE | `archive/releases/20261017-web`; after source/reference/restore review |
| `D:\work\_git-backup-20261013` | 34,503,108 B | Ref bundles, tracked patches, untracked TGZs, stash patches, removed-tree recovery | ACTIVE / REQUIRED | Preserve; later `archive/recovery/20261013` only after byte-hash/restore validation; not cleanup material |
| `D:\work\.studybirds-email-cdp` | 78,870,824 B | Browser/CDP session profile; may contain credentials/cookies | UNKNOWN / NEEDS REVIEW | Keep private and in place; future private tooling area only after owner retention/session review, never public archive |
| `D:\work\.studybirds-email-preview-profile` | 9,569,532 B | Browser preview profile | UNKNOWN / NEEDS REVIEW | Same private-session hold; no proof of disposability |
| `D:\work\.studybirds-email-preview-profile-desktop` | 6,424,254 B | Browser preview profile | UNKNOWN / NEEDS REVIEW | Same private-session hold |
| `D:\work\.studybirds-email-preview-profile-mobile` | 11,681,368 B | Browser preview profile | UNKNOWN / NEEDS REVIEW | Same private-session hold |
| `D:\work\.studybirds-email-preview-profile-mobile2` | 6,424,243 B | Browser preview profile | UNKNOWN / NEEDS REVIEW | Same private-session hold |
| `D:\work\.studybirds-mobile-audit-release.log` | 16,694 B | Historical audit/release log, contents not reviewed for sensitivity | HISTORICAL / ARCHIVE CANDIDATE | `archive/audit/20261017/logs`, private retention review first |
| `D:\work\.studybirds-security-backend-release.log` | 316,222 B | Historical security/backend release log | HISTORICAL / ARCHIVE CANDIDATE | Same private audit archive; retain if needed as release evidence |
| `D:\work\.studybirds-security-files.json` | 2,456 B | Audit/recovery inventory metadata | HISTORICAL / ARCHIVE CANDIDATE | `archive/audit/20261017/manifests`, preserve alongside patches/logs |
| `D:\work\.studybirds-security-mobile.patch` | 40,641 B | Patch affecting 10 auth/network/security/test paths | HISTORICAL / ARCHIVE CANDIDATE | `archive/patches/20261017`; do not discard until covered-work proof and recovery checks |
| `D:\work\.studybirds-security-web.patch` | 133,761 B | Patch affecting 37 app/web/API paths | HISTORICAL / ARCHIVE CANDIDATE | Same patch archive, preserve complete file |
| `D:\work\.studybirds-security-uploads-extra.patch` | 2,159 B | Patch affecting admin-agent and partner controllers | HISTORICAL / ARCHIVE CANDIDATE | Same patch archive; application/supersession not proven here |

## Git repositories, branches and exact HEADs

Counts are porcelain path entries: staged/unstaged combinations count once, not “features.” Untracked counts include reports/tests. Snapshots were taken before this new report.

| Repository/worktree | Branch | HEAD | Tracked changes / untracked files | Ownership |
|---|---|---|---:|---|
| `studybirds_app/study_birds_app-main` | `main` | `3e31e19c5343170056e6d7559c59bfb891f2c624` | 16 / 76 | Independent `aboodsiaj2/fsfs` |
| `studybirds_session_release` | detached | `e9060536e8dc7a70150da9c42d6dfac901713553` | 49 / 63 | Common Git at `studybirds_web/.git`; `aboodsiaj2/studybirds_web` |
| `studybirds_web` | `main` | `f42dc7a0edb9630a8d24f1800191a9de06856cea` | 9 / 0 | Main/common owner of seven worktrees |
| `studybirds_app` (parent) | `abood-changes` | `6bae3a11f6f955339f996487044b5b2a9b95b64c` | 313 / 92 | Independent `aboodsiaj2/studybirds_app`; overlapping tracked child |
| `study-birds` | `main` | `a1da3390c797f485141b1aabf79cb200d43231d4` | 0 / 0 | Independent `IslamOsman1/STUDY-BIRDS` |
| `studybirds-security-release-20261017-mobile` | `main` | `fa75e05910ae1ef003acdd9303bb8b22dfde8aaa` | 0 / 0 | Independent `aboodsiaj2/fsfs` |
| `studybirds-security-release-20261017-web` | `main` | `a6f722636dbf48b25baef6e041ca0c44f62a05d4` | 0 / 0 | Independent `IslamOsman1/STUDY-BIRDS` |
| `studybirds-stories-release` | detached | `a5b118ab394546e487fe2eb3dbf7436188f1a375` | 3 / 0 | Shared `studybirds_web/.git` |
| `studybirds_islam_google_password_fix` | `fix/islam-google-password` | `4fed84c56c6f825558d781dbb80fe10818e1daa0` | 104 / 51 | Shared `studybirds_web/.git` |
| `studybirds_web/monorepo` | `main` | `0e85f587665069a962ea39619892447edcabb16d` | 1 / 0 | Independent `IslamOsman1/STUDY-BIRDS`, embedded as staged gitlink |

The nested `monorepo` is index mode **160000** at commit `0e85f...`, with parent status `AM monorepo`; its own dirty file is `study_birds_app-main/test/flutter_test_config.dart`. The web owner's other eight changed paths are staged Gradle metadata under `study_birds_app-main/android/.gradle`. They are tracked/staged even if generated-looking; do not clean or reorganize them as caches.

Registered external worktrees must also be preserved if their common owner ever moves:

- `C:\Users\Abood\studybirds-claude`, `claude-assistant`, `c1ae0df6299f16442372867de6e5d759bca1fb0b`.
- `C:\Users\Abood\studybirds-email-refresh`, `email-branding-refresh`, `aac8419adac77d6fb2ee2e5ad7dd53c9eed69d7c`.
- `C:\Users\Abood\studybirds-wink`, `wink-game`, `e0aff5b59fe670f04cdd1057acf420ae2edc3d14`.

All three existed and were clean in this snapshot. Clean status does not mean their branch commits are merged. No remote fetch/ancestry reconciliation was performed. They share the same common owner as the three D worktrees and main checkout; raw Explorer moves can break `.git` pointers/registrations.

## Source comparison and unique-work holds

Selected comparator sizes: Flutter **365 scanned files**, backend **345**, website **252**. Summary counts are `same / different shared paths / only in compared copy / only in selected comparator`.

| Compared source | Flutter | Backend | Website |
|---|---|---|---|
| `study-birds` | 154 / 133 / 0 / 78 | 160 / 77 / 0 / 108 | 199 / 34 / 0 / 19 |
| `security-release-20261017-mobile` | 191 / 158 / 0 / 16 | — | — |
| `security-release-20261017-web` | 188 / 161 / 0 / 16 | 267 / 52 / 0 / 26 | 234 / 12 / 0 / 6 |
| `studybirds-stories-release` | 70 / 276 / 0 / 19 | 221 / 82 / 0 / 42 | 223 / 20 / 0 / 9 |
| legacy `studybirds_app/server,client` | — | 113 / 84 / 0 / 148 | 174 / 44 / 0 / 34 |
| `studybirds_islam_google_password_fix` | 83 / 119 / 41 / 163 | 106 / 91 / 1 / 148 | 94 / 121 / 30 / 37 |
| deployment `studybirds_session_release/app` | 203 / 160 / 38 / 2 | Selected | Selected |
| retained `studybirds_web/app,server,client` | 170 / 127 / 0 / 68 | 186 / 108 / 0 / 51 | 197 / 43 / 0 / 12 |
| nested `studybirds_web/monorepo` | 83 / 120 / 41 / 162 | 104 / 81 / 0 / 160 | 161 / 51 / 0 / 40 |

These are not byte-identical duplicate checkouts. Specific work to preserve:

- **Authoritative app:** uncommitted notification, journey/chat/story-viewer tests and UI changes; untracked notification preference code/tests, Phase 1–8 reports and checkpoint evidence. Do not replace it wholesale with deployment `app`.
- **Deployment QA app:** 38 scanned paths absent from the authoritative comparator, including QA configuration/TLS client, QA tests, native QA activity/manifests/backend and new diagnostic controller core/tests. Earlier approved correctness patches and QA preparation are meaningful state. Primary has two scanned paths absent from deployment; retain both sides until an explicit parity decision. Existing fullscreen-design differences remain a product decision, not a folder-cleanup issue.
- **Stories worktree:** `server/src/routes/storyRoutes.js` (7 additions/13 deletions), `server/src/utils/mediaMaintenance.js` (13/5), `server/tests/stories.test.js` (1/0) differ from its HEAD. This is unsaved integration work even though no new filenames are unique in the comparison.
- **Google/password worktree:** 41 Flutter-only paths include `lib/connected/*` and older repository layout; 30 website-only paths include `AppErrorBoundary`, `AuthShell`, `GoogleAuthFlow`, `BrowserAlerts`, `JourneyRequirements`; backend-only `tests/webParity.test.js`. Some may be older alternative designs or renamed equivalents. Preserve and review intent rather than automatically porting or deleting them. Its 104/51 dirty/untracked entries prove it is not a disposable clone.
- **Parent repository:** 313 changed entries include staging-only and `MM`/`AM` combinations, plus backend edits; `study_birds_app-main.zip` is staged and about **2,113,041,483 bytes**. The archive itself is protected recovery/source material, not a safe storage candidate. Git index versions may contain work different from both HEAD and the nested working tree; a future recovery plan must preserve index blobs as well as files.
- **Nested historical copies:** `STUDY-BIRDS-main/server` samples contain 136 scanned files with 52 matching/84 differing from selected API; client samples 199 files with 128 matching/71 differing. Similar counts across copies are not a byte-for-byte whole-tree proof. No archives were extracted or declared redundant.
- **Backups/patches:** `_git-backup-20261013` includes refs bundles, tracked patches, untracked TGZs and stash patches. Loose security patches affect 10, 37 and 2 paths respectively. Their coverage/supersession and restore completeness were not proven; preserve complete bytes and associations.

## Operational reference graph: must stay put now

1. **IDE workspace:** authoritative `.vscode/StudyBirds.code-workspace` selects the nested app via `..` and API/website via `../../../studybirds_session_release/server|client`. It already provides a single logical view without moving source; any later physical change needs deliberate relative-path updates.
2. **Dependency junctions:** deployment `server/node_modules` and stories `server/node_modules` -> `D:\work\studybirds_web\server\node_modules`; deployment `client/node_modules` -> `D:\work\studybirds_app\study_birds_app-main\.git\router-20261021\candidate\node_modules`. Do not archive either owner or install through a shared link casually.
3. **App build/cache junctions:** authoritative `build` and `.dart_tool/flutter_build` -> `C:\Users\Abood\AppData\Local\StudyBirds\build-cache\study_birds_app-main\...`. Leave both link and target intact. Changing the repo path affects generated absolute paths and helpers even though the link target is on C.
4. **QA processes:** MongoDB PID **21696** references `studybirds_qa_phase7`; Node PID **23368** references both `studybirds_qa_phase7` and `studybirds_session_release`. These are direct active-use indicators. No services/processes were changed. Audit subprocess command-line matches were not treated as evidence of an external consumer.
5. **QA path configuration:** selected backend `qa.local.env.example:4`, `scripts/qa-provision.cjs:9` reference `D:\work\studybirds_qa_phase7`; `tests/qaLocalConfig.test.js:7` references the primary `.git/phase7-20261021` fixture. DB/mail/storage/TLS/private account state remains protected at its current root; no secret values were output.
6. **Phase 8 output location:** deployment `android/build.gradle.kts:16`, source test and controller constant select `C:\Users\Abood\AppData\Local\StudyBirds\qa-diagnostic-phase8\gradle-build`. Four prepared child directories and prior D `android-build` evidence must stay distinct. QA resources false, pending CA, default-deny gate and local telemetry code are not organization knobs.
7. **Generated/test references:** both app copies' iOS ephemeral environment files contain their current absolute source paths; integration tests reference historical `D:\Temp\study-birds-*` tools. Generated plugin/package configs can also carry absolute Pub/project paths. A migration needs approved regeneration/validation later; do not blanket search/replace snapshots or secrets now.
8. **Tooling/evidence:** primary `.build-tools/audit-server-repros.cjs:4` references stories worktree; other `.build-tools` release/audit helpers reference `studybirds_web`. Phase 7/8 recovery snapshots and evidence extensively reference the selected/current paths. Historical records should remain immutable with an explicit old-to-new mapping, not be rewritten to pretend old evidence was produced at new paths.
9. **Deployment uncertainty:** local remotes differ (`fsfs`, `studybirds_web`, Islam's `STUDY-BIRDS`). Hosted build root/service/branch configuration was not accessed. Local selected working roots are not proof of current production checkout or authority to deploy. Hosting/source-root decisions require separate owner confirmation before renaming tracked web/API directories.

Thus, **keep all active/shared absolute paths now**. Historical standalone checkouts and loose logs/patches are lower-risk future archive candidates, but only after unique-work, external-reference and restore checks. Nothing is unconditionally movable today.

## Proposed final structure and phased migration

### Preferred first organization: one logical workspace, no physical movement

Expose five named workspace entries after separate approval:

```text
Study Birds workspace (IDE view, not a new repository)
  mobile-app  -> existing authoritative Flutter root
  website     -> existing deployment/client
  backend     -> existing deployment/server
  qa-testing  -> existing protected QA root + QA app/evidence references
  archive     -> a future indexed archive location, not created in this audit
```

This meets the daily “one place” goal while respecting current Git and active absolute paths. Keep a clearly labeled **QA Flutter input** reference alongside `qa-testing`; the authoritative app must not silently replace it.

### Physical target: explicit Git-layout decision needed

Safest history-preserving physical option is a single parent workspace with independent mobile repo, a **platform worktree container** holding its existing `client`, `server`, protected `app`, plus `qa-testing` and `archive`. IDE labels remain `website` and `backend`. That adds a `platform` level but avoids silently splitting the monorepo.

If exactly five physical directories `mobile-app`, `website`, `backend`, `qa-testing`, `archive` are mandatory, the owner must first choose between a controlled monorepo layout change or separate repository extraction. Renaming/moving `client` and `server` outside their common checkout would detach them from their history/configuration. Turning the whole workspace into the platform Git root risks tracking nested mobile/QA/archive data unless deliberately scoped. Splitting history or introducing root junction aliases is a separate, larger design choice; **neither is approved or implemented**. Recommend retaining the platform container rather than recreating today's nested-repository confusion.

### Safe phases, each requiring a new scoped approval

1. **Authority/recovery:** confirm selected repositories and QA app role; preserve working tree **and staged/index versions**, untracked source, refs, existing stashes, config/signing hashes and protected APKs in verified recovery storage. Reconcile parent/child tracking and the nested gitlink intentionally; no blanket staging, reset, stash or history rewrite.
2. **Pending-work decisions:** review stories and Google/auth worktree diffs and unmatched source paths. Integrate only approved features/tests with provenance; decide what remains historical. Clean standalone status is insufficient to discard branch history or release artifacts.
3. **Logical naming:** approve workspace-label/documentation updates first. This is the lowest-risk usability improvement and does not solve physical path confusion by itself.
4. **Dependency/worktree design:** inventory all seven linked worktrees and dependency consumers; approve a Git-aware relocation plan for any common owner and linked checkout together. Update dependency links only after their owners are preserved. Ordinary filesystem moves are not a substitute for worktree relocation/repair procedures.
5. **Archive lower-risk items:** approve exact archive paths and retention/privacy requirements for standalone historical repos/logs/patches/backups. Verify bytes/refs/working/index state and restore ability before any later removal of old locations. Keep browser profiles separate/private until ownership/session use is established.
6. **Active-source migration:** only after previous holds are resolved, freeze writers and validate the chosen Git layout, absolute path mapping, build/junction/IDE/config/hosting roots. Recheck production APK and security hashes, QA gate/config and all source changes before/after. Any test/build/regeneration requires its own authorization; none is included now.
7. **QA data migration last:** a separate owner-approved maintenance operation with coordinated service shutdown, consistent DB/storage backup, ACL/credential preservation, path changes and isolated validation. Never move the live db/TLS/storage tree merely to tidy Explorer. Preserve old evidence and record its historical paths.

Rollback for any future phase must be specified before execution and retain old verified data/refs until owner sign-off. No deletion approval follows from this audit.

## Capacity and protected artifacts

Latest snapshot before report: **D 7,832,629,248 bytes (~7.295 GiB)**, C **33,778,237,440 bytes (~31.46 GiB)**. No disk space was recovered by this audit. Copying the 8.68 GB legacy parent alone exceeds D free space, before other roots; broad copy-then-delete on D is not feasible. Same-volume moves normally avoid full payload duplication but do not reclaim capacity and can still break Git/services/absolute paths. C relocation requires explicit storage and link planning and competes with future VM/build space; it is not automatically approved.

Preserve all discovered APK/AAB deliverables: selected deployment has two 320,844,144-byte debug APK copies; old web checkout has two 309,551,263-byte APKs; mobile release checkout has two 215,536,654-byte release APKs; parent `releases/StudyBirds-1.0.13.apk` is 215,716,846 bytes; `study-birds` has four debug/release copies. Same size/name does not establish equivalent signing/provenance. Do not deduplicate them during organization.

Primary `.git` Phase 7/8 checkpoints, Router dependency candidate, controller recovery records, owner cleanup audit and historical D manifest evidence are required, not clutter. Previously deleted generated caches are not permission to delete anything else. Browser profiles, logs and QA contents require privacy-aware handling; public Git/archive exports must exclude credentials and personal data.

## Required owner decisions / audit conclusion

Essential now: nested fsfs mobile repo, selected platform worktree with QA app, common `studybirds_web` owner/dependencies, live QA root, pending stories/Google worktrees, legacy parent/index recovery and Phase 7/8 checkpoints. Historical standalone release checkouts and loose audit/patch material **appear suitable for eventual archiving**, not deletion; their differently hashed source and release evidence must be retained. Browser profiles and external deployment references remain uncertain.

Explicit approvals needed: logical labels versus exact physical five-folder design; staged/index/untracked recovery scope; pending-work integration; any Git-aware repo/worktree/link relocation; exact archive destinations/privacy/retention; hosting-root/config updates; and a separately scheduled QA service/data migration. No move/rename/copy/delete, source reconciliation, build, partition change or deployment is authorized by this report.

Post-audit integrity: **139/139 protected file hashes** match the Phase 8 preparation reference. Primary app, selected deployment and common web owner's HEAD/index/worktree registrations remain unchanged against their recorded baseline. The new audit report is an expected untracked document; no project directory was created or migrated.
