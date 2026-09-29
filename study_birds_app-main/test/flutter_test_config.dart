import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
 TestWidgetsFlutterBinding.ensureInitialized();
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
