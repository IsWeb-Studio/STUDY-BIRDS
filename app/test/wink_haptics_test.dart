import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/screens/games/wink_haptics.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Android uses a short native vibration with a safe Flutter fallback', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var native = 0, fallback = 0;
    var supported = true;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(WinkHaptics.channel, (call) async { expect(call.method, 'lightImpact'); native++; return supported; });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async { if (call.method == 'HapticFeedback.vibrate') fallback++; return null; });
    try {
      await WinkHaptics.lightImpact(); expect(native, 1); expect(fallback, 0);
      supported = false; await WinkHaptics.lightImpact(); expect(native, 2); expect(fallback, 1);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await WinkHaptics.lightImpact(); expect(native, 2); expect(fallback, 2);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(WinkHaptics.channel, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    }
  });
}
