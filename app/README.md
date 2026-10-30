# Study Birds

Store preparation on 27 October 2026 uses the owner-supplied API/website source at `D:\work\studybirds_web\server` and `D:\work\studybirds_web\client`. See [store changes, deployment contracts and remaining checks](docs/STORE_SUBMISSION_PREPARATION_20261027.md). No store submission or production deployment is implied.

Flutter application for the Study Birds platform. Current version: 1.0.13+14.

The selected app source is this independent repository at D:\work\studybirds_app\study_birds_app-main (aboodsiaj2/fsfs, main). The owner-supplied current paired API is D:\work\studybirds_web\server; D:\work\studybirds_web\client contains the website. These sources remain separate; do not merge or delete older copies without comparing their unique work.

Use Flutter 3.47.5 / Dart 3.13.4 (C:\src\flutter), Java 17 and the Android SDK. The default API is https://study-birds1.onrender.com/api in debug and release; local development requires an explicit API_BASE_URL dart define.

```powershell
& C:\src\flutter\bin\flutter.bat pub get
& C:\src\flutter\bin\flutter.bat run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
& C:\src\flutter\bin\flutter.bat analyze
& C:\src\flutter\bin\flutter.bat test
& C:\src\flutter\bin\flutter.bat build apk --debug
.\tools\build_release.ps1
```

The release helper preserves source on D and uses C for generated build caches through junctions when needed. Existing signing configuration remains private. Check free space before building; do not delete junction targets as duplicate folders.

- [Development setup](docs/DEVELOPMENT_SETUP.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Audit findings and validation](docs/PROJECT_AUDIT_REPORT.md)
- [Copies and exact cleanup proposal](docs/DUPLICATE_INVENTORY.md)
- [Maintenance and recovery](docs/MAINTENANCE_GUIDE.md)
- [iOS sign-in configuration](docs/ios-social-sign-in.md)
- [Wink game](docs/wink-game.md)

Phase 2: open [.vscode/StudyBirds.code-workspace](.vscode/StudyBirds.code-workspace) for the three active source folders. See the [Phase 2 results](docs/PHASE2_FINAL_REPORT.md), [daily workflow](docs/WORKSPACE_WORKFLOW.md), [feature recovery review](docs/FEATURE_PARITY_REPORT.md), [deployment parity](docs/DEPLOYMENT_PARITY_REPORT.md), and [exact cleanup approval list](docs/FINAL_CLEANUP_APPROVAL.md).

The October 2026 audit checkpoint is private local Git metadata, not an off-device backup. No production database or external source directory was deleted or relocated.

See [local stabilization and account notification preferences](docs/STABILIZATION_20261021.md) for recovery points, concurrent-writer observation, mandatory notification policy and the remaining deployment-app differences.

Phase 3: [stabilization results](docs/PHASE3_FINAL_REPORT.md), [validation evidence](docs/PHASE3_VALIDATION.json), [release-readiness checklist](docs/RELEASE_READINESS_CHECKLIST.md), [deployment patch review](docs/proposals/phase3/README.md), and [dependency migration proposals](docs/PHASE3_DEPENDENCY_PLAN.md). Changes remain local; release/deployment and applying deployment-app patches require separate approval.

The owner-approved deployment patches 01/02/03/05 are now applied locally; fullscreen 04 remains excluded. See [the reconciliation results](docs/APPROVED_DEPLOYMENT_PARITY_20261021.md).

Phase 4 reverified the applied subset and built the actual deployment debug APK: [results](docs/PHASE4_FINAL_REPORT.md), [validation](docs/PHASE4_VALIDATION.json), [updated readiness](docs/UPDATED_RELEASE_READINESS.md), and [isolated security migration plans](docs/proposals/phase4/SECURITY_MIGRATIONS.md). No publishing action was performed.

Approved Router-only security migration: [7.18.4 results](docs/REACT_ROUTER_UPGRADE_20261021.md) and [validation](docs/REACT_ROUTER_VALIDATION.json). Actual website tests/build passed; production-dependency audit is clean. The active client dependency link now uses the tested isolated tree; preserve its owner as described in the workflow guide. Vitest/Tailwind and publishing remain separate approvals.
