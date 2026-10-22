import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/games/wink_controller.dart';
import 'wink_game_test.dart' show mount, fixture;

void main() {
  for (final exists in [false, true]) {
    testWidgets('recover room provides a real result (exists=$exists)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      AuthSession.instance.token = 'synthetic-recovery';
      addTearDown(() => AuthSession.instance.token = null);
      int reads = 0;
      final game =
          WinkController(api: ApiClient.forTesting(MockClient((r) async {
        if (r.url.path.endsWith('/current')) {
          reads++;
          return http.Response(
              jsonEncode({'code': exists && reads > 1 ? 'ABCD1234' : null}),
              200);
        }
        return http.Response(jsonEncode(fixture(phase: 'lobby')), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      })));
      await mount(tester, game);
      expect(find.text('قواعد اللعبة'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('استعادة غرفتي'), 250,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('استعادة غرفتي'));
      await tester.pumpAndSettle();
      expect(reads, 2);
      if (exists) {
        expect(find.text('ABCD1234'), findsOneWidget);
      } else {
        await tester.scrollUntilVisible(
            find.textContaining('لا توجد غرفة سابقة'), 150,
            scrollable: find.byType(Scrollable).first);
        expect(find.textContaining('لا توجد غرفة سابقة'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
