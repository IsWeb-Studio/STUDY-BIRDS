# Private student document delivery

New student Document uploads use Cloudinary `raw` assets with delivery type `authenticated`, UUID-based public IDs and no public delivery URL in API responses. The stored filePath is `/api/documents/:id/access`; clients POST to it with their existing session to obtain a download link valid for 120 seconds. Storage descriptors are excluded from default queries and upload responses.

## Authorization

- The owning student and admins.
- Employees with applications or student-documents permission.
- Parents with an approved ParentLink to the owner.
- University accounts only while the file is attached to an application for their linked university.
- Others receive 404; missing sessions receive 401. Authorization is checked each time a new link is issued. An already issued link remains a bearer capability until its expiry; session revocation does not cancel an existing Cloudinary URL.

The public content/file-open helper rejects private/authenticated delivery types and the private-documents namespace. It continues serving existing public content.

## Payment proofs

New PaymentProof uploads use the same authenticated storage. Their filePath is `/api/payment-proofs/:id/access`. Access requires the owner, an admin, an employee with student-financials permission, or an approved linked parent. Applications permission alone does not grant access, and university accounts cannot access proofs. Both clients request a fresh signed link using their session.

## Support attachments

New student and partner SupportTicket attachments use authenticated storage and `/api/support-attachments/:id/access`. Only the ticket owner, admin or employee with support permission may obtain a 120-second link. Parent links, financial permissions and applications permissions do not grant access. The website student, partner and admin ticket views and the Flutter ticket detail show attachment links with error handling. Existing attachments retain legacy links; no migration was executed.

## Scope and rollout

Deploy the website and API changes together; use the updated Flutter build. All existing CLOUDINARY_* configuration remains required; no new secrets were introduced. Verify real PDF and image downloads on a staging account, unsigned authenticated asset denial, expiration after 120 seconds, and cross-account denial before production rollout. Unit/integration tests use the real signing SDK with dummy credentials and a mocked upload stream; they do not establish provider configuration or live expiry enforcement.

New Document, PaymentProof and student/partner SupportTicket attachments are covered. Existing files and partner VerificationDocument uploads keep their previous storage behavior. The shared website link component preserves legacy links. Old student files cannot use the private access endpoint until migrated (409).

## Legacy migration — not executed

1. Inventory old Document and PaymentProof entries and all other references to their Cloudinary assets. Keep a database backup and a mapping of old and new references.
2. Copy each original to authenticated storage; verify its bytes, MIME type and ownership. Do not delete originals yet.
3. Update only the corresponding Document or PaymentProof storage descriptor and filePath after successful verification. Recheck all applications and authorized viewers.
4. After coordinated rollout and explicit migration approval, restrict or remove the old public assets and invalidate cached public copies. Updating the database alone does not revoke previously shared public URLs.
5. Verify old URLs no longer deliver content. Keep a recovery plan and complete the audit before declaring legacy data private.

References: [Cloudinary media access controls](https://cloudinary.com/documentation/control_access_to_media), [Upload/download API](https://cloudinary.com/documentation/image_upload_api_reference).
