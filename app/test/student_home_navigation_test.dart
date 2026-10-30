import 'package:study_birds/screens/home_journey/student_menu.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/app_shell.dart';
import 'package:study_birds/core/config/app_theme.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/home_journey/home_dashboard_screen.dart';
import 'package:study_birds/screens/home_journey/journey_tracker_screen.dart';
import 'package:study_birds/screens/stories/student_stories.dart';
import 'package:study_birds/screens/services_support/services_consultation_screens.dart';
import 'package:study_birds/screens/profile_account/profile_account_screens.dart';
import 'package:study_birds/screens/services_support/community_screen.dart';
import 'package:study_birds/screens/universities_programs_countries/explore_hub_screen.dart';
import 'community_test.dart' show publicPost;
import 'smart_home_test.dart' show overview;

http.Response response(Object value) => http.Response(jsonEncode(value), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});
void main() {
  final previewKey = GlobalKey();
  const preview = bool.fromEnvironment('STUDENT_HOME_PREVIEW');
  const menuPreview = bool.fromEnvironment('STUDENT_MENU_PREVIEW');
  setUpAll(() async {
    if (preview) {
      await (FontLoader('Tajawal')
            ..addFont(rootBundle.load('assets/fonts/Tajawal-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf')))
          .load();
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    }
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthSession.instance.token = 'student-home-test';
    AuthSession.instance.currentUser = const AuthUser(
        id: 'me',
        name: 'Student',
        email: 'student@example.test',
        role: UserRole.student);
  });
  tearDown(() {
    AuthSession.instance.token = null;
    AuthSession.instance.currentUser = null;
    ApiClient.instance.clearCache();
  });
  MockClient client(List<String> calls) => MockClient((r) async {
        calls.add(r.url.path);
        if (r.url.path.endsWith('/community/posts')) {
          return response([publicPost]);
        }
        if (r.url.path.endsWith('/overview')) return response(overview());
        if (r.url.path.endsWith('/community/status')) {
          return response({'suspended': false});
        }
        if (r.url.path.contains('/stories') ||
            r.url.path.contains('story-progress')) {
          return response({'stories': [], 'items': [], 'progress': {}});
        }
        if (r.url.path.endsWith('/conversations')) {
          return response({'conversations': []});
        }
        if (r.url.path.endsWith('/games/wink/current')) {
          return response({'code': null});
        }
        if (r.url.path.endsWith('/profile')) return response({});
        return response([]);
      });
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(RepaintBoundary(
        key: previewKey,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const StudentAppShell())));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
      'dashboard opens first with stories, account and left header controls',
      (tester) async {
    final calls = <String>[];
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await http.runWithClient(() async {
      await mount(tester);
      expect(find.byType(HomeDashboardScreen), findsOneWidget);
      expect(find.byType(StudentCommunityScreen), findsNothing);
      expect(find.byType(StudentStories), findsOneWidget);
      expect(
          find.byKey(const ValueKey('student-home-account')), findsOneWidget);
      expect(find.byKey(const ValueKey('main-account-avatar')), findsNothing);
      expect(find.byKey(const ValueKey('student-home-game')), findsNothing);
      for (final id in [kTabJourney, kTabExplore, kTabServices, kTabAccount]) {
        expect(find.byKey(ValueKey('main-tab-$id')), findsNothing);
      }
      expect(calls.where((path) => path.endsWith('/overview')), isNotEmpty);
      expect(find.textContaining('مرحب'), findsNothing);
      final account =
          tester.getCenter(find.byKey(const ValueKey('student-home-account')));
      final menu =
          tester.getCenter(find.byKey(const ValueKey('student-home-menu')));
      final notifications = tester.getCenter(find.byTooltip('الإشعارات'));
      expect(notifications.dx, lessThan(menu.dx));
      expect(menu.dx, lessThan(account.dx));
      final nav = [kTabHome, kTabCommunity, kTabGame]
          .map((id) => tester.getRect(find.byKey(ValueKey('main-tab-$id'))))
          .toList();
      expect(nav[0].width, closeTo(nav[1].width, 0.1));
      expect(nav[1].width, closeTo(nav[2].width, 0.1));
      expect(nav[0].center.dy, nav[2].center.dy);
      expect(
          tester.getTopLeft(find.byKey(const ValueKey('dashboard-stories'))).dy,
          greaterThan(account.dy));
      if (preview) {
        if (menuPreview) {
          await tester.tap(find.byKey(const ValueKey('student-home-menu')));
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.byKey(const ValueKey('menu-section-discover')));
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 300));
          expect(
              find.byKey(const ValueKey('menu-item-explore')), findsOneWidget);
        }
        await tester.runAsync(() async {
          final boundary = previewKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(menuPreview
                  ? 'integration/previews/student-grouped-menu.png'
                  : 'integration/previews/student-dashboard-home.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        if (menuPreview) {
          await tester.tap(find.byTooltip('إغلاق القائمة'));
          await tester.pump(const Duration(milliseconds: 500));
        }
      }
      await tester.tap(find.byKey(const ValueKey('main-tab-$kTabCommunity')));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(StudentCommunityScreen), findsOneWidget);
      final ai = find.byKey(const ValueKey('main-tabs-ai-button'));
      expect(ai, findsOneWidget);
      final create = find.byKey(const ValueKey('home-community-new-post'));
      expect(create, findsOneWidget);
      expect(tester.widget(create), isA<FloatingActionButton>());
      expect(tester.getRect(create).overlaps(tester.getRect(ai)), isFalse);
      expect(tester.getCenter(create).dy,
          greaterThan(tester.view.physicalSize.height / 2));
      await tester.tap(find.byKey(const ValueKey('main-tab-$kTabHome')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('student-home-account')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, () => client(calls));
  });
  testWidgets(
      'student menu opens journey, exploration and services from the dashboard',
      (tester) async {
    await http.runWithClient(() async {
      await mount(tester);
      await tester.tap(find.byKey(const ValueKey('student-home-menu')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('menu-section-journey')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester
          .ensureVisible(find.byKey(const ValueKey('menu-item-journey')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.descendant(
          of: find.byType(StudentMenuPanel), matching: find.text('الرحلة')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(JourneyTrackerScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(JourneyTrackerScreen))).pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('student-home-menu')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('menu-section-discover')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester
          .ensureVisible(find.byKey(const ValueKey('menu-item-explore')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.descendant(
          of: find.byType(StudentMenuPanel), matching: find.text('الاستكشاف')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ExploreHubScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(ExploreHubScreen))).pop();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('student-home-menu')));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('menu-section-services')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester
          .ensureVisible(find.byKey(const ValueKey('menu-item-services')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.descendant(
          of: find.byType(StudentMenuPanel), matching: find.text('الخدمات')));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ServicesCenterScreen), findsOneWidget);

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, () => client([]));
  });
}
