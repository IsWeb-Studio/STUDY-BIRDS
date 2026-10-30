# Final cleanup approval list - Phase 2

Reverified on 21 October 2026. **No deletion is authorized by this report and nothing has been deleted.** The Phase 2 request requires explicit approval for external ZIPs/generated directories. This is a proposal for exactly eight targets, not permission to delete their parent folders.

## 1. C:\Users\Abood\Downloads\study_birds_flutter_app (15).zip

- Type: exact ZIP duplicate. Logical size: 1,227,491 bytes (0.001143 GiB).
- KEEP: `C:\Users\Abood\Downloads\study_birds_flutter_app (14).zip`. Both files still exist and current SHA-256 hashes match: `bb97f264d4e2e5a2802d65edd0fd33aed5baeba3fab849c1cad9954bfde44e26`. Neither is a link. Exact duplicate content, including any internal configuration, remains in the retained archive.
- Recommendation: DELETE CANDIDATE, low redundancy risk after approval. No source repository/worktree is removed.

## 2. C:\Users\Abood\Downloads\study_birds_flutter_app (2).zip

- Type: exact ZIP duplicate. Logical size: 86,287 bytes (0.000080 GiB).
- KEEP: `C:\Users\Abood\Downloads\study_birds_flutter_app (1).zip`. Both files still exist and current SHA-256 hashes match: `e9f813ebb0cf3e7a1453ba02da0c16ab40eb13da81c060c8f9d2e9704ea15bfd`. Neither is a link. Exact duplicate content, including any internal configuration, remains in the retained archive.
- Recommendation: DELETE CANDIDATE, low redundancy risk after approval. No source repository/worktree is removed.

## 3. C:\Users\Abood\Downloads\study_birds_flutter_app (21).zip

- Type: exact ZIP duplicate. Logical size: 1,232,893 bytes (0.001148 GiB).
- KEEP: `C:\Users\Abood\Downloads\study_birds_flutter_app (20).zip`. Both files still exist and current SHA-256 hashes match: `5c2de699f0282f789fe4504e26ec4ac20526753c500562695de9d736fb7507a7`. Neither is a link. Exact duplicate content, including any internal configuration, remains in the retained archive.
- Recommendation: DELETE CANDIDATE, low redundancy risk after approval. No source repository/worktree is removed.

## 4. C:\Users\Abood\Downloads\study_birds_flutter_app (7).zip

- Type: exact ZIP duplicate. Logical size: 1,203,972 bytes (0.001121 GiB).
- KEEP: `C:\Users\Abood\Downloads\study_birds_flutter_app (6).zip`. Both files still exist and current SHA-256 hashes match: `4480f31d68f4d97420f33b11b5cf4b2b5555cc395ed3d5b770328d8c16811616`. Neither is a link. Exact duplicate content, including any internal configuration, remains in the retained archive.
- Recommendation: DELETE CANDIDATE, low redundancy risk after approval. No source repository/worktree is removed.

## 5. C:\Users\Abood\Downloads\study_birds_flutter_app (9).zip

- Type: exact ZIP duplicate. Logical size: 1,213,415 bytes (0.001130 GiB).
- KEEP: `C:\Users\Abood\Downloads\study_birds_flutter_app (10).zip`. Both files still exist and current SHA-256 hashes match: `cca8e7228726d1994170934be05dcc6ac67d813fa391fb31fef61c986bea6b6f`. Neither is a link. Exact duplicate content, including any internal configuration, remains in the retained archive.
- Recommendation: DELETE CANDIDATE, low redundancy risk after approval. No source repository/worktree is removed.

## 6. C:\Users\Abood\Downloads\study_birds_test_app.zip

- Type: exact ZIP duplicate. Logical size: 1,243,049 bytes (0.001158 GiB).
- KEEP: `C:\Users\Abood\Downloads\study_birds_flutter_app (25).zip`. Both files still exist and current SHA-256 hashes match: `b64b46d7009d146e4525f4b4bf50a13ab7f1c59af1f8e1b1b92cf8e1a4e15482`. Neither is a link. Exact duplicate content, including any internal configuration, remains in the retained archive.
- Recommendation: DELETE CANDIDATE, low redundancy risk after approval. No source repository/worktree is removed.

## 7. D:\work\studybirds-security-release-20261017-mobile\build\app\intermediates

- Type: generated Android intermediates. Logical size: 1,393,909,198 bytes (1.298179 GiB).
- Current resolved path: `D:\work\studybirds-security-release-20261017-mobile\build\app\intermediates`; ordinary directory, not a junction; 1867 files. Size unchanged since Phase 1; no nested links, signing keystores, .env files, APKs or AABs found in target.
- These are Gradle application intermediates in an old source copy. The parent/source repository was clean in Phase 1; no target files were tracked. Source, signing files and build outputs outside this exact subdirectory remain. Generated contents are rebuildable; no original application module or independent data store was identified.
- Recommendation: DELETE CANDIDATE, medium risk/cost because rebuilding takes time. Recheck the parent's Git state and that no build uses it immediately before an approved deletion. This is not byte-for-byte source duplication.

## 8. D:\work\study-birds\app\build\app\intermediates

- Type: generated Android intermediates. Logical size: 2,178,289,197 bytes (2.028690 GiB).
- Current resolved path: `D:\work\study-birds\app\build\app\intermediates`; ordinary directory, not a junction; 2680 files. Size unchanged since Phase 1; no nested links, signing keystores, .env files, APKs or AABs found in target.
- These are Gradle application intermediates in an old source copy. The parent/source repository was clean in Phase 1; no target files were tracked. Source, signing files and build outputs outside this exact subdirectory remain. Generated contents are rebuildable; no original application module or independent data store was identified.
- Recommendation: DELETE CANDIDATE, medium risk/cost because rebuilding takes time. Recheck the parent's Git state and that no build uses it immediately before an approved deletion. This is not byte-for-byte source duplication.

## Totals and exclusions

- C ZIP subtotal: 6,207,107 bytes (5.92 MiB).
- D intermediates subtotal: 3,572,198,395 bytes (3.327 GiB).
- Combined: 3,578,405,502 logical bytes (3.333 GiB). Physical NTFS space recovered may differ. Parent-directory sizes overlap and must not be added.

The active app's build and flutter_build junctions point to C; neither target is on this list. The active app, API, website, their shared dependency/junction owners, old repositories, backups, other ZIPs, delivered APKs, .env files and signing keys are all retained. No copy with valuable pending work is a deletion target.

Approval must identify these exact targets (all eight or a specific numbered subset). Before acting, recheck paths/hashes/links and avoid any recursive operation on a computed or unverified parent path. If anything changed, stop that deletion and revise the proposal. No removal command has been executed.
