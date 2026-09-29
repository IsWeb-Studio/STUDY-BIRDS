import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:posthog_flutter/posthog_flutter.dart';
import 'app_config.dart';
import 'auth_session.dart';

/// Analytics layer wired to PostHog.
/// Set AppConfig.posthogApiKey before release to activate.
/// All calls are fire-and-forget and never throw to the caller.
///
/// PRD بند 91: Product Analytics
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  bool _ready = false;

  Future<void> init() async {
    if (AppConfig.posthogApiKey.isEmpty) return;
    try {
      final config = PostHogConfig(AppConfig.posthogApiKey)
        ..host = AppConfig.posthogHost
        ..debug = kDebugMode
        ..captureApplicationLifecycleEvents = true;
      await Posthog().setup(config);
      _ready = true;
    } catch (e) {
      if (kDebugMode) print('[Analytics] PostHog init failed: $e');
    }
  }

  Future<void> identify(String userId, {Map<String, dynamic>? traits}) async {
    if (!_ready) return;
    try {
      final props = traits?.map((k, v) => MapEntry(k, v as Object));
      await Posthog().identify(userId: userId, userProperties: props);
    } catch (_) {}
  }

  Future<void> reset() async {
    if (!_ready) return;
    try { await Posthog().reset(); } catch (_) {}
  }

  Future<void> track(String event, [Map<String, dynamic>? props]) async {
    final userId = AuthSession.instance.currentUser?.id ?? 'anonymous';
    if (kDebugMode) print('[Analytics] $event ${props ?? ''}');
    if (!_ready) return;
    try {
      await Posthog().capture(
        eventName: event,
        properties: {'userId': userId, ...?props},
      );
    } catch (_) {}
  }

  // ── convenience wrappers ──────────────────────────────────────────────────

  Future<void> screenView(String screenName) async {
    if (kDebugMode) print('[Analytics] screen: $screenName');
    if (!_ready) return;
    try { await Posthog().screen(screenName: screenName); } catch (_) {}
  }

  Future<void> buttonTap(String button, {String? screen}) =>
      track('button_tap', {'button': button, if (screen != null) 'screen': screen});

  Future<void> documentUploaded(String docType) =>
      track('document_uploaded', {'type': docType});

  Future<void> consultationBooked(String consultantId) =>
      track('consultation_booked', {'consultant': consultantId});

  Future<void> applicationViewed(String applicationId) =>
      track('application_viewed', {'id': applicationId});

  Future<void> paymentInitiated(String invoiceId, double amount) =>
      track('payment_initiated', {'invoice': invoiceId, 'amount': amount});

  Future<void> searchPerformed(String query, {String? category}) =>
      track('search', {'query': query, if (category != null) 'category': category});

  Future<void> universityViewed(String universityId) =>
      track('university_viewed', {'id': universityId});

  Future<void> programViewed(String programId) =>
      track('program_viewed', {'id': programId});

  Future<void> onboardingCompleted() => track('onboarding_completed');

  Future<void> loginCompleted(String role) =>
      track('login_completed', {'role': role});

  Future<void> referralShared(String code) =>
      track('referral_shared', {'code': code});

  Future<void> birdAiOpened() => track('bird_ai_opened');
}
