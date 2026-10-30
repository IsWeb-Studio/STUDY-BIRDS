import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum InputValidationIssue {
  requiredValue,
  invalidEmail,
  invalidPhone,
  invalidNumber,
  invalidDate,
  futureDate,
}

/// Shared, purpose-specific validation for fields used by multiple forms.
///
/// These checks intentionally avoid country-specific phone lengths, GPA maxima,
/// and restrictive name character sets because those rules are not available
/// consistently across the current product workflows.
class FormInputValidators {
  static InputValidationIssue? requiredText(String? value) =>
      value == null || value.trim().isEmpty
          ? InputValidationIssue.requiredValue
          : null;

  static bool isValidEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty || email.contains(RegExp(r'\s'))) return false;
    final at = email.indexOf('@');
    if (at <= 0 || at != email.lastIndexOf('@') || at == email.length - 1) {
      return false;
    }
    final local = email.substring(0, at);
    final domain = email.substring(at + 1);
    if (local.startsWith('.') || local.endsWith('.') || local.contains('..')) {
      return false;
    }
    final labels = domain.split('.');
    if (labels.length < 2) return false;
    return labels.every((label) =>
        label.isNotEmpty &&
        !label.startsWith('-') &&
        !label.endsWith('-'));
  }

  static InputValidationIssue? email(String? value, {bool required = false}) {
    if (value == null || value.trim().isEmpty) {
      return required ? InputValidationIssue.requiredValue : null;
    }
    return isValidEmail(value) ? null : InputValidationIssue.invalidEmail;
  }

  /// Validates a phone field with a selected calling code. Empty optional
  /// fields remain valid; if the user starts typing, the full E.164 digit range
  /// is checked without assuming a fixed national length.
  static InputValidationIssue? phoneWithDialCode(
    String? localNumber, {
    required String dialCode,
    bool required = false,
  }) {
    final local = normalizeDigits(localNumber ?? '').trim();
    if (local.isEmpty) {
      return required ? InputValidationIssue.requiredValue : null;
    }
    final compact = local.replaceAll(RegExp(r'[\s().-]'), '');
    if (!RegExp(r'^\+?[0-9]+$').hasMatch(compact)) {
      return InputValidationIssue.invalidPhone;
    }
    final digits = '${normalizeDigits(dialCode)}${compact.replaceAll('+', '')}';
    if (digits.length < 7 || digits.length > 15) {
      return InputValidationIssue.invalidPhone;
    }
    return null;
  }

  /// Validates a phone value entered without a separate country selector.
  static InputValidationIssue? phone(String? value, {bool required = false}) {
    final input = normalizeDigits(value ?? '').trim();
    if (input.isEmpty) {
      return required ? InputValidationIssue.requiredValue : null;
    }
    final compact = input.replaceAll(RegExp(r'[\s().-]'), '');
    if (!RegExp(r'^\+?[0-9]+$').hasMatch(compact)) {
      return InputValidationIssue.invalidPhone;
    }
    final digits = compact.replaceAll('+', '');
    if (digits.length < 7 || digits.length > 15) {
      return InputValidationIssue.invalidPhone;
    }
    return null;
  }

  /// Checks a non-negative decimal without assuming whether the value is a
  /// percentage, a 4/5-point GPA, or another institution-specific scale.
  static InputValidationIssue? nonNegativeDecimal(
    String? value, {
    bool required = false,
  }) {
    final normalized = normalizeDecimal(value ?? '').trim();
    if (normalized.isEmpty) {
      return required ? InputValidationIssue.requiredValue : null;
    }
    if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(normalized)) {
      return InputValidationIssue.invalidNumber;
    }
    final parsed = double.tryParse(normalized);
    return parsed != null && parsed.isFinite && parsed >= 0
        ? null
        : InputValidationIssue.invalidNumber;
  }

  /// Accepts a strict YYYY-MM-DD date only, rejects impossible calendar dates,
  /// and optionally disallows dates after [today].
  static InputValidationIssue? isoDate(
    String? value, {
    bool required = false,
    bool mustNotBeFuture = false,
    DateTime? today,
  }) {
    final input = normalizeDigits(value ?? '').trim();
    if (input.isEmpty) {
      return required ? InputValidationIssue.requiredValue : null;
    }
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(input);
    if (match == null) return InputValidationIssue.invalidDate;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return InputValidationIssue.invalidDate;
    }
    if (mustNotBeFuture &&
        DateUtils.dateOnly(date).isAfter(DateUtils.dateOnly(today ?? DateTime.now()))) {
      return InputValidationIssue.futureDate;
    }
    return null;
  }

  static String normalizeDigits(String value) => value.runes.map((rune) {
        if (rune >= 0x0660 && rune <= 0x0669) {
          return String.fromCharCode(rune - 0x0660 + 0x30);
        }
        if (rune >= 0x06f0 && rune <= 0x06f9) {
          return String.fromCharCode(rune - 0x06f0 + 0x30);
        }
        return String.fromCharCode(rune);
      }).join();

  static String normalizeDecimal(String value) =>
      normalizeDigits(value).replaceAll('\u066b', '.');

  static String message(BuildContext context, InputValidationIssue issue) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return switch (issue) {
      InputValidationIssue.requiredValue =>
        arabic ? 'هذا الحقل مطلوب' : 'This field is required',
      InputValidationIssue.invalidEmail => arabic
          ? 'أدخل بريدًا إلكترونيًا صالحًا'
          : 'Enter a valid email address',
      InputValidationIssue.invalidPhone => arabic
          ? 'تحقق من رقم الهاتف ورمز الدولة'
          : 'Check the phone number and country code',
      InputValidationIssue.invalidNumber => arabic
          ? 'أدخل رقمًا عشريًا غير سالب'
          : 'Enter a non-negative decimal number',
      InputValidationIssue.invalidDate => arabic
          ? 'أدخل تاريخًا صحيحًا'
          : 'Enter a valid date',
      InputValidationIssue.futureDate => arabic
          ? 'لا يمكن أن يكون التاريخ في المستقبل'
          : 'The date cannot be in the future',
    };
  }
}

/// Accepts plain or Arabic/Persian digits and a single decimal separator.
/// Invalid pasted text is rejected as a whole instead of being silently
/// transformed into a different numeric value.
class LocalizedDecimalInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = FormInputValidators.normalizeDecimal(newValue.text);
    if (!RegExp(r'^\d*(?:\.\d*)?$').hasMatch(normalized)) return oldValue;
    return newValue.copyWith(text: normalized);
  }
}

/// Accepts ASCII, Arabic-Indic, and Eastern Arabic-Indic digits while keeping
/// phone identifiers as text (including any leading zeroes).
class LocalizedDigitsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = FormInputValidators.normalizeDigits(newValue.text);
    if (!RegExp(r'^\d*$').hasMatch(normalized)) return oldValue;
    return newValue.copyWith(text: normalized);
  }
}
