# Community publishing release fix

The hosted API health response reported commit
`9603a4c4fa24d12220367eecc24ad267dd32d8ac` during investigation. That exact
commit only exposes student text posts with a required title. It has no
`POST /api/community/posts/image` route or emoji reaction routes. The current
mobile photo publisher therefore receives a 404 even though the new server
implementation exists in a different local working copy.

This branch is based on that hosted commit and contains the complete scoped
community implementation: optional-title text posts, private image publishing,
authorized photo reads, idempotent publish operations, administrator filtering,
replaceable emoji reactions and post/comment edits. Existing moderation,
blocked-word, suspension, ownership and file validation checks remain active.
New reaction/block records and post images are included in account cleanup.

## Deployment

Publish/merge this fix into the repository and branch actually connected to the
API Render service, then deploy that new commit. Redeploying the old commit
without the fix cannot activate the missing endpoints. Use the existing
`server` root and `npm start`; no environment variable or dependency change is
required. Cloudinary configuration already used by chat images is reused.

After deployment, request:

`https://study-birds1.onrender.com/api/mobile/capabilities`

It must include `communityPosts.version: 2`, with `images`, `optionalTitle`,
`reactions` and `administrationFilter` all true. Verify that `/api/health`
reports the new deployed commit as well. A mobile rebuild is not required
for this server compatibility fix.

## Validation

Five community integration/regression tests passed against temporary isolated
MongoDB instances. The new publishing test mounts the actual application and
calls `/api/community/...`, rather than only testing an isolated router. It
covers text-only publishing without a title, private photo publishing and
retry deduplication, administration filtering, reactions, edits, unauthorized
access, hidden posts, suspensions, image cleanup and the capability marker.
Cloudinary was mocked; no production users, posts or databases were changed.
