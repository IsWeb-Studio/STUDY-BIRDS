import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/core/config/app_theme.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/services/connectivity_service.dart';
import 'package:study_birds/core/utils/app_error.dart';
import 'package:study_birds/screens/auth/login_register_screens.dart';

void main() {
  late StreamController<List<ConnectivityResult>> radio;
  late List<ConnectivityResult> interfaces;
  late bool backendUp;
  late ConnectivityService service;
  late ConnectivityService original;

  setUp(() {
    original = ConnectivityService.instance;
    radio = StreamController<List<ConnectivityResult>>.broadcast();
    interfaces = [ConnectivityResult.wifi];
    backendUp = true;
    service = ConnectivityService(
      changes: () => radio.stream,
      check: () async => interfaces,
      probe: () async => backendUp,
      offlineDebounce: const Duration(milliseconds: 50),
      confirmDelay: const Duration(milliseconds: 10),
      minRecoveryDelay: const Duration(seconds: 1),
    );
    ConnectivityService.instance = service;
  });

  tearDown(() async {
    service.dispose();
    await radio.close();
    ConnectivityService.instance = original;
  });

  Future<void> goOffline(WidgetTester tester) async {
    interfaces = [ConnectivityResult.none];
    radio.add(interfaces);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('one banner appears offline, content/state is preserved, and a '
      'brief "back online" replaces it without dialogs or snackbars',
      (tester) async {
    final controller = TextEditingController(text: 'half-typed message');
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        home: OfflineBannerWrapper(
            child: Scaffold(body: TextField(controller: controller)))));
    await service.start();
    await tester.pump();
    expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);

    await goOffline(tester);
    expect(find.text('لا يوجد اتصال بالإنترنت — تُعرض آخر بيانات محفوظة'),
        findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    // Typed input survives the outage (no rebuild-from-scratch of the screen).
    expect(controller.text, 'half-typed message');
    expect(find.text('half-typed message'), findsOneWidget);

    interfaces = [ConnectivityResult.mobile];
    radio.add(interfaces);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('عاد الاتصال بالإنترنت'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
    expect(controller.text, 'half-typed message');

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('عاد الاتصال بالإنترنت'), findsNothing);
  });

  testWidgets('Wi-Fi without real internet shows the "service unreachable" '
      'banner, not the airplane-mode one', (tester) async {
    backendUp = false;
    await tester.pumpWidget(const MaterialApp(
        home: OfflineBannerWrapper(child: Scaffold(body: Text('screen')))));
    await service.start();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('تعذّر الوصول إلى الخدمة'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
    expect(find.text('screen'), findsOneWidget);
    // Unmount: listeners/timers must be released without errors.
    await tester.pumpWidget(const SizedBox());
    service.stop(); // cancels the recovery timer
    expect(tester.takeException(), isNull);
  });

  testWidgets('ErrorState retries itself exactly once when the connection '
      'returns (no loops, no duplicate loads)', (tester) async {
    var loads = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ErrorState(
                message: AppError.connection, onRetry: () => loads++))));
    await service.start();
    backendUp = false;
    await goOffline(tester);
    interfaces = [ConnectivityResult.wifi];
    backendUp = true;
    radio.add(interfaces);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300));
    expect(loads, 1);
    // A second outage/recovery must not fire another automatic retry.
    await goOffline(tester);
    interfaces = [ConnectivityResult.wifi];
    radio.add(interfaces);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300));
    expect(loads, 1);
  });

  testWidgets('login while offline says so, keeps the typed input and '
      'unlocks the button (never "wrong password")', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: LoginScreen(onLoginAttempt: (email, password) async {
          AuthSession.instance
              .reportAuthFailure(const ApiException(0, AppError.connection));
          return false;
        })));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'sara@example.com');
    await tester.enterText(find.byType(TextField).last, 'Birds@Sky2');
    await tester.ensureVisible(find.text('تسجيل الدخول'));
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();
    expect(find.text(AppError.connection), findsOneWidget);
    expect(find.text('البريد الإلكتروني أو كلمة المرور غير صحيحة'),
        findsNothing);
    expect(find.text('sara@example.com'), findsOneWidget);
    expect(find.text('جاري الدخول...'), findsNothing,
        reason: 'loading indicator terminated');
  });

  testWidgets('login with wrong credentials still says wrong credentials',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: LoginScreen(onLoginAttempt: (email, password) async {
          AuthSession.instance.reportAuthFailure(
              const ApiException(401, 'Invalid credentials'));
          return false;
        })));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'sara@example.com');
    await tester.enterText(find.byType(TextField).last, 'Birds@Sky2');
    await tester.ensureVisible(find.text('تسجيل الدخول'));
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();
    expect(find.text('البريد الإلكتروني أو كلمة المرور غير صحيحة'),
        findsOneWidget);
  });

  testWidgets('double-tapping login submits once while the request is pending',
      (tester) async {
    var attempts = 0;
    final gate = Completer<bool>();
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: LoginScreen(onLoginAttempt: (email, password) {
          attempts++;
          return gate.future;
        })));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'sara@example.com');
    await tester.enterText(find.byType(TextField).last, 'Birds@Sky2');
    await tester.ensureVisible(find.text('تسجيل الدخول'));
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pump();
    await tester.tap(find.text('جاري الدخول...'), warnIfMissed: false);
    await tester.pump();
    expect(attempts, 1);
    gate.complete(true);
    await tester.pumpAndSettle();
  });
}
