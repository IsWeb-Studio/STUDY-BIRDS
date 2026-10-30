# Remaining website advisories — applicability review

21 October 2026. Current full `npm audit`: **15 affected package entries: 7 moderate, 6 high, 2 critical**. Production-dependency-only audit: **2 moderate entries**, `react-router` and `react-router-dom`. These are package entries/propagated findings, not 15 demonstrated exploit chains. Both audit commands return exit 1 because findings remain.

An isolated `npm audit fix --package-lock-only --ignore-scripts --dry-run --json` reports **0 added, 0 removed, 0 changed**. No further compatible dependency update was identified; no lockfile/manifests were changed in Phase 2 and no force upgrade was used. The Phase 1 compatible fixes remain. The clean validation dependency tree, not the older shared node_modules junction, was used to identify actual installed paths.

## Production navigation: React Router

`react-router` / `react-router-dom` 6.30.6 are production dependencies. [Backslash open redirect](https://github.com/advisories/GHSA-wrjc-x8rr-h8h6) affects navigation inputs. Current login redirects are built from role-home mappings or an encoded mobile request ID, rather than an arbitrary return URL. However, `HomePage.tsx` contains `<Link to={item.href}>` using content/config-derived links; Navbar and other data-driven links also need end-to-end validation. The review does **not** establish that all Link inputs are safe or that an attacker can currently write those values. Classify as production-relevant, reachability not fully proven.

[SSR constructor injection](https://github.com/advisories/GHSA-337j-9hxr-rhxg) needs server hydration/deserialized errors. The current entry is `ReactDOM.createRoot` + `BrowserRouter`, not `hydrateRoot`, a StaticRouter or an SSR hydration setup; no active SSR path was found in the reviewed entry/config. This limits current applicability; it does not remove the dependency advisory.

npm proposes react-router-dom 7.18.4, a major update. Before approval: review v7 migration behavior, all route definitions, protected role routing, browser/mobile handoff, external/content links, language/query preservation and history/back behavior. Add malicious backslash/protocol-relative/control-character navigation cases and valid external/internal link cases. Do not globally strip links without a product decision about intentionally external content.

## Test execution: Vitest, Tinypool, mocker and vite-node

- `vitest` 2.1.9 and `@vitest/mocker` 2.1.9: [mock redirect traversal/read](https://github.com/advisories/GHSA-82fw-gwwq-j7x9). Current tests use the Vitest CLI; the repository script is `vitest run`. There is no `--ui` or exposed `--api` in the inspected command/config. Redirect-mock HTTP reachability was not demonstrated for this run. Vulnerable tooling is still installed and can become exposed if developer commands change.
- Vitest: [UI/API-server arbitrary file read/execution](https://github.com/advisories/GHSA-5xrq-8626-4rwp). No configured public UI/API server was found. This concerns development/test services, not the compiled static website. A test pass does not patch the dependency.
- `tinypool` 1.1.1: [worker-options prototype gadget](https://github.com/advisories/GHSA-5gmw-xhrv-c9v3) and [run-options prototype gadget](https://github.com/advisories/GHSA-85c8-ppgw-ccpr). Worker infrastructure is exercised by tests. No app/API request-to-worker-options path was found: inputs here are repository test/config code. Treat untrusted tests/plugins/configuration as code execution and never expose tooling on the assumption that the production app does not use it. These findings explain the two critical package entries (Tinypool and propagated Vitest), not two proven production RCEs.
- `vite-node` 2.1.9 and mocker carry nested Vite findings. They are test-tool dependencies, not independent production routes.

npm proposes Vitest 5.0.5 (major), resolving the old worker/mocker/Vite dependency family. A migration needs Node/peer compatibility checks, all 65 website tests, mock/timeout/fake-timer/worker behavior, environment setup and coverage/UI configuration review. Do not independently override Tinypool across a major API boundary to produce a cosmetic zero audit count.

## Nested Vite 5 and esbuild

The direct Vite used to build the website is **6.4.5**, after Phase 1 compatible remediation. The remaining vulnerable Vite paths are **5.4.21 nested under Vitest and vite-node**. The remaining esbuild paths are **0.21.5 in those test trees**. Reporting the direct Vite 6.4.5 as the still-vulnerable server would be inaccurate.

Remaining Vite advisories concern [optimized dependency source-map traversal](https://github.com/advisories/GHSA-4w7w-66w2-5vf9), [Windows alternate-path deny bypass](https://github.com/advisories/GHSA-fx2h-pf6j-xcff), and launch-editor handling: [UNC/NTLM exposure](https://github.com/advisories/GHSA-v6wh-96g9-6wx3), [percent escaping](https://github.com/advisories/GHSA-698v-4r3x-3vcv), [editor CLI arguments](https://github.com/advisories/GHSA-r825-w8mm-5pxw), [Windows existence checks](https://github.com/advisories/GHSA-587h-7wmj-h5pm). These require the relevant development HTTP/editor handlers and attacker-supplied requests/paths; they are not shipped as an Express route in the static deployment. Current CLI test execution does not establish an externally reachable vulnerable handler. Resolve through the Vitest migration and retest development endpoints, especially on Windows.

[esbuild serve cross-origin requests](https://github.com/advisories/GHSA-67mh-4wv8-2f99) concerns its HTTP serve API, not normal transpilation/bundling. No application call to esbuild's serve API was found in reviewed client source/config. Keep this as a development dependency finding until its parent chain is upgraded; do not assume the advisory applies to every generated JS file.

## CSS/source processing: Tailwind dependency chain

- `braces` 3.0.3: [deep pattern stack exhaustion](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm).
- `postcss-selector-parser` 6.1.5: [quadratic selector parsing](https://github.com/advisories/GHSA-rj75-hqrm-r3gf).
- `chokidar` 3.6.0, `fast-glob` 3.3.3, `micromatch` 4.0.8, `postcss-nested` 6.2.0 and `tailwindcss` 3.4.19 inherit those findings; they do not each add a distinct advisory in the current audit.

These tools scan/build repository CSS, selectors and source patterns. Current Tailwind configuration points at repository HTML/TS/TSX inputs. No production API that feeds arbitrary uploaded CSS/glob patterns into this build chain was identified. Developer/build risk remains if untrusted source/configuration is processed. They are development dependencies; `npm audit --omit=dev` omits this chain.

npm proposes Tailwind 4.3.3 (major). That changes CSS/PostCSS integration and may affect layout/classes and browser support; it is not a harmless lock-only patch. Before approval, inventory plugins and generated styles, preserve visual baselines for the site/admin/student flows, migrate configuration deliberately, and run typecheck/tests/build plus responsive/RTL/contrast checks. Avoid major overrides of parser/glob APIs under Tailwind 3.

## Disposition

No automatic credential rotation, production configuration change or major migration. Keep separate reviewable migration proposals for (1) navigation, (2) test tooling, (3) CSS toolchain. All remain attention items with the applicability limits above. Advisory descriptions were checked against GitHub's primary advisory records and the current npm lock/audit paths; reachability conclusions are code-review inferences, not penetration-test results.
