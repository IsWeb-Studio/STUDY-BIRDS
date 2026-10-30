# Maintenance and recovery

## Before a change

Check the absolute path, `git status --short`, branch, HEAD and remotes. The app uses `main`; the API currently uses a detached deployment worktree. Preserve unrelated modifications and staged changes in all other repositories. Do not change remotes, force-push, delete branches or remove a worktree's Git storage as cleanup.

Implement small changes and run focused tests first, followed by the relevant full suite. Keep SDK and CI versions aligned. Avoid global dependency upgrades and mass formatting mixed into functional changes. A passing debug APK does not certify production readiness.

## Audit checkpoint

Private recovery files for this audit are under:

`D:\work\studybirds_app\study_birds_app-main\.git\audit-20261021\checkpoint`

- `HEAD.txt` and `initial-status.txt` capture the application's starting state.
- `app.bundle` was checked with `git bundle verify`.
- `app/` contains the initial tracked files plus available ignored signing/local configuration; `manifest.json` records SHA-256 hashes.
- `backend/` contains the server's initial tracked source, manifest, commit and status.
- `server/` separately preserves available private environment/manifests from the backend.
- `client/` contains the website checkpoint created and hash-verified before its approved lockfile updates.

The app and selected backend were clean before this audit. Other dirty copies were inventoried but not edited, reset or merged. This checkpoint is local recovery protection, not an off-device backup. It contains private configuration: never commit or upload it.

To recover a file, first preserve any newer work, verify its checkpoint hash, then restore **that specific file** from `checkpoint/app` or `checkpoint/backend`. Review the diff afterward. Do not use a hard reset or blindly copy a whole checkpoint over subsequent work. For an independent history recovery, clone the verified bundle into a new empty recovery directory after choosing an approved destination. Recover ignored signing/environment files separately and privately.

## Disk space and copies

Use `DUPLICATE_INVENTORY.md` before proposing deletion. Sizes are logical file bytes, not guaranteed physical NTFS recovery. Nested entries overlap; junction targets and common worktree Git storage must not be counted twice. Never recursively remove a junction target because the link looks like a build folder. Do not remove `studybirds_web`: active dependency junctions and linked worktrees use it.

Archive unique historical work before considering removal. Preserve environment files, keystores, uploads, database exports and delivered APKs. Exact duplicate ZIPs are the lowest-risk proposal; approval is still required before deleting external files.

## Common failures

- `compileFlutterBuildRelease` is a wrapper error. Find the first Flutter/Dart/Gradle error above it; check free disk space and actual junction destinations.
- Cross-drive Kotlin incremental failures: keep the tracked `kotlin.incremental=false` and in-process execution settings unless a validated replacement is available.
- Package/SDK mismatch: invoke `C:\src\flutter\bin\flutter.bat pub get` explicitly and inspect the lockfile diff.
- Local tests cannot find MongoDB: prepare an isolated test binary and development dependencies; do not substitute a production URI.
- Stale catalogue edits: reload the record to obtain its current revision; investigate client/API versions before weakening concurrency protection.
- Sign-in or private-document problems: check safe status/error codes, verification state, session ownership and current team/resource authorization. Do not log tokens, email codes or signed document URLs.

## Release

Review diffs, tests, APK identity/signing and deployment repository divergence. This audit does not authorize production configuration changes or database migrations. Source relocation and external deletion require the exact reviewed path list and explicit approval. Keep independent website/API deployment status visible; a custom domain can serve a different frontend build from the Render URL.
