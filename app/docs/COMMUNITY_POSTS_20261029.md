# Community posts, optional photos and reactions

The community now uses “New post”, “All posts”, “My posts” and “Administration posts”. The administration filter is a server query over actual administrator accounts, never a client-supplied flag. Public author data includes role and verified university identity; administrator posts display their identity badge and a dedicated label.

Posts support a required text body (up to 5,000 characters), an optional title (up to 150 characters), and an optional JPEG/PNG/WebP photo (up to 5 MB). Selecting or removing a photo is local until Publish. Multipart publishing validates the same content, suspension and blocked-word rules as text publishing. The operation ID belongs to the authenticated author and prevents duplicate sends/re-uploads after an uncertain response. Changes to the draft issue a fresh operation ID.

Photos use authenticated Cloudinary image storage. API responses expose a protected image path without storage identifiers. Image reads enforce authentication, post visibility, ownership, block rules and authorized moderation access. Deleting a post or an account includes its stored photos; deleting a post also removes its reactions. Account deletion removes the departing user's reactions on other posts.

Seven reactions are available: heart, thumbs up, 100, laughter, surprise, trophy and applause. A unique `(post, user)` index permits one reaction per person; selecting another replaces it, and removal is idempotent. Counts and the viewer's selected reaction are returned on feeds, threads and writes. Hidden posts, blocked relationships and suspensions restrict reaction writes. The existing like endpoints remain compatible.

The admin web community page includes an admin-only publisher, with an optional photo. Its moderation detail can load the protected photo. Other existing moderator permissions remain in place. The general community API accepts the roles already exposed by the mobile community: student, parent, university, employee and admin; agent/partner accounts remain excluded.

## Deployment

Follow-up: The owner confirmed that the community server changes have not yet been deployed. Photo publishing and emoji reaction routes require that server update; mobile-only updates cannot activate those endpoints. The embedded community uses a bottom floating New post button beside the retained AI button, with spacing to prevent overlap. The three student navigation destinations have a rounded, elevated bar with a navy selected state. A publishing 404 preserves the draft and reports service unavailability rather than incorrectly saying that a new post was removed.

Update the server and web client in `D:\work\studybirds_web` on Render, then distribute/install a fresh mobile build. Deploy the server first so the new image/reaction endpoints exist before clients use them. Mongoose creates additive post-operation and reaction uniqueness indexes; existing posts without operation IDs are unaffected. Existing Cloudinary configuration is reused. No production service, database or provider setting was changed and no deployment was performed.

## Validation

The full Flutter suite passed 589 tests. Focused tests cover administration filtering, text-only publishing without a title, photo publishing, replacing/removing reactions and existing comments, editing, reporting and moderation. Six isolated backend tests passed, including concurrency, authorization, hidden content, suspension, private media delivery and account deletion. The web production build passes. Native device photo-picker behavior and platform emoji rendering still need device QA; all uploads in these tests were mocked.
