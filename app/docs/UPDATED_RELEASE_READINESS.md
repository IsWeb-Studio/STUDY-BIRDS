# Updated release readiness — Phase 4

21 October 2026. Local validation evidence only. This does not authorize publishing.

**Router follow-up:** the separately approved 7.18.4 migration is complete locally. Actual website tests: 100 passed; build passed; production-dependency audit: zero known findings; full audit: 13 development-tool entries. See [migration evidence](REACT_ROUTER_UPGRADE_20261021.md).

## VERIFIED

- Deployment correctness patches 01/02/03/05 are present, with hashes and reverse-apply checks matching the approved state. No replay or whole-app synchronization.
- Patch 04 remains excluded; existing card-style story viewport is retained.
- Actual deployment pub get succeeded; 444 tests passed, including deletion/rollback, viewer logout privacy, account/session switching and notification preferences.
- Actual deployment debug APK build succeeded (exit 0). Artifact: `D:\work\studybirds_session_release\app\build\app\outputs\flutter-apk\app-debug.apk`; its size/hash are in `PHASE4_VALIDATION.json`. Ready for controlled real-device QA with a QA API, not a signed production release.
- Authentication, ownership/role checks, API contracts, signing source/configuration, Git indexes/history and existing worktree relationships are preserved.
- Fresh recoverable checkpoints and private configuration hashes are retained. No source, repository or backup was deleted.

## NEEDS ATTENTION before release

- Deployment analyze remains exit 1 with 279 informational diagnostics; zero warnings/errors does not make this a clean-analysis pass. Approve and test scoped maintenance separately rather than suppress rules.
- After the approved Router migration, website audit has 13 development-tool entries (5 moderate, 6 high, 2 critical), with zero production-dependency findings. Vitest/Tailwind migrations still require separate approval. This audit result is not production certification.
- Tailwind's proposed major migration requires a browser-support and visual-compatibility decision. No CSS redesign/browser policy has been inferred.
- Existing Android future Gradle/AGP/Kotlin support warnings remain. No toolchain/signing migration or signed release has been validated here.
- Coordinated server/app release must provide the notification preference endpoints. Local tests do not deploy them or prove current hosted endpoint state.

## REAL-DEVICE QA scope

The debug build passed; the APK path and hash are recorded in the Phase 4 report/validation JSON. It permits further controlled device QA, not production certification. Choose an isolated QA API rather than treating the existing default hosted URL as a staging configuration.

On a test device, verify registration/password/email verification and Google sign-in; expiration/logout/account switching; deletion success/failure/retry and feed refresh; private viewer clearing; each preference category and offline retry; mandatory urgent/security notifications with OS permissions; background/killed-app behavior; media/video/OCR and document flows; accessibility/RTL layout. Record providers/device versions and failures explicitly. No physical-device or iOS pass is claimed by the automated suite.

## APPROVAL REQUIRED

Router was separately approved and completed locally; do not repeat it. Review the remaining [security migration plans](proposals/phase4/SECURITY_MIGRATIONS.md) for Vitest and Tailwind, with the Tailwind browser decision. Review remaining analysis/toolchain maintenance and real-device/macOS/signed-release evidence, then approve a coordinated publishing action. Fullscreen patch 04, repository cleanup and off-device sharing remain outside this phase's authorization.
