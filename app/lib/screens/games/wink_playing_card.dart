import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Only mounted with the caller's private card number after a deliberate hold.
class WinkPlayingCard extends StatelessWidget {
  final bool revealed;
  final int? number;
  const WinkPlayingCard({super.key, required this.revealed, this.number});
  static const _cream = Color(0xFFF2EEE5);
  static const _navy = Color(0xFF193F68);

  @override
  Widget build(BuildContext context) => Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 290),
        child: AspectRatio(
            aspectRatio: 2 / 3,
            child: FittedBox(
                child: SizedBox(
                    width: 290,
                    height: 435,
                    child: Semantics(
                      image: true,
                      label: !revealed
                          ? (Localizations.localeOf(context).languageCode ==
                                  'ar'
                              ? 'ظهر كرت مغلق'
                              : 'Hidden card back')
                          : number == 11
                              ? (Localizations.localeOf(context).languageCode ==
                                      'ar'
                                  ? 'كرت العين، الغمّاز'
                                  : 'Eye card, the winker')
                              : '${number ?? ''}',
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x55000000),
                                    blurRadius: 20,
                                    offset: Offset(0, 8))
                              ]),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: !revealed
                                ? Image.asset(
                                    'assets/images/games/wink_back.png',
                                    fit: BoxFit.fill,
                                    cacheWidth: 600)
                                : ColoredBox(
                                    color: _cream,
                                    child: Stack(children: [
                                      const Positioned.fill(
                                          child: CustomPaint(
                                              painter: _LinenPainter())),
                                      if (number != 11)
                                        Positioned(
                                            top: 16,
                                            left: 20,
                                            child: Text('${number ?? ''}',
                                                textScaler:
                                                    TextScaler.noScaling,
                                                style: const TextStyle(
                                                    fontSize: 34,
                                                    color: _navy,
                                                    fontWeight:
                                                        FontWeight.w600))),
                                      Positioned.fill(
                                          child: Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      28, 70, 28, 72),
                                              child: number == 11
                                                  ? Image.asset(
                                                      'assets/images/games/wink_eye.png',
                                                      fit: BoxFit.contain,
                                                      cacheWidth: 600)
                                                  : _OrnamentNumber(
                                                      number: number))),
                                      const Positioned(
                                          bottom: 22,
                                          left: 12,
                                          right: 12,
                                          child: Text('STUDY BIRDS',
                                              textAlign: TextAlign.center,
                                              textScaler: TextScaler.noScaling,
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  letterSpacing: .8,
                                                  fontWeight: FontWeight.w800,
                                                  color: _navy))),
                                    ])),
                          )),
                    )))),
      ));
}

class _LinenPainter extends CustomPainter {
  const _LinenPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x08193F68)
      ..strokeWidth = .5;
    for (double x = 0; x < size.width; x += 3) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OrnamentNumber extends StatefulWidget {
  final int? number;
  const _OrnamentNumber({this.number});
  @override
  State<_OrnamentNumber> createState() => _OrnamentNumberState();
}

class _OrnamentNumberState extends State<_OrnamentNumber> {
  ImageStream? _stream;
  late final ImageStreamListener _listener;
  ImageInfo? _image;
  @override
  void initState() {
    super.initState();
    _listener = ImageStreamListener((image, _) {
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _image?.dispose();
        _image = image;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream?.removeListener(_listener);
    _stream = const AssetImage('assets/images/games/wink_ornament.png')
        .resolve(createLocalImageConfiguration(context));
    _stream!.addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _NumberPainter(widget.number, _image?.image));
}

class _NumberPainter extends CustomPainter {
  final int? number;
  final ui.Image? image;
  const _NumberPainter(this.number, this.image);
  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()..color = const Color(0xFF193F68);
    if (image != null) {
      ink.shader = ImageShader(
          image!,
          TileMode.repeated,
          TileMode.repeated,
          Matrix4.diagonal3Values(170 / image!.width, 170 / image!.height, 1)
              .storage);
    }
    final text = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
            text: '${number ?? ''}',
            style: TextStyle(
                fontFamily: 'serif',
                fontWeight: FontWeight.w900,
                height: 1,
                fontFeatures: const [ui.FontFeature.liningFigures()],
                fontSize: size.height * 1.2,
                foreground: ink)));
    text.layout();
    final scaleX = (size.width / text.width).clamp(0.0, 1.0);
    const scaleY = 1.0;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate((size.width - text.width * scaleX) / 2,
        (size.height - text.height * scaleY) / 2);
    canvas.scale(scaleX, scaleY);
    text.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NumberPainter oldDelegate) =>
      number != oldDelegate.number || image != oldDelegate.image;
}
