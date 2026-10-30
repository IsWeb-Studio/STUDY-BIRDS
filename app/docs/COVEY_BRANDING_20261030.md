# COVEY branding

The application display name, localized copy, assistant name, community labels,
reminders, sharing text, website copy, server messages and email branding now use
COVEY. Android and iOS launcher assets were regenerated. Existing service URLs,
package and bundle IDs, API headers, storage keys and login/deep-link contracts
remain compatible with installed accounts and current services.

## Assets

- `assets/images/branding/covey_logo.jpg`: original supplied circular logo,
  unchanged. `logo_mark.png`, `logo_full.png` and `logo.png` are PNG conversions.
- `assets/images/branding/covey_icon.png`: square icon prepared from the supplied
  mark with reduced outer margins; feeds native launcher/launch-screen assets.
- `assets/images/branding/covey_splash.png`: supplied twelve-panel image with its
  old footer replaced by COVEY. Flutter displays the entire image using contain
  fitting on white; it retains the existing 1.8-second navigation timer.
- `assets/images/games/wink_back.png`: COVEY version of the card-back artwork.
- `D:/work/studybirds_web/server/assets/email/header.png` and `logo.png`:
  updated email branding, with asset cache versions advanced to 20261030.
- `D:/work/studybirds_web/client/public/logo.jpeg`: original supplied mark.
- `integration/previews/covey-splash.png`: actual Flutter phone preview.

Android's OS launch stage uses the circular mark; the detailed splash appears
when Flutter starts. iOS launch artwork is constrained to avoid clipping.

## Image preparation provenance

Built-in image generation/editing was used, without the CLI/API fallback.
The original logo pixels remain the source for in-app marks. An initial
transparent candidate was rejected because of edge artifacts and is not used.
Selected generated images were copied into the application/server workspaces.

Final prompt set:

1. **Splash:** Preserve the exact supplied portrait 3-column by 4-row study
   abroad collage, its twelve photos/headings, circular logo and decorations;
   change only the footer `Sponsored by Study Birds` to centered `COVEY`,
   preserving its gray-blue style and the complete portrait composition.
2. **Launcher:** Preserve the supplied circular C/bird silhouette and green
   color; remove excess outer white margin so the mark fills about 82 percent
   of a square white canvas, with clean opaque edges, no text or shadows.
3. **Email header:** Rebrand the existing wide welcome banner using the
   supplied circular green logo, `Welcome to COVEY`, COVEY backpack marks and
   lime accents; retain the students, landmarks, flag row and remaining copy.
4. **Card back:** Preserve the ornate navy portrait card background and border;
   replace the central old bird logo and name with the supplied green C/bird
   mark and bold `COVEY`, with navy showing through its negative spaces.

## Verification and rollout

Full Flutter suite: 590 passed. Static analysis passed. Actual phone splash
preview inspected. Website production build passed. Email branding tests: ten
passed; community/media/account integration tests also passed against an
isolated temporary database with provider calls mocked.

Android debug APK built successfully. iOS assets were prepared but an iOS build
requires macOS/Xcode. Nothing was committed, pushed, deployed or published.
Install the new mobile build and deploy the updated server/website on Render.
If sender/site display names are overridden by Render environment variables,
set those existing display-name overrides to COVEY as part of deployment.
