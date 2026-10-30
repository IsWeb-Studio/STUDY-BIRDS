import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/widgets/community_reactions.dart';
import 'package:study_birds/screens/services_support/community_screen.dart';

http.Response reply(Object data) => http.Response(jsonEncode(data), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

class _Picker extends ImagePickerPlatform {
  @override
  Future<XFile?> getImageFromSource(
          {required ImageSource source,
          ImagePickerOptions options = const ImagePickerOptions()}) async =>
      XFile.fromData(File('assets/images/logo_mark.png').readAsBytesSync(),
          path: 'photo.png');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(
        {'gallery_picker_confirmed': true, 'community_terms_v1:me': true});
    AuthSession.instance.token = 'community-post-test';
    AuthSession.instance.currentUser = const AuthUser(
        id: 'me', name: 'Me', email: 'me@example.test', role: UserRole.student);
    ApiClient.instance.clearCache();
  });
  tearDown(() {
    AuthSession.instance.token = null;
    AuthSession.instance.currentUser = null;
    ApiClient.instance.clearCache();
  });
  testWidgets('administration tab requests authoritative admin posts',
      (tester) async {
    String? filter;
    await http.runWithClient(() async {
      await tester.pumpWidget(
          const MaterialApp(home: StudentCommunityScreen(embedded: true)));
      await tester.pumpAndSettle();
      expect(find.text('New post'), findsOneWidget);
      expect(find.text('All posts'), findsOneWidget);
      expect(find.text('My posts'), findsOneWidget);
      await tester.tap(find.text('Administration posts'));
      await tester.pumpAndSettle();
      expect(filter, '1');
      expect(find.text('Official update'), findsOneWidget);
      expect(find.text('Administration post'), findsOneWidget);
      expect(find.text('Student post'), findsNothing);
      expect(find.text('Ordinary user post'), findsNothing);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((r) async {
              if (r.url.path.endsWith('/community/status')) {
                return reply({'suspended': false});
              }
              if (r.url.path.endsWith('/community/posts')) {
                filter = r.url.queryParameters['admin'];
                return reply([
                  if (filter == '1')
                    {
                      '_id': 'ordinary',
                      'body': 'Ordinary user post',
                      'author': {
                        '_id': 's1',
                        'name': 'Student',
                        'role': 'student'
                      },
                      'isAdminPost': true,
                    },
                  {
                    '_id': 'p1',
                    'body': filter == '1' ? 'Official update' : 'Student post',
                    'author': {
                      '_id': 'a1',
                      'name': 'Publisher',
                      'role': filter == '1' ? 'admin' : 'student'
                    },
                    'isAdminPost': filter == '1',
                    'reactionTotal': 0
                  }
                ]);
              }
              return reply([]);
            }));
  });
  testWidgets('emoji reactions can be selected, replaced and removed',
      (tester) async {
    var post = <String, dynamic>{'_id': 'p1', 'reactionTotal': 0};
    final sent = <String?>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: StatefulBuilder(
                  builder: (context, update) => CommunityReactions(
                      post: post,
                      buttonKey: const ValueKey('react'),
                      onChanged: (result) =>
                          update(() => post = {...post, ...result}))))));
      Future<void> choose(String id) async {
        await tester.tap(find.byKey(const ValueKey('react')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('reaction-choice-$id')));
        await tester.pumpAndSettle();
      }

      await choose('love');
      expect(post['myReaction'], 'love');
      expect(post['reactionTotal'], 1);
      await choose('laugh');
      expect(post['myReaction'], 'laugh');
      expect(post['reactionTotal'], 1);
      await tester.tap(find.byKey(const ValueKey('react')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove my reaction'));
      await tester.pumpAndSettle();
      expect(post['myReaction'], isNull);
      expect(post['reactionTotal'], 0);
      expect(sent, ['love', 'laugh', null]);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((r) async {
              final value = r.method == 'DELETE'
                  ? null
                  : (jsonDecode(r.body) as Map)['reaction'] as String;
              sent.add(value);
              return reply({
                'myReaction': value,
                'reactionTotal': value == null ? 0 : 1,
                'reactionCounts': {if (value != null) value: 1}
              });
            }));
  });
  for (final photo in [false, true]) {
    testWidgets('publishes a body without a title (photo=$photo)',
        (tester) async {
      final old = ImagePickerPlatform.instance;
      ImagePickerPlatform.instance = _Picker();
      addTearDown(() => ImagePickerPlatform.instance = old);
      String? path;
      Map? payload;
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    const CommunityComposeScreen())),
                        child: const Text('Compose'))))));
        await tester.tap(find.text('Compose'));
        await tester.pumpAndSettle();
        await tester.enterText(find.widgetWithText(TextField, 'Text'),
            'My text-only or photo post');
        if (photo) {
          await tester.tap(find.text('Add photo (optional)'));
          await tester.pumpAndSettle();
          expect(find.text('Remove photo'), findsOneWidget);
        }
        final button = find.widgetWithText(FilledButton, 'Publish');
        await tester.scrollUntilVisible(button, 150,
            scrollable: find.byType(Scrollable).first);
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(path,
            photo ? '/api/community/posts/image' : '/api/community/posts');
        if (!photo) {
          expect(payload!['title'], '');
          expect(payload!['body'], 'My text-only or photo post');
        }
        expect(find.text('Compose'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
          () => MockClient((r) async {
                path = r.url.path;
                if (!photo) {
                  payload = jsonDecode(r.body) as Map;
                } else {
                  expect(r.headers['content-type'],
                      contains('multipart/form-data'));
                  final text = latin1.decode(r.bodyBytes);
                  expect(text, contains('photo.png'));
                  expect(text, contains('operationId'));
                }
                return reply({});
              }));
    });
  }
}
