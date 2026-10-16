# iOS social sign-in

Bundle identifier: `com.studybirds.studyBirds`.

## Google

Create an **iOS** OAuth client for this bundle in the Google Cloud project that
owns the existing web client. The web client cannot be used as the iOS client.
Configure the real iOS ID before building:

```sh
python3 tools/configure_ios_google.py --client-id YOUR_IOS_CLIENT_ID.apps.googleusercontent.com
flutter pub get
flutter build ipa
```

This writes `ios/Flutter/GoogleSignIn.xcconfig`, which both Xcode configurations
include. `GIDClientID` and the reversed callback scheme use the iOS ID;
`GIDServerClientID` remains the web ID accepted by the backend. No client secret
belongs in the app. The supplied iOS client ID is configured in the xcconfig;
rebuild the signed iOS app for it to take effect.

## Apple

The login and registration buttons invoke the native Apple authorization sheet.
They do not open the browser sign-in screen. The backend verifies the Apple
signature, issuer, expiration, exact bundle audience and one-time server nonce.
Two-factor email verification remains required for accounts that enabled it.
Apple-only accounts do not need to create a local password to enter or restore
their session.

Enable **Sign in with Apple** for this App ID in Apple Developer and regenerate
the signing profile (or use Xcode automatic signing). The entitlement is included
in `Runner.entitlements`. This native flow does not require a web Services ID or
redirect URL. The server audience defaults to the bundle above; set
`APPLE_IOS_BUNDLE_ID` only if releasing with a different bundle identifier.

Run a signed iPhone build to validate Google account selection, Apple first and
returning logins, cancellation, private email relay, and optional two-factor
verification. Windows cannot produce or run an iOS build; automated tests use
mock native credentials and locally signed test Apple tokens.
