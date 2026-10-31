package com.studybirds.app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.os.Build
import android.os.Vibrator
import android.os.VibratorManager
import android.os.VibrationEffect

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PassportScanner.register(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.studybirds.app/wink_haptics")
            .setMethodCallHandler { call, result ->
                if (call.method != "lightImpact") { result.notImplemented(); return@setMethodCallHandler }
                try {
                    val vibrator = if (Build.VERSION.SDK_INT >= 31) {
                        getSystemService(VibratorManager::class.java)?.defaultVibrator
                    } else {
                        @Suppress("DEPRECATION")
                        getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                    }
                    if (vibrator == null || !vibrator.hasVibrator()) { result.success(false); return@setMethodCallHandler }
                    if (Build.VERSION.SDK_INT >= 26) {
                        val amplitude = if (vibrator.hasAmplitudeControl()) 70 else VibrationEffect.DEFAULT_AMPLITUDE
                        vibrator.vibrate(VibrationEffect.createOneShot(35, amplitude))
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(35)
                    }
                    result.success(true)
                } catch (error: Exception) { result.error("VIBRATION_UNAVAILABLE", "Vibration unavailable", null) }
            }
    }
}
