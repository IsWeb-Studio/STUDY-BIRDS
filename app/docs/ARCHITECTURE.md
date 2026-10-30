# Architecture

Audit baseline: 21 October 2026. This describes the inspected code, not a proposed rewrite.

## Active sources

- Flutter: `D:\work\studybirds_app\study_birds_app-main`, independent `aboodsiaj2/fsfs` repository, branch `main`, baseline `3e31e19`.
- API and website: `D:\work\studybirds_session_release\server` and sibling `client`, in the `IsWeb-Studio/STUDY-BIRDS` Git worktree, baseline `e906053`, detached HEAD.
- These sources are logically paired. No directory was relocated or repository merged during this audit. The other `app` inside the deployment repository is divergent; do not overwrite either application wholesale.

## Flutter

`lib/main.dart` initializes services and authentication routing. `lib/app_shell.dart` hosts student navigation, with role-specific screens under `lib/screens/roles`. Features live under `lib/screens`; shared configuration, repositories, services, networking, utilities and widgets live under `lib/core`. Localization lives in `lib/l10n`; native passport recognition lives in Android Kotlin code.

Screens use feature repositories, which call the shared `ApiClient`. `AuthSession` is a `ChangeNotifier` with secure session persistence, refresh coordination and role mapping. State is primarily local `StatefulWidget` state and service listeners; no new state-management framework was introduced. Account-scoped encrypted snapshots support cached rendering. Connectivity and realtime services drive recovery and refresh.

The default API is `https://study-birds1.onrender.com/api`. `API_BASE_URL` can override it at build time. Release traffic requires HTTPS and the bundled certificate trust roots. A public OAuth client ID or Sentry ingestion DSN is client configuration, not a server secret.

## Backend and website

The API uses Node.js, CommonJS, Express 4, Mongoose 8 and MongoDB. `server/src/app.js` composes routes and middleware. `server/src/server.js` loads environment configuration, listens, connects to MongoDB and starts schedulers. Routes delegate to controllers and shared utilities; Mongoose models define persistence. Authentication verifies tokens, active users, token versions and revocations. Employee sections, student support teams and document access add resource-level authorization.

Cloudinary stores uploaded media and private documents; private document access uses scoped, expiring links. Authentication and notification integrations include Google, Apple, email and push providers. Idempotency, revision checks, outboxes and transactions protect selected writes. Startup includes a service migration and background schedulers: **do not start the application against production during tests**.

The website uses React 18, TypeScript and Vite, with Vitest tests. Its `npm run build` includes SEO generation, which can read the configured API. This is separate from the API, which runs JavaScript directly and has no compilation stage.

## Boundaries and remaining debt

- `AuthSession` imports role UI and the application shell; network and connectivity services also import each other. These dependencies deserve gradual separation with tests, not an audit-wide rewrite.
- Several feature screen files exceed 1,000 lines. Split them only as individual feature changes with regression coverage.
- Flutter and the deployment repository's app differ in authentication, repositories, stories, native code and tests. Git history and filename equality alone cannot establish interchangeable releases.
- Existing worktrees depend on their common Git directory. The deployment worktree's `node_modules` junctions depend on `D:\work\studybirds_web`; deleting that parent would break development.
- Android was checked on Windows. iOS requires macOS/Xcode and a separate signing/provider verification pass.
