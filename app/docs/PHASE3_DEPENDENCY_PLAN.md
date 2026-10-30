# Website dependency review — Phase 3

21 October 2026. Fresh lockfile audits reproduce Phase 2: 15 affected package entries (7 moderate, 6 high, 2 critical); production-only 2 moderate entries (`react-router`, `react-router-dom`). Entries include inherited advisories, not 15 independently proven production vulnerabilities. Compatible `npm audit fix --package-lock-only --ignore-scripts --dry-run --json` reports zero added/removed/changed. No vulnerability-remediation major migration, override or force upgrade was made in Phase 3.

The new Node-environment SEO regression exposed a missing build-time type dependency. Added `@types/node` 22.20.5 (`^22.20.5`, matching the Node 22 toolchain) and its `undici-types` dependency. Lockfile comparison verified these two new entries and root devDependencies were the only dependency changes; no runtime package was upgraded. Installation ran only in the ordinary isolated validation node_modules; the authoritative manifest/lock change was copied after inspection. Shared dependency junctions were untouched.

## Production priority — PROPOSED navigation migration

React Router 6.30.6 remains advisory-affected. The primary [backslash redirect advisory](https://github.com/advisories/GHSA-wrjc-x8rr-h8h6) concerns Link/useNavigate input handling. Inspected login redirects use role routes/encoded mobile request IDs; Navbar's inspected menu routes are constants. HomePage also uses content-derived `item.href`. End-to-end write permissions and all dynamic navigation inputs have not been proven safe. Do not claim the production issue is resolved by a static build or passing tests.

The [constructor injection advisory](https://github.com/advisories/GHSA-337j-9hxr-rhxg) concerns SSR hydration. Current createRoot/BrowserRouter entry is client rendered; reviewed entry/config does not enable SSR. This is a reachability limit, not removal of the dependency advisory.

Approval proposal: migrate react-router-dom to the compatible supported v7 line after reviewing upstream migration/peer requirements. npm currently proposes 7.18.4; reverify versions at implementation time. Check every role route, employee permission redirect, query/language propagation, Google/mobile login handoff, back/history and content/external links. Add cases for backslashes, protocol-relative targets, encoded/control characters, safe internal URLs and intended external URLs. Preserve intended external content; do not introduce a blanket URL policy without review. Run typecheck/full website tests/build and browser QA for student, employee, admin and mobile handoff. Keep the migration separate from test/CSS tooling for review/rollback.

## Development tooling — PROPOSED test migration

Vitest 2.1.9 carries old mocker/vite-node, nested Vite 5.4.21/esbuild 0.21.5 and Tinypool 1.1.1. The direct build Vite is already 6.4.5; it is inaccurate to describe it as the remaining nested vulnerable server. Critical entries are Tinypool and propagated Vitest findings. The [Tinypool advisory](https://github.com/advisories/GHSA-5gmw-xhrv-c9v3) describes unsafe worker option resolution; current repository test/config is the worker input. No application request-to-worker-option path or publicly exposed Vitest UI/API was identified. This does not make vulnerable tooling safe for untrusted tests/configuration.

Approval proposal: migrate Vitest as a unit (npm proposes 5.0.5, reverify later), reviewing Node engine/peer/Vite/plugin compatibility. Run the complete test set, including new Node-environment SEO tests, React act/session tests, fake timers, mock isolation and worker behavior. Keep UI/API servers unexposed while the tooling remains affected. No major transitive overrides of Tinypool, Vite or esbuild.

## Build processing — PROPOSED Tailwind migration

Tailwind 3.4.19's processing chain carries braces/selector-parser and propagated chokidar/fast-glob/micromatch/postcss-nested findings. Reviewed configuration processes repository CSS/source, not a production arbitrary CSS/glob upload API. Untrusted repository inputs still matter for developer/build availability.

Approval proposal: migrate Tailwind as a separate CSS/toolchain change (npm proposes 4.3.3, reverify later). Inventory PostCSS integration/plugins/custom utilities and supported browsers. Preserve reference screenshots for public pages, discovery/search, forms and role dashboards; verify responsive Arabic RTL/English layout, focus, contrast and motion. Run all tests/typecheck/build and inspect generated CSS. Avoid broad overrides that silently replace parser/glob APIs under Tailwind 3.

## Limits and disposition

Source applicability was reviewed locally; it is not penetration testing. Upstream advisories were rechecked during this phase. Existing detailed package paths/advisory list remain in [Phase 2 security review](PHASE2_SECURITY_REVIEW.md). No credentials were exposed, rotated or reconfigured. These migrations require owner approval; Phase 3 proceeds with local testing and review artifacts without performing them.
