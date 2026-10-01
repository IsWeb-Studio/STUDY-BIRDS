/// Central app configuration constants.
/// Fill in the values before release.
class AppConfig {
  AppConfig._();

  // PostHog — injected at build time via --dart-define=POSTHOG_API_KEY=phx_...
  // Leave empty to disable analytics silently.
  static const posthogApiKey = String.fromEnvironment('POSTHOG_API_KEY', defaultValue: '');
  static const posthogHost = 'https://us.i.posthog.com';

  // Sentry — crash & performance monitoring (sentry.io > study-birds-mobile > Settings > Client Keys)
  static const sentryDsn =
      'https://11e84bec329882ef21415b9149ed2dff@o4512153224216576.ingest.us.sentry.io/4512153236668416';

  // Google Sign-In — Web Application client ID from Google Cloud Console.
  // Required on Android (no google-services.json).
  // Also add this value to GOOGLE_CLIENT_ID env var on Render.
  static const googleWebClientId = '495236497658-q78f4513t3rj6neonktm49h2h3tlickf.apps.googleusercontent.com';
}
