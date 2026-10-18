# Verification document storage and upload policy

New verification documents use authenticated Cloudinary storage. Listings return only `/api/verification-documents/:id/access`; the POST download endpoint allows the owner, admins and employees with the `verification` permission. Links expire after 120 seconds and responses use no-store headers.

Public uploads use UUIDs and overwrite:false and reject reused/overwritten results. The public helper refuses the verification-document folder.

## Upload formats

PDF, JPG/JPEG, PNG, WEBP and TXT remain supported, up to 5 MiB per file. Office and ZIP are blocked until bounded structural inspection and malware scanning are implemented. Existing private documents remain downloadable. Signature checks alone are not a malware scanner.

## Existing public verification documents

Deploy the server and updated clients. Unmigrated documents return 409; public URLs are hidden in API responses. From server/ with the intended environment configured:

```powershell
node scripts/migrateVerificationDocuments.js
node scripts/migrateVerificationDocuments.js --apply
```

The first command is a dry-run. The second moves owned assets under study-birds/agent-verification/ to authenticated delivery, requests CDN invalidation and checks that the original object is no longer accessible through the provider API before recording success. Failures return a nonzero status and are retriable. CDN invalidation may take time to propagate. Do not consider the migration complete until all candidates succeed.

Source cloud ownership and folder are validated; no arbitrary URL is fetched. Previous URLs are kept only in a non-selected reconciliation field, never in client responses. Production deployment and migration were not executed during implementation.

## Verification

The uploadSecurity.test.js suite uses temporary MongoDB and fake Cloudinary methods. It checks MIME/extension restrictions, unique IDs under a frozen clock, overwrite refusal, private upload, owner/section authorization, temporary links, legacy URL redaction and safe migration retries.
