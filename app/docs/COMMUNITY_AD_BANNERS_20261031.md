# Administration adverts in Student Community

Community shows active admin banners above All posts / My posts / Administration posts. These adverts are separate from feed posts. If no eligible banners exist, the carousel occupies no space and shows no seeded promotion.

The same Community placement also appears in the inbox/stories page opened from the top Community icon, between Stories and Messages. Pull-to-refresh updates it there too. Small story/banner sections retain their state while scrolled out of view; posts remain lazy. Private post images use an account/token-scoped, memory-only LRU (12 images / 20 MB), coalescing concurrent requests and painting saved bytes immediately. Logout/account changes clear the cache and reject late old-session responses. Evicted images still load normally when revisited. Unchanged inbox polling responses no longer rebuild the whole inbox; new messages continue to update.

On mobile, open the administrator's content management → Banners. On web, open `/admin/banners`. Add the title, optional image/subtitle/button, choose Home, Student Community or both, set the order and enable the banner. Save, edit, hide and delete use the existing admin-only routes. The mobile placement selector is a dropdown, not a code the administrator must type.

Existing banners without a placement remain on Home. Home queries default to Home; Community requests `placement=community`. Server filtering excludes inactive or other-placement content, and the client filters defensively for older servers. Pulling to refresh Community fetches current ads without the local response cache. Normal loads retain local-first behavior. Server mutations invalidate cached public banner responses.

Upload now returns the actual image URL from the storage helper, fixing the prior object/string mismatch. Partial updates preserve omitted content. Destinations retain the existing internal universities, programs, applications and services flow.

Validation covers server placement/active filtering, legacy Home records, student write denial, image URL response, partial updates and cached mutation visibility. Flutter checks cover mobile-admin creation, community selection, refresh/removal, navigation and absence of fallback ads, plus community posting/profile regressions. The web TypeScript/production build is checked. Render must deploy the server and web changes; the app must be updated too.
