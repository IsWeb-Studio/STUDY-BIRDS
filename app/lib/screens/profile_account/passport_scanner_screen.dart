import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/config/app_theme.dart';
import '../../core/utils/passport_scan.dart';

/// Reviewed data is separate from the unmodified MRZ validation result.
class ReviewedPassportFile extends PlatformFile {
  final PassportAnalysis analysis;
  final Map<String, String> reviewedFields;
  final Set<String> correctedFields;
  ReviewedPassportFile(
      {required super.name,
      required Uint8List super.bytes,
      required this.analysis,
      required this.reviewedFields,
      required this.correctedFields})
      : super(size: bytes.length);
  Map<String, Object> get submissionMetadata {
    final d = analysis.mrz.details!;
    return {
      'extracted': {
        'number': d.number,
        'name': d.fullName,
        'nationality': d.nationality,
        'birth': d.dateOfBirth,
        'expiry': d.expirationDate,
        'sex': d.sex
      },
      'reviewed': reviewedFields,
      'clientReportedMrzChecksPassed': analysis.mrz.checkDigitsPassed,
    };
  }
}

/// One scanner and review route shared by live captures, photos and PDF imports.
/// No network calls. A confirmed result is handed back to the existing uploader.
class PassportScannerScreen extends StatefulWidget {
  final PlatformFile? initialFile;
  final PassportScanOptions options;
  const PassportScannerScreen(
      {super.key,
      this.initialFile,
      this.options = const PassportScanOptions()});
  @override
  State<PassportScannerScreen> createState() => _PassportScannerScreenState();
}

class _PassportScannerScreenState extends State<PassportScannerScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _camera;
  Future<void> _cameraTransition = Future.value();
  bool _active = true, _ready = false, _busy = false, _analyzing = false;
  bool _torch = false, _liveAvailable = true, _review = false, _consent = false;
  bool _showOriginal = false;
  int _generation = 0;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);
  late final PassportStability _stability;
  PassportAnalysis? _analysis;
  Uint8List? _original;
  String _fileName = 'passport.jpg';
  String _guidance = 'ضع صفحة بيانات الجواز داخل الإطار';
  String? _error;
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  final _originalFields = <String, String>{};
  final _corrected = <String>{};
  final _stages = <String, String>{};
  late final AnimationController _line;

  @override
  void initState() {
    super.initState();
    _stability = PassportStability(
        requiredFrames: widget.options.stableFrames,
        maxMovement: widget.options.maxMovement,
        options: widget.options);
    WidgetsBinding.instance.addObserver(this);
    _line =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    if (widget.initialFile case final file?) {
      _fileName = file.name;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (file.bytes == null) {
          setState(() => _error = 'تعذر قراءة الملف');
          return;
        }
        _process(file.bytes!);
      });
    } else {
      _scheduleCamera();
    }
  }

  void _scheduleCamera() {
    final generation = ++_generation;
    _cameraTransition = _cameraTransition
        .catchError((_) {})
        .then((_) => _openCamera(generation));
  }

  Future<void> _openCamera(int generation) async {
    if (!mounted ||
        !_active ||
        _review ||
        widget.initialFile != null ||
        generation != _generation) {
      return;
    }
    CameraController? next;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw const PassportScanException('لا توجد كاميرا متاحة');
      }
      final back = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first);
      next = CameraController(back, ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: Platform.isIOS
              ? ImageFormatGroup.bgra8888
              : ImageFormatGroup.yuv420);
      await next.initialize();
      if (!mounted || !_active || generation != _generation) {
        await next.dispose();
        return;
      }
      _camera = next;
      setState(() {
        _ready = true;
        _error = null;
        _torch = false;
      });
      await _startStream(next);
    } catch (_) {
      if (next != null && next != _camera) await next.dispose();
      if (mounted && generation == _generation) {
        setState(() => _error =
            'تعذر فتح الكاميرا. اسمح باستخدامها من إعدادات الهاتف ثم أعد المحاولة.');
      }
    }
  }

  Future<void> _startStream(CameraController camera) async {
    if (!mounted || !_active || _review || _camera != camera) return;
    try {
      await camera.startImageStream((image) => _onFrame(image, camera));
    } catch (_) {
      if (mounted && _camera == camera) {
        setState(() {
          _liveAvailable = false;
          _guidance = 'التحليل الحي غير متاح؛ يمكنك التصوير يدويًا';
        });
      }
    }
  }

  int _rotation(CameraController camera) {
    // AVFoundation rotates captureVideoOutput buffers to device orientation.
    // CameraX delivers sensor-oriented YUV, which still needs this correction.
    if (Platform.isIOS) return 0;
    final angle = switch (camera.value.deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    return camera.description.lensDirection == CameraLensDirection.front
        ? (camera.description.sensorOrientation + angle) % 360
        : (camera.description.sensorOrientation - angle + 360) % 360;
  }

  Future<void> _onFrame(CameraImage image, CameraController camera) async {
    final now = DateTime.now();
    if (!_liveAvailable ||
        _analyzing ||
        _busy ||
        !_active ||
        _review ||
        _camera != camera ||
        now.difference(_lastFrame).inMilliseconds <
            widget.options.frameIntervalMs) {
      return;
    }
    _lastFrame = now;
    _analyzing = true;
    final generation = _generation;
    try {
      final plane = image.planes.first;
      final result = await PassportScan.analyzeFrame({
        ...widget.options.native,
        'bytes': plane.bytes,
        'width': image.width,
        'height': image.height,
        'rowStride': plane.bytesPerRow,
        'pixelStride': plane.bytesPerPixel ??
            (image.format.group == ImageFormatGroup.bgra8888 ? 4 : 1),
        'format':
            image.format.group == ImageFormatGroup.bgra8888 ? 'bgra' : 'yuv',
        'rotation': _rotation(camera),
      });
      if (!mounted || !_active || _busy || generation != _generation) return;
      final capture = _stability.add(result);
      setState(() {
        _analysis = result;
        _guidance = !result.documentDetected
            ? 'نبحث عن الجواز؛ أظهر الصفحة كاملة واقترب قليلًا'
            : !result.quality.acceptableWith(widget.options)
                ? result.quality.guidanceWith(widget.options)
                : !result.mrz.valid
                    ? 'ظهر مستند؛ نقرأ سطرَي MRZ لتحديد الجواز'
                    : result.mrz.details!.expired
                        ? 'الجواز منتهي الصلاحية؛ استخدم جوازًا ساريًا'
                        : !result.mrzInLowerRegion
                            ? 'أظهر سطرَي MRZ أسفل صفحة البيانات'
                            : result.ocrConfidence == null ||
                                    result.ocrConfidence! <
                                        widget.options.minOcrConfidence
                                ? 'القراءة غير مؤكدة؛ اقترب قليلًا أو صوّر يدويًا'
                                : 'تم التعرف على تنسيق الجواز؛ ثبّت الهاتف';
      });
      if (capture) await _capture();
    } on MissingPluginException {
      if (mounted && generation == _generation) {
        setState(() {
          _liveAvailable = false;
          _guidance = 'حدّث التطبيق لتفعيل التحليل الحي';
        });
      }
    } catch (_) {
      _stability.reset();
      if (mounted && generation == _generation && !_busy) {
        setState(() => _guidance = 'تعذر تحليل الإطار؛ يمكنك التصوير يدويًا');
      }
    } finally {
      if (mounted && !_active) setState(() => _busy = false);
      _analyzing = false;
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (_busy || !_ready || !_active || camera == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _guidance = 'جارٍ التقاط الصورة وفحصها';
    });
    XFile? picture;
    try {
      if (camera.value.isStreamingImages) await camera.stopImageStream();
      picture = await camera.takePicture();
      final bytes = await picture.readAsBytes();
      if (!mounted || !_active || _camera != camera) return;
      _fileName = 'passport.jpg';
      await _process(bytes);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'تعذر التصوير. حاول مجددًا';
        });
      }
    } finally {
      // Only camera-owned temporary captures are deleted; gallery files are untouched.
      if (mounted && !_active) setState(() => _busy = false);
      if (picture != null) {
        try {
          await File(picture.path).delete();
        } catch (_) {/* Already removed by OS. */}
      }
      if (mounted && !_review) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _process(Uint8List bytes) async {
    if (!mounted) return;
    _stability.reset();
    setState(() {
      _busy = true;
      _analysis = null;
      _original = bytes;
      _guidance = 'فحص جودة الصورة وقراءة MRZ على جهازك';
    });
    try {
      _stages.clear();
      final result = await PassportScan.inspect(bytes, options: widget.options,
          onProgress: (stage, state) {
        if (mounted) setState(() => _stages[stage] = state);
      });
      if (!mounted) return;
      _analysis = result;
      final details = result.mrz.details;
      if (details != null) {
        _originalFields.addAll({
          'number': details.number,
          'name': details.fullName,
          'nationality': details.nationality,
          'birth': details.dateOfBirth,
          'expiry': details.expirationDate,
          'sex': details.sex
        });
        for (final entry in _originalFields.entries) {
          _fields[entry.key]?.dispose();
          _fields[entry.key] = TextEditingController(text: entry.value);
        }
      }
      setState(() {
        _review = true;
        _busy = false;
        _consent = false;
        _corrected.clear();
        _showOriginal = false;
      });
      final old = _camera;
      _camera = null;
      _ready = false;
      _generation++;
      if (old != null) await old.dispose();
    } on PassportScanException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _busy = false;
          _review = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'تعذر تحليل الصورة؛ أعد التصوير';
          _busy = false;
          _review = true;
        });
      }
    } finally {
      if (mounted && _review) {
        _line.stop();
        if (_error != null) {
          setState(() {
            for (final stage in _stages.keys.toList()) {
              if (_stages[stage] == 'processing') _stages[stage] = 'failed';
            }
            _stages['completed'] = 'retry';
          });
        }
      }
    }
  }

  Future<void> _retry() async {
    _stability.reset();
    _stages.clear();
    final old = _camera;
    _camera = null;
    if (old != null) await old.dispose();
    if (!mounted) return;
    if (widget.initialFile != null) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _review = false;
      _ready = false;
      _busy = false;
      _analysis = null;
      _original = null;
      _error = null;
      _liveAvailable = true;
      _guidance = 'ضع صفحة بيانات الجواز داخل الإطار';
    });
    _line.repeat(reverse: true);
    _scheduleCamera();
  }

  Future<void> _flash() async {
    final camera = _camera;
    if (camera == null || _busy) return;
    try {
      await camera.setFlashMode(_torch ? FlashMode.off : FlashMode.torch);
      if (mounted) setState(() => _torch = !_torch);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الفلاش غير متاح على هذه الكاميرا')));
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _active = true;
      if (!_review && !_line.isAnimating) _line.repeat(reverse: true);
      if (!_review && widget.initialFile == null) _scheduleCamera();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _active = false;
      _line.stop();
      _generation++;
      _stability.reset();
      final old = _camera;
      _camera = null;
      if (mounted) setState(() => _ready = false);
      _cameraTransition = _cameraTransition.then((_) async {
        if (old != null) await old.dispose();
      });
    }
  }

  @override
  void dispose() {
    _active = false;
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _line.dispose();
    _camera?.dispose();
    for (final field in _fields.values) {
      field.dispose();
    }
    _original = null;
    super.dispose();
  }

  void _confirm() {
    if (!_consent ||
        !(_analysis?.mrz.canSubmit ?? false) ||
        !_form.currentState!.validate()) {
      return;
    }
    final values =
        _fields.map((key, value) => MapEntry(key, value.text.trim()));
    final birth = DateTime.tryParse(values['birth']!),
        expiry = DateTime.tryParse(values['expiry']!);
    final now = DateTime.now();
    if (birth == null ||
        expiry == null ||
        birth.isAfter(now) ||
        !expiry.isAfter(birth) ||
        expiry.isBefore(DateTime(now.year, now.month, now.day))) {
      setState(() => _error =
          'راجع تاريخ الميلاد والانتهاء؛ يجب أن تكون البيانات كاملة والجواز ساريًا');
      return;
    }
    final bytes = _analysis!.correctedBytes ?? _original!;
    Navigator.pop(
        context,
        ReviewedPassportFile(
            name:
                _analysis!.correctedBytes != null ? 'passport.jpg' : _fileName,
            bytes: bytes,
            analysis: _analysis!,
            reviewedFields: values,
            correctedFields: Set.of(_corrected)));
  }

  Widget _progress({bool dark = false}) {
    final analysis = _analysis;
    final checks = <String, (String, bool?)>{
      'document': ('كشف المستند', analysis?.documentDetected),
      'quality': (
        'جودة الصورة',
        analysis?.quality.acceptableWith(widget.options)
      ),
      'passport': (
        'تحديد تنسيق الجواز',
        analysis?.ocrAttempted == true ? analysis?.mrz.formatRecognized : null
      ),
      'mrz': (
        'قراءة MRZ',
        analysis?.ocrAttempted == true ? analysis!.mrz.details != null : null
      ),
      'information': (
        'اتساق المعلومات',
        analysis?.ocrAttempted == true ? analysis?.mrz.canSubmit : null
      ),
      'completed': ('اكتمال المسح', _review ? analysis?.mrz.canSubmit : null),
    };
    return Wrap(
        spacing: 8,
        runSpacing: 6,
        children: checks.entries.map((entry) {
          final state = _stages[entry.key] ??
              (entry.value.$2 == null
                  ? 'waiting'
                  : entry.value.$2!
                      ? 'passed'
                      : 'retry');
          final label = switch (state) {
            'processing' => 'قيد المعالجة',
            'passed' => 'اجتاز',
            'failed' => 'فشل',
            'retry' => 'أعد المحاولة',
            _ => 'بانتظار'
          };
          return Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
                state == 'processing'
                    ? Icons.hourglass_top
                    : state == 'passed'
                        ? Icons.check_circle_outline
                        : state == 'waiting'
                            ? Icons.more_horiz
                            : Icons.refresh,
                size: 15,
                color: state == 'passed'
                    ? (dark ? Colors.greenAccent : Colors.green.shade700)
                    : dark
                        ? Colors.white70
                        : Colors.grey.shade700),
            const SizedBox(width: 4),
            Text('${entry.value.$1}: $label',
                style: TextStyle(
                    fontSize: 10,
                    color: dark ? Colors.white70 : Colors.black87)),
          ]);
        }).toList());
  }

  Widget _result() {
    final result = _analysis;
    final image = _showOriginal
        ? result?.originalPreviewBytes ?? _original
        : result?.correctedBytes ?? result?.originalPreviewBytes ?? _original;
    final pdf = image != null &&
        image.length >= 5 &&
        String.fromCharCodes(image.take(5)) == '%PDF-';
    return Scaffold(
        appBar: AppBar(title: const Text('مراجعة بيانات الجواز')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          if (image != null && !pdf)
            ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(image,
                    height: 210,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Text('تعذر عرض الصورة'))),
          if (pdf)
            const ListTile(
                leading: Icon(Icons.picture_as_pdf),
                title: Text('ملف PDF؛ تمت قراءة أول 3 صفحات على الجهاز')),
          if (result?.correctedBytes != null)
            SwitchListTile(
                title: const Text('عرض الصورة الأصلية'),
                value: _showOriginal,
                onChanged: (v) => setState(() => _showOriginal = v)),
          const SizedBox(height: 16),
          _progress(),
          const SizedBox(height: 16),
          Text(
              result?.mrz.canSubmit == true
                  ? 'تم التعرف على تنسيق الجواز واستخراج البيانات'
                  : 'يلزم إعادة التصوير أو مراجعة يدوية',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
              'فحص MRZ يتحقق من التنسيق واتساق البيانات فقط؛ لا يثبت أصالة الجواز أو ملكيته.'),
          if (result != null) ...[
            const SizedBox(height: 8),
            Text(result.quality.guidanceWith(widget.options)),
            if (!result.mrzInLowerRegion)
              const Text('لم يتضح موضع MRZ أسفل الصفحة؛ راجع المستند يدويًا.'),
            if (!result.documentDetected)
              const Text('لم تتضح حدود المستند؛ راجع الصورة كاملة يدويًا.'),
            if (result.ocrConfidence == null ||
                result.ocrConfidence! < widget.options.minOcrConfidence)
              const Text(
                  'ثقة القراءة غير كافية للالتقاط التلقائي؛ راجع كل حقل يدويًا.'),
            if (result.mrz.details?.expired == true)
              const Text('الجواز منتهي الصلاحية؛ لا يمكن تأكيده للرفع'),
            for (final issue in result.mrz.issues)
              Text(issue, style: const TextStyle(color: Colors.red)),
          ],
          if (_error != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child:
                    Text(_error!, style: const TextStyle(color: Colors.red))),
          if (result?.mrz.details != null)
            Form(
                key: _form,
                child: Column(children: [
                  for (final entry in const {
                    'number': 'رقم الجواز',
                    'name': 'الاسم الكامل',
                    'nationality': 'رمز الجنسية (3 أحرف)',
                    'birth': 'تاريخ الميلاد (YYYY-MM-DD)',
                    'expiry': 'تاريخ الانتهاء (YYYY-MM-DD)',
                    'sex': 'الجنس (M / F / <)'
                  }.entries)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: TextFormField(
                          controller: _fields[entry.key],
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                              labelText: entry.value,
                              helperText: _corrected.contains(entry.key)
                                  ? 'عدلته أنت؛ يحتاج مراجعة يدوية'
                                  : 'مستخرج من MRZ؛ اجتاز فحص الاتساق'),
                          onChanged: (value) => setState(() {
                            if (value.trim() == _originalFields[entry.key]) {
                              _corrected.remove(entry.key);
                            } else {
                              _corrected.add(entry.key);
                            }
                          }),
                          validator: (value) {
                            final v = value?.trim() ?? '';
                            if (entry.key == 'name' && v.length > 200) {
                              return 'الاسم طويل جدًا (حتى 200 حرف)';
                            }
                            if (v.isEmpty) return 'هذا الحقل مطلوب';
                            if (entry.key == 'number' &&
                                !RegExp(r'^[A-Z0-9]{1,9}$').hasMatch(v)) {
                              return 'استخدم أحرفًا إنجليزية كبيرة وأرقامًا (حتى 9)';
                            }
                            if (entry.key == 'nationality' &&
                                !RegExp(r'^[A-Z]{3}$').hasMatch(v)) {
                              return 'استخدم رمزًا من 3 أحرف كبيرة';
                            }
                            if (entry.key == 'sex' &&
                                !['M', 'F', '<'].contains(v)) {
                              return 'استخدم M أو F أو <';
                            }
                            if (['birth', 'expiry'].contains(entry.key) &&
                                !_validDate(v)) {
                              return 'أدخل تاريخًا صحيحًا بصيغة YYYY-MM-DD';
                            }
                            return null;
                          },
                        )),
                ])),
          if (_corrected.isNotEmpty)
            const Text(
                'تصحيحاتك منفصلة عن بيانات MRZ؛ لا تغيّر نتيجة فحص أرقام التحقق.'),
          CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _consent,
              onChanged: result?.mrz.canSubmit == true
                  ? (value) => setState(() => _consent = value ?? false)
                  : null,
              title: const Text(
                  'راجعت البيانات وأوافق على إرسال صورة الجواز لفريق القبول لإكمال طلبي')),
          FilledButton(
              onPressed:
                  _consent && result?.mrz.canSubmit == true ? _confirm : null,
              child: const Text('تأكيد المعلومات ومتابعة الرفع')),
          TextButton(
              onPressed: _retry,
              child: Text(widget.initialFile == null
                  ? 'إعادة المسح'
                  : 'اختيار صورة أو ملف آخر')),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
        ]));
  }

  bool _validDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    final date = DateTime.tryParse(value);
    return date != null && date.toIso8601String().substring(0, 10) == value;
  }

  @override
  Widget build(BuildContext context) {
    if (_review) return _result();
    return Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(builder: (context, constraints) {
          final size = constraints.biggest;
          final padding = MediaQuery.paddingOf(context);
          final availableHeight =
              math.max(80.0, size.height - padding.vertical - 260);
          final width = math.min(size.width * .88, availableHeight * 125 / 88);
          final height = width * 88 / 125;
          final frame = Rect.fromLTWH((size.width - width) / 2,
              padding.top + 85 + (availableHeight - height) / 2, width, height);
          return Stack(fit: StackFit.expand, children: [
            if (_ready && _camera != null)
              Center(child: CameraPreview(_camera!))
            else if (_error == null)
              const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
            CustomPaint(painter: _PassportFramePainter(frame)),
            if (_ready && !_busy)
              AnimatedBuilder(
                  animation: _line,
                  builder: (_, __) => Positioned(
                      left: frame.left + 10,
                      top: frame.top + 8 + (height - 16) * _line.value,
                      width: width - 20,
                      height: 2,
                      child: const DecoratedBox(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                        Colors.transparent,
                        AppColors.orange,
                        Colors.transparent
                      ]))))),
            SafeArea(
                child: Column(children: [
              Row(children: [
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'إلغاء',
                    icon: const Icon(Icons.close, color: Colors.white)),
                const Expanded(
                    child: Text('مسح جواز السفر',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))),
                IconButton(
                    onPressed: _ready && !_busy ? _flash : null,
                    tooltip: 'الفلاش',
                    icon: Icon(_torch ? Icons.flash_on : Icons.flash_off,
                        color: Colors.white))
              ]),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(_error ?? _guidance,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 15))),
              const Spacer(),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _progress(dark: true)),
              const SizedBox(height: 12),
              if (_error != null)
                TextButton(
                    onPressed: _retry, child: const Text('إعادة المحاولة')),
              FilledButton.icon(
                  onPressed: _ready && !_busy ? _capture : null,
                  icon: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.camera_alt),
                  label: Text(_busy
                      ? 'فحص الصورة وقراءة المعلومات...'
                      : 'التقاط يدوي')),
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                      _liveAvailable
                          ? 'التقاط تلقائي بعد قراءة MRZ وثبات الجواز؛ لا تُرسل الصورة قبل تأكيدك'
                          : 'يمكنك التصوير يدويًا ثم مراجعة النتيجة',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11))),
            ])),
          ]);
        }));
  }
}

class _PassportFramePainter extends CustomPainter {
  final Rect frame;
  const _PassportFramePainter(this.frame);
  @override
  void paint(Canvas canvas, Size size) {
    final cutout = RRect.fromRectAndRadius(frame, const Radius.circular(16));
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(cutout);
    canvas.drawPath(mask, Paint()..color = const Color(0xB3000000));
    canvas.drawRRect(
        cutout,
        Paint()
          ..color = AppColors.orange
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const arm = 20.0;
    for (final corner in [
      frame.topLeft,
      frame.topRight,
      frame.bottomLeft,
      frame.bottomRight
    ]) {
      final dx = corner.dx == frame.left ? arm : -arm,
          dy = corner.dy == frame.top ? arm : -arm;
      canvas.drawLine(corner + Offset(0, dy), corner, paint);
      canvas.drawLine(corner, corner + Offset(dx, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PassportFramePainter old) => old.frame != frame;
}
