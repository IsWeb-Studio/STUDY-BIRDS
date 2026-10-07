import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';

/// Full-screen camera overlay that guides the user to align their passport
/// inside a passport-shaped frame before capturing.
/// Returns an [XFile] on capture, or null if the user backs out.
class PassportScannerScreen extends StatefulWidget {
  const PassportScannerScreen({super.key});

  @override
  State<PassportScannerScreen> createState() => _PassportScannerScreenState();
}

class _PassportScannerScreenState extends State<PassportScannerScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _ctrl;
  bool _ready = false;
  bool _capturing = false;
  String? _error;

  late final AnimationController _scanAnim;
  late final Animation<double> _scanLine;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanAnim = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _scanLine = CurvedAnimation(parent: _scanAnim, curve: Curves.easeInOut);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _error = 'لا توجد كاميرا');
        return;
      }
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final ctrl = CameraController(cam, ResolutionPreset.high, enableAudio: false);
      await ctrl.initialize();
      if (!mounted) { ctrl.dispose(); return; }
      setState(() { _ctrl = ctrl; _ready = true; });
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر فتح الكاميرا');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _ctrl;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      ctrl.dispose();
      _ctrl = null;
      if (mounted) setState(() => _ready = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _capture() async {
    if (!_ready || _capturing || _ctrl == null) return;
    setState(() => _capturing = true);
    try {
      final img = await _ctrl!.takePicture();
      if (mounted) Navigator.of(context).pop(img);
    } catch (_) {
      if (mounted) {
        setState(() => _capturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر التقاط الصورة، حاول مجدداً')),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanAnim.dispose();
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 56),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.white70, fontSize: 15)),
            const SizedBox(height: 20),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('رجوع'),
            ),
          ]),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final frameW = size.width * 0.88;
    final frameH = frameW * (88 / 125); // passport landscape: 125×88mm
    final frameL = (size.width - frameW) / 2;
    final frameT = (size.height - frameH) / 2 - 30;
    final frameRect = Rect.fromLTWH(frameL, frameT, frameW, frameH);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_ready && _ctrl != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _ctrl!.value.previewSize!.height,
                  height: _ctrl!.value.previewSize!.width,
                  child: CameraPreview(_ctrl!),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // Dark overlay with transparent passport cutout
          CustomPaint(
            size: size,
            painter: _PassportFramePainter(frameRect),
          ),

          // Animated scan line
          if (_ready)
            AnimatedBuilder(
              animation: _scanLine,
              builder: (_, __) {
                final y = frameT + (frameH - 2) * _scanLine.value;
                return Positioned(
                  top: y,
                  left: frameL + 8,
                  width: frameW - 16,
                  height: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.transparent,
                        AppColors.orange.withValues(alpha: 0.9),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                );
              },
            ),

          // Top instruction
          Positioned(
            top: frameT - 72,
            left: 24,
            right: 24,
            child: Column(children: [
              const Text(
                'ضع صفحة بيانات الجواز داخل الإطار',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'تأكد من ظهور المنطقة السفلية (الخطوط الرفيعة) كاملةً',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12.5,
                  shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
            ]),
          ),

          // MRZ label at bottom of frame
          Positioned(
            top: frameT + frameH + 10,
            left: frameL,
            width: frameW,
            child: const Text(
              '▲  منطقة القراءة الآلية (MRZ)',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 11,
                letterSpacing: 0.3,
              ),
            ),
          ),

          // Capture button
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 44,
            left: 0,
            right: 0,
            child: Column(children: [
              GestureDetector(
                onTap: _capturing ? null : _capture,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _capturing ? Colors.grey.shade600 : Colors.white,
                    border: Border.all(color: Colors.white30, width: 4),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 8)],
                  ),
                  child: _capturing
                      ? const Padding(
                          padding: EdgeInsets.all(18),
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
                        )
                      : const Icon(Icons.camera_alt_rounded, color: Colors.black87, size: 30),
                ),
              ),
              const SizedBox(height: 10),
              const Text('اضغط للتصوير',
                  style: TextStyle(color: Colors.white60, fontSize: 12.5)),
            ]),
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            left: 4,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PassportFramePainter extends CustomPainter {
  final Rect frame;
  const _PassportFramePainter(this.frame);

  @override
  void paint(Canvas canvas, Size size) {
    // Dark overlay with transparent cutout
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xAA000000),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(frame, const Radius.circular(6)),
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();

    // Orange border around frame
    canvas.drawRRect(
      RRect.fromRectAndRadius(frame, const Radius.circular(6)),
      Paint()
        ..color = AppColors.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // White corner brackets
    _drawCorners(canvas);
  }

  void _drawCorners(Canvas canvas) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    const arm = 22.0;

    final l = frame.left, t = frame.top, r = frame.right, b = frame.bottom;

    // top-left
    canvas.drawLine(Offset(l, t + arm), Offset(l, t), p);
    canvas.drawLine(Offset(l, t), Offset(l + arm, t), p);
    // top-right
    canvas.drawLine(Offset(r - arm, t), Offset(r, t), p);
    canvas.drawLine(Offset(r, t), Offset(r, t + arm), p);
    // bottom-left
    canvas.drawLine(Offset(l, b - arm), Offset(l, b), p);
    canvas.drawLine(Offset(l, b), Offset(l + arm, b), p);
    // bottom-right
    canvas.drawLine(Offset(r - arm, b), Offset(r, b), p);
    canvas.drawLine(Offset(r, b), Offset(r, b - arm), p);
  }

  @override
  bool shouldRepaint(covariant _PassportFramePainter old) => old.frame != frame;
}
