import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/screens/applications_documents_payments/documents_screens.dart';

void main() {
  // ── kDocumentTypes ────────────────────────────────────────────────────────

  group('kDocumentTypes', () {
    test('english-test is in the upload picker', () {
      expect(kDocumentTypes.any((t) => t['key'] == 'english-test'), isTrue);
    });

    test('bank-statement is in the upload picker', () {
      expect(kDocumentTypes.any((t) => t['key'] == 'bank-statement'), isTrue);
    });

    test('no-criminal-record is in the upload picker', () {
      expect(
          kDocumentTypes.any((t) => t['key'] == 'no-criminal-record'), isTrue);
    });

    test('passport is in the upload picker', () {
      expect(kDocumentTypes.any((t) => t['key'] == 'passport'), isTrue);
    });

    test('all keys and labels are non-empty', () {
      for (final t in kDocumentTypes) {
        expect(t['key'], isNotEmpty);
        expect(t['label'], isNotEmpty);
      }
    });

    test('no duplicate keys', () {
      final keys = kDocumentTypes.map((t) => t['key']).toList();
      expect(keys.toSet().length, keys.length);
    });
  });

  // ── docTypeLabel ──────────────────────────────────────────────────────────

  group('docTypeLabel', () {
    test('passport returns Arabic label', () {
      expect(docTypeLabel('passport'), 'جواز السفر');
    });

    test('english-test returns Arabic label', () {
      expect(docTypeLabel('english-test'), 'شهادة اختبار الإنجليزية');
    });

    test('translation (website key) returns Arabic label', () {
      expect(docTypeLabel('translation'), 'ترجمة معتمدة');
    });

    test('police-clearance (extra label) returns Arabic label', () {
      expect(docTypeLabel('police-clearance'), 'صحيفة الحالة الجنائية');
    });

    test('unknown key falls back to the key itself, not empty', () {
      final label = docTypeLabel('some-unknown-type');
      expect(label, isNotEmpty);
    });

    test('null key returns non-empty fallback', () {
      expect(docTypeLabel(null), isNotEmpty);
    });
  });
}
