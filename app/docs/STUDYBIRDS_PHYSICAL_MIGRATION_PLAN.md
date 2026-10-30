# Study Birds — reviewed-batch physical migration plan

2026-10-22. Controlling inventory: `STUDYBIRDS_WORKSPACE_ORGANIZATION_AUDIT.md`.

**PLAN ONLY. No batch is approved for execution.** No project directory, Git/index/worktree/link, source/configuration, service or database was changed. No copy, move, archive, cleanup, build, installer or deployment occurred. Only this new document was created. The target `D:\work\StudyBirds` does not exist.

## Recommended end state: physical organization plus matching workspace

Keep the selected platform worktree intact. `website`, `backend` and `qa-app` are VS Code labels for its existing children, **not three extracted repositories or duplicate root folders**:

```text
D:\work\StudyBirds\
  mobile-app\                         independent fsfs repository
  platform\                           existing selected platform worktree
    client\                           VS Code: website
    server\                           VS Code: backend
    app\                              VS Code: qa-app
  qa-testing\                         protected QA data/runtime/evidence, moved last
  archive\                            approved historical checkouts/recovery/logs/patches
  .repositories\
    platform-owner\                   active common Git/dependency owner, NOT archive
      monorepo\                       preserve nested independent repo/gitlink
    legacy-parent\                    frozen dirty parent repo/index recovery, NOT disposable
  .worktrees\
    stories-pending\                  dirty registered worktree, NOT historical archive
    google-auth-pending\              dirty registered worktree, NOT historical archive
  .private\browser-profiles\           conditional; private owner/session decision first
  StudyBirds.code-workspace
```

The extra private/infrastructure directories preserve current Git ownership and distinguish active pending work from archives. No root `website`, `backend` or `qa-app` directory/junction is recommended: they would be misleading duplicates or new link dependencies. If those must be physical root entries, pause for a separately reviewed monorepo layout change; do not split histories or create aliases implicitly.

## Revalidation and holds

Current inventory has **21 top-level Study Birds items**. The prior report's “22” label was a counting error: its actual listed items match these 21; no missing-item deletion was inferred.

| Repository (relative to `D:\work`) | Branch / HEAD | Staged / unstaged path counts | Untracked | Hold |
|---|---|---:|---:|---|
| `studybirds_app/study_birds_app-main` | main / `3e31e19c5343170056e6d7559c59bfb891f2c624` | 0 / 16 | 77 | Authoritative app; nested parent ownership and website dependency |
| `studybirds_app` | abood-changes / `6bae3a11f6f955339f996487044b5b2a9b95b64c` | 306 / 111 | 93 | 313 distinct dirty entries; staged and unstaged overlap |
| `studybirds_session_release` | detached / `e9060536e8dc7a70150da9c42d6dfac901713553` | 0 / 49 | 63 | Selected website/API/QA app; shared owner and active backend |
| `studybirds_web` | main / `f42dc7a0edb9630a8d24f1800191a9de06856cea` | 9 / 1 | 0 | Common owner, shared backend dependencies, staged gitlink |
| `studybirds_web/monorepo` | main / `0e85f587665069a962ea39619892447edcabb16d` | 0 / 1 | 0 | Nested independent repo; preserve both indexes |
| `studybirds-stories-release` | detached / `a5b118ab394546e487fe2eb3dbf7436188f1a375` | 0 / 3 | 0 | Unique uncommitted stories work |
| `studybirds_islam_google_password_fix` | fix/islam-google-password / `4fed84c56c6f825558d781dbb80fe10818e1daa0` | 0 / 104 | 51 | Unique/alternative auth/UI source, not a spare clone |
| `study-birds` | main / `a1da3390c797f485141b1aabf79cb200d43231d4` | 0 / 0 | 0 | Historical independent repo, protected APKs |
| `studybirds-security-release-20261017-mobile` | main / `fa75e05910ae1ef003acdd9303bb8b22dfde8aaa` | 0 / 0 | 0 | Historical release source/APKs |
| `studybirds-security-release-20261017-web` | main / `a6f722636dbf48b25baef6e041ca0c44f62a05d4` | 0 / 0 | 0 | Historical release source/dependencies |

App/parent untracked counts increased by one versus the controlling audit's initial snapshot because the audit report was added. These counts precede this plan's creation. No unexplained HEAD/index/worktree change was found. Index SHA-256 values were freshly read; key baseline values remain: app `7394c2812de5e975683e7b1a18a3fc73ab783b1f50087930eb9bb849e0025950`, parent `29bc47f842f7f6bb1564a5e11b14d1ffd56fea20335122307c48290ac5e65b35`, selected platform `36001c28f6c0373f6924d9936eb6a3810195d53f6d68dfbd80cc3fc0d95f2ab0`. Future execution must record all exact current index hashes afresh, not assume this snapshot is still current.

All seven common-owner worktree registrations remain: main `studybirds_web`; D stories/google-auth/selected-platform; C `studybirds-claude`, `studybirds-email-refresh`, `studybirds-wink`. External C paths stay unchanged but their `.git` backlinks must follow any common-owner move. The three linked D worktrees currently have **no index mode-160000 gitlink entries**, reducing one known `git worktree move` constraint; this must be checked again, and refusal must not be overcome with an unreviewed force/manual metadata edit.

The four standalone owners checked (legacy parent, nested fsfs, common web owner and nested monorepo) have no local `core.worktree` setting or object alternates file. This is helpful, not proof that all other absolute references are absent.

Live QA MongoDB PID **21696** and Node PID **23368** still exist. No shutdown occurred. **139/139 protected Phase 8 hashes passed**. QA gate/default-deny, resources=false, pending CA, native provider exclusions/local telemetry, old evidence and APK remain unchanged.

## Exact old-to-new map

Each destination is a proposal requiring its named batch approval. No same-name overwrite, directory merge or destination substitution is allowed.

| Existing source | Intended physical destination | Method / prerequisite |
|---|---|---|
| `D:\work\studybirds_app\study_birds_app-main` | `D:\work\StudyBirds\mobile-app` | B2: relocate entire standalone checkout including private `.git`/checkpoints and link objects; preserve parent-visible files separately first |
| `D:\work\studybirds_app` remainder | `D:\work\StudyBirds\.repositories\legacy-parent` | B2: whole standalone parent after child decoupling; preserve raw index, staged/unstaged/untracked state and historical child materialization |
| `D:\work\studybirds_web` | `D:\work\StudyBirds\.repositories\platform-owner` | B3: common-owner relocation plus supported repair of all seven worktree relationships; move nested monorepo as part of owner |
| `D:\work\studybirds_session_release` | `D:\work\StudyBirds\platform` | B4: Git-aware linked-worktree relocation as one unit, after owner/dependency repair and backend downtime |
| `D:\work\studybirds-stories-release` | `D:\work\StudyBirds\.worktrees\stories-pending` | B4: Git-aware worktree relocation preserving dirty index/files; not historical archive |
| `D:\work\studybirds_islam_google_password_fix` | `D:\work\StudyBirds\.worktrees\google-auth-pending` | B4: Git-aware worktree relocation preserving all dirty/untracked/ignored unique data |
| `D:\work\studybirds_qa_phase7` | `D:\work\StudyBirds\qa-testing` | B5 only: coordinated API/DB downtime, consistent recovery, private path/ACL updates and isolated service validation |
| `D:\work\study-birds` | `D:\work\StudyBirds\archive\checkouts\study-birds` | B6: independent historical checkout whole-unit relocation after unique-work/ref review |
| `D:\work\studybirds-security-release-20261017-mobile` | `D:\work\StudyBirds\archive\releases\20261017-mobile` | B6: whole checkout, history/source/APKs retained |
| `D:\work\studybirds-security-release-20261017-web` | `D:\work\StudyBirds\archive\releases\20261017-web` | B6: whole checkout, history/source/dependencies retained |
| `D:\work\_git-backup-20261013` | `D:\work\StudyBirds\archive\recovery\20261013` | B6: protected bundles/patches/TGZs, complete hash and restore checks |
| `D:\work\.studybirds-mobile-audit-release.log` | `D:\work\StudyBirds\archive\audit\20261017\logs\.studybirds-mobile-audit-release.log` | B6: exact-file retention/sensitivity approval |
| `D:\work\.studybirds-security-backend-release.log` | `D:\work\StudyBirds\archive\audit\20261017\logs\.studybirds-security-backend-release.log` | B6: same private evidence hold |
| `D:\work\.studybirds-security-files.json` | `D:\work\StudyBirds\archive\audit\20261017\manifests\.studybirds-security-files.json` | B6: preserve associations with patches/logs |
| `D:\work\.studybirds-security-mobile.patch` | `D:\work\StudyBirds\archive\patches\20261017\.studybirds-security-mobile.patch` | B6: preserve all bytes, no application/discard implied |
| `D:\work\.studybirds-security-web.patch` | `D:\work\StudyBirds\archive\patches\20261017\.studybirds-security-web.patch` | B6: same |
| `D:\work\.studybirds-security-uploads-extra.patch` | `D:\work\StudyBirds\archive\patches\20261017\.studybirds-security-uploads-extra.patch` | B6: same |
| `D:\work\.studybirds-email-cdp` | `D:\work\StudyBirds\.private\browser-profiles\.studybirds-email-cdp` | B7 conditional: identify owner/consumer, stop browser cleanly, preserve ACL/session data; may need to stay put |
| `D:\work\.studybirds-email-preview-profile` | `D:\work\StudyBirds\.private\browser-profiles\.studybirds-email-preview-profile` | B7 conditional; never public archive |
| `D:\work\.studybirds-email-preview-profile-desktop` | `D:\work\StudyBirds\.private\browser-profiles\.studybirds-email-preview-profile-desktop` | B7 conditional |
| `D:\work\.studybirds-email-preview-profile-mobile` | `D:\work\StudyBirds\.private\browser-profiles\.studybirds-email-preview-profile-mobile` | B7 conditional |
| `D:\work\.studybirds-email-preview-profile-mobile2` | `D:\work\StudyBirds\.private\browser-profiles\.studybirds-email-preview-profile-mobile2` | B7 conditional |

The source-parent row includes the child until B2; it is not an instruction to move/copy it twice. The nested `studybirds_web\monorepo` maps with its owner to `.repositories\platform-owner\monorepo`, retaining its own repository/index and staged parent gitlink. Existing C worktree paths, C primary build caches and C QA build output root do not move.

## Recovery design: mandatory B0, not performed

Preferred recovery destination is independent, encrypted, owner-approved storage with **at least 25 GiB free** for the bounded D inventory and verification reserve. Alternative proposal: `C:\Users\Abood\AppData\Local\StudyBirds\migration-recovery-20261022` (currently absent), with private ACLs/encryption and **>=25 GiB free before backup**. C and D share Disk 0: a C copy is rollback protection, **not independent disk-failure protection**. Owner must accept that limitation or provide another device. No encryption key or credential contents belong in public Git/reports.

For every affected repository and worktree, preserve:

- A consistent complete Git object/ref store, per-worktree metadata and **raw index**, plus its SHA-256 and `ls-files --stage` inventory. Ref bundles and ordinary diffs alone miss staging-only/unreachable/index versions; keep referenced blobs and required packs/loose objects. Do not run GC/prune/repack or create commits to simplify recovery.
- Working-file manifests/hashes, binary content, unstaged and staged diffs separately, deleted-path records, untracked and unique ignored files, stashes/refs/reflogs and nested repository boundaries. Preserve staged/working disagreement (`MM`, `AM`) exactly. Do not restore staging by `git add` or substitute a fresh checkout.
- `.git` link files and common-owner worktree metadata/backlinks; junction objects and target maps without following them during the inventory. Distinguish generated C targets left in place from irreplaceable private source/dependency owners.
- Protected APKs, original signing/environment files, private QA TLS/accounts, Phase 7/8 checkpoints and old evidence. Use private secure backup, no secret printing. Active DB files require a separately approved consistent cold backup/snapshot or supported backup procedure; a live byte copy is not a verified DB recovery.
- A machine-readable old/new path map and provenance manifest. Verify backup byte hashes and representative restore/index-object access in an isolated approved recovery area before releasing any batch. Actual backup/restore testing is not authorized now.

Freeze all writers during each affected snapshot and migration. If another writer changes HEAD/index/status, files, links, DB state or working processes between approval and action, stop and refresh the proposed batch; never silently rebaseline.

## Capacity and proposed reserves

Current free: **D 7,832,580,096 bytes (~7.295 GiB)**; **C 33,783,152,640 bytes (~31.46 GiB)**. Prior no-link D inventory totals **13,502,571,495 bytes (~12.575 GiB)** across 21 roots, counting the nested app once. These are logical sizes, not exact allocated backup requirements; QA/live files and new docs vary.

- A full second D copy is **not feasible**. Even duplicating the 8,675,761,710-byte legacy parent exceeds current D free. No move may fall back silently to recursive copy across volumes or follow links into C/shared owners.
- Planning recovery allowance: inventory plus 30% = **17,553,342,944 bytes (~16.35 GiB)**, before any additional C-only private resources. C would retain roughly **15.1 GiB** after that estimate; an 8 GiB reserve fits, but future VM/build capacity competes with it. The true manifest must include necessary external private data/ACL metadata and be measured before approval. Reserve >=25 GiB available at the backup destination; stop if the actual requirement exceeds the approved budget.
- Same-volume whole-directory renames should not duplicate payload, but metadata/index copies, recovery manifests and overlap materialization still need space. Proposed migration-only precondition: **D>=4 GiB free before each batch**, with **<=256 MiB approved temporary D growth** for B2 materialization/metadata and explicit monitoring. This is not a change to any QA build capacity policy. Current D meets that proposed reserve; it does not guarantee future capacity.
- Parent-visible child materialization measured now: **515 tracked + 92 untracked paths, 607 existing regular files, 18,887,155 bytes (~18.01 MiB), no missing/link entries**. The child's private `.git` is ~1.54 GB; duplicating that store just to retain the parent's visible file state is unnecessary. The exact 607-file set must be frozen/revalidated at execution, including this new plan if it becomes visible to the parent. Do not infer permission to omit other unique ignored files from full recovery.
- No compression ratio, cleanup saving, deduplication or unlinking of protected artifacts is assumed. Organization itself does not increase D capacity.

## Ordered batches: separate exact approval for each

### B0 — private recovery and path manifests

**Approval:** exact backup destination, privacy/encryption/ACL procedure, file/index/object scope, writer/QA shutdown window where needed, measured capacity and restore validation. No source relocation yet.

**Preflight:** absent canonical destination, ordinary ancestors, correct volume/owner/ACL, capacity budget; all refs/indexes/status/links/current protected hashes match the approved snapshot. Back up without dereferencing junctions into unrelated stores; separately include needed dependency owners. Verify restores and raw-index blobs, not just archive creation.

**Rollback:** production paths remain unchanged. Preserve incomplete recovery material privately and diagnose; do not delete or repeat into an existing destination without another approval. B1–B7 remain blocked until B0 evidence passes.

### B1 — establish physical container and maintenance boundary

**Approval:** create only the exact new workspace/infrastructure/archive parents needed by reviewed later batches, plus the approved maintenance controls. Root is absent now. Do not initialize a new Git repository at `StudyBirds`.

**Preflight/verification:** no case-insensitive collision, path/reparse/ACL/volume checks; directory allowlist; no inherited public exposure of private archives. Confirm new parents are empty and all old roots untouched.

**Rollback:** leave empty containers for owner review; no automatic directory removal. This batch alone does not move source or change VS Code.

### B2 — decouple and relocate authoritative mobile + legacy parent

**Approval:** exact two destination paths and **file-level historical materialization** of the parent's overlapping paths, dependency-junction updates and active consumer downtime. This is a larger coordinated operation, not a raw child rename.

**Preflight:** B0 restore proof; freeze app/editor/website/dependency writers; inventory both raw indexes, all parent-visible child paths and all child's private/untracked/ignored data. Review that 607-file materialization is within budget and ordinary files only. Preserve missing/deleted states if the inventory changes. Stop on unknown files/links or budget drift.

**Order:** prepare verified private file-level snapshots of parent-visible paths; relocate the entire independent mobile checkout as one same-D unit, retaining its `.git`, ignored checkpoints and existing C cache link objects. Materialize **only the reviewed parent-visible historical files** back into the parent's old relative child position, preserving parent working hashes/deletions and raw index without staging. Then relocate the remaining standalone parent to `.repositories\legacy-parent`. This preserves the parent Git view without retaining a second active nested fsfs `.git`. It requires a detailed operator manifest before execution; do not invent copy rules while moving.

**Verification:** both HEADs/index hashes and branch ownership unchanged; parent's tracked/untracked statuses and bytes equivalent under root mapping; active mobile files/checkpoints identical; all unique ignored data retained at the active mobile root or approved secure recovery. Retarget selected website dependency junction from the old app `.git\router-20261021\candidate\node_modules` to the identical subtree under `mobile-app`. Preserve old-link target metadata for rollback; do not dereference/install dependencies. Preserve primary C build/cache targets.

**Rollback:** with writers still stopped, reverse whole-checkout relocations and restore only approved overlap snapshot placements, exact prior junction and indexes as recorded. Do not overwrite historical materialization or subsequent edits blindly. Stop for a new review if either destination acquired unexpected work. No reset/stash/re-add, no deletion of the old index/objects.

### B3 — relocate active common owner, repair all external relationships

**Approval:** moving `studybirds_web` as the active owner, supported Git metadata repair for all seven worktrees, shared dependency-link changes, coordinated downtime for every consumer on C and D. This is not an archive operation.

**Preflight:** lock out all Git writers/editors/test runners across the full worktree family; verify nested monorepo/index and parent staged gitlink; no missing registered worktree; preserve common metadata, per-worktree indexes and exact previous links. Inspect Git version/support and worktree constraints before action, without auto-force or metadata hand edits.

**Order:** same-volume whole common-owner relocation to `.repositories\platform-owner`; use Git-supported main/common-owner relocation repair against each registered worktree at its then-current location. Do not use `git worktree move` to pretend the main worktree is a linked worktree. Retarget deployment and stories backend dependency junctions to `.repositories\platform-owner\server\node_modules`; identify any further consumers before cutover.

**Verification:** all seven roots resolve to the new common directory, own branch/HEAD/raw index/status retained, nested monorepo still resolves correctly, staged mode-160000 entry unchanged, every dependency link resolves to byte-identical owner content. C worktrees stay at their original C paths.

**Rollback:** reverse owner relocation and supported repair for all seven, restore dependency links from the manifest and verify all raw indexes/refs. Any partially repaired family stays offline until consistent; no fetch/reset/checkout/commit or forced removal.

### B4 — relocate selected platform and pending worktrees

**Approval:** exact three linked-worktree moves and required consumer/config path edits, including API downtime and new manifest verification references. Keep the platform checkout whole; no renaming/splitting client/server/app.

**Preflight:** B3 family healthy; no submodule/gitlink or locked-worktree constraint drift; all dirty/untracked/ignored states backed up; Git supports same-volume worktree moves in current conditions. API PID 23368 must be stopped by its approved lifecycle procedure; do not terminate it without the batch's explicit downtime authorization. DB can stay put only if its own dependent process policy permits; no database move here.

**Order:** Git-aware selected worktree relocation to `platform`, then stories/google-auth to `.worktrees` destinations. If Git refuses because of a constraint, stop for a specific alternate plan; no ordinary fallback move or force. Update affected active tooling/private API launch root under the same approved batch. Historical evidence records retain original paths; current consumers use explicit mappings and new evidence rather than rewriting history.

**Verification:** common owner/registration, HEAD/branch/raw index and dirty/untracked/ignored hashes preserved for each; source/code changes remain equivalent; dependency junctions resolve; protected APK bytes now at `platform\app\build\app\outputs\flutter-apk\app-debug.apk`. New C QA output path and gate remain unchanged. Verify API from its approved new root against isolated existing QA resources only, with separate service-validation permission; no production probes.

**Rollback:** reverse each completed Git-aware worktree move and private launch-path edits in reverse order, restore old dependency mappings and registrations, verify each dirty/index state before restarting any affected service. Keep receipts and old evidence; no destructive cleanup.

### B5 — protected QA environment, last active-resource move

**Approval:** a separate maintenance/data-migration procedure with service owner, isolated endpoints, cold/supported consistent DB backup/restore, exact private settings edits, ACL/security handling, verification and downtime/rollback thresholds.

**Preflight:** stop API then MongoDB gracefully using approved lifecycle controls; verify no locks/writers, consistent recovery and available space. Preserve DB paths/keyfiles/TLS/account/storage/mail and old `android-build` evidence; no secret values printed. Do not copy a live DB directory as a substitute for a consistent backup.

**Order/verification:** relocate QA root as a same-volume unit to `qa-testing`; update only the approved private QA db/storage/mail/TLS/config/launcher paths and selected QA scripts/tests, preserving isolation and no production fallback. Start isolated DB then API under approved controls. Check data/account/document ownership and local TLS/health from the new settings without production access. All historical static evidence byte hashes stay intact under a recorded path map. Gate/resources=false/pending CA do not change.

**Rollback:** stop new writers, reverse private configuration/path relocation and restore the consistent DB snapshot only if needed and explicitly approved. Account for any writes accepted after cutover before rollback; never blindly replace newer data. Keep the old private path mapping/recovery securely. No runtime app installation follows.

### B6 — lower-risk historical archives and loose audit evidence

**Approval:** exact mapped repositories/files, retention/privacy policy, verified backup and any external-reference update. Standalone clean repos are candidates, not deletion approvals. Source differences and release APK provenance remain preserved.

**Preflight/verification:** ordinary same-volume destinations absent; all refs/index/status/unique files/ignored APKs/config protected; no active consumer or unresolved reference. Whole independent checkouts may be relocated as units with Git-aware before/after checks (not `git worktree move` for a main standalone checkout). Preserve filenames for loose patches/logs and associations; do not extract/apply or classify patch contents as already merged.

**Rollback:** reverse each exact move and path edit with hashes/refs/status verified. Keep every archive and backup until owner retention sign-off; no archive pruning, cleanup or compression is part of this batch.

### B7 — private browser profiles, optional and separately owned

**Approval:** owner confirms which browser/automation uses each profile, privacy/retention requirements, clean session shutdown and exact new launch paths. If ownership or active use is uncertain, leave that profile at its original location and document the exception.

**Verification/rollback:** preserve ACLs, session data and exact profile contents without public disclosure; never expose the `.private` area in shared Git/archive or the ordinary workspace. Reverse the profile/path change if validation fails; no profile reset, merge or credential inspection. It is acceptable for this batch to remain deferred indefinitely.

### B8 — install the final VS Code multi-root file and verify presentation

**Approval:** create `D:\work\StudyBirds\StudyBirds.code-workspace` only after active target directories exist and verified mappings pass. Adjust/deprecate the old mobile `.vscode/StudyBirds.code-workspace` in a separately approved small config edit; do not overwrite it opportunistically.

Recommended final contents (proposal only; **not written as a workspace file**):

```json
{
  "folders": [
    { "name": "mobile-app", "path": "mobile-app" },
    { "name": "platform — shared Git worktree", "path": "platform" },
    { "name": "website", "path": "platform/client" },
    { "name": "backend", "path": "platform/server" },
    { "name": "qa-app — diagnostic/release input", "path": "platform/app" },
    { "name": "qa-testing — private isolated resources", "path": "qa-testing" },
    { "name": "archive — historical, not active source", "path": "archive" }
  ]
}
```

`platform` and its child entries deliberately overlap for repository visibility and role labels; VS Code may display files in more than one root. No filesystem duplication is involved. Exposing private `qa-testing` to editor extensions/search needs owner privacy approval; prefer replacing that entry with a non-sensitive QA documentation view if extensions are not trusted. Do not add `.private` browser profiles or private recovery storage to the workspace. Rollback restores only the previous workspace config and labels; it does not move repositories back automatically.

## Reference changes to enumerate in each execution manifest

- Old mobile workspace relative paths (`..`, `../../../studybirds_session_release/client|server`) -> proposed final explicit paths above.
- Selected website `node_modules` -> new `mobile-app\.git\router-20261021\candidate\node_modules`; selected/stories backend junctions -> new common-owner dependency directory. No dependency install/rebuild is authorized by a move.
- Common-owner `.git/worktrees` registrations and worktree `.git` backlinks, including three unchanged C worktree addresses; nested monorepo own Git/link state.
- Primary C cache junctions remain pointed to their existing C targets; C QA output root stays unchanged. Never replace them with root aliases or whole-source junctions as a shortcut.
- Backend `qa.local.env.example`, `scripts/qa-provision.cjs`, `tests/qaLocalConfig.test.js`, private QA environment/startup scripts and dbPath/storage/mail/TLS settings. Update values privately only in their approved batch, never dump secrets.
- Primary `.build-tools/audit-server-repros.cjs` (stories path), other `.build-tools` release/audit helpers referencing `studybirds_web`, integration tool paths and iOS ephemeral/project/package metadata containing old absolute paths. Some generated metadata needs later approved regeneration; do not start builds merely to tidy references.
- Phase 7/8 current test/evidence selectors and protected-file verification adapters: use an explicit old/new map to verify identical bytes at relocated locations. Old checkpoint JSON, owner audit records and historical logs must not be rewritten or silently re-hashed as if created elsewhere.
- Original signing/local SDK paths, relative server upload/storage paths, IDE launch/tasks, shell shortcuts and user automation must be individually inventoried before cutover. Hosted Render/GitHub build-root/service configuration remains **unverified**; no deployment edit is included. A source-root change requiring production configuration blocks that affected batch pending owner review.

## Universal stop conditions and approval boundary

Unexpected hash/index/ref/branch change, missing worktree, link/ACL drift, occupied destination, active writer, unreviewed source/private path change, insufficient capacity, live DB uncertainty or new consumer => **STOP that batch**. Do not broaden its manifest, force Git, rebaseline evidence or repair unrelated state. Recovery must preserve later work as well as the approved snapshot.

The owner must approve a **specific reviewed batch** with its exact paths, downtime, recovery destination, link/config edits, verification commands and rollback authority. This plan does not authorize B0 backups, creation of the target container, copying even the small overlap snapshot, Git repairs, service shutdown or the final workspace file. No QA build gate relaxation, compilation, installation or deployment is part of migration approval.

## شرح عربي مختصر

الخطة تنظّم الملفات فعليًا تحت `D:\work\StudyBirds`، مع بقاء الموقع والسيرفر وتطبيق QA داخل مستودع `platform` الواحد، وعرضها بأسماء واضحة في VS Code. مالك Git والتبعيات المشتركة يبقى بنية نشطة، وليس أرشيفًا. نقل التطبيق يحتاج أولًا حفظ فهرس المستودع الأب وملفاته المتداخلة؛ ونقل QA يحتاج توقفًا وصيانة مستقلة. مساحة D لا تكفي لنسخة احتياطية كاملة، لذلك يلزم اعتماد تخزين استرجاع آمن على C أو قرص آخر. لم يُنفّذ أي نقل؛ كل دفعة تحتاج موافقة صريحة قبل تنفيذها.
