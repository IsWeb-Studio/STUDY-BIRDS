import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/services/push_notification_service.dart';
import 'package:study_birds/screens/profile_account/login_notification_gate.dart';
import 'package:study_birds/screens/profile_account/notification_permission_sheet.dart';

class Access implements NotificationAccess {
  @override
  bool supported = true;
  @override
  bool permissionGranted = false;
  bool grantOnRequest = true;
  bool failInit = false;
  int requests = 0, enabled = 0, disabled = 0;
  Completer<void>? initializing;
  @override
  Future<void> init() async {
    if (failInit) throw StateError('Notification SDK unavailable');
    await initializing?.future;
  }

  @override
  Future<void> requestPermission() async {
    requests++;
    permissionGranted = grantOnRequest;
  }

  @override
  Future<void> enableForCurrentUser() async {
    enabled++;
  }

  @override
  Future<void> disableDelivery() async {
    disabled++;
  }
}

Future<void> open(WidgetTester tester, Access access) async {
  await tester.pumpWidget(MaterialApp(
      home: LoginNotificationGate(
          access: access, homeBuilder: (_) => const Text('Dashboard'))));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('notification SDK errors do not block account access',
      (tester) async {
    final access = Access()..failInit = true;
    await open(tester, access);
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    expect(access.enabled, 0);
    expect(access.disabled, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('dashboard waits for rationale and native permission approval',
      (tester) async {
    final access = Access();
    await open(tester, access);
    expect(find.text('Dashboard'), findsNothing);
    expect(find.byType(NotificationPermissionSheet), findsOneWidget);
    await tester.ensureVisible(find.text('تفعيل الإشعارات'));
    await tester.tap(find.text('تفعيل الإشعارات'));
    await tester.pumpAndSettle();
    expect(access.requests, 1);
    expect(access.enabled, 1);
    expect(find.text('Dashboard'), findsOneWidget);
  });
  testWidgets(
      'declining opens dashboard and delivery disabled without repeating sheet',
      (tester) async {
    final access = Access();
    await open(tester, access);
    await tester.ensureVisible(find.text('ليس الآن'));
    await tester.tap(find.text('ليس الآن'));
    await tester.pumpAndSettle();
    expect(access.requests, 0);
    expect(access.enabled, 0);
    expect(access.disabled, 1);
    expect(find.text('Dashboard'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await open(tester, access);
    expect(find.byType(NotificationPermissionSheet), findsNothing);
    expect(find.text('Dashboard'), findsOneWidget);
  });
  testWidgets('native refusal still opens dashboard', (tester) async {
    final access = Access()..grantOnRequest = false;
    await open(tester, access);
    await tester.ensureVisible(find.text('تفعيل الإشعارات'));
    await tester.tap(find.text('تفعيل الإشعارات'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    expect(access.enabled, 0);
    expect(access.disabled, 1);
  });
  testWidgets(
      'already granted permission skips rationale after SDK finishes loading',
      (tester) async {
    final access = Access()..initializing = Completer<void>();
    await tester.pumpWidget(MaterialApp(
        home: LoginNotificationGate(
            access: access, homeBuilder: (_) => const Text('Dashboard'))));
    await tester.pump();
    expect(find.byType(NotificationPermissionSheet), findsNothing);
    expect(find.text('Dashboard'), findsNothing);
    access.permissionGranted = true;
    access.initializing!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(NotificationPermissionSheet), findsNothing);
    expect(access.requests, 0);
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
