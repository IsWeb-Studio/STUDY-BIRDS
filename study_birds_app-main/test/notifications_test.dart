import 'package:study_birds/core/notification_links.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/screens/home_journey/notifications_screen.dart';
import 'package:study_birds/screens/services_support/services_consultation_screens.dart';
import 'package:study_birds/screens/home_journey/journey_tracker_screen.dart';
import 'package:study_birds/screens/applications_documents_payments/documents_screens.dart';
import 'package:study_birds/screens/applications_documents_payments/payments_screens.dart';
import 'package:study_birds/screens/applications_documents_payments/applications_screens.dart';
import 'package:study_birds/screens/visa_travel_accommodation/visa_travel_screens.dart';
import 'package:study_birds/screens/visa_travel_accommodation/accommodation_arrival_screens.dart';
import 'package:study_birds/screens/services_support/support_team_ai_screens.dart';
import 'package:study_birds/screens/services_support/community_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── notificationScreenForLink ─────────────────────────────────────────────

  group('notificationScreenForLink', () {
    test('custom links preserve student host and reject other websites', () {
      expect(notificationPath('studybirds://student/payments'), '/student/payments');
      expect(notificationPath('https://studybirds.app/student/documents'), '/student/documents');
      expect(notificationPath('https://untrusted.test/student/payments'), isNull);
      expect(notificationPath('//untrusted.test/student/payments'), isNull);
      expect(notificationScreenForLink('payments'), isA<PaymentsSummaryScreen>());
    });
    test('null link returns null', () {
      expect(notificationScreenForLink(null), isNull);
    });

    test('link without /student/ prefix returns null', () {
      expect(notificationScreenForLink('/admin/something'), isNull);
      expect(notificationScreenForLink('consultations'), isA<ConsultationBookingScreen>());
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
      expect(notificationScreenForLink('/student/visa'),
          isA<VisaCenterScreen>());
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

    test('/student/community → StudentCommunityScreen', () {
      expect(notificationScreenForLink('/student/community'),
          isA<StudentCommunityScreen>());
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
