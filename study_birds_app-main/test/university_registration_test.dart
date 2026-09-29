import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/screens/visa_travel_accommodation/accommodation_arrival_screens.dart';
import 'package:study_birds/core/app_theme.dart';

void main() {
  // ── kUniversityRegistrationDocs ───────────────────────────────────────────

  group('kUniversityRegistrationDocs', () {
    test('contains exactly 4 documents', () {
      expect(kUniversityRegistrationDocs.length, 4);
    });

    test('passport is in the list', () {
      expect(
          kUniversityRegistrationDocs.any((d) => d.docKey == 'passport'),
          isTrue);
    });

    test('all docKeys and labels are non-empty', () {
      for (final d in kUniversityRegistrationDocs) {
        expect(d.docKey, isNotEmpty);
        expect(d.label, isNotEmpty);
      }
    });

    test('no duplicate docKeys', () {
      final keys = kUniversityRegistrationDocs.map((d) => d.docKey).toList();
      expect(keys.toSet().length, keys.length);
    });
  });

  // ── uniRegBadgeFromJourneyStage ───────────────────────────────────────────

  group('uniRegBadgeFromJourneyStage', () {
    test('unknown or empty stage returns neutral badge', () {
      final b = uniRegBadgeFromJourneyStage('');
      expect(b.label, 'لم يحن الوقت بعد');
      expect(b.color, AppColors.neutral);
    });

    test('early stages before university-registration return neutral badge', () {
      for (final stage in [
        'file-received',
        'documents-review',
        'visa',
        'travel',
        'accommodation',
      ]) {
        final b = uniRegBadgeFromJourneyStage(stage);
        expect(b.label, 'لم يحن الوقت بعد',
            reason: '$stage should be "لم يحن الوقت بعد"');
      }
    });

    test('university-registration stage returns warning badge', () {
      final b = uniRegBadgeFromJourneyStage('university-registration');
      expect(b.label, 'بانتظار الموعد');
      expect(b.color, AppColors.warning);
    });

    test('studies-started returns success badge', () {
      final b = uniRegBadgeFromJourneyStage('studies-started');
      expect(b.label, 'مكتمل');
      expect(b.color, AppColors.success);
    });
  });
}
