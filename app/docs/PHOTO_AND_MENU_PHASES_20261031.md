# Requested photo/menu work — 2026-10-31

Work is delivered in separate testable phases.

## Phase 1 — menu and sponsorship

- Persistent Refer Friends button in the student menu opens the existing friends search/request screen. It does not copy an invite link or grant friendship automatically.
- Exact `Sponsored by Study Birds` credit below the COVEY splash identity and below the menu sign-out action.
- Small-screen, large-text, splash geometry and menu navigation checks. No backend behavior change or new permissions.

## Phase 2 — story photo editor (implemented)

- Shared photo editor for text, drawing, emoji stickers, crop/rotate, filters, blur and visual adjustments, using pro_image_editor 11 (compatible with the current Flutter app). Source photos are never overwritten.
- User explicitly selected a local audio file, not a licensed online music library.
- Preview and explicit publication after editing; cancel must preserve the source and never publish.
- Optional local MP3/M4A/WAV up to 60 seconds and 10 MB. Preview supports playback/removal. This phase does not include an online music library, audio trimming or recording.
- Edited photo bytes are uploaded as the story image. The soundtrack is a separate Cloudinary MP3, with an owner/expiry upload record. Only the uploader can attach it to a photo story; arbitrary URLs and client-supplied duration are rejected. The viewer plays it alongside the image and pauses it on hold, navigation and backgrounding. A failed soundtrack leaves the image readable.
- Image/video stories without audio and administrator audience selection remain supported. Admin photos use the same editor and return to the existing publish form.
- Story deletion, expiry and account deletion include audio cleanup. Pending abandoned uploads are queued for expiry cleanup.
- Backend deployment on Render is required for `/stories/audio` and the audio fields. Old clients can still read the image without the soundtrack.
- Automated validation covers exported byte handoff, cancel, narrow Arabic layout, soundtrack lifecycle, media validation, ownership, expiry, idempotency, cleanup and existing story regressions. Native playback on a real phone and a real Cloudinary upload still need a device smoke test after deployment.

## Phase 3 — community post image editor (implemented)

- Reuse the shared photo editor when selecting/changing a post attachment.
- Retain optional-image publishing and required body validation.
- Verify edited image bytes reach the post upload rather than only changing the local preview.
- Picking a photo opens the shared editor in post mode, with no soundtrack controls (post attachments support images; story soundtracks remain in phase 2). Use photo accepts the result; cancelling retains the prior attachment.
- An explicit Edit photo button reopens the accepted draft image. Picking/editing/removal creates a new publish operation ID, while retry of the same unchanged draft retains its ID.
- Regression test exports different JPEG bytes and checks those exact bytes and the matching filename in the outgoing multipart post. Text-only publishing, required-body validation and inline post navigation remain covered.
- No new server endpoint is needed for post images. The assistant guide content is updated to explain this workflow.

The student friends search screen remains accessible from the account as well as the new shortcut. Existing app name COVEY is retained; the explicitly requested Study Birds sponsorship is only a credit.
