import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/services/realtime_sync_service.dart';
import 'package:study_birds/core/widgets/current_user_avatar.dart';
import 'package:study_birds/screens/home_journey/notifications_screen.dart';
import 'package:study_birds/screens/profile_account/delete_account_screen.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    AuthSession.instance.token = 'audit-regression';
    AuthSession.instance.currentUser = const AuthUser(id: 'audit-new-account',
      name: 'Audit', email: 'audit@example.test', role: UserRole.student,
      authProvider: 'apple', hasPassword: false);
  });
  tearDown(() {
    AuthSession.instance.currentUser = null;
    AuthSession.instance.token = null;
  });
  testWidgets('covered notifications page does not poll', (tester) async {
    final key = GlobalKey<NavigatorState>();
    var reads = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(navigatorKey: key, home: const NotificationsScreen()));
      await tester.pumpAndSettle();
      final initial = reads;
      key.currentState!.push(MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Covered'))));
      await tester.pumpAndSettle();
      RealtimeSyncService.instance.forceSync();
      await tester.pumpAndSettle();
      expect(reads, initial);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((_) async {
      reads++;
      return http.Response('[]', 200, headers: {'content-type': 'application/json'});
    }));
  });
  testWidgets('unowned legacy photo is discarded instead of assigned', (tester) async {
    SharedPreferences.setMockInitialValues({'profile_avatar_b64': 'unowned-photo'});
    await tester.pumpWidget(const MaterialApp(home: CurrentUserAvatar()));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('profile_avatar_b64_audit-new-account'), isNull);
    expect(prefs.getString('profile_avatar_b64'), isNull);
    expect(find.text('A'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Apple account deletion offers email code instead of password', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DeleteAccountScreen()));
    await tester.pumpAndSettle();
    expect(find.text('إرسال رمز التأكيد'), findsOneWidget);
    expect(find.text('رمز التأكيد'), findsOneWidget);
    expect(find.text('كلمة المرور'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
