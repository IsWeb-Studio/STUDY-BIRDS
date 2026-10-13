# Additional login methods and Bird AI

These changes are local source changes. Provider setup and production deployment
are separate steps; blank example variables do not activate a provider.

## Website and server

- Install dependencies with `npm ci` separately in `server` and `client`.
  The new WebAuthn server dependency requires Node.js 20 or later.
- Set `CLIENT_URL` to the actual HTTPS website URL and include its origin in
  `CLIENT_URLS`. The website must serve `/mobile-sign-in` through its SPA fallback.
- Google: set matching `GOOGLE_CLIENT_ID` on the server and
  `VITE_GOOGLE_CLIENT_ID` in the client build. Register the website's JavaScript
  origin in the Google OAuth client settings.
- Apple: set `APPLE_CLIENT_ID` to the web Services ID and `APPLE_REDIRECT_URI`
  to its registered HTTPS return URL. Configure that Services ID and domain in
  Apple Developer. This implementation uses the Apple JS popup and verifies the
  identity token's signature, issuer, audience and one-use nonce on the server.
  An existing local account with the same email is not automatically linked.
- Passkeys: set `WEBAUTHN_RP_ID` to the exact relying-party domain (no scheme or
  port), and `WEBAUTHN_ORIGINS` to the comma-separated allowed HTTPS origins.
  Enrollment currently requires the account's password. Passwordless social
  accounts need to establish a password through email recovery first.
- Phone verification: set `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, and
  `TWILIO_VERIFY_SERVICE_SID` on the server. The last value is a Twilio Verify
  service SID. Numbers use E.164. This verifies the phone of a signed-in account;
  it does not implement passwordless SMS login. Test trial-account restrictions
  and delivery with your own number before launch.
- Email recovery and email-based 2FA still depend on working SMTP credentials.
  The last production SMTP check returned EAUTH; no fix is claimed here.

The Flutter Google/Apple buttons open the website login flow. The website asks
for explicit app-login consent, and the app exchanges a secret proof for a
session. The URL contains a short-lived request ID, never the session token.
The app's device lock uses local biometric/device authentication; website
passkeys are a separate mechanism. Physical-device enrollment remains untested.

## Bird AI

Set server-only `AI_BASE_URL`, `AI_API_KEY`, `AI_MODEL`, and optional
`AI_DAILY_LIMIT` (default 20 attempts per user per UTC day, capped at 100).
The provider must support Chat Completions including `max_completion_tokens`.
The URL must use HTTPS. No provider, paid model, or production key is selected
automatically. Failed provider attempts also count toward the daily limit.

The assistant persists owned conversations and generation token usage. It has
no tools to access records or execute account actions. It is an information
assistant, and does not perform bookings, payments or application submissions.
The mocked provider integration test passed: ownership, persistence, provider failure, and daily quota. No paid provider was called.

## Verification before release

1. Run the backend tests with an isolated MongoDB memory server; no production DB.
2. Build the website and Flutter APK again after the latest assistant changes.
3. Test real Google and Apple login, passkey enrollment/login, and Twilio delivery
   on the configured HTTPS domain. Test app handoff and cancellation on a device.
4. Test locking/unlocking and logout on a physical Android device.
5. Configure production Android application ID and release signing. The current
   debug APK is for testing; an iOS target is not present in this project.

Push notification delivery, chat attachments, full English localization, and
independent consultation/service-booking workflows remain outside the completed
implementation. Current chat updates poll every ten seconds while visible.
