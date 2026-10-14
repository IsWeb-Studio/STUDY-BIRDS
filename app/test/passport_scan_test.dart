import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/core/utils/passport_scan.dart';

// Synthetic fixture, not an image or data from a real traveler.
String td3(
    {String number = 'L898902C3',
    String birth = '740812',
    String expiry = '351031',
    String optional = 'TEST123',
    String nationality = 'UTO'}) {
  final first = 'P<UTOEXAMPLE<<TEST<PERSON'.padRight(44, '<');
  final passport = number.padRight(9, '<'), extra = optional.padRight(14, '<');
  final second =
      '$passport${PassportScan.checkDigit(passport)}$nationality$birth${PassportScan.checkDigit(birth)}F$expiry${PassportScan.checkDigit(expiry)}$extra${PassportScan.checkDigit(extra)}';
  final composite = second.substring(0, 10) +
      second.substring(13, 20) +
      second.substring(21, 43);
  return '$first\n$second${PassportScan.checkDigit(composite)}';
}

final now = DateTime(2026, 10, 14);
String replaceAt(String text, int position, String value) =>
    text.substring(0, position) + value + text.substring(position + 1);
PassportAnalysis frame(
        {bool quality = true,
        bool detected = true,
        double? confidence = .9,
        double movement = 0}) =>
    PassportAnalysis(
        mrz: PassportScan.parseMrz(td3(), now: now),
        documentDetected: detected,
        quality: PassportQuality(
            measured: true,
            sharpness: quality ? 100 : 20,
            glare: .02,
            brightness: 120),
        ocrConfidence: confidence,
        corners: [.1 + movement, .2, .9, .2, .9, .8, .1, .8]);

void main() {
  test('ICAO weighted digits and invalid alphabet', () {
    expect(PassportScan.checkDigit('L898902C3'), 6);
    expect(PassportScan.checkDigit('740812'), 2);
    expect(PassportScan.checkDigit('<<<<<<<<'), 0);
    expect(() => PassportScan.checkDigit('A?1'), throwsFormatException);
  });
  test('extracts all TD3 fields and accepts joined/space-separated OCR', () {
    final result = PassportScan.parseMrz(td3(), now: now);
    expect(result.canSubmit, isTrue);
    expect(result.details!.number, 'L898902C3');
    expect(result.details!.fullName, 'TEST PERSON EXAMPLE');
    expect(result.details!.nationality, 'UTO');
    expect(result.details!.sex, 'F');
    expect(result.details!.dateOfBirth, '1974-08-12');
    expect(result.details!.expirationDate, '2035-10-31');
    expect(PassportScan.parseMrz(td3().replaceAll('\n', ''), now: now).valid,
        isTrue);
    expect(
        PassportScan.parseMrz(td3().toLowerCase().replaceAll('<', ' < '),
                now: now)
            .valid,
        isTrue);
  });
  for (final position in [9, 19, 27, 42, 43]) {
    test('rejects incorrect check digit at second-line offset $position', () {
      final source = td3();
      final index = 45 + position;
      final incorrect = '${(int.parse(source[index]) + 1) % 10}';
      expect(
          PassportScan.parseMrz(replaceAt(source, index, incorrect), now: now)
              .valid,
          isFalse);
    });
  }
  test('does not guess ambiguous characters or fill incomplete lines', () {
    expect(
        PassportScan.parseMrz(replaceAt(td3(), 45 + 13, 'O'), now: now).valid,
        isFalse);
    expect(PassportScan.parseMrz(td3().substring(1), now: now).valid, isFalse);
    expect(
        PassportScan.parseMrz(td3().substring(0, 86), now: now).valid, isFalse);
  });
  test('rejects non-passports and missing identity fields', () {
    expect(
        PassportScan.parseMrz(td3().replaceFirst('P<', 'I<'), now: now).valid,
        isFalse);
    expect(
        PassportScan.parseMrz(td3().replaceFirst('P<', 'V<'), now: now).valid,
        isFalse);
    expect(
        PassportScan.parseMrz('A rectangle or driving license', now: now).valid,
        isFalse);
    expect(PassportScan.parseMrz(td3(number: ''), now: now).valid, isFalse);
    expect(PassportScan.parseMrz(td3(nationality: '<<<'), now: now).valid,
        isFalse);
  });
  test('rejects nonexistent calendar dates even with matching digits', () {
    expect(
        PassportScan.parseMrz(td3(birth: '740231'), now: now).valid, isFalse);
    expect(
        PassportScan.parseMrz(td3(expiry: '350431'), now: now).valid, isFalse);
    expect(
        PassportScan.parseMrz(td3(birth: '740000'), now: now).valid, isFalse);
  });
  test('separates expired passports from MRZ consistency', () {
    final expired = PassportScan.parseMrz(td3(expiry: '201031'), now: now);
    expect(expired.valid, isTrue);
    expect(expired.canSubmit, isFalse);
    expect(expired.details!.expired, isTrue);
    expect(PassportScan.parseMrz(td3(expiry: '261014'), now: now).canSubmit,
        isTrue);
  });
  test('birth century follows current date, not a hardcoded 2030 boundary', () {
    expect(
        PassportScan.parseMrz(td3(birth: '300101'), now: now)
            .details!
            .birthDate
            .year,
        1930);
    expect(
        PassportScan.parseMrz(td3(birth: '180101'), now: now)
            .details!
            .birthDate
            .year,
        2018);
  });
  test('empty optional field may use filler in its check digit', () {
    final lines = td3(optional: '').split('\n');
    var second = replaceAt(lines[1], 42, '<');
    second = '${second.substring(0, 43)}'
        '${PassportScan.checkDigit(second.substring(0, 10) + second.substring(13, 20) + second.substring(21, 43))}';
    expect(
        PassportScan.parseMrz('${lines[0]}\n$second', now: now).valid, isTrue);
  });
  test('auto capture requires consecutive good frames and measured confidence',
      () {
    final stability = PassportStability();
    expect(stability.add(frame()), isFalse);
    expect(stability.add(frame()), isFalse);
    expect(stability.add(frame(movement: .08)), isFalse);
    expect(stability.count, 1);
    expect(stability.add(frame(quality: false)), isFalse);
    expect(stability.count, 0);
    expect(stability.add(frame(confidence: null)), isFalse);
    expect(stability.add(frame(detected: false)), isFalse);
    expect(stability.add(frame()), isFalse);
    expect(stability.add(frame()), isFalse);
    expect(stability.add(frame()), isTrue);
    stability.reset();
    expect(stability.count, 0);
  });
  test('quality messages come from measured blur glare and exposure', () {
    expect(const PassportQuality().acceptable, isFalse);
    expect(
        const PassportQuality(
                measured: true, sharpness: 100, brightness: 120, glare: .3)
            .guidance,
        contains('انعكاس'));
    expect(
        const PassportQuality(measured: true, sharpness: 100, brightness: 20)
            .acceptable,
        isFalse);
  });
  test('quality and automatic capture thresholds are configurable', () {
    const strict =
        PassportScanOptions(minSharpness: 150, minOcrConfidence: .98);
    expect(frame().readyWith(strict), isFalse);
    expect(frame().quality.acceptableWith(strict), isFalse);
    expect(strict.native['minSharpness'], 150);
    final stability = PassportStability(options: strict);
    expect(stability.add(frame()), isFalse);
    expect(stability.count, 0);
  });
  test('a valid MRZ outside the expected layout cannot trigger auto capture', () {
    final good = frame();
    final misplaced = PassportAnalysis(mrz: good.mrz, quality: good.quality,
      documentDetected: true, corners: good.corners, ocrConfidence: .95, mrzInLowerRegion: false);
    expect(misplaced.ready, isFalse);
    expect(PassportStability().add(misplaced), isFalse);
  });
  test('inspection handles native OCR failures without leaking native details',
      () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        PassportScan.channel,
        (_) async => throw PlatformException(
            code: 'failed', message: 'sensitive native payload'));
    addTearDown(
        () => messenger.setMockMethodCallHandler(PassportScan.channel, null));
    await expectLater(
        PassportScan.inspect(Uint8List.fromList([1])),
        throwsA(isA<PassportScanException>().having(
            (e) => e.message, 'message', isNot(contains('sensitive')))));
  });
}
