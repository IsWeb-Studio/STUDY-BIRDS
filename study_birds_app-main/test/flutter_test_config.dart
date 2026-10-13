import 'package:study_birds/screens/universities_programs_countries/catalog_language.dart';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
 TestWidgetsFlutterBinding.ensureInitialized();
 // The catalog pages default to English in the product; the existing widget
 // tests were written against the Arabic view, so start each test file there.
 // (Tests of the default and of the toggle set the value explicitly.)
 CatalogLanguage.instance.english = false;
 // No background translation timers in widget tests unless a test opts in.
 CatalogLanguage.translationEnabled = false;
 FlutterSecureStorage.setMockInitialValues({});
 AndroidFlutterLocalNotificationsPlugin.registerWith();
 TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
   const MethodChannel('dexterous.com/flutter/local_notifications'), (call) async {
     if (call.method == 'initialize') return true;
     if (call.method == 'getNotificationAppLaunchDetails') return {'notificationLaunchedApp': false};
     return null;
   });
 await testMain();
}
