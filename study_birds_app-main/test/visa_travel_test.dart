import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/screens/visa_travel_accommodation/visa_travel_screens.dart';

void main() {
  // ── visaStepFromJourneyStage ──────────────────────────────────────────────

  group('visaStepFromJourneyStage', () {
    test('unknown or empty stage returns 0', () {
      expect(visaStepFromJourneyStage(''), 0);
      expect(visaStepFromJourneyStage('not-a-real-stage'), 0);
    });

    test('early stages (before preliminary-accepted) return 0', () {
      for (final stage in [
        'file-received',
        'documents-review',
        'university-selection',
        'applying',
        'university-review',
      ]) {
        expect(visaStepFromJourneyStage(stage), 0,
            reason: '$stage should be step 0 (لم تبدأ)');
      }
    });

    test('preliminary-accepted and first-payment return 1 (التحضير)', () {
      expect(visaStepFromJourneyStage('preliminary-accepted'), 1);
      expect(visaStepFromJourneyStage('first-payment'), 1);
    });

    test('final-accepted returns 2 (إعداد المستندات)', () {
      expect(visaStepFromJourneyStage('final-accepted'), 2);
    });

    test('visa stage returns 3 (تم التقديم)', () {
      expect(visaStepFromJourneyStage('visa'), 3);
    });

    test('travel and beyond return 5 (تمت الموافقة)', () {
      for (final stage in [
        'travel',
        'reception',
        'accommodation',
        'university-registration',
        'studies-started',
      ]) {
        expect(visaStepFromJourneyStage(stage), 5,
            reason: '$stage should be step 5 (تمت الموافقة)');
      }
    });
  });

  // ── visaBadgeFromJourneyStage ─────────────────────────────────────────────

  group('visaBadgeFromJourneyStage', () {
    test('early stages produce neutral badge labeled "لم تبدأ"', () {
      final b = visaBadgeFromJourneyStage('file-received');
      expect(b.label, 'لم تبدأ');
    });

    test('preliminary-accepted produces info badge', () {
      final b = visaBadgeFromJourneyStage('preliminary-accepted');
      expect(b.label, 'التحضير');
    });

    test('final-accepted produces warning badge', () {
      final b = visaBadgeFromJourneyStage('final-accepted');
      expect(b.label, 'إعداد المستندات');
    });

    test('visa stage produces orange "قيد المعالجة" badge', () {
      final b = visaBadgeFromJourneyStage('visa');
      expect(b.label, 'قيد المعالجة');
    });

    test('travel stage produces success "تمت الموافقة" badge', () {
      final b = visaBadgeFromJourneyStage('travel');
      expect(b.label, 'تمت الموافقة');
    });

    test('unknown stage produces neutral badge', () {
      final b = visaBadgeFromJourneyStage('no-such-stage');
      expect(b.label, 'لم تبدأ');
    });
  });

  // ── kVisaRequirements ─────────────────────────────────────────────────────

  group('kVisaRequirements', () {
    test('contains exactly 4 requirements', () {
      expect(kVisaRequirements.length, 4);
    });

    test('passport is always in the list', () {
      expect(kVisaRequirements.any((r) => r.docKey == 'passport'), isTrue);
    });

    test('all docKeys are non-empty strings', () {
      for (final r in kVisaRequirements) {
        expect(r.docKey, isNotEmpty);
        expect(r.label, isNotEmpty);
      }
    });

    test('requirement is done when docKey is in uploaded set', () {
      final uploaded = {'passport', 'biometric-photo'};
      for (final r in kVisaRequirements) {
        final done = uploaded.contains(r.docKey);
        if (r.docKey == 'passport' || r.docKey == 'biometric-photo') {
          expect(done, isTrue);
        } else {
          expect(done, isFalse);
        }
      }
    });
  });
}
