# Development setup

## Required tools

Verified locally: Flutter 3.47.5 / Dart 3.13.4 at `C:\src\flutter`, Node 22.19.0, npm 10.9.3, Java 17, Git and Android SDK. Another Flutter installation exists at `C:\Users\Abood\flutter`; avoid switching SDKs implicitly. Use the SDK configured in `.vscode/settings.json` and CI. Python is not required by the application.

Keep the app and API as independent existing Git repositories. Do not initialize a new Git repository around them. The parent `D:\work\studybirds_app` already has a different repository and uncommitted work; run Git commands inside the intended root.

## Flutter

```powershell
Set-Location D:\work\studybirds_app\study_birds_app-main
& C:\src\flutter\bin\flutter.bat pub get
& C:\src\flutter\bin\flutter.bat run
# Explicit local Android emulator API:
& C:\src\flutter\bin\flutter.bat run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
```

The default URL is the HTTPS Render API even in debug mode. Hot reload does not change `--dart-define` values. For a physical device, use the development computer's reachable LAN address. HTTP is development-only.

```powershell
& C:\src\flutter\bin\flutter.bat analyze
& C:\src\flutter\bin\flutter.bat test
& C:\src\flutter\bin\dart.bat format --output=none --set-exit-if-changed .
& C:\src\flutter\bin\flutter.bat build apk --debug
.\tools\build_release.ps1
```

Formatting currently has a pre-existing backlog; check results do not mean files were rewritten. Format changed files deliberately rather than reformatting the whole project in unrelated work.

Android release signing uses ignored `android/key.properties` and the referenced keystore. Keep both private and backed up; never invent a replacement signing key for an existing release. Java 17 and the tracked Kotlin cross-drive cache settings are required locally.

The release helper can move **generated caches** to `%LOCALAPPDATA%\StudyBirds\build-cache` and create junctions at `build` and `.dart_tool/flutter_build`. Inspect existing junction targets before cleanup. It does not move source or signing files. The current D drive is too small to hold all generated caches; keeping source on D and temporary caches on C is intentional until more space is available. A junction does not mean its target is redundant.

## Backend

```powershell
Set-Location D:\work\studybirds_session_release\server
npm ci
# Prepare a private local .env using the variable names below.
# Point MONGODB_URI at a development database only.
npm run dev
```

Minimum database/authentication names: `MONGODB_URI`, `JWT_SECRET`, `PORT`. Integrations use `GOOGLE_CLIENT_ID`, `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET` and mail/push/provider settings. The full statically discovered variable-name inventory is in `BACKEND_ENVIRONMENT_NAMES.json`; values are intentionally absent. Review the corresponding source and deployment configuration before enabling an integration. There is no single universal .env that can safely be copied from production.

## Isolated backend tests

`npm test` runs the existing Node test suite sequentially with the network-isolation preload. A temporary local MongoDB replica set supplies the opt-in integration tests; test database URI variables are replaced, not inherited from deployment configuration. The test helper stops its replica set afterward. Individual tests also create and stop isolated local MongoDB processes.

Install development dependencies, then prepare a MongoDB test binary **before** running the isolated suite. `mongodb-memory-server-core` does not download a binary during package installation. You may provide an existing local binary via `MONGOMS_SYSTEM_BINARY`, or prefetch through the library in a deliberate setup step. During the test command, runtime downloads are disabled. Do not point the tests at production or a database containing valuable data.

```powershell
npm ci
# Optional: reuse the locally installed test-tools package during this session:
$env:STUDY_BIRDS_TEST_TOOLS = "$env:TEMP\studybirds-session-tests"
npm test
npm test -- tests/authSecurity.test.js tests/storyViewers.test.js
```

The API has no separate build or lint script; syntax checks and tests are the applicable checks. Do not run `npm run seed` as a validation command.

## Website and iOS

The sibling `client` supports `npm ci`, `npm run dev`, `npm test`, and `npm run build`. The build's SEO step may read the API. Security upgrades to its toolchain need separate compatibility work; see the audit report.

On macOS, install Xcode and the appropriate iOS tooling, resolve Flutter packages, configure the existing signing team and Google/Apple identifiers, then run `flutter build ios --no-codesign` and device authentication/upload tests. See `ios-social-sign-in.md`. Windows cannot validate Xcode builds or iOS signing.
