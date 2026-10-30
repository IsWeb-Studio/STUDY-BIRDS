import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:study_birds/screens/auth/splash_screen.dart';

void main() {
  for (final entry in {
    'assets/images/branding/covey_icon.png': (.72, .5),
    'assets/images/branding/covey_icon_foreground.png': (.52, 33 / 108),
    'assets/images/branding/covey_splash_mark.png': (.80, .5),
    'android/app/src/main/res/drawable-nodpi/covey_launch_android12.png': (
      .56,
      1 / 3
    ),
  }.entries) {
    test('${entry.key} centers the original mark inside its platform mask', () {
      final image = img.decodeImage(File(entry.key).readAsBytesSync())!;
      var left = image.width, top = image.height, right = 0, bottom = 0;
      var radius = 0.0;
      for (final pixel in image) {
        if (pixel.g > pixel.r + 20 && pixel.g > pixel.b + 30) {
          left = math.min(left, pixel.x);
          right = math.max(right, pixel.x);
          top = math.min(top, pixel.y);
          bottom = math.max(bottom, pixel.y);
          final dx = pixel.x - (image.width - 1) / 2;
          final dy = pixel.y - (image.height - 1) / 2;
          radius = math.max(radius, math.sqrt(dx * dx + dy * dy) / image.width);
        }
      }
      expect(image.width, image.height);
      expect(((left + right) / 2 - (image.width - 1) / 2).abs(), lessThan(2));
      expect(((top + bottom) / 2 - (image.height - 1) / 2).abs(), lessThan(2));
      expect((bottom - top + 1) / image.height, closeTo(entry.value.$1, .01));
      expect(radius, lessThanOrEqualTo(entry.value.$2));
    });
  }

  test('iOS launch images have real 1x, 2x and 3x pixel dimensions', () {
    for (var scale = 1; scale <= 3; scale++) {
      final suffix = scale == 1 ? '' : '@${scale}x';
      final image = img.decodeImage(File(
              'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage$suffix.png')
          .readAsBytesSync())!;
      expect(image.width, 200 * scale);
      expect(image.height, 200 * scale);
    }
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
    const Size(768, 1024)
  ]) {
    testWidgets('splash keeps the collage and separate COVEY mark within $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
      await tester.pumpAndSettle();
      expect(find.text('COVEY'), findsOneWidget);
      final logo =
          tester.getRect(find.byKey(const ValueKey('splash-covey-mark')));
      expect(logo.width, closeTo(logo.height, .01));
      expect(logo.left, greaterThanOrEqualTo(0));
      expect(logo.bottom, lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
