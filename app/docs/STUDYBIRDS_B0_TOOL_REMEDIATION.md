# Study Birds — B0 tool remediation

2026-10-22. Controlling evidence: `STUDYBIRDS_B0_TOOL_VALIDATION.md`; capacity constraints remain those in `STUDYBIRDS_LOW_SPACE_B0_DESIGN.md`.

**Decision:** the original synthetic timestamp/ACL mismatch has a working, tested remediation. Password transfer without secret command arguments also passed. **Real B0 and migration remain NO-GO.** The smallest next action is an owner-approved **download and signature review only** of the maintained stable WinRAR installer. Download, installation and real backup are separate boundaries; none occurred here.

## Installed and maintained versions

- Installed `C:\Program Files\WinRAR\WinRAR.exe`: **6.11.0**; console RAR banner **6.11 x64**. The installed `Rar.exe` Authenticode check returned Valid, signer `win.rar GmbH`. A valid old signature does not mean the old code is patched.
- Official vendor download page currently lists **7.23 x64 stable**, plus **7.30 beta 1**. Select stable7.23 for review, not the beta. The stable installer href was independently read from the official HTML: `https://www.rarlab.com/rar/winrar-x64-723.exe`. **No installer bytes were downloaded.** [Official releases](https://www.rarlab.com/download.htm).
- Updating before real B0 is recommended as an execution prerequisite: vendor history documents extraction path-traversal corrections and later recovery-code security fixes affecting Windows RAR/UnRAR. Do not treat an old-version synthetic pass as a waiver. The newer beta also documents stricter ADS-open error reporting, so independent complete stream inventories/hashes remain necessary even when reviewing stable7.23. [Vendor change history](https://www.rarlab.com/rarnew.htm).

An application update need not touch Study Birds repositories or existing archives. It can, however, replace Program Files binaries and shell extensions/associations and require elevation; those are separate approved system changes. Do not silently execute the installer, change associations, remove the old application or let an updater open existing archives. First download/verify without execution; then approve a reviewed installation or supported isolated-tool procedure. No unsupported portable extraction is assumed.

## Fresh synthetic experiment

Exact new isolated root:

`C:\Users\Abood\AppData\Local\StudyBirds\b0-metadata-remediation-20261022-b62518c6b483494db7c0a61b835aadfa`

Absence and non-reparse ancestors were verified before creation. No previous experiment directory was reused. This root contains only new synthetic files, source/restore trees, a synthetic junction target, helper code/assemblies and results. It is retained for review: **6,396,768 ordinary logical bytes, 43 filesystem entries** at the final inventory. No cleanup was performed in this task. Final sampled free space: **C 34,080,956,416 bytes**, **D 8,053,370,880 bytes**; host background activity means these are live samples, not attributed capacity recovery.

Evidence: `docs/STUDYBIRDS_B0_TOOL_REMEDIATION_VALIDATION.json`, including exact paths/hashes, test results and the limited real-scope metadata sample. Executable synthetic prototype: `metadata-test.ps1`; native helper source/assembly: `SyntheticNtfs4.cs` / `SyntheticNtfs4.dll` inside the isolated root. Its root allowlist is intentionally fixed to this experiment; **it is not a real B0 execution script**.

Windows PowerShell5.1 and existing .NET/Windows APIs were used. A small C# test helper was compiled with the existing CodeDom toolchain; output assembly and compiler temporary paths were explicitly inside the new root. No software installation, dependency download or Android compilation occurred. No production/QA service, database, security gate, Git state, source or existing checkpoint was modified.

## Metadata companion mechanism

The synthetic companion binds relative node identities to:

1. UTC creation/write/access timestamps as integer ticks, node kind and attributes.
2. Binary security descriptor plus SDDL, preserving owner/group, DACL ACEs and control flags in the captured sections.
3. Every named stream, including **directory ADS**, separately from the unnamed file stream.
4. Link type, target and raw reparse buffer, captured without descending into the junction.

The test stores small stream bytes as Base64 with a **1 MiB per-stream synthetic limit**. A production implementation must instead stream arbitrary-size ADS as separately identified encrypted archive entries with lengths/SHA-256; it cannot inherit this synthetic limit or put large ADS into an unbounded JSON object. Default-stream file hashes and the encrypted companion's hash are independently verified.

### Corrections actually tested

- **Directory ADS discovery:** PowerShell5.1 `Get-Item -Stream *` returned no directory streams in this test despite a real named stream. The helper uses `FindFirstStreamW`/`FindNextStreamW`, rejects unexpected API errors and reads/writes named streams through `CreateFileW` with directory-handle support. This avoids silently losing directory ADS.
- **Directory timestamps:** apply streams and security first; set attributes and all three timestamps last, directories deepest-first. Using `File` timestamp setters for directories failed during development; the corrected prototype uses explicit filesystem-node timestamp properties.
- **ACL control flags:** a single restore API did not reproduce both descriptor classes. The tested helper chooses `SetNamedSecurityInfoW` when the captured descriptor has `SE_DACL_AUTO_INHERITED`; otherwise it uses `SetFileSecurityW`. Owner/group/DACL information and protected/unprotected state are explicit. This restored both `D:PAI(...)` and the descriptors without AI exactly in the sample. Windows documents automatic inheritance behavior for these interfaces. [Microsoft inheritance documentation](https://learn.microsoft.com/en-us/windows/win32/secauthz/automatic-propagation-of-inheritable-aces).
- **Privilege boundaries:** generic `Set-Acl` attempts failed with a SeSecurityPrivilege requirement. The helper explicitly writes the captured owner/group/DACL sections; it does **not** claim to capture/restore SACLs or bypass privilege requirements. Required auditing/owner rights must be separately verified for the real scope.
- **Path safety:** synthetic script rejects a different root, rooted/traversal relative paths and linked restoration ancestors. Link nodes are recorded/compared, not traversed or fed into ordinary stream/security restoration. Raw reparse buffer, type and target matched after archive restoration.

**Important production guard:** `SetNamedSecurityInfoW` can propagate inheritance to descendants. The prototype exercised its AI branch on the protected synthetic file; it does not prove safety for every directory ACL/link topology. A real restorer must restore ordinary nodes in a private isolated area with links withheld until ACL propagation and metadata application finish, validate the complete path/link map before writing, then materialize approved links without targeting live roots. Unknown nodes/streams/links must cause rejection, never automatic removal. Further synthetic directory-inheritance/deny-ACE/non-owner/SACL and hostile-path tests are required before general use. Passing the current sample is not general authorization.

## Actual results

| Test | Result |
|---|---|
| RAR5 encrypted creation using installed6.11, companion included | Exit0 |
| Full native integrity test | Exit0 |
| Decryption and actual restore | Exit0; three ordinary source file SHA-256 values match, including binary/Unicode files |
| Companion restored from archive | SHA-256 matches the original companion |
| No-key filename listing | Exit11; member names not disclosed |
| Wrong-key test | Exit11 |
| Separate corrupted synthetic archive | Exit3/checksum error |
| Final metadata comparisons | **33/33 pass**: five ordinary nodes × six checks, plus three junction checks |
| Directory ADS and file ADS | Captured/restored bytes match |
| Security descriptors | Exact SDDL matches for every tested ordinary node; original protected-file AI mismatch resolved |
| Timestamps/attributes | Creation/write/access ticks and attributes match every tested ordinary node, including empty directory |
| Junction | Type, target and raw reparse bytes match; no sentinel descendant archived as an ordinary member |
| Wrong root / `..\out-of-scope` companion path | Both rejected, exit1 |
| PowerShell final prototype syntax | Zero parser errors |

The final prototype does not assert success solely from an archiver exit code. The evidence lists each metadata boolean and content hash. Long paths had passed the earlier controlling experiment; this new remediation round did **not** re-test the full metadata companion on long paths, so archive-level long-path support is not treated as complete companion-level support.

Development failures are not hidden: .NET stream paths initially rejected ADS, directory File time setters failed, a CodeDom assembly reference was added, a PowerShell array-wrapper issue was corrected, and single-API security restoration produced mismatches. No privileges were enabled and no source metadata was changed to make comparisons pass. Earlier failed variants remain in the synthetic directory for review.

## Password handling

The successful test generated a random synthetic password **in process memory**, supplied it as **one LF-terminated line** to the RAR child's redirected stdin, and used `-hp` / `-p` **without an appended password**. The password was absent from child argument arrays and captured stdout/stderr; no key file, environment variable or literal secret was written to a script, command history or evidence. Missing/wrong passwords failed as expected.

An initial two-line CRLF input sequence created an archive that the corresponding later read did not unlock. That sequence is rejected; it is not an approved handshake. The successful one-line framing must be re-tested on7.23, including password length/character rules and failure detection. The installed manual explicitly supports piped password input; do not infer that every framing or tool version is equivalent.

This protects against ordinary argument/history/log disclosure; it does not protect a process from an administrator, debugger, memory dump or compromised host. Garbage-collected strings cannot be guaranteed wiped. Real use still needs an owner-entered secret through a secure prompt, bounded pipe ownership, no transcript/input logging, tested independent key recovery and a policy against persistently storing the key beside the archive. No real password was requested or used.

**Privacy blocker still open:** the synthetic `companion.json` is plaintext because it contains only synthetic data. Real companion data includes private paths, ACL identities and possibly sensitive ADS payloads. It must be encrypted from first persistent output or generated within verified private encrypted scratch, with no plaintext secret staging. The current prototype does not demonstrate that production writer. RAR's password and `-si` data paths both involving stdin must not be combined without a separately verified design. Do not reuse the synthetic on-disk plaintext companion pattern on real data.

## Essential requirements versus unproven/absent metadata

Read-only metadata-only sampling checked **14 existing known B0 nodes**: selected repository/root/index paths, signing/config paths, the protected APK, QA root/db and three C worktrees. No file/stream contents were read in that sample. Seven descriptors contained AI, so control-flag preservation is a **real requirement**, not an invented edge case.

- Always essential: every default-stream byte and raw Git object/ref/index, unique working/ignored files, ownership/DACLs, relevant timestamps/attributes, private data confidentiality and independently verified restoration.
- Known required links: the six junctions recorded in the controlling B0 census. Preserve them as metadata with explicit external target ownership, not recursive payload additions.
- Named streams/EFS/compression/sparse attributes: **none found on those 14 sampled nodes**. This does **not** establish absence across the full238,266-file historical scope. ADS support is now demonstrated synthetically; EFS/raw-encryption and sparse/EA handling remain conditional requirements pending a complete metadata census.
- Hard links: the previous B0 census detected none; this task did not perform a new full hard-link inventory. Implementing their identity restoration is unnecessary only if the frozen execution census reconfirms absence.
- SACLs, special owners, EAs and arbitrary reparse types: not exhaustively inspected. Lack of access or an unqueried field is **unknown**, never evidence of absence. Required privileges or unsupported present metadata block execution; absent types need no speculative restore implementation once absence is proven.

No requirement to preserve unique content, Git recovery or privacy has been weakened. The complete B0 capacity/consistency/restore-unit proof remains outstanding; a small synthetic ratio does not prove the14.25 GiB cap. QA database backup still requires its separately approved consistent procedure. Android gate and capacity policies are unchanged.

## Smallest next execution step and approval

**GO only after explicit owner approval for this exact package-review step; NO-GO until then:**

1. Revalidate absence/canonical ordinary ancestry of proposed new directory `C:\Users\Abood\AppData\Local\StudyBirds\b0-tool-upgrade-review-20261022` (absent at inspection).
2. Create only that review directory and download **one** official stable x64 installer from `https://www.rarlab.com/rar/winrar-x64-723.exe` to `C:\Users\Abood\AppData\Local\StudyBirds\b0-tool-upgrade-review-20261022\winrar-x64-723.exe`. Apply a32 MiB total review-output cap; stop on redirect outside reviewed official origin, unexpected version/size or occupied destination.
3. Inspect SHA-256, PE version and Authenticode signature/trust chain; require the verified vendor publisher (`win.rar GmbH`) and version7.23. Do not label a locally computed hash an independently published checksum. Save a small review receipt without executing the package.
4. **Stop.** No installation, elevation, association change, portable extraction, real-data access or B0 permission follows. Present a separate installation/isolation plan and obtain approval before running any installer. After tool remediation, repeat the synthetic matrix and finish the encrypted-companion writer and broader metadata tests.

Package-review permissions needed: outbound HTTPS to the official vendor and signature-validation infrastructure, create/write access only to the named new review directory, and read-only signature/version inspection. No administrator rights or service downtime is needed for download-only review. Actual Program Files update would be a separate owner-approved/elevated action with reviewed shell/association choices and rollback; projects/archives remain outside its write scope.

## خلاصة عربية

نجح المرافق الاصطناعي في **33/33 مقارنة**، وأصلح فرق ACL وطابع وقت المجلد مع حفظ ADS والوصلة. نجح أيضًا تمرير كلمة اختبار دون وضعها في وسائط العملية أو السجلات. المثبت WinRAR6.11، والمستقر الرسمي المتاح7.23. القرار **NO-GO للنسخة الفعلية والترحيل**؛ الخطوة الأصغر هي موافقة صريحة لتنزيل المثبّت الرسمي إلى مسار المراجعة المحدد وفحص توقيعه فقط، دون تثبيت. يبقى حفظ المرافق الحقيقي مشفّرًا من البداية وفحص بقية أنواع البيانات الوصفية قبل B0. لم يُنزّل أو يُثبّت شيء، ولم تتغير المشاريع أو خدمات QA.
