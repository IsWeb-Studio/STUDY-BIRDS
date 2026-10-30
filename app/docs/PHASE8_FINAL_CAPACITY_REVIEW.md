# Phase 8 — completed cleanup verification and final capacity review

Date: 2026-10-22 (Europe/Istanbul). Read-only verification plus this requested report only. No cleanup, cleanup-script generation/execution, build, ADB, emulator, installer, dependency retrieval, Git mutation or production/QA configuration change.

## Exact owner execution audit

Read:
`D:\work\studybirds_app\study_birds_app-main\docs\PHASE8_OWNER_CLEANUP_RUN_20261021T222825361_3ae025510c704069b56c1be764d52afd.json`

The run records `Completed=true`; all nine approved entries have status `DELETED`. Fresh existence checks confirm every exact target is absent. No skipped/failed entry or failure field is recorded.

Observed per-target free-space increases:

1. `D:\work\studybirds_session_release\app\build\test_cache`: **566,919,168 bytes**.
2. `D:\work\studybirds_session_release\app\.dart_tool\flutter_build`: **102,768,640 bytes**.
3. `D:\work\studybirds_web\app\.dart_tool\flutter_build`: **496,861,184 bytes**.
4. `D:\work\studybirds-security-release-20261017-mobile\.dart_tool\flutter_build`: **226,160,640 bytes**.
5. `D:\work\study-birds\app\.dart_tool\flutter_build`: **188,833,792 bytes**.
6. `D:\work\studybirds-security-release-20261017-mobile\build\test_cache`: **94,380,032 bytes**.
7. `D:\work\studybirds-security-release-20261017-web\app\build\test_cache`: **94,375,936 bytes**.
8. `D:\work\studybirds-security-release-20261017-mobile\build\app\generated`: **51,912,704 bytes**.
9. `D:\work\study-birds\app\build\89a6598c8854ed031dfc25d83c80860e.cache.dill.track.dill`: **94,580,736 bytes**.

Audit initial free: **5,917,052,928 bytes**. Audit final free: **7,833,829,376 bytes**. Net observed recovery: **1,916,776,448 bytes (~1.785 GiB)**. Per-operation deltas sum to **1,916,792,832 bytes**; the 16,384-byte difference is the gap between the run's initial measurement and the first operation's measurement, not an additional deletion. Audit/log writes and concurrent activity can affect volume deltas, so these are actual observations, not exact allocation attribution.

## Integrity checks

The audit records `GitUnchanged=true` and `ProtectedFilesUnchanged=true`. Independent current checks match the audit's HEAD, index SHA-256 and Git worktree registrations for all six repositories:

- Primary: `3e31e19c5343170056e6d7559c59bfb891f2c624`.
- Deployment: `e9060536e8dc7a70150da9c42d6dfac901713553`.
- Retained web: `f42dc7a0edb9630a8d24f1800191a9de06856cea`.
- Old mobile: `fa75e05910ae1ef003acdd9303bb8b22dfde8aaa`.
- study-birds: `a1da3390c797f485141b1aabf79cb200d43231d4`.
- Old web release: `a6f722636dbf48b25baef6e041ca0c44f62a05d4`.

Current porcelain Git status matches the audit after excluding the expected owner-run audit JSON. This comparison was made before creating this review; the review is an additional expected untracked document. No claim that existing local changes are committed or published.

Fresh protected SHA-256 comparisons against the previous reviewed execution records all pass:

- Existing deployment `app\build\app\outputs\flutter-apk\app-debug.apk`: `9638b98f111bf25b4079555f4a48029d40a4892dc12f48f407b3894b61b9ce23`.
- Deployment `app\android\app\build.gradle.kts`: `2fa29230bac7cb3795ae577e5dc1a627e57e39365f34549ec4f15f63b12b0390`.
- Deployment `app\config\qa_android.pending.json`: `a398ee5cde8131c1b75ab4abab244420ff99866a19bf13a642ba7c99e92bf3aa`.

Primary/deployment Flutter `lib`, backend and website source directories still exist. These are targeted integrity checks, not a new comprehensive source/configuration hash audit.

## Current capacity and feasibility

Current measured free snapshot after the read-only lock checks: **7,833,174,016 bytes (~7.295 GiB)**. Exact snapshot gap to **8,589,934,592 bytes (8 GiB)**: **756,760,576 bytes (~721.70 MiB)**. Free space is dynamic.

**No additional clearly eligible set of 1 GiB, much less 2 GiB, was established under the requested exclusions.** The numbered candidates below total only **190,760,974 logical bytes (~181.92 MiB / 0.178 GiB)**. Even all of them would project free space to only **8,023,934,990 bytes (~7.473 GiB)** and leave **565,999,602 bytes** below 8 GiB before allocation differences. These candidates do not solve the requested capacity gap.

## New numbered candidates — separate approval required

These are exact generated Android project outputs in two older independent repositories, not shared dependency caches or registered protected worktrees. Only the exact listed children are nominated; never their repositories, build parents or siblings. The JNI and Flutter plugin outputs are reproducible from retained project source and installed toolchain/dependencies; no rebuild was run and offline availability for every older project is not guaranteed.

All candidates were recursively inventoried without following links. Git `ls-files` returns zero tracked entries for each; no descendant junction/symlink or hard-linked file was found. No APK/AAB, signing key, certificate, environment file, backup archive or original signing configuration was identified. Generated class/JAR/native libraries, Android resources, dependency/stamp/build metadata may be present; these are project build products, not original plugin source or dependency-cache owners.

Sizes are logical lengths, not independently measured allocated disk clusters. Any reclaim estimate must account for filesystem allocation and fresh verification. No candidates are approved by this report.

1. `D:\work\study-birds\app\build\jni` — **25,501,392 bytes** (24.32 MiB), 782 files. Generated JNI Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

2. `D:\work\studybirds-security-release-20261017-mobile\build\jni` — **21,810,679 bytes** (20.80 MiB), 642 files. Generated JNI Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

3. `D:\work\study-birds\app\build\camera_android_camerax` — **18,996,135 bytes** (18.12 MiB), 2225 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

4. `D:\work\studybirds-security-release-20261017-mobile\build\camera_android_camerax` — **9,407,077 bytes** (8.97 MiB), 981 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

5. `D:\work\study-birds\app\build\google_sign_in_android` — **8,913,629 bytes** (8.50 MiB), 1666 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

6. `D:\work\study-birds\app\build\shared_preferences_android` — **8,750,617 bytes** (8.35 MiB), 1730 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

7. `D:\work\studybirds-security-release-20261017-mobile\build\google_sign_in_android` — **7,810,346 bytes** (7.45 MiB), 1502 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

8. `D:\work\study-birds\app\build\onesignal_flutter` — **7,252,224 bytes** (6.92 MiB), 1532 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

9. `D:\work\studybirds-security-release-20261017-mobile\build\shared_preferences_android` — **6,886,525 bytes** (6.57 MiB), 1512 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

10. `D:\work\studybirds-security-release-20261017-mobile\build\onesignal_flutter` — **6,681,840 bytes** (6.37 MiB), 1430 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

11. `D:\work\study-birds\app\build\local_auth_android` — **6,362,502 bytes** (6.07 MiB), 1489 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

12. `D:\work\studybirds-security-release-20261017-mobile\build\local_auth_android` — **5,753,799 bytes** (5.49 MiB), 1386 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

13. `D:\work\study-birds\app\build\posthog_flutter` — **3,800,405 bytes** (3.62 MiB), 857 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

14. `D:\work\study-birds\app\build\image_picker_android` — **3,732,817 bytes** (3.56 MiB), 744 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

15. `D:\work\study-birds\app\build\flutter_local_notifications` — **3,685,973 bytes** (3.52 MiB), 831 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

16. `D:\work\studybirds-security-release-20261017-mobile\build\video_player_android` — **3,109,704 bytes** (2.97 MiB), 652 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

17. `D:\work\study-birds\app\build\sentry_flutter` — **2,995,668 bytes** (2.86 MiB), 802 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

18. `D:\work\study-birds\app\build\url_launcher_android` — **2,470,175 bytes** (2.36 MiB), 624 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

19. `D:\work\studybirds-security-release-20261017-mobile\build\flutter_local_notifications` — **2,454,130 bytes** (2.34 MiB), 657 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

20. `D:\work\study-birds\app\build\sqflite_android` — **2,405,166 bytes** (2.29 MiB), 729 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

21. `D:\work\studybirds-security-release-20261017-mobile\build\image_picker_android` — **2,332,561 bytes** (2.22 MiB), 554 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

22. `D:\work\studybirds-security-release-20261017-mobile\build\posthog_flutter` — **2,257,104 bytes** (2.15 MiB), 634 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

23. `D:\work\study-birds\app\build\file_picker` — **2,043,283 bytes** (1.95 MiB), 657 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

24. `D:\work\studybirds-security-release-20261017-mobile\build\sentry_flutter` — **2,035,547 bytes** (1.94 MiB), 633 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

25. `D:\work\studybirds-security-release-20261017-mobile\build\url_launcher_android` — **1,957,256 bytes** (1.87 MiB), 531 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

26. `D:\work\study-birds\app\build\flutter_secure_storage` — **1,938,778 bytes** (1.85 MiB), 679 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

27. `D:\work\studybirds-security-release-20261017-mobile\build\sqflite_android` — **1,745,675 bytes** (1.66 MiB), 612 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

28. `D:\work\studybirds-security-release-20261017-mobile\build\sign_in_with_apple` — **1,680,014 bytes** (1.60 MiB), 588 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

29. `D:\work\studybirds-security-release-20261017-mobile\build\file_picker` — **1,628,053 bytes** (1.55 MiB), 588 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

30. `D:\work\studybirds-security-release-20261017-mobile\build\flutter_secure_storage` — **1,546,488 bytes** (1.47 MiB), 600 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

31. `D:\work\study-birds\app\build\connectivity_plus` — **1,503,135 bytes** (1.43 MiB), 633 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

32. `D:\work\study-birds\app\build\package_info_plus` — **1,398,456 bytes** (1.33 MiB), 629 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

33. `D:\work\study-birds\app\build\app_links` — **1,352,571 bytes** (1.29 MiB), 610 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

34. `D:\work\studybirds-security-release-20261017-mobile\build\connectivity_plus` — **1,341,681 bytes** (1.28 MiB), 588 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

35. `D:\work\study-birds\app\build\flutter_plugin_android_lifecycle` — **1,331,502 bytes** (1.27 MiB), 614 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

36. `D:\work\studybirds-security-release-20261017-mobile\build\package_info_plus` — **1,292,616 bytes** (1.23 MiB), 589 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

37. `D:\work\studybirds-security-release-20261017-mobile\build\flutter_plugin_android_lifecycle` — **1,255,781 bytes** (1.20 MiB), 577 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

38. `D:\work\studybirds-security-release-20261017-mobile\build\app_links` — **1,252,233 bytes** (1.19 MiB), 574 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

39. `D:\work\study-birds\app\build\jni_flutter` — **1,082,695 bytes** (1.03 MiB), 605 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

40. `D:\work\studybirds-security-release-20261017-mobile\build\jni_flutter` — **1,004,742 bytes** (0.96 MiB), 571 files. Generated Flutter plugin Android outputs; untracked; no descendant links or hard links; no protected filename matches. Process/lock and rebuild-risk conditions below apply.

### Process, locks and risk

Build-related processes are active in the current session: Java PIDs **21768, 25148, 2956, 9800, 20432** and Dart PIDs **1940, 24496, 35776, 31072** were observed. No process was stopped, and command lines/secrets were not printed. Later process state must be rechecked. These candidates are therefore **CONDITIONAL, NOT READY FOR DELETION**, even when exclusive reads succeed.

For each of candidates 1–40, all ancestor reparse-point checks returned zero; recursive inventories found no descendant links. Every enumerated file was opened read-only with exclusive sharing and then closed: **zero exclusive-access failures for every candidate**. This establishes point-in-time accessibility only, not that the active Java/Dart processes cannot start writing later. Therefore all 40 remain conditional on idle processes and fresh checks at any future approved operation. No cleanup script was generated or executed; these were read-only inspection commands.

For every candidate the risk is loss of that old project's incremental compilation reuse; regeneration takes time and consumes disk again. They are outside the selected deployment QA output root and are not original authentication/push configuration despite plugin names. No runtime QA resource is nominated. Active process uncertainty prevents unconditional safety approval. Before any future deletion, obtain exact-target owner approval and freshly verify inventory, protected contents, Git status, all ancestor/descendant links, hard links and locks with build tooling idle.

## Explicitly excluded

- Quantis entirely; no Quantis capacity is counted.
- All APK/AAB deliverables and duplicate APK copies, including all `build\app\outputs` parents.
- Primary app's junction-backed build outputs on C; D capacity cannot be reclaimed by deleting the junction.
- Protected/registered worktrees and their outputs; the deployment QA manifest evidence and `D:\work\studybirds_qa_phase7` entirely.
- All original source/configuration/signing files, certificates, repositories, Git metadata/checkpoints/backups, dependency caches, Gradle/npm/pub caches, shared `node_modules` and dependency owners.
- Test asset bundles containing generated certificate copies: not nominated.
- Tracked Gradle files in retained web repository: not candidates even though their names look generated.
- Other tiny generated website outputs were observed but not nominated because they cannot provide the missing capacity and may belong to protected worktrees/nested repositories.

## Decision

Owner cleanup is verified complete. No further deletion is authorized or performed. The 1–2 GiB additional-cleanup objective cannot be honestly satisfied from the clearly eligible outputs inspected under these exclusions. Keep the remaining gap explicit; request a separately scoped review if more capacity must be found rather than expanding this list to protected material.

The QA build gate and pending QA configuration remain unchanged. **No APK compilation/assembly approval is granted or implied**, regardless of capacity.
