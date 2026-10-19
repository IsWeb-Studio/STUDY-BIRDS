import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/widgets/profile_bottom_navigation.dart';
import 'package:study_birds/core/services/auth_session.dart';

void main() {
  const labels = [
    'الرئيسية',
    'رحلتي',
    'الاستكشاف',
    'الخدمات',
    'المجتمع',
    'الغمّازة',
    'حسابي'
  ];
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthSession.instance.currentUser = const AuthUser(
        id: 'nav-preview',
        name: 'Abood',
        email: 'test@example.test',
        role: UserRole.student);
  });
  tearDown(() => AuthSession.instance.currentUser = null);
  for (final width in [320.0, 390.0, 600.0]) {
    testWidgets('center account and all destinations remain tappable at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = -1;
      await tester.pumpWidget(MaterialApp(
          home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                  bottomNavigationBar: ProfileBottomNavigation(
                      currentIndex: 6,
                      labels: labels,
                      onTap: (i) => selected = i)))));
      await tester.pumpAndSettle();
      final avatar = find.byKey(const ValueKey('main-account-avatar'));
      final rect = tester.getRect(avatar);
      expect(rect.center.dx, closeTo(width / 2, .01));
      expect(rect.width, closeTo(rect.height, .01));
      expect(tester.getCenter(find.byKey(const ValueKey('main-tab-2'))).dx,
          greaterThan(rect.center.dx));
      expect(tester.getCenter(find.byKey(const ValueKey('main-tab-3'))).dx,
          lessThan(rect.center.dx));
      await tester.tapAt(Offset(rect.center.dx, rect.top + 3));
      expect(selected, 6);
      for (var i = 0; i < 7; i++) {
        await tester.tap(find.byKey(ValueKey('main-tab-$i')));
        expect(selected, i);
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('large text stays within the bar; render actual design preview',
      (tester) async {
    tester.view.physicalSize = const Size(430, 230);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    final output = Platform.environment['NAV_PREVIEW'];
    if (output != null) {
      await tester.runAsync(() async {
        await (FontLoader('Tajawal')
              ..addFont(rootBundle.load('assets/fonts/Tajawal-Regular.ttf')))
            .load();
        final iconFont = Platform.environment['MATERIAL_ICON_FONT'];
        if (iconFont != null) {
          final bytes = await File(iconFont).readAsBytes();
          await (FontLoader('MaterialIcons')
                ..addFont(Future.value(ByteData.sublistView(bytes))))
              .load();
        }
      });
    }
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'Tajawal'),
        home: MediaQuery(
            data: MediaQueryData(
                textScaler: TextScaler.linear(output == null ? 1.8 : 1),
                padding: const EdgeInsets.only(bottom: 24)),
            child: Directionality(
                textDirection: TextDirection.rtl,
                child: RepaintBoundary(
                    key: boundary,
                    child: Scaffold(
                        backgroundColor: const Color(0xFFF2F6FC),
                        bottomNavigationBar: ProfileBottomNavigation(
                            currentIndex: 6,
                            labels: labels,
                            onTap: (_) {})))))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (output != null) {
      await tester.runAsync(() async {
        final image = await (boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(output).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
