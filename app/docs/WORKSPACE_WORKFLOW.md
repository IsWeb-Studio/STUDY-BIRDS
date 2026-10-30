# Daily Study Birds workflow

## Open the correct code

Open `.vscode/StudyBirds.code-workspace` with VS Code (File → Open Workspace from File). It groups the existing Flutter, API and website folders without moving them or creating a repository. Its three relative folder paths were checked on this machine. If the folder layout changes later, update this file deliberately.

- Flutter: `D:\work\studybirds_app\study_birds_app-main` — independent fsfs repository.
- API: `D:\work\studybirds_session_release\server`.
- Website: `D:\work\studybirds_session_release\client`.
- API and website share one Git worktree rooted at `D:\work\studybirds_session_release`; they are not separate repositories. Its sibling `app` is a release copy with documented differences, not the primary Flutter folder.

Do not open `D:\work\studybirds_app` as the application root: it is an older parent repository that also tracks files inside the active app directory. Never stage that entire parent directory. Before Git work, check `Get-Location`, `git rev-parse --show-toplevel`, `git status --short`, `git branch --show-current` and `git remote -v`. Stop if the root is not the intended repository.

## Start development

Use separate terminals for Flutter, API and website. Each terminal's current directory matters.

```powershell
# API: prepare a local development .env first; never reuse production DB settings.
Set-Location D:\work\studybirds_session_release\server
npm run dev

# Website:
Set-Location D:\work\studybirds_session_release\client
npm run dev

# Android emulator app, explicitly pointing to that local API:
Set-Location D:\work\studybirds_app\study_birds_app-main
& C:\src\flutter\bin\flutter.bat run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
```

The API defaults to port 5000, Vite to 5173. The Flutter default without a define is the hosted HTTPS API; hot reload cannot change the define. Use the current Flutter 3.47.5 installation, not the second SDK under the user directory. See `DEVELOPMENT_SETUP.md` for prerequisites, private environment names and device-specific notes.

The server node_modules still uses its existing shared junction. After the approved Router migration, the selected client's node_modules points to `D:\work\studybirds_app\study_birds_app-main\.git\router-20261021\candidate\node_modules`, an ordinary isolated installation matching its current lockfile. The previous client junction is preserved at `.git/router-20261021/previous-client-node_modules-junction`; its original `studybirds_web` dependency target and other worktree links are untouched. Actual selected-client tests/build passed against the new link. Do not install through a shared/active link without reviewing the affected tree; use a fresh isolated candidate for another approved dependency migration. Keep the Router candidate dependency directory while the client points to it. It is an active dependency owner, not a cleanup candidate.

## Test and build

```powershell
# Flutter root:
& C:\src\flutter\bin\flutter.bat pub get
& C:\src\flutter\bin\flutter.bat analyze
& C:\src\flutter\bin\flutter.bat test
& C:\src\flutter\bin\flutter.bat build apk --debug
.\tools\build_release.ps1

# API root, after installing test dependencies and preparing a local MongoDB binary:
$env:STUDY_BIRDS_TEST_TOOLS = "$env:TEMP\studybirds-session-tests"
npm test
# Or focus a recovery regression:
npm test -- tests/recoveredParity.test.js

# Website with an installation matching its lockfile:
npm test
npm run build
```

Historical website validation root `.git/audit-20261021/client-validation` retains Router 6.30.6 and is now also a negative-control fixture; it no longer matches the selected Router manifest. The current approved Router candidate is `.git/router-20261021/candidate`, with test/build/audit evidence and matching dependencies; the selected client itself was also tested/built after application. Keep authoritative edits in `D:\work\studybirds_session_release\client`; private source copies are evidence, not additional authoritative repositories. Compare source/config/lock hashes before reusing private-copy results. `npm run build` includes SEO generation and can read the configured API; validation uses an explicit isolated content fixture rather than hosted content.

On a busy machine, run the API integration suite after Flutter compilation/testing finishes; starting many MongoDB processes during heavy compilation can exceed test-binary startup deadlines. Do not increase deadlines or suppress assertions to hide failed runs. Read the first failure and rerun in a controlled environment.

The release helper keeps source on D and generated caches on C through existing junctions. Check free space on both drives. Never delete their targets as old duplicates. iOS builds require macOS/Xcode; Windows test success is not iOS verification.

## Branches, releases and backups

The app is currently on `main`. The deployment worktree is currently detached at its release commit. Phase 1 and Phase 2 changes are uncommitted: review and preserve them first. **Do not switch branches, stash or commit the old copies as part of cleanup.**

When the owner approves preparing a feature branch, use a unique descriptive name such as `fix/alumni-scholarship-parity` with `git switch -c ...` from the intended repository and verified starting commit. This preserves history; it does not push or deploy. Do not reuse branch names already attached to other worktrees. Prefer an intentional Git worktree for parallel work over copying a project folder; keep one documented purpose and owner per worktree.

Treat fsfs Flutter and the deployment repository's `app` as separate release inputs until `DEPLOYMENT_PARITY_REPORT.md` is resolved. Port reviewed features and their tests, not whole directories. Never copy signing keys, `.env`, generated iOS/Android files or local SDK paths into release source. Record application version/build number, app commit, server commit and validation results for each release. Push/deploy needs a separate authorized release action; Phase 2 forbids both.

Private local recovery checkpoints:

- Phase 1: `.git/audit-20261021/checkpoint` (includes necessary private local configuration).
- Phase 2: `.git/phase2-20261021/checkpoint`, with `checkpoint-manifest.json` and captured Git statuses. It preserves the Phase 1 uncommitted state before recovery edits.

Verify backup hashes before restoring individual files. Keep an approved encrypted off-device backup for disaster recovery; the local checkpoint shares the disk failure risk. Do not upload private checkpoints or add them to Git. Keep the old copies until their reviewed work is preserved and exact cleanup approval is given. Avoid new `final`, `new`, numbered or ZIP-extracted development copies; use the three named source folders and this workspace file.
