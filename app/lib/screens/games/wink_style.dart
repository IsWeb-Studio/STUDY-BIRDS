import 'package:flutter/material.dart';

/// The selected Sky Clean design, shared by every Winker state and dialog.
abstract final class WinkSky {
  static const navy = Color(0xFF09285C);
  static const orange = Color(0xFFFF741C);
  static const sky = Color(0xFFE2F4FF);
  static const header = Color(0xFFBDE7FF);
  static const muted = Color(0xFF6683A4);
  static const pale = Color(0xFFEAF4FB);
  static const green = Color(0xFF36C98C);

  static ThemeData theme(ThemeData base) => ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      fontFamily: base.textTheme.bodyMedium?.fontFamily,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      scaffoldBackgroundColor: sky,
      colorScheme: ColorScheme.fromSeed(seedColor: orange).copyWith(
          primary: orange,
          onPrimary: Colors.white,
          secondary: navy,
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: navy,
          onSurfaceVariant: muted,
          outline: const Color(0xFFCADFED)),
      appBarTheme: const AppBarTheme(
          backgroundColor: header,
          foregroundColor: navy,
          scrolledUnderElevation: 0,
          centerTitle: true,
          elevation: 0),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              animationDuration: Duration.zero,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              foregroundColor: navy,
              side: const BorderSide(color: Color(0xFFD6E7F4)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)))),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              foregroundColor: navy, animationDuration: Duration.zero)),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: pale,
          helperMaxLines: 3,
          labelStyle: const TextStyle(color: muted),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFFD6E7F4))),
          focusedBorder:
              OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: orange, width: 1.5))),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.white, showDragHandle: true, shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28)))),
      dialogTheme: const DialogThemeData(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(26)))));
}

class WinkSkyClouds extends CustomPainter {
  const WinkSkyClouds();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xA6FFFFFF);
    final y = size.height * .72;
    for (var i = -1; i < 9; i++) {
      final x = i * size.width / 7;
      canvas.drawCircle(
          Offset(x, y + (i.isEven ? 12 : 0)), size.width / 10, paint);
    }
    canvas.drawRect(Rect.fromLTRB(0, y + 15, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant WinkSkyClouds oldDelegate) => false;
}

class WinkAvatar extends StatelessWidget {
  final String id;
  final String? url;
  final double size;
  const WinkAvatar({super.key, required this.id, this.url, this.size = 64});
  @override
  Widget build(BuildContext context) {
    final index = id.codeUnits.fold<int>(0, (sum, n) => sum + n) % 4;
    Widget fallback() => Stack(children: [
          Positioned(
              left: -(index % 2) * size,
              top: -(index ~/ 2) * size,
              width: size * 2,
              height: size * 2,
              child: Image.asset('assets/images/games/wink_avatars.png',
                  fit: BoxFit.fill,
                  cacheWidth: 512,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.person_rounded, color: WinkSky.navy))),
        ]);
    return SizedBox(
        width: size,
        height: size,
        child: ClipOval(
            child: ColoredBox(
                color: WinkSky.pale,
                child: url != null && Uri.tryParse(url!)?.scheme == 'https'
                    ? Image.network(url!,
                        fit: BoxFit.cover,
                        cacheWidth: 192,
                        errorBuilder: (_, __, ___) => fallback())
                    : fallback())));
  }
}
