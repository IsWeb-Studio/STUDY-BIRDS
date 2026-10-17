# Web session security

The browser keeps access tokens only in the in-memory session store. Existing
`studyBirdsToken` localStorage entries are removed; an old browser session without
a refresh cookie must sign in again after upgrading. No refresh token is returned
in web JSON responses. Mobile JSON refresh credentials remain supported.

The server issues a host-only HttpOnly refresh cookie scoped to `/api/auth` for
requests marked `X-Study-Birds-Client: web`. Mutating web authentication requests
must carry an Origin in the existing CLIENT_URL / CLIENT_URLS allowlist. Browser
JSON cannot override the refresh cookie. Production cookies use Secure and
SameSite=None to support the current separate frontend/API origins; local HTTP
development uses SameSite=Lax. JWT access tokens issued to the web last 15 minutes.
Refresh credentials retain the existing 30-day expiry and atomic single-use rotation.

The client sends credentials, restores sessions through POST /auth/refresh, and
rotates credentials every ten minutes while mounted. Failed authentication is
not treated like a resource authorization failure: resource 403 does not log out
the user. An authenticated resource 401 clears only the matching current session.
Stale asynchronous results cannot modify newer sessions. Password changes update
the shared in-memory token read by both React and Axios.

Login, refresh, and logout requests are serialized in each tab; Web Locks also
serializes them across tabs where supported. Other tabs clear their displayed
session when an account is replaced or signs out. Storage contains only logout
signals and an offline logout retry flag, never credentials. Logout revocation is
retried at startup/reconnect before restoring a cookie session.

## Deployment

Deploy the backend and frontend together. Verify CLIENT_URL / CLIENT_URLS contains
the exact deployed frontend origins. Test login, reload, refresh, password change,
and logout using the actual supported browsers and deployment domains.

Browsers may block third-party cookies when frontend and API are on different
sites, even with SameSite=None. Use same-site custom domains or an API reverse
proxy for reliable persistence. There is intentionally no localStorage credential
fallback when cookies are blocked. Local unit/HTTP tests do not establish that a
production browser accepts cookies under its privacy policy.

The rich-text renderer continues to use escaped React text nodes and HTTP(S)
links. No raw HTML renderer or sanitizer dependency was introduced.
