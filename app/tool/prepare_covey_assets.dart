import 'dart:io';
import 'package:image/image.dart' as img;

/// Format conversion only: preserve the supplied artwork's pixels and margins.
void main() {
  final original = img.decodeImage(
      File('assets/images/branding/covey_logo.jpg').readAsBytesSync())!;
  final png = img.encodePng(original);
  for (final name in ['logo_mark', 'logo_full', 'logo']) {
    File('assets/images/$name.png').writeAsBytesSync(png);
  }
  final icon = File('assets/images/branding/covey_icon.png').readAsBytesSync();
  File('assets/images/app_icon.png').writeAsBytesSync(icon);
  File('android/app/src/main/res/drawable-nodpi/covey_launch_mark.png')
      .writeAsBytesSync(icon);
  for (final name in [
    'LaunchImage.png',
    'LaunchImage@2x.png',
    'LaunchImage@3x.png'
  ]) {
    File('ios/Runner/Assets.xcassets/LaunchImage.imageset/$name')
        .writeAsBytesSync(icon);
  }
}
