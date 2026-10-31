import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WinkHaptics {
  static const channel = MethodChannel('com.studybirds.app/wink_haptics');
  static Future<void> lightImpact() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        if (await channel.invokeMethod<bool>('lightImpact') == true) return;
      } on PlatformException catch (_) {
        // Fall back to Flutter's native feedback if the device driver fails.
      } on MissingPluginException catch (_) {}
    }
    try {
      await HapticFeedback.lightImpact();
    } on PlatformException catch (_) {
    } on MissingPluginException catch (_) {}
  }
}
