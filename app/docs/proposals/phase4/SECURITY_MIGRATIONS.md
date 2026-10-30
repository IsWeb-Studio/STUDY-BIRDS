# Phase 4 — isolated security migration proposals

21 October 2026. **Router plan A was subsequently approved and completed locally; B/C remain PROPOSED.** Planning baseline was 15 affected entries / 2 moderate production Router entries. The completed Router migration yields 13 development-tool entries / zero production findings; see [the tested migration](../../REACT_ROUTER_UPGRADE_20261021.md). Existing applicability details remain in `PHASE2_SECURITY_REVIEW.md` and `PHASE3_DEPENDENCY_PLAN.md`. Approval for Router does not approve the other major migrations.

## Isolation and acceptance common to all three plans

After approval, preserve the then-current source/lock/configuration, check disk space, and create a unique private evaluation folder per migration under `.git/security-migration-evaluations/<unit>-<timestamp>`. Copy only the reviewed website source/assets/manifests/lock/config examples with hashes; exclude real environment files, signing files, generated output and node_modules links. Install dependencies into an ordinary isolated node_modules directory, never through the existing shared junction. Do not create/switch branches or change worktree relationships under the present restrictions.

Each unit gets its own manifest/lock diff, baseline and candidate test/build/audit evidence. Apply no candidate diff to the authoritative client until its scoped approval and independent tests permit it. Use an isolated content fixture for SEO builds, preserve the current test assertions, and perform browser/manual checks before publishing. Do not remove tests, use force updates, add broad overrides or run an upgrade tool directly on the working client. Preserve failed-run evidence. Recovery uses the saved individual files; do not use reset/stash or delete prior checkpoints.

## A — React Router production navigation

Reviewed candidate: `react-router-dom@7.18.4`, not the latest arbitrary major. Fresh npm metadata requires Node >=20 and React/react-dom >=18, compatible with the current Node 22.19.0 / React 18 environment at the engine/peer level. That is not evidence of behavioral compatibility or a successful migrated audit. Current official docs default to a newer Router major; do not apply its migration requirements blindly to the reviewed v7 target. Check the version-specific package source/changelog and APIs during the evaluation. [Official changelog](https://reactrouter.com/changelog).

In the Router-only evaluation folder, install the reviewed exact candidate, retain Vite/Vitest/Tailwind major versions, inspect every changed dependency entry, and reconcile only actual Router API differences. The application uses client BrowserRouter routing; do not introduce SSR, a framework-mode server or new authentication semantics as part of remediation.

Acceptance: all website tests and TypeScript/Vite/isolated SEO build pass; audit confirms the reviewed Router findings are absent; role/employee redirects, protected-route denial, Google/mobile handoff, language/query preservation, browser back and refresh work. Add malicious backslash/protocol-relative/control-character cases and valid internal/external navigation cases. Review content-derived HomePage links. Keep intentionally external destinations supported; any new URL/content policy requires a separate product decision. Produce a minimal reviewed source/manifest/lock patch before applying to the authoritative client.

Approval required: this Router-only major migration and its scoped authoritative patch after evaluation. No publication is included.

## B — Vitest developer tooling

Reviewed candidate: `vitest@5.0.5`. Fresh metadata supports Node ^22.12 / ^24 / >=26 and Vite ^6.4 / ^7 / ^8, with Node types ^22 or >=24. The current Node 22.19.0, direct Vite 6.4.5 and Node 22 types satisfy those declared ranges. Optional coverage/UI/browser peers are not permission to add all of them. Preserve current direct Vite and React plugin unless a demonstrated peer conflict requires a separately reviewed change.

Evaluate in its own source copy. Inspect migration steps from Vitest 2 through 3/4/5, worker isolation, fake timers, mock clearing/hoisting and jsdom behavior. Vitest 5 changes mock-history clearing defaults and enforces top-level hoisted mocking; investigate affected tests rather than weakening their security/session assertions. [Official migration guide](https://vitest.dev/guide/migration/).

Acceptance: all 73 current website tests remain represented and pass, including session races, API retries, document reuse and actual-generator SEO tests; new regressions cover any confirmed migration issue. Typecheck/build pass independently of tests. Audit no longer reports the old Vitest/Tinypool/nested Vite/esbuild family; inspect actual resolved paths rather than assuming a version bump fixes every finding. Keep the test runner CLI-only, with no public UI/API listener. This upgrade addresses development tooling; it is not a substitute for production Router remediation.

Approval required: this test-tooling major migration and its scoped authoritative patch after evaluation.

## C — Tailwind CSS build chain

Reviewed candidate: Tailwind 4.3.3. The current website uses Tailwind 3's PostCSS plugin plus autoprefixer, `src/app/index.css`, repository HTML/TS/TSX content paths and custom brand/shadow/background theme values, with no Tailwind plugins. Plan a PostCSS-based v4 evaluation first to minimize integration changes; verify the matching `@tailwindcss/postcss` version/peer requirements before installation. A Vite plugin transition is optional separate scope.

This migration has an unresolved browser-support decision. The [official upgrade guide](https://tailwindcss.com/docs/upgrade-guide) specifies Safari 16.4+, Chrome 111+ and Firefox 128+ for v4, changes CSS/PostCSS integration and removes/renames utility behavior. Confirm that product minimum-browser policy accepts these requirements before adopting v4. Preserve the current CSS/theme in the baseline; review upgrade-tool output only inside the isolated copy.

Acceptance: retain theme colors/backgrounds/shadows and all required classes; review preflight, borders, rings, spacing, forms and removed/renamed utilities. Capture comparable Arabic RTL/English screenshots at mobile/tablet/desktop sizes for public, discovery, auth and role-dashboard pages; check keyboard focus/contrast and error/offline states. All tests/typecheck/build pass and audit confirms the reviewed parser/glob chain is resolved. Document any visual/browser behavior change for explicit approval. Do not approve this unit merely because a static build succeeds.

Approval required: browser-support decision, this CSS/toolchain major migration, and the resulting visual/source diff. No such approval has been inferred.

## What was actually done in Phase 4

Read plans and current package/configuration, rerun read-only audit/compatible dry-run, and inspect published target engine/peer metadata and primary documentation. No migration installation, package/lock change or dependency-junction modification was performed. Future candidates must be reverified at implementation time; metadata compatibility alone is not independent testing.
