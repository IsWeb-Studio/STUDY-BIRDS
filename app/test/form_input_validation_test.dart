import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/core/utils/form_input_validation.dart';

void main() {
  group('email validation', () {
    test('trims outer whitespace and accepts international characters', () {
      expect(FormInputValidators.isValidEmail('  learner@school.example  '), isTrue);
      expect(FormInputValidators.isValidEmail('élève@例え.テスト'), isTrue);
    });

    test('rejects incomplete or malformed addresses', () {
      expect(FormInputValidators.isValidEmail(''), isFalse);
      expect(FormInputValidators.isValidEmail('person@'), isFalse);
      expect(FormInputValidators.isValidEmail('a..b@example.test'), isFalse);
      expect(FormInputValidators.isValidEmail('person @example.test'), isFalse);
    });
  });

  group('phone validation', () {
    test('allows optional empty numbers and globally sized international numbers', () {
      expect(FormInputValidators.phoneWithDialCode('', dialCode: '90'), isNull);
      expect(FormInputValidators.phoneWithDialCode('1234567', dialCode: '90'), isNull);
      expect(FormInputValidators.phone('+1 (202) 555-0100'), isNull);
      expect(FormInputValidators.phone('123456789012345'), isNull);
    });

    test('rejects incomplete, overlong, and non-phone values', () {
      expect(
        FormInputValidators.phoneWithDialCode('123', dialCode: '966'),
        InputValidationIssue.invalidPhone,
      );
      expect(FormInputValidators.phone('1234567890123456'), InputValidationIssue.invalidPhone);
      expect(FormInputValidators.phone('555CALL'), InputValidationIssue.invalidPhone);
    });
  });

  group('numeric validation', () {
    test('accepts non-negative decimals without assuming a grading maximum', () {
      expect(FormInputValidators.nonNegativeDecimal('85'), isNull);
      expect(FormInputValidators.nonNegativeDecimal('3.75'), isNull);
      expect(FormInputValidators.nonNegativeDecimal('١٢٫٥'), isNull);
      expect(FormInputValidators.nonNegativeDecimal('١٢.٥'), isNull);
      expect(FormInputValidators.nonNegativeDecimal(''), isNull);
    });

    test('rejects negative, malformed, or non-finite numbers', () {
      expect(FormInputValidators.nonNegativeDecimal('-1'), InputValidationIssue.invalidNumber);
      expect(FormInputValidators.nonNegativeDecimal('3.2.1'), InputValidationIssue.invalidNumber);
      expect(FormInputValidators.nonNegativeDecimal('1e6'), InputValidationIssue.invalidNumber);
    });

    test('normalizes localized digits and rejects lossy pasted text', () {
      final formatter = LocalizedDecimalInputFormatter();
      const old = TextEditingValue(text: '3');
      expect(
        formatter.formatEditUpdate(old, const TextEditingValue(text: '٣.٧')).text,
        '3.7',
      );
      expect(
        formatter.formatEditUpdate(old, const TextEditingValue(text: '-3')).text,
        '3',
      );
      final digitsOnly = LocalizedDigitsInputFormatter();
      expect(
        digitsOnly.formatEditUpdate(old, const TextEditingValue(text: '٠٠١٢')).text,
        '0012',
      );
      expect(
        digitsOnly.formatEditUpdate(old, const TextEditingValue(text: '12a')).text,
        '3',
      );
    });
  });

  group('strict date validation', () {
    final today = DateTime(2026, 10, 23);

    test('accepts real dates including leap day', () {
      expect(
        FormInputValidators.isoDate('2024-02-29', mustNotBeFuture: true, today: today),
        isNull,
      );
      expect(
        FormInputValidators.isoDate('2026-10-23', mustNotBeFuture: true, today: today),
        isNull,
      );
    });

    test('rejects impossible, malformed, and future dates', () {
      expect(FormInputValidators.isoDate('2025-02-29'), InputValidationIssue.invalidDate);
      expect(FormInputValidators.isoDate('2026-2-03'), InputValidationIssue.invalidDate);
      expect(
        FormInputValidators.isoDate('2026-10-24', mustNotBeFuture: true, today: today),
        InputValidationIssue.futureDate,
      );
    });
  });
}
