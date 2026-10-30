# Study Birds — B0 backup tool validation

2026-10-22. Controlling design: `STUDYBIRDS_LOW_SPACE_B0_DESIGN.md`.

**Real B0: NO-GO.** A concrete existing RAR mechanism passed synthetic encrypted backup/restore, filename confidentiality, data hashing, long-path, junction and ADS tests. It did not reproduce every tested security-descriptor control flag or directory timestamp. The installed RAR version is old and predates vendor security fixes. Windows tar also failed important tests. No available mechanism has yet satisfied the complete preservation/security requirements.

No real backup, migration, compression measurement of project data, Git mutation, service stop, Android build, download or installation occurred. Only synthetic data was archived/restored. This report and its synthetic evidence JSON were written in docs; no existing project source/configuration was edited.

## Isolation and evidence

Exact fresh experiment root:

`C:\Users\Abood\AppData\Local\StudyBirds\b0-tool-validation-20261022-7d236615bc4f4cc0847c9f032e59692c`

Before creation, its absence and ordinary/non-reparse ancestry were checked. It was created explicitly; no existing test directory was reused. Source, restore directories, archives, scripts, logs and the junction target were all new synthetic items beneath this root. The junction target contained only the synthetic `DO_NOT_FOLLOW.txt` sentinel; no real project, browser, credential or database data was included. No tool was directed at a real repository for compression.

Synthetic source: five ordinary files, an empty directory with a named stream, nested directories, and a junction. Files included random 8 MiB and repeated 2 MiB content, a plain file with a named stream and deliberately protected DACL, a Unicode filename (`مرحبا-鳥-é.txt`), and a 409-character source file path. A fixed 2020 modification timestamp tested restoration. File and directory ADS were separate checks.

Evidence: `STUDYBIRDS_B0_TOOL_VALIDATION_SYNTHETIC_INVENTORY.json`. It records **all 138 exact created filesystem nodes** (77 ordinary files, 58 directories, three junction nodes including restored copies), ordinary-file lengths/hashes, link targets, test outputs, metrics and removal receipts. ADS results are recorded in the test evidence, not counted as ordinary files. Synthetic archive passwords were public test strings, not real credentials.

After recording the inventory outside the experiment, a fresh no-follow walk matched every path/type/length/hash/link target; ordinary files had no extra hard links, link targets stayed within the synthetic root, and ancestor checks passed. Cleanup removed each synthetic file/link independently and empty directories deepest-first, **without recursive deletion**. All 138 nodes were removed; the exact experiment root is absent. No parent or sibling was deleted.

Windows generated two tar crash dumps outside the isolated root:

- `C:\Users\Abood\AppData\Local\CrashDumps\tar.exe.35836.dmp` — 298,246 bytes.
- `C:\Users\Abood\AppData\Local\CrashDumps\tar.exe.4252.dmp` — 306,779 bytes.

Only names/lengths were inspected. They were **not opened or deleted**, because outside-root cleanup was not included in the isolated cleanup operation. Treat dumps as private diagnostic data; no claim is made about their contents. This illustrates OS crash-reporting writes outside an archive tool's requested output path.

## Tools actually found

| Tool / path | Version | Validation performed |
|---|---|---|
| `C:\Windows\System32\tar.exe` | bsdtar/libarchive **3.8.9**, zlib 1.2.13.1-motley, liblzma 5.8.3, bz2 1.0.8, zstd 1.5.7, CNG 2.0 | Version/help, PAX/TAR/GZIP, AES ZIP, stream output, corruption and restoration |
| `C:\Program Files\WinRAR\Rar.exe` | **RAR 6.11 x64**, banner 3 Mar 2022; WinRAR file version 6.11.0 | Installed manual, encrypted RAR5 creation/test/extraction, metadata and corruption checks |
| `C:\Windows\System32\Robocopy.exe` | **10.0.26100.8875** | Synthetic `/COPYALL` and `/COPY:DATS` copies |
| `icacls.exe`, `cipher.exe` | **10.0.26100.8875** | Availability/version only; no encryption/settings operation |
| `wbadmin.exe` | **10.0.26100.8972** | Availability/version only; no backup/snapshot operation |
| Windows PowerShell | **5.1.26100.9711** | Synthetic ACL/ADS/timestamp checks and process sampling |
| Node.js | **22.19.0** | Binary hashes, direct child exit codes, no-follow inventories and synthetic cleanup |

7z/7za, age, GPG, restic, borg and duplicacy were not found on PATH. Checked conventional locations for 7-Zip, PeaZip, GnuPG, VeraCrypt, Duplicati and Macrium were absent. This is bounded discovery, not proof no other installation exists. WinRAR was found by checking its conventional installed location after the initial PATH inspection. Its bundled `7zxa.dll` is not a validated 7-Zip writer/metadata mechanism.

## Concrete RAR mechanism tested

From the synthetic root, with placeholders below standing only for paths inside that root:

```text
Rar.exe a -cfg- -ma5 -m1 -md4m -mt1 -s- -hp<SYNTHETIC_PASSWORD>
  -os -ow -ol -tsmca -htb -w<ROOT>\rar-work -r <ROOT>\synthetic.rar source
Rar.exe t -cfg- -p<SYNTHETIC_PASSWORD> <ROOT>\synthetic.rar
Rar.exe x -cfg- -p<SYNTHETIC_PASSWORD> -ow -ola -tsmca
  <ROOT>\synthetic.rar <ROOT>\rar-restore\
```

These are a record of synthetic tests, **not owner commands for real B0**. Real passwords must not be placed in process arguments/history. A safe interactive/secret-entry procedure remains to be validated. `-cfg-` prevents hidden RAR configuration/environment options; `-ol` stores reparse points rather than their contents. Extraction `-ola` was used only because every synthetic link target was individually verified inside the experiment. It must **not** be reused as blanket permission to restore original absolute Study Birds junctions into live paths. Real restoration needs a reviewed explicit link map and isolated targets.

RAR wrote a new archive directly to its final test filename. No archive update/repack was tested or authorized. Installed `Rar.txt` documents `-os`, `-ow`, `-ol`, `-hp`, and `-w`; the manual also explicitly limits streams for EFS-encrypted files and security capture to available privileges.

### RAR results

| Check | Actual result |
|---|---|
| New RAR5 archive with encrypted headers/data | Exit **0**, 8,403,038-byte archive |
| Native archive integrity test | Exit **0**, All OK |
| Missing password / wrong password listing | Both exit **11**, no member filenames disclosed |
| Actual restoration | Exit **0**; all five ordinary file SHA-256 values match, including random binary and Unicode name |
| Long path | 409-character source path restored and content hash matches; restore prefix is longer |
| Junction | Restored as a junction with identical target; sentinel was not a separate archived member; no automatic source-target recursion in this test |
| File ADS | Named stream bytes match |
| Directory ADS | Named stream bytes match |
| File times | Tested modification times match; plain-file creation time matches |
| Empty directory | Exists; **its modification time differs** after restore despite timestamp switches |
| Protected file security descriptor | Owner/group, explicit ACE rights and protected-DACL state match; **exact SDDL differs**: source `D:PAI(...)`, restored `D:P(...)` (auto-inherited control flag lost) |
| SACL, arbitrary owners and elevated privileges | **Not proven**; no synthetic audit ACE or different owner was installed, no elevation or privilege change occurred |
| Corrupted synthetic archive | Native test exit **3** after a byte flip in a separate synthetic copy; original test archive unchanged |
| Streamed extraction/hash without writing restored payload | `p` command emitted **8,388,608 bytes**, exit **0**, SHA-256 matches the random file |

Exact metadata reproduction is a requirement, so equivalent effective access permissions do not convert the SDDL mismatch into a pass. A tested metadata companion and restore procedure could potentially repair control flags/times **inside isolated restores only**, but none was implemented here. EFS, sparse/compressed-file semantics, arbitrary reparse types, EAs, hard-link identity, maximum-length paths and full ACL/SACL privilege coverage remain unvalidated. No source preservation requirement is waived.

RAR `p` uses stored Windows member separators; an initial forward-slash selector returned exit10/no members. Retesting `source\random.bin` passed. The failed selector is retained in evidence, not counted as a successful integrity check.

## Other tool results — why they are not substitutes

**Windows tar:** multiple GZIP/PAX and default-compressed AES ZIP creation attempts terminated with **3221225477 (`0xC0000005`)**. Truncated archives failed reads/restores; some empty/truncated outputs extracted with exit0, demonstrating why exit code alone is insufficient. No diagnosis of the underlying crash cause is claimed.

Uncompressed TAR of a regular binary succeeded. A plain-file TAR restored its default stream and modification time, but **lost ADS, exact ACL and original creation time**. Long nested file restoration succeeded. Critically, default junction archiving **followed the synthetic junction**, adding `source/junction/DO_NOT_FOLLOW.txt`; this default is unacceptable for B0.

AES ZIP with **store compression explicitly selected** succeeded for a basic synthetic file, restored matching bytes, rejected the wrong password (exit1), and detected corruption (`ZIP bad Authentication code`, exit1). It emitted corrupted plaintext before reporting authentication failure, so a pipeline must not accept streamed bytes before checking final exit status and hashes. ZIP member names remained listable without a key. This does not meet encrypted-inventory confidentiality or complete NTFS metadata preservation.

**Robocopy:** `/E /SJ /SL /COPY:DATS /DCOPY:DAT /R:0 /W:0` returned **1** (files copied, not failure). Tested default streams, file/directory ADS, protected file SDDL, Unicode/long paths, empty directory modification time and junction target were preserved. `/COPYALL` returned **16** because the process lacks Manage Auditing user rights. No privilege change was attempted. Robocopy is neither an encrypted packed archive nor a direct low-allocation solution; adding it as a full plaintext staging copy would invalidate the controlling low-space budget. `/MIR`, delete, move and purge modes were never used.

## Streaming size measurement and resources

**No complete safe measurement mechanism for real B0 is validated.** tar can write archive bytes to stdout into a counting sink without a persistent archive: uncompressed TAR and stored AES ZIP both returned0 and emitted **8,396,800 bytes** for the 8 MiB file. File outputs were 8,390,144 and 8,388,862 bytes respectively, so seekable-file versus pipe padding/layout differs. These counts cannot be treated as exact RAR-file predictions. The tested RAR manual documents stdout extraction, not a validated stdout archive-creation/count mode. Do not invent a `NUL`/stdout command or assume sample ratios predict the full scope. A bounded final encrypted shard could be measured later under explicit real-data authorization, with its allocation charged to B0.

Measured resource observations:

- All synthetic experiment files retained simultaneously reached **157,293,200 default-stream bytes (~150.006 MiB)** before cleanup, plus named streams and filesystem metadata. Per-file 4 KiB rounding estimate: **157,474,816 bytes**; not measured allocated size. This is the observed experiment footprint, not a kernel-level global temporary-space peak.
- One full successful RAR creation used a 4 MiB dictionary and one worker. Twelve samples observed **117,747,712 bytes peak working set (~112.293 MiB)** and **138,846,208 private bytes (~132.414 MiB)**. Dictionary size alone is not process-memory usage. The measured repeat archive was 8,402,990 bytes; metadata/access-time differences mean it was not byte-identical to the first archive.
- Dedicated RAR work-directory observed disk usage: **0 bytes** during those samples. Very short-lived spill, global TEMP activity, OS paging and other processes were not comprehensively traced; zero observed spill is not a zero-spill guarantee.
- Successful tar store/AES-store creation observations: ~5.76/6.23 MiB working set and ~1.45/1.63 MiB private bytes. Short runtimes limit sampling accuracy.
- A complete synthetic restore required approximately **10 MiB default-stream data**, plus streams/directories/security allocation. This does not prove the real 3 GiB sequential Git/DB restore ceiling; no real source was measured or restored in this experiment.
- Final post-cleanup free space: **C 34,181,292,032 bytes (31.834 GiB)**; **D 8,053,612,544 bytes (7.501 GiB)**. C rose 156,135,424 bytes between the immediate pre/post-cleanup samples; concurrent host writes prevent equating this with exact physical allocation reclaimed.

The first PowerShell Start-Process harness did not capture reliable child exit codes (`null`); its stderr/memory observations remain diagnostic only. Direct Node spawning and a corrected handle-retaining Process harness established actual statuses. Initial Unicode transmission through the PowerShell-to-Node pipe also failed; escaped Unicode code points corrected the synthetic setup, after which actual restored filenames/hashes were verified. No failed or empty-output run is counted as a full backup pass.

## Remaining blockers and next approval

1. **Installed RAR security review/update.** Version6.11 predates vendor fixes affecting Windows RAR/UnRAR extraction, including later path-traversal corrections. Passing a self-generated synthetic test is not security approval for this old version. Use an owner-approved maintained version or separately reviewed alternative and repeat the synthetic matrix; no update/download was performed. [Vendor change history](https://www.rarlab.com/rarnew.htm).
2. **Metadata completeness.** Resolve and retest directory times and security control flags; establish SACL/owner privilege coverage and all actual required stream/reparse/EFS/EA types. Unsupported required metadata means NO-GO, not silent exclusion.
3. **Private operation.** Validate safe password entry, confidential inventories/logs, trusted authenticated manifest, independent key recovery, canonical destination ACLs and fail-closed temporary-output behavior. Synthetic passwords in arguments are not a real-data key-handling pattern.
4. **Bounded capacity proof.** Measure the complete fresh B0 scope only after authorization; synthetic compression cannot justify the 14.25 GiB cap. Prove largest full Git-owner and consistent DB restore units fit the sequential scratch budget, with monitored free-space reserves.
5. **Consistency/operational recovery.** Separate approval remains required for browser/editor/Git writer quiescence, supported cold QA database snapshot, restart, real backup creation and actual isolated Git/DB recovery tests. No current experiment demonstrates DB consistency or Git recovery.

**Recommended next step:** review a maintained RAR-based direct-write mechanism with an explicit NTFS metadata companion, or another metadata-complete encrypted mechanism. Authorize only the tool remediation and another synthetic test round first. Do not authorize real B0 merely because RAR reports All OK. Android gate/reserve policies and all production/QA settings remain unchanged.

## خلاصة عربية

اختُبرت الأدوات على بيانات اصطناعية فقط. نجح WinRAR 6.11 في التشفير وإخفاء الأسماء واستعادة الملفات الطويلة وADS ووصلة junction، لكن ظهرت فروق في بيانات ACL وطابع وقت مجلد، والإصدار يحتاج مراجعة أمنية وتحديثًا معتمدًا. أداة tar تعطّلت في اختبارات الضغط وفشلت في حفظ بيانات NTFS كاملة. القرار **NO-GO لنسخة B0 الفعلية** حتى معالجة هذه الفجوات وإعادة الاختبار. حُفظت الأدلة ثم حُذف المجلد الاصطناعي وحده؛ لم تُنسخ أو تُنقل المشاريع ولم تبدأ الهجرة أو عملية بناء.
