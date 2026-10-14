import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/app_shell.dart';
import 'package:study_birds/core/config/app_theme.dart';
import 'package:study_birds/core/utils/responsive.dart';

void setSize(WidgetTester tester, double w, double h) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  test('size classes follow window width, not device type', () {
    expect(Responsive.ofWidth(320), ScreenSize.compact);
    expect(Responsive.ofWidth(599), ScreenSize.compact);
    expect(Responsive.ofWidth(600), ScreenSize.medium);
    expect(Responsive.ofWidth(839), ScreenSize.medium);
    expect(Responsive.ofWidth(840), ScreenSize.expanded);
    expect(Responsive.ofWidth(1366), ScreenSize.expanded);
  });

  testWidgets('MaxWidthBody leaves phones untouched and caps tablets',
      (tester) async {
    final key = GlobalKey();
    Future<double> widthAt(double w) async {
      setSize(tester, w, 800);
      await tester.pumpWidget(MaterialApp(
          home: MaxWidthBody(child: Container(key: key, color: Colors.red))));
      return tester.getSize(find.byKey(key)).width;
    }

    expect(await widthAt(390), 390, reason: 'phone: exactly as before');
    expect(await widthAt(720), 720);
    expect(await widthAt(1024), 720, reason: 'tablet: centered, capped');
    final left = tester.getTopLeft(find.byKey(key)).dx;
    expect(left, (1024 - 720) / 2);
  });

  testWidgets('AppScaffold content is capped on iPad but full-width on phones',
      (tester) async {
    final key = GlobalKey();
    Future<double> bodyWidth(double w) async {
      setSize(tester, w, 900);
      await tester.pumpWidget(MaterialApp(
          home: AppScaffold(
              title: 't',
              hideAiButton: true,
              body: SizedBox.expand(key: key))));
      await tester.pump();
      return tester.getSize(find.byKey(key)).width;
    }

    expect(await bodyWidth(375), 375);
    expect(await bodyWidth(1024), lessThanOrEqualTo(720));
  });

  testWidgets('MasterDetail shows one pane on phones and two on wide windows',
      (tester) async {
    Widget app() => const MaterialApp(
        home: Scaffold(
            body: MasterDetail(
                master: Text('LIST'),
                detail: Text('DETAIL'),
                placeholder: Text('PICK'))));
    setSize(tester, 390, 800);
    await tester.pumpWidget(app());
    expect(find.text('LIST'), findsOneWidget);
    expect(find.text('DETAIL'), findsNothing);

    setSize(tester, 1024, 768);
    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.text('LIST'), findsOneWidget);
    expect(find.text('DETAIL'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: MasterDetail(
                master: Text('LIST'),
                detail: null,
                placeholder: Text('PICK')))));
    expect(find.text('PICK'), findsOneWidget);
  });

  testWidgets('student shell: bottom bar on phones and tablets',
      (tester) async {
    setSize(tester, 390, 844);
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const StudentAppShell()));
    await tester.pump();
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('الرحلة'), findsWidgets);

    setSize(tester, 1024, 768);
    await tester.pump();
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(AdaptiveBottomBar), findsOneWidget);
    await tester.tap(find.text('حسابي').last);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
