import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/widgets/community_post_image.dart';

const path = '/community/posts/aaaaaaaaaaaaaaaaaaaaaaaa/image';
const user = AuthUser(
    id: 'image-owner',
    name: 'Owner',
    email: 'owner@test.local',
    role: UserRole.student);
Widget imageView() => const MaterialApp(
        home: Scaffold(
            body: Column(children: [
      SizedBox(width: 200, child: CommunityPostImage(path: path)),
      SizedBox(
          width: 80, child: CommunityPostImage(path: path, thumbnail: true)),
    ])));

void main() {
  final png = img.encodePng(img.Image(width: 32, height: 32));
  setUp(() {
    ApiClient.instance.clearCache();
    AuthSession.instance.currentUser = user;
    AuthSession.instance.token = 'image-session';
  });
  tearDown(() {
    AuthSession.instance.token = null;
    AuthSession.instance.currentUser = null;
    ApiClient.instance.clearCache();
  });
  testWidgets(
      'oldest image is evicted after twelve entries rather than retaining the whole feed',
      (tester) async {
    final calls = <String, int>{};
    String location(int n) =>
        '/community/posts/${n.toRadixString(16).padLeft(24, '0')}/image';
    Widget view(int n) => MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 200, child: CommunityPostImage(path: location(n)))));
    await http.runWithClient(() async {
      for (var n = 1; n <= 13; n++) {
        await tester.pumpWidget(view(n));
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(view(13));
      await tester.pumpAndSettle();
      expect(calls['/api${location(13)}'], 1);
      await tester.pumpWidget(view(1));
      await tester.pumpAndSettle();
      expect(calls['/api${location(1)}'], 2);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              calls.update(request.url.path, (value) => value + 1,
                  ifAbsent: () => 1);
              return http.Response.bytes(png, 200);
            }));
  });
  testWidgets(
      'same image shares a request and survives lazy disposal without a spinner or download',
      (tester) async {
    var downloads = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(imageView());
      await tester.pumpAndSettle();
      expect(downloads, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pumpWidget(imageView());
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle();
      expect(downloads, 1);
      unawaited(
          AuthSession.instance.logout(revoke: false).catchError((Object _) {}));
      await tester.idle();
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((_) async {
              downloads++;
              return http.Response.bytes(png, 200,
                  headers: {'content-type': 'image/png'});
            }));
  });
  testWidgets(
      'switching accounts removes old pixels and late private responses cannot fill new account cache',
      (tester) async {
    final old = Completer<http.Response>();
    var downloads = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(imageView());
      await tester.pump();
      expect(downloads, 1);
      AuthSession.instance.currentUser = const AuthUser(
          id: 'other-owner',
          name: 'Other',
          email: 'other@test.local',
          role: UserRole.student);
      AuthSession.instance.token = 'other-session';
      await tester.pumpAndSettle();
      old.complete(http.Response.bytes(png, 200));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('Retry image'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
        () => MockClient((_) async {
              downloads++;
              return downloads == 1
                  ? await old.future
                  : http.Response('{}', 403);
            }));
  });
}
