import 'package:flutter/services.dart';
import 'app_error.dart';

class PassportScanException implements Exception, UserFacingFailure {
  @override
  final String message;
  const PassportScanException(this.message);
  @override
  String toString() => message;
}

/// Internal consistency of a TD3 transcription is not authenticity evidence.
class PassportDetails {
  final String number, fullName, nationality, issuingCountry, sex;
  final DateTime birthDate, expiryDate;
  final bool expired;
  const PassportDetails(
      {required this.number,
      required this.fullName,
      required this.nationality,
      required this.issuingCountry,
      required this.sex,
      required this.birthDate,
      required this.expiryDate,
      required this.expired});
  String get dateOfBirth => birthDate.toIso8601String().substring(0, 10);
  String get expirationDate => expiryDate.toIso8601String().substring(0, 10);
  @override
  String toString() => 'PassportDetails(redacted)';
}

class MrzResult {
  final PassportDetails? details;
  final List<String> issues;
  final bool formatRecognized, checkDigitsPassed;
  const MrzResult(
      {this.details,
      this.issues = const [],
      this.formatRecognized = false,
      this.checkDigitsPassed = false});
  bool get valid => details != null && issues.isEmpty && checkDigitsPassed;
  bool get canSubmit => valid && !details!.expired;
}

class PassportScanOptions {
  final double minSharpness,
      maxGlare,
      minBrightness,
      maxBrightness,
      minOcrConfidence,
      maxMovement;
  final int stableFrames, frameIntervalMs;
  const PassportScanOptions(
      {this.minSharpness = 65,
      this.maxGlare = .18,
      this.minBrightness = 45,
      this.maxBrightness = 225,
      this.minOcrConfidence = .75,
      this.maxMovement = .025,
      this.stableFrames = 3,
      this.frameIntervalMs = 700});
  Map<String, Object> get native => {
        'minSharpness': minSharpness,
        'maxGlare': maxGlare,
        'minBrightness': minBrightness,
        'maxBrightness': maxBrightness
      };
}

class PassportQuality {
  final double sharpness, glare, brightness;
  final bool measured;
  const PassportQuality(
      {this.sharpness = 0,
      this.glare = 0,
      this.brightness = 0,
      this.measured = false});
  factory PassportQuality.fromMap(Map data) => PassportQuality(
      sharpness: (data['sharpness'] as num?)?.toDouble() ?? 0,
      glare: (data['glare'] as num?)?.toDouble() ?? 0,
      brightness: (data['brightness'] as num?)?.toDouble() ?? 0,
      measured: data['sharpness'] is num &&
          data['brightness'] is num &&
          data['glare'] is num);
  // Starting thresholds, to be calibrated on permitted real-world samples.
  bool get acceptable => acceptableWith(const PassportScanOptions());
  bool acceptableWith(PassportScanOptions options) =>
      measured &&
      sharpness >= options.minSharpness &&
      glare <= options.maxGlare &&
      brightness >= options.minBrightness &&
      brightness <= options.maxBrightness;
  String get guidance => guidanceWith(const PassportScanOptions());
  String guidanceWith(PassportScanOptions options) => !measured
      ? 'تعذر قياس جودة الصورة'
      : glare > options.maxGlare
          ? 'انعكاس قوي؛ غيّر زاوية الهاتف'
          : brightness < options.minBrightness
              ? 'الإضاءة ضعيفة؛ انتقل إلى مكان أكثر إضاءة'
              : brightness > options.maxBrightness
                  ? 'الإضاءة قوية؛ تجنب الضوء المباشر'
                  : sharpness < options.minSharpness
                      ? 'الصورة غير واضحة؛ ثبّت الهاتف'
                      : 'جودة الصورة مناسبة';
}

class PassportAnalysis {
  final MrzResult mrz;
  final PassportQuality quality;
  final List<double> corners;
  final double? ocrConfidence;
  final Uint8List? correctedBytes;
  final Uint8List? originalPreviewBytes;
  final bool documentDetected;
  final bool ocrAttempted;
  final bool mrzInLowerRegion;
  const PassportAnalysis(
      {required this.mrz,
      required this.quality,
      this.corners = const [],
      this.ocrConfidence,
      this.correctedBytes,
      this.originalPreviewBytes,
      this.documentDetected = false,
      this.ocrAttempted = true,
      this.mrzInLowerRegion = true});
  bool get ready => readyWith(const PassportScanOptions());
  bool readyWith(PassportScanOptions options) =>
      documentDetected &&
      mrzInLowerRegion &&
      quality.acceptableWith(options) &&
      mrz.canSubmit &&
      ocrConfidence != null &&
      ocrConfidence!.isFinite &&
      ocrConfidence! <= 1 &&
      ocrConfidence! >= options.minOcrConfidence;
  factory PassportAnalysis.fromMap(Map data) => PassportAnalysis(
      mrz: PassportScan.parseMrz(data['text'] as String? ?? ''),
      quality: PassportQuality.fromMap(data),
      corners: (data['corners'] as List? ?? const [])
          .cast<num>()
          .map((n) => n.toDouble())
          .toList(),
      ocrConfidence: (data['confidence'] as num?)?.toDouble(),
      correctedBytes: data['correctedBytes'] as Uint8List?,
      originalPreviewBytes: data['originalPreviewBytes'] as Uint8List?,
      documentDetected: data['documentDetected'] == true,
      ocrAttempted: data['ocrAttempted'] != false,
      mrzInLowerRegion: data['mrzInLowerRegion'] == true);
}

/// Consecutive measured detections; an elapsed timer alone never captures.
class PassportStability {
  final PassportScanOptions options;
  final int requiredFrames;
  final double maxMovement;
  List<double>? _previous;
  String? _number;
  int count = 0;
  PassportStability(
      {this.requiredFrames = 3,
      this.maxMovement = .025,
      this.options = const PassportScanOptions()});
  void reset() {
    count = 0;
    _previous = null;
    _number = null;
  }

  bool add(PassportAnalysis frame) {
    if (!frame.readyWith(options) || frame.corners.length != 8) {
      reset();
      return false;
    }
    final d = frame.mrz.details!;
    final identity =
        '${d.number}|${d.fullName}|${d.nationality}|${d.sex}|${d.dateOfBirth}|${d.expirationDate}';
    final same = _number == identity &&
        _previous != null &&
        List.generate(8, (i) => (frame.corners[i] - _previous![i]).abs())
            .every((movement) => movement <= maxMovement);
    count = same ? count + 1 : 1;
    _previous = frame.corners;
    _number = identity;
    return count >= requiredFrames;
  }
}

class PassportScan {
  static const channel = MethodChannel('studybirds/passport_scan');
  static const maxBytes = 5 * 1024 * 1024;
  static int _requestId = 0;
  static bool _progressInitialized = false;
  static final _listeners = <int, void Function(String, String)>{};
  static void _initializeProgress() {
    if (_progressInitialized) return;
    _progressInitialized = true;
    channel.setMethodCallHandler((call) async {
      if (call.method != 'scanProgress' || call.arguments is! Map) return;
      final data = call.arguments as Map;
      _listeners[data['id']]
          ?.call(data['stage'] as String, data['state'] as String);
    });
  }

  static int checkDigit(String value) {
    if (!RegExp(r'^[A-Z0-9<]*$').hasMatch(value)) {
      throw const FormatException('Invalid MRZ character');
    }
    const weights = [7, 3, 1];
    var total = 0;
    for (var i = 0; i < value.length; i++) {
      final code = value.codeUnitAt(i);
      total += (code == 60
              ? 0
              : code >= 65
                  ? code - 55
                  : code - 48) *
          weights[i % 3];
    }
    return total % 10;
  }

  /// Normalizes spacing/case only; never guesses O/0, I/1, or missing digits.
  static MrzResult parseMrz(String text, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final lines = text
        .toUpperCase()
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ''))
        .where((line) => RegExp(r'^[A-Z0-9<]+$').hasMatch(line))
        .toList();
    MrzResult? failure;
    for (var i = 0; i < lines.length; i++) {
      for (final candidate in [
        lines[i],
        if (i + 1 < lines.length) lines[i] + lines[i + 1]
      ]) {
        if (candidate.length != 88 || !candidate.startsWith('P')) continue;
        final first = candidate.substring(0, 44),
            second = candidate.substring(44);
        if (!RegExp(r'^P[A-Z<][A-Z<]{3}[A-Z<]{39}$').hasMatch(first) ||
            !first.substring(5).contains('<<') ||
            !RegExp(r'^[A-Z0-9<]{9}[0-9][A-Z<]{3}[0-9]{6}[0-9][MF<][0-9]{6}[0-9][A-Z0-9<]{14}[0-9<][0-9]$')
                .hasMatch(second)) {
          failure =
              const MrzResult(issues: ['تنسيق MRZ غير مكتمل؛ أعد التصوير']);
          continue;
        }
        final checks = <String, bool>{
          'رقم الجواز': '${checkDigit(second.substring(0, 9))}' == second[9],
          'تاريخ الميلاد':
              '${checkDigit(second.substring(13, 19))}' == second[19],
          'تاريخ الانتهاء':
              '${checkDigit(second.substring(21, 27))}' == second[27],
          'البيانات الاختيارية': second[42] == '<'
              ? second.substring(28, 42) == '<' * 14
              : '${checkDigit(second.substring(28, 42))}' == second[42],
          'التحقق المركب':
              '${checkDigit(second.substring(0, 10) + second.substring(13, 20) + second.substring(21, 43))}' ==
                  second[43],
        };
        final issues = checks.entries
            .where((e) => !e.value)
            .map((e) => 'فشل رقم التحقق: ${e.key}')
            .toList();
        if (issues.isNotEmpty) {
          failure = MrzResult(formatRecognized: true, issues: issues);
          continue;
        }
        final birth = _date(second.substring(13, 19), today, birth: true);
        final expiry = _date(second.substring(21, 27), today, birth: false);
        final names = first.substring(5).split('<<');
        final surname = names.first.replaceAll('<', ' ').trim();
        final given = names
            .skip(1)
            .join(' ')
            .replaceAll('<', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        final number = second.substring(0, 9).replaceAll('<', '');
        final nationality = second.substring(10, 13);
        if (birth == null || expiry == null || !expiry.isAfter(birth)) {
          issues.add('تواريخ الجواز غير متسقة أو غير مقروءة');
        }
        if (surname.isEmpty ||
            number.isEmpty ||
            !RegExp(r'^[A-Z]{3}$').hasMatch(nationality) ||
            !RegExp(r'^[A-Z]{3}$').hasMatch(first.substring(2, 5))) {
          issues.add('بيانات الجواز ناقصة؛ يلزم إعادة التصوير أو مراجعة يدوية');
        }
        if (issues.isNotEmpty) {
          failure = MrzResult(
              formatRecognized: true, checkDigitsPassed: true, issues: issues);
          continue;
        }
        return MrzResult(
            formatRecognized: true,
            checkDigitsPassed: true,
            details: PassportDetails(
                number: number,
                fullName: '$given $surname'.trim(),
                nationality: nationality,
                issuingCountry: first.substring(2, 5),
                sex: second[20],
                birthDate: birth!,
                expiryDate: expiry!,
                expired: expiry
                    .isBefore(DateTime(today.year, today.month, today.day))));
      }
    }
    return failure ??
        const MrzResult(
            issues: ['لم نقرأ سطرَي MRZ لجواز TD3؛ أظهر صفحة البيانات كاملة']);
  }

  static DateTime? _date(String value, DateTime now, {required bool birth}) {
    final yy = int.parse(value.substring(0, 2)),
        month = int.parse(value.substring(2, 4)),
        day = int.parse(value.substring(4, 6));
    final candidates = [1900 + yy, 2000 + yy, 2100 + yy]
        .map((year) => DateTime(year, month, day))
        .where((date) =>
            date.month == month && date.day == day && date.year % 100 == yy)
        .where((date) => birth
            ? !date.isAfter(now) && now.difference(date).inDays <= 120 * 366
            : (date.year - now.year).abs() <= 50)
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => birth
        ? b.compareTo(a)
        : (a.difference(now).inDays.abs())
            .compareTo(b.difference(now).inDays.abs()));
    return candidates.first;
  }

  static bool hasValidPassportMrz(String text) => parseMrz(text).valid;
  static Future<PassportAnalysis> analyzeFrame(
          Map<String, Object> frame) async =>
      PassportAnalysis.fromMap(
          await channel.invokeMapMethod('analyzeFrame', frame) ?? {});
  static Future<PassportAnalysis> inspect(List<int> bytes,
      {void Function(String, String)? onProgress,
      PassportScanOptions options = const PassportScanOptions()}) async {
    _size(bytes);
    _initializeProgress();
    final id = ++_requestId;
    if (onProgress != null) _listeners[id] = onProgress;
    try {
      final data = await channel.invokeMapMethod('inspect', {
            ...options.native,
            'scanId': id,
            'bytes': bytes is Uint8List ? bytes : Uint8List.fromList(bytes)
          }) ??
          {};
      onProgress?.call('information', 'processing');
      final result = PassportAnalysis.fromMap(data);
      onProgress?.call(
          'passport', result.mrz.formatRecognized ? 'passed' : 'retry');
      onProgress?.call('mrz', result.mrz.details != null ? 'passed' : 'retry');
      onProgress?.call(
          'information', result.mrz.canSubmit ? 'passed' : 'failed');
      onProgress?.call('completed', result.mrz.canSubmit ? 'passed' : 'retry');
      return result;
    } on MissingPluginException {
      throw const PassportScanException(
          'المسح متاح على أندرويد وآيفون؛ حدّث التطبيق');
    } on PlatformException {
      throw const PassportScanException(
          'تعذر قراءة الصورة؛ اختر JPG أو PNG واضحًا أو PDF غير محمي');
    } finally {
      _listeners.remove(id);
    }
  }

  static void _size(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const PassportScanException(
          'اختر ملفًا واضحًا لا يتجاوز 5 ميجابايت');
    }
  }

  static Future<void> validate(List<int> bytes) async {
    final result = await inspect(bytes);
    if (!result.mrz.canSubmit) {
      throw PassportScanException(result.mrz.details?.expired == true
          ? 'الجواز منتهي الصلاحية؛ ارفع جوازًا ساريًا'
          : result.mrz.issues.join('\n'));
    }
  }

  static Future<({String? passportNumber, String? dateOfBirth})>
      extractFromBytes(List<int> bytes) async {
    try {
      final result = await inspect(bytes);
      return (
        passportNumber: result.mrz.details?.number,
        dateOfBirth: result.mrz.details?.dateOfBirth
      );
    } on PassportScanException {
      return (passportNumber: null, dateOfBirth: null);
    }
  }
}
