import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/screens/services_support/live_consultation_screen.dart';

void main() {
  // ── kConsultationModes ────────────────────────────────────────────────────

  group('kConsultationModes', () {
    test('contains exactly three mode keys', () {
      expect(kConsultationModes.length, 3);
    });

    test('online maps to أونلاين', () {
      expect(kConsultationModes['online'], 'أونلاين');
    });

    test('phone maps to هاتف', () {
      expect(kConsultationModes['phone'], 'هاتف');
    });

    test('office maps to مكتب', () {
      expect(kConsultationModes['office'], 'مكتب');
    });

    test('all mode labels are non-empty', () {
      for (final label in kConsultationModes.values) {
        expect(label, isNotEmpty);
      }
    });

    test('unknown mode key returns null (no silent fallback)', () {
      expect(kConsultationModes['video'], isNull);
      expect(kConsultationModes[''], isNull);
    });
  });
}
