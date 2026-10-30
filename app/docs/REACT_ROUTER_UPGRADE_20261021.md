# Approved React Router security migration — 21 October 2026

## Outcome

The owner approved **React Router only**, first in isolation and then locally after successful checks. The selected website at `D:\work\studybirds_session_release\client` now pins `react-router-dom` and resolves `react-router` to **7.18.4**. Actual website tests and TypeScript/Vite/isolated SEO build pass. Production-dependency audit reports **zero known findings**; full audit still reports **13 development-tool package entries** (5 moderate, 6 high, 2 critical). This does not certify the application or hosted deployment as vulnerability-free.

No commit, push, deployment, source deletion, branch/history/worktree operation, credential/signing change, backend/API change or Flutter change was performed. Vitest remains 2.1.9, Tailwind 3.4.19 and direct Vite 6.4.5. Fullscreen patch 04 remains excluded.

## Preservation and isolation

Fresh source checkpoints are under `.git/router-20261021/app-final` and `deployment-final`; they preserve the complete pre-migration working state, statuses, HEADs and binary diffs with SHA-256 verified copies. Existing Phase 1–4 and approved-parity checkpoints/configuration remain intact. Initial free bytes: C 31,547,068,416; D 1,381,990,400. The isolated candidate contains 265 copied website files plus the new regression file, without real environment files or a copied dependency junction.

Installed `react-router-dom@7.18.4` with an exact version and `--ignore-scripts` into the candidate's ordinary node_modules. Compared the old and new lockfile: only root Router dependency metadata, removal of `@remix-run/router` 1.23.4, Router/DOM 6.30.6 → 7.18.4, and new `cookie` 1.1.1 / `set-cookie-parser` 2.7.2 entries changed. No unrelated lockfile package entry changed. No force/override or other major upgrade was used.

Before applying, source hashes were checked again against the checkpoint to reject concurrent edits. Applied only `client/package.json`, `client/package-lock.json` and `client/src/lib/routerMigration.test.tsx`. Existing SEO and Node type work was preserved, not reclassified as new Router work. No application route, authentication implementation, permission rule or external-link policy needed changing.

## Local runtime dependencies

The selected client's original node_modules junction pointed to `D:\work\studybirds_web\client\node_modules`, which still contains the old dependency tree. Installing through it would modify other copies. After isolated acceptance, moved **only the junction entry**, preserving it under `.git/router-20261021/previous-client-node_modules-junction`, and created the selected client's junction to `.git/router-20261021/candidate/node_modules`. The original target directory was not moved/deleted/installed into; its Router package hash remained unchanged. Existing Git worktree relationships and other dependency links remain unchanged.

Actual website commands now resolve the tested 7.18.4 dependency tree. **The candidate dependency folder is now an active local dependency owner, not disposable validation output.** Keep it while this link exists. The prior link, source checkpoint and generated website dist were preserved for coordinated recovery; do not reset Git, delete either dependency tree or restore only the manifest while leaving mismatched dependencies. See WORKSPACE_WORKFLOW for current paths. A fresh checkout/CI should install the tracked lockfile normally; the private local junction is not a production configuration.

## Independent validation

- Isolated focused suite: final **27 passed**. First run had 26 pass / 1 fixture failure because the Google button is conditional on a configured client ID. The corrected test supplies a fake ID and mocked provider result; no real Google request/configuration or production assertion was changed.
- Isolated full suite: **100 passed / 12 files**, npm test exit 0; build exit 0, including TypeScript, Vite and an empty local SEO fixture.
- Security negative control against the retained 6.30.6 validation tree: selected nine security cases produced **8 failures / 1 pass**, with 18 other tests excluded by the deliberate name filter. All the same cases pass under 7.18.4. The baseline failure log is retained and is not a target acceptance failure. No test is skipped in the final complete 100-test suite.
- **Actual selected website root:** npm test exit 0, **100 passed / 12 files**; npm run build exit 0. This verifies the local dependency link resolves the candidate correctly, rather than claiming only a private-source test pass.
- Actual `npm audit --omit=dev --json`: exit 0, zero findings. Full `npm audit --json`: exit 1, 13 remaining entries. `npm ls` for Router/Vitest/Tailwind/Vite: exit 0, approved versions verified.

Logs and exact commands are in `.git/router-20261021` and `REACT_ROUTER_VALIDATION.json`. SEO build uses the existing local fetch fixture and `VITE_API_URL=http://127.0.0.1:1/api`; it makes no hosted content request. New test mocks are file-scoped and restore environment/mocks; no security rule, test expectation or production setting was relaxed.

## Behavior tested and reviewed

The new suite exercises actual ProtectedRoute, LoginPage login/Google-success handlers and LanguageRouteSync, alongside Router browser/memory integration. It covers anonymous and wrong-role denial, employee assigned-section and account-security behavior, offline-session retry, all six role homes, encoded mobile handoff IDs and the password-setup gate. History tests exercise query/hash preservation, back navigation and a router remount at the existing history location. This is jsdom integration, not a real browser reload against hosting configuration.

Security cases reject external useNavigate targets, including backslash/protocol-relative/control-character forms, before history changes; pathname-object Links remain same-origin. Explicit HTTPS and protocol-relative string Links to intended university destinations remain supported. Current inspected programmatic navigate call sites use internal routes/role-home mappings, the language location object or numeric back; content-driven HomePage Links remain subject to Router's handling. No blanket external URL filtering or new product policy was introduced.

The [backslash navigation advisory](https://github.com/advisories/GHSA-wrjc-x8rr-h8h6) and [SSR hydration advisory](https://github.com/advisories/GHSA-337j-9hxr-rhxg) identify 7.18.0 as patched; 7.18.4 exceeds that boundary, and the selected lockfile audits no longer list these Router entries. The website remains createRoot/BrowserRouter declarative rendering; no SSR/framework server was introduced. Dependency evidence is not proof of arbitrary content-write permissions or a penetration test.

## Remaining limits

Real-browser visual/accessibility and provider-backed end-to-end checks, hosting fallback/real reload, physical devices, production accounts/data and publishing remain **NOT TESTED**. Existing automated auth/session regressions pass, but they do not perform real Google OAuth or email delivery. Vitest/Tinypool/nested Vite/esbuild and Tailwind processing advisories remain for separately approved migrations. No Flutter/backend suite was rerun for this website-only package/test change; their source and contracts remain unchanged.

The selected local website is ready for further manual QA, not automatic publishing. The historical Phase 4 report's 15/2 audit counts are superseded by the 13/0 results here. Prior reports remain snapshots. Approval for Router does not authorize Vitest, Tailwind, fullscreen design or deployment.
