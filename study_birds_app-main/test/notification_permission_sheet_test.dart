import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/screens/profile_account/notification_permission_sheet.dart';

void main() {
  for (final accept in [true, false]) {
    testWidgets('notification rationale returns $accept on a small screen',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      bool? result;
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () async {
                          result = await showModalBottomSheet<bool>(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => const Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: NotificationPermissionSheet()));
                        },
                        child: const Text('open')),
                  ))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final button = find.text(accept ? 'تفعيل الإشعارات' : 'ليس الآن');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(result, accept);
      expect(tester.takeException(), isNull);
    });
  }
}
