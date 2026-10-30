import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:study_birds/screens/ai/assistant_answer.dart';
import 'package:study_birds/screens/ai/assistant_navigation.dart';

void main() {
  test('old Markdown cannot expose raw markers or turn links into actions', () {
    expect(
        assistantPlainText(
            '**Important**\n- [Open app](https://example.test)\n`code`'),
        'Important\n• Open app\ncode');
  });
  testWidgets('empty, duplicate and stale details never offer expansion',
      (tester) async {
    for (final details in ['', 'Short', 'Other']) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: AssistantAnswer(
                  content: 'Short',
                  details: details,
                  knowledgeVersion: details == 'Other'
                      ? 'old'
                      : AssistantNavigation.knowledgeVersion))));
      expect(find.text('Explain More'), findsNothing);
    }
  });
  testWidgets(
      'Arabic disclosure fits phone, stays in same answer and collapses',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData.dark(),
        home: const Scaffold(
            body: AssistantAnswer(
                content: 'افتح مستنداتي.',
                details: 'افتح مستنداتي ثم اضغط رفع مستند واختر نوع الملف.',
                knowledgeVersion: AssistantNavigation.knowledgeVersion))));
    expect(find.text('اشرح أكثر'), findsOneWidget);
    await tester.tap(find.text('اشرح أكثر'));
    await tester.pump();
    expect(find.text('افتح مستنداتي.'), findsNothing);
    expect(find.byType(AssistantAnswer), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('عرض أقل'))),
        TextDirection.rtl);
    await tester.tap(find.text('عرض أقل'));
    await tester.pump();
    expect(find.text('افتح مستنداتي.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
