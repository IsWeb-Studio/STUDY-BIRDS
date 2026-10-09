import 'app_error.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class PassportScanException implements Exception, UserFacingFailure {
  final String message;
  const PassportScanException(this.message);
  @override
  String toString() => message;
}

/// Local OCR gate, not an identity or authenticity verification service.
class PassportScan {
  static const channel = MethodChannel('studybirds/passport_scan');

  static Future<void> validate(List<int> bytes) async {
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw const PassportScanException('اختر ملفًا واضحًا لا يتجاوز 10 ميجابايت.');
    }
    try {
      final pages = await channel.invokeListMethod<String>('recognize', {
        'bytes': Uint8List.fromList(bytes),
      });
      if (pages == null || !pages.any(hasValidPassportMrz)) {
        throw const PassportScanException(
          'لم نتمكن من قراءة جواز سفر صالح للرفع. اختر صفحة البيانات كاملة، '
          'مع السطرين أسفلها، بصورة واضحة دون لمعان. لملف PDF ضع صفحة البيانات ضمن أول 3 صفحات.',
        );
      }
    } on MissingPluginException {
      throw const PassportScanException('فحص الجواز متاح في تطبيق أندرويد وآيفون. استخدم أحدث نسخة من التطبيق.');
    } on PlatformException {
      throw const PassportScanException('تعذر مسح الملف. اختر صورة JPG أو PNG واضحة، أو PDF غير محمي بكلمة مرور (حتى 3 صفحات للفحص).');
    }
  }

  /// ICAO TD3 passport: two 44-character lines and three data check digits
  /// plus the composite check digit. Visa/ID MRZs must not pass this gate.
  static bool hasValidPassportMrz(String text) {
    final lines = text.toUpperCase().replaceAll('«', '<<').replaceAll('‹', '<')
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ''))
        .where((line) => RegExp(r'^[A-Z0-9<]+$').hasMatch(line)).toList();
    for (var i = 0; i < lines.length; i++) {
      // Some OCR engines join both MRZ lines into a single observation.
      final candidates = <String>[lines[i]];
      if (i + 1 < lines.length) candidates.add(lines[i] + lines[i + 1]);
      for (final mrz in candidates) {
        if (mrz.length != 88) continue;
        final first = mrz.substring(0, 44);
        final second = mrz.substring(44);
        if (!RegExp(r'^P[A-Z<][A-Z<]{3}[A-Z<]{39}$').hasMatch(first) ||
            !first.substring(5).contains('<<') ||
            !RegExp(r'[A-Z]{2}').hasMatch(first.substring(5)) ||
            !RegExp(r'^[A-Z0-9<]{9}[0-9][A-Z<]{3}[0-9]{6}[0-9][MF<][0-9]{6}[0-9][A-Z0-9<]{14}[0-9<][0-9]$').hasMatch(second)) continue;
        if (_check(second.substring(0, 9), second[9]) &&
            _check(second.substring(13, 19), second[19]) &&
            _check(second.substring(21, 27), second[27]) &&
            _check(second.substring(0, 10) + second.substring(13, 20) +
                second.substring(21, 43), second[43])) return true;
      }
    }
    return false;
  }

  /// Extract passport number and DOB from MRZ. Never throws — returns nulls on failure.
  static Future<({String? passportNumber, String? dateOfBirth})>
      extractFromBytes(List<int> bytes) async {
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      return (passportNumber: null, dateOfBirth: null);
    }
    try {
      final pages = await channel.invokeListMethod<String>('recognize', {
        'bytes': Uint8List.fromList(bytes),
      });
      if (pages == null) return (passportNumber: null, dateOfBirth: null);
      for (final text in pages) {
        final mrz = _findMrz(text);
        if (mrz == null) continue;
        final second = mrz.substring(44);
        final rawPassport = second.substring(0, 9).replaceAll('<', '').trim();
        final dobRaw = second.substring(13, 19); // YYMMDD
        final dobYY = int.tryParse(dobRaw.substring(0, 2)) ?? 0;
        final fullYear = dobYY > 30 ? 1900 + dobYY : 2000 + dobYY;
        final dob =
            '$fullYear-${dobRaw.substring(2, 4)}-${dobRaw.substring(4, 6)}';
        return (
          passportNumber: rawPassport.isEmpty ? null : rawPassport,
          dateOfBirth: dob,
        );
      }
    } catch (_) {}
    return (passportNumber: null, dateOfBirth: null);
  }

  static String? _findMrz(String text) {
    final lines = text
        .toUpperCase()
        .replaceAll('«', '<<')
        .replaceAll('‹', '<')
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ''))
        .where((line) => RegExp(r'^[A-Z0-9<]+$').hasMatch(line))
        .toList();
    for (var i = 0; i < lines.length; i++) {
      final candidates = <String>[lines[i]];
      if (i + 1 < lines.length) candidates.add(lines[i] + lines[i + 1]);
      for (final mrz in candidates) {
        if (mrz.length != 88) continue;
        final first = mrz.substring(0, 44);
        final second = mrz.substring(44);
        if (!RegExp(r'^P[A-Z<][A-Z<]{3}[A-Z<]{39}$').hasMatch(first)) continue;
        if (!first.substring(5).contains('<<')) continue;
        if (!RegExp(r'^[A-Z<]{2}').hasMatch(first.substring(5))) continue;
        if (!RegExp(
                r'^[A-Z0-9<]{9}[0-9][A-Z<]{3}[0-9]{6}[0-9][MF<][0-9]{6}[0-9][A-Z0-9<]{14}[0-9<][0-9]$')
            .hasMatch(second)) continue;
        if (_check(second.substring(0, 9), second[9]) &&
            _check(second.substring(13, 19), second[19]) &&
            _check(second.substring(21, 27), second[27]) &&
            _check(
                second.substring(0, 10) +
                    second.substring(13, 20) +
                    second.substring(21, 43),
                second[43])) return mrz;
      }
    }
    return null;
  }

  static bool _check(String value, String digit) {
    const weights = [7, 3, 1];
    var total = 0;
    for (var i = 0; i < value.length; i++) {
      final code = value.codeUnitAt(i);
      final number = code == 60 ? 0 : code >= 65 ? code - 55 : code - 48;
      total += number * weights[i % 3];
    }
    return '${total % 10}' == digit;
  }
}
