# Flutter Play Store split/deferred components (not used but referenced by Flutter engine)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# OneSignal
-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**

# Sentry
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**
-keep class io.sentry.android.** { *; }

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# flutter_local_notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Google Sign-In
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.api.** { *; }

# local_auth (biometric)
-keep class androidx.biometric.** { *; }

# Connectivity Plus
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# app_links / deep links
-keep class com.llfbandit.app_links.** { *; }

# Prevent stripping of data classes used via reflection (JSON)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
