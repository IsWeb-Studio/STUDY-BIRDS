import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/screens/roles/agent_program_pricing_screen.dart';

void main() {
  testWidgets('agent prices have the requested label without strikethrough at phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: AgentProgramPricingScreen()));
      await tester.pumpAndSettle();
      expect(find.text('السعر: \$700'), findsOneWidget);
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.style?.decoration, isNot(TextDecoration.lineThrough));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((_) async => http.Response('[{"title":"Program","tuition":1100,"partnerTuition":700}]', 200)));
  });
}
