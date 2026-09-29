/// Central app configuration constants.
/// Fill in the values before release.
class AppConfig {
  AppConfig._();

  // PostHog — get from app.posthog.com > Project Settings > Project API Key
  // Leave empty to disable analytics silently.
  static const posthogApiKey = 'phx_CoDdxqf2boidfjFWWWDHERsEfj8n5mn72QpL2Dar868JeRUw';
  static const posthogHost = 'https://us.i.posthog.com';

  // Sentry — crash & performance monitoring (sentry.io > study-birds-mobile > Settings > Client Keys)
  static const sentryDsn =
      'https://11e84bec329882ef21415b9149ed2dff@o4512153224216576.ingest.us.sentry.io/4512153236668416';

  // Google Sign-In — Web Application client ID from Google Cloud Console.
  // Required on Android (no google-services.json).
  // Also add this value to GOOGLE_CLIENT_ID env var on Render.
  static const googleWebClientId = '384879232095-rqr6ifgn90i7goftdqv7ldr0ntl82o6l.apps.googleusercontent.com';
}
