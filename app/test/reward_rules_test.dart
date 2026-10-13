import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/screens/roles/admin_reward_rules_screen.dart';

void main() {
  testWidgets('staff can create an explicitly configured reward rule', (tester) async {
    Map? saved;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: AdminRewardRulesScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة قاعدة'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'مكافأة تقديم الطلب');
      await tester.enterText(find.byType(TextField).at(1), '25');
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(saved?['points'], 25);
      expect(saved?['enabled'], false);
      expect(saved?['event'], 'application-submitted');
      expect(find.text('مكافأة تقديم الطلب'), findsOneWidget);
    }, () => MockClient((request) async {
      if (request.method == 'POST') saved = jsonDecode(request.body) as Map;
      return http.Response(jsonEncode(request.method == 'POST'
          ? {'_id': 'rule', ...saved!}
          : saved == null ? [] : [{'_id': 'rule', ...saved!}]), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
  });
}
