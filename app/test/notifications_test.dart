import 'package:study_birds/core/utils/notification_links.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/repositories/student_repository.dart';
import 'package:study_birds/screens/home_journey/notifications_screen.dart';
import 'package:study_birds/screens/services_support/services_consultation_screens.dart';
import 'package:study_birds/screens/home_journey/journey_tracker_screen.dart';
import 'package:study_birds/screens/applications_documents_payments/documents_screens.dart';
import 'package:study_birds/screens/applications_documents_payments/payments_screens.dart';
import 'package:study_birds/screens/applications_documents_payments/applications_screens.dart';
import 'package:study_birds/screens/visa_travel_accommodation/visa_travel_screens.dart';
import 'package:study_birds/screens/visa_travel_accommodation/accommodation_arrival_screens.dart';
import 'package:study_birds/screens/services_support/support_team_ai_screens.dart';
import 'package:study_birds/screens/community/student_community_hub.dart';
import 'package:study_birds/screens/services_support/messaging_and_emergency_screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('notification inbox uses the role-neutral authenticated API', () async {
    AuthSession.instance.token = 'notifications-role-test';
    final requests = <http.Request>[];
    ApiClient.instance.clearCache();
    try {
      await http.runWithClient(() async {
        await StudentRepository.instance.getNotifications();
        await StudentRepository.instance.markNotificationRead('notice-id');
        await StudentRepository.instance.markAllNotificationsRead();
      },
          () => MockClient((request) async {
                requests.add(request);
                return http.Response('[]', 200,
                    headers: {'content-type': 'application/json'});
              }));
      expect(requests.map((request) => request.url.path), [
        '/api/content/notifications',
        '/api/content/notifications/notice-id/read',
        '/api/content/notifications/read-all',
      ]);
      expect(
          requests.map((request) => request.method), ['GET', 'PATCH', 'PATCH']);
    } finally {
      AuthSession.instance.token = null;
      ApiClient.instance.clearCache();
    }
  });

  // ── notificationScreenForLink ─────────────────────────────────────────────

  group('notificationScreenForLink', () {
    test('custom links preserve student host and reject other websites', () {
      expect(notificationPath('studybirds://student/payments'),
          '/student/payments');
      expect(notificationPath('https://studybirds.app/student/documents'),
          '/student/documents');
      expect(
          notificationPath('https://untrusted.test/student/payments'), isNull);
      expect(notificationPath('//untrusted.test/student/payments'), isNull);
      expect(
          notificationScreenForLink('payments'), isA<PaymentsSummaryScreen>());
    });
    test('null link returns null', () {
      expect(notificationScreenForLink(null), isNull);
    });

    test('global notification inbox links are safe for every account role', () {
      expect(notificationLinkAllowedForRole('/student/notifications', isStudent: false), isTrue);
      expect(notificationLinkAllowedForRole('/student/journey', isStudent: false), isFalse);
      expect(notificationLinkAllowedForRole('/student/journey', isStudent: true), isTrue);
      expect(notificationLinkAllowedForRole('https://untrusted.test/student/notifications', isStudent: false), isFalse);
      expect(notificationScreenForLink('/student/notifications'), isA<NotificationsScreen>());
    });

    test('link without /student/ prefix returns null', () {
      expect(notificationScreenForLink('/admin/something'), isNull);
      expect(notificationScreenForLink('consultations'),
          isA<ConsultationBookingScreen>());
      expect(notificationScreenForLink(''), isNull);
    });

    test('/student/consultations → ConsultationBookingScreen', () {
      expect(notificationScreenForLink('/student/consultations'),
          isA<ConsultationBookingScreen>());
    });

    test('/student/journey → JourneyTrackerScreen', () {
      expect(notificationScreenForLink('/student/journey'),
          isA<JourneyTrackerScreen>());
    });

    test('/student/visa → JourneyTrackerScreen', () {
      expect(
          notificationScreenForLink('/student/visa'), isA<VisaCenterScreen>());
    });

    test('/student/documents → MyDocumentsScreen', () {
      expect(notificationScreenForLink('/student/documents'),
          isA<MyDocumentsScreen>());
    });

    test('/student/upload-document → MyDocumentsScreen', () {
      expect(notificationScreenForLink('/student/upload-document'),
          isA<MyDocumentsScreen>());
    });

    test('/student/payments → PaymentsSummaryScreen', () {
      expect(notificationScreenForLink('/student/payments'),
          isA<PaymentsSummaryScreen>());
    });

    test('/student/applications → ApplicationsListScreen', () {
      expect(notificationScreenForLink('/student/applications'),
          isA<ApplicationsListScreen>());
    });

    test('/student/travel → ArrivalServicesScreen', () {
      expect(notificationScreenForLink('/student/travel'),
          isA<TravelCenterScreen>());
    });

    test('/student/accommodation → ArrivalServicesScreen', () {
      expect(notificationScreenForLink('/student/accommodation'),
          isA<AccommodationScreen>());
    });

    test('/student/university-registration → UniversityRegistrationScreen', () {
      expect(notificationScreenForLink('/student/university-registration'),
          isA<UniversityRegistrationScreen>());
    });

    test('/student/support → SupportCenterScreen', () {
      expect(notificationScreenForLink('/student/support'),
          isA<SupportCenterScreen>());
    });

    test('message notifications open the specific sender conversation', () {
      final screen = notificationScreenForLink('/student/messages/abc123')
          as ConversationThreadScreen;
      expect(screen.contactId, 'abc123');
      expect(notificationActionLabel('/student/messages/abc123'), isNotNull);
    });

    test('community message notifications open the isolated conversation', () {
      final screen =
          notificationScreenForLink('/student/community/messages/abc123')
              as ConversationThreadScreen;
      expect(screen.contactId, 'abc123');
      expect(screen.communityMode, isTrue);
      expect(notificationActionLabel('/student/community/messages/abc123'),
          '\u0641\u062a\u062d \u0627\u0644\u0645\u062d\u0627\u062f\u062b\u0629');
    });

    test('/student/community → StudentCommunityHub', () {
      expect(notificationScreenForLink('/student/community'),
          isA<StudentCommunityHub>());
    });

    test('/student/bird-ai → BirdAIChatScreen', () {
      expect(notificationScreenForLink('/student/bird-ai'),
          isA<BirdAIChatScreen>());
    });

    test('unknown /student/ destination returns null', () {
      expect(notificationScreenForLink('/student/unknown-page'), isNull);
    });
  });
}
