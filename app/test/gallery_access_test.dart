import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/widgets/gallery_access.dart';

void main() {
  for (final allow in [false, true]) {
    testWidgets('gallery only proceeds after approval: $allow', (tester) async {
      SharedPreferences.setMockInitialValues({});
      var opened = 0;
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () async {
                          if (await confirmGalleryAccess(context)) opened++;
                        },
                        child: const Text('Gallery')),
                  ))));
      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();
      expect(opened, 0);
      await tester.tap(find.text(allow ? 'السماح وفتح المعرض' : 'إلغاء'));
      await tester.pumpAndSettle();
      expect(opened, allow ? 1 : 0);
      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), allow ? findsNothing : findsOneWidget);
      expect(opened, allow ? 2 : 0);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
