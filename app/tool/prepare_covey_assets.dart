import 'dart:io';
import 'package:image/image.dart' as img;

/// Build platform-sized assets from the original supplied mark. Never redraw it.
void main() {
  final original = img.decodeImage(
      File('assets/images/branding/covey_logo.jpg').readAsBytesSync())!;
  final png = img.encodePng(original);
  for (final name in ['logo_mark', 'logo_full', 'logo']) {
    File('assets/images/$name.png').writeAsBytesSync(png);
  }
  // Find the green artwork independently of the source image's uneven margins.
  var left = original.width, top = original.height, right = 0, bottom = 0;
  for (final pixel in original) {
    if (pixel.g > pixel.r + 20 && pixel.g > pixel.b + 30) {
      if (pixel.x < left) left = pixel.x;
      if (pixel.x > right) right = pixel.x;
      if (pixel.y < top) top = pixel.y;
      if (pixel.y > bottom) bottom = pixel.y;
    }
  }
  if (right <= left || bottom <= top) throw StateError('COVEY mark not found');
  final mark = img.copyCrop(original,
      x: left, y: top, width: right - left + 1, height: bottom - top + 1);
  final icon = img.encodePng(frame(mark, 1024, .72));
  File('assets/images/branding/covey_icon.png').writeAsBytesSync(icon);
  File('assets/images/branding/covey_icon_foreground.png')
      .writeAsBytesSync(img.encodePng(frame(mark, 1080, .52)));
  File('assets/images/branding/covey_splash_mark.png')
      .writeAsBytesSync(img.encodePng(frame(mark, 1024, .80)));
  File('assets/images/app_icon.png').writeAsBytesSync(icon);
  File('android/app/src/main/res/drawable-nodpi/covey_launch_mark.png')
      .writeAsBytesSync(img.encodePng(frame(mark, 600, .80)));
  // Android 12 applies its own circular mask, independently of launcher icons.
  File('android/app/src/main/res/drawable-nodpi/covey_launch_android12.png')
      .writeAsBytesSync(img.encodePng(frame(mark, 864, .56)));
  for (var scale = 1; scale <= 3; scale++) {
    final suffix = scale == 1 ? '' : '@${scale}x';
    File('ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage$suffix.png')
        .writeAsBytesSync(img.encodePng(frame(mark, 200 * scale, .80)));
  }
}

img.Image frame(img.Image mark, int size, double fraction) {
  final canvas = img.Image(width: size, height: size, numChannels: 3);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  final maxSide = (size * fraction).round();
  final scale = maxSide / (mark.width > mark.height ? mark.width : mark.height);
  final scaled = img.copyResize(mark,
      width: (mark.width * scale).round(),
      height: (mark.height * scale).round(),
      interpolation: img.Interpolation.average);
  img.compositeImage(canvas, scaled,
      dstX: (size - scaled.width) ~/ 2, dstY: (size - scaled.height) ~/ 2);
  return canvas;
}
