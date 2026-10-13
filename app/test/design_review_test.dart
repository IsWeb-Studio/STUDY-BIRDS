import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/home_journey/calendar_screen.dart';
import 'package:study_birds/screens/profile_account/edit_profile_screen.dart';
import 'package:study_birds/screens/profile_account/security_settings_screen.dart';
import 'package:study_birds/screens/auth/account_recovery_screen.dart';
import 'package:study_birds/screens/universities_programs_countries/compare_list_screen.dart';

void main() {
  for (final width in [360.0, 430.0]) {
    testWidgets('review screens at $width pixels', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AuthSession.instance.token = 'preview';
      addTearDown(() => AuthSession.instance.token = null);
      SharedPreferences.setMockInitialValues({});
      if (const bool.fromEnvironment('WRITE_UI_PREVIEWS')) {
        await (FontLoader('MaterialIcons')
              ..addFont(Future.value(ByteData.sublistView(File(
                      'D:/fluter/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
                  .readAsBytesSync()))))
            .load();
        await (FontLoader('Tajawal')
              ..addFont(rootBundle.load('assets/fonts/Tajawal-Regular.ttf')))
            .load();
      }
      for (final entry in <String, Widget>{
        'calendar': const CalendarScreen(),
        'profile': const EditProfileScreen(),
        'password': const ChangePasswordScreen(),
        'security': const SecuritySettingsScreen(),
        'recovery': const AccountRecoveryScreen(),
        'compare': const CompareListScreen()
      }.entries) {
        final key = GlobalKey();
        await http.runWithClient(() async {
          await tester.pumpWidget(MaterialApp(
              theme: ThemeData(
                  fontFamily: 'Tajawal',
                  colorScheme:
                      ColorScheme.fromSeed(seedColor: const Color(0xFF011E46))),
              home: RepaintBoundary(key: key, child: entry.value)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: entry.key);
          if (const bool.fromEnvironment('WRITE_UI_PREVIEWS')) {
            await tester.runAsync(() async {
              final boundary = key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
              final image = await boundary.toImage();
              final bytes =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              await Directory('integration/previews/redesign')
                  .create(recursive: true);
              await File(
                      'integration/previews/redesign/${entry.key}-${width.toInt()}.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
            () => MockClient((request) async {
                  Object? data = {};
                  if (request.url.path.endsWith('financials'))
                    data = {
                      'invoices': [
                        {
                          'dueDate': DateTime.now().toIso8601String(),
                          'description': 'الرسوم الدراسية',
                          'status': 'unpaid'
                        }
                      ]
                    };
                  if (request.url.path.endsWith('arrival-services'))
                    data = null;
                  if (request.url.path.endsWith('profile'))
                    data = {
                      'englishFullName': 'Tarek Ahmed',
                      'nationality': 'مصر',
                      'currentResidenceCountry': 'تركيا'
                    };
                  if (request.url.path.endsWith('universities'))
                    data = [
                      {
                        '_id': 'a',
                        'name': 'جامعة إسطنبول',
                        'country': {'name': 'تركيا'},
                        'city': 'إسطنبول'
                      },
                      {
                        '_id': 'b',
                        'name': 'جامعة أنقرة',
                        'country': {'name': 'تركيا'},
                        'city': 'أنقرة'
                      }
                    ];
                  if (request.url.path.endsWith('site-settings'))
                    data = {'contactEmail': 'support@example.test'};
                  return http.Response(jsonEncode(data), 200, headers: {
                    'content-type': 'application/json; charset=utf-8'
                  });
                }));
      }
    });
  }
}
