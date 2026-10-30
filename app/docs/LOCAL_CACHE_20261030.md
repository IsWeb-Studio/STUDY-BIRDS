# COVEY local-first cache

Implemented 2026-10-30. Previously visited eligible pages can paint saved data
before a network read, including after the process restarts. The first visit
still needs a successful download. Session verification remains unchanged.

## Storage and policies

- `ResponseCachePolicy` is an explicit endpoint policy, not a blanket GET cache.
- Public catalog/content: 30-minute freshness, maximum retained age 24 hours.
- Scholarship/accommodation listings: 10-minute freshness, six-hour retained age.
- Eligible personal summaries: 45-second freshness, 24-hour retained age.
- Stories, community, friends and messaging use only short in-session memory.
- Auth, security, payment/financial/wallet/access URLs, appointment slots and
  game state bypass these caches. Private media `no-store` remains respected.
- Every restored disk response is shown first and revalidated in the background.
- Public JSON uses app temporary files, limited to 120 files / 8 MB total and
  2 MB per response. The OS may evict this expendable cache.
- Private summaries use FlutterSecureStorage with 40 records / 2 MB total and
  128 KB per record. Large administrative directories are not persisted.
- Memory responses are bounded to 160 entries / 8 MB of encoded JSON payloads.
  Actual runtime object memory is larger and must be profiled on devices.
- Scope includes user, role, employee role, linked university and permissions.
  Disk keys contain no session token; token rotation retains the same scope.
- Stored URLs include API origin and normalized query parameters, preventing
  sharing between environments or filters. Reads return independent JSON copies.

## Refresh and invalidation

- Cache generations prevent an earlier network response from repopulating a
  cache after a mutation or logout. Store operations serialize writes/cleanup.
- Successful mutations invalidate related resources on disk and in memory.
- Visible screens listen for background changes. Updates arriving while hidden
  remain pending until the route/application becomes visible again.
- Screens retain existing content during refresh. Major read pages identify
  saved data with the original save date/time.
- The foreground sync bus no longer clears all caches every tick; its fallback
  interval is 30 seconds. Explicit actions and foreground push still refresh.
- A 401/403/404/410 removes the affected stored response rather than using it
  as an offline fallback. Server operations always enforce current permissions.

## Other changes

- Favorite IDs are account-scoped; failed optimistic updates roll back and
  their UI callers handle errors. Legacy unscoped keys are discarded.
- Last successful display exchange rates survive restarts for up to 24 hours,
  with background renewal after six hours; payment settlement stays server-side.
- Public images use a shared bounded cache manager and display-sized decoding.
- Document thumbnails/previews and signed private Cloudinary URLs do not enter
  the public disk image cache. Logout clears image memory and private snapshots.
- Security settings include a cache-cleaning action. It removes disposable
  response/image caches, not accounts, documents, credentials or saved drafts.

## Verification and limits

Tests cover actual files read by a new cache-store instance; account separation;
queued writes versus logout; cold-client reads; stale background updates; a
widget painting saved content before the network completes; no extra loading
screen on refresh; mutation invalidation; expired/future timestamps; no-store;
and sensitive endpoints bypassing persistence.

This does not promise offline writes, permanent downloads, cached bank balances
for transactions, or offline authorization. It does not add video prefetch or a
server cache/Redis. Real-device release-mode profiling is still needed to measure
latency, frame times, RAM, storage pressure and actual mobile network savings.

Existing large legacy secure snapshots are no longer used as the general
network-failure fallback; their logout cleanup remains for installed versions.
