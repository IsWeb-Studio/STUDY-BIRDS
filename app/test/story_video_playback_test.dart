import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:study_birds/core/repositories/stories_repository.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/stories/story_viewer.dart';
import 'story_viewer_test.dart' show open, json;

class _VideoPlatform extends VideoPlayerPlatform {
  final events = StreamController<VideoEvent>();
  Duration position = Duration.zero;
  bool playing = false, disposed = false;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    events.add(VideoEvent(
        eventType: VideoEventType.initialized,
        size: const Size(640, 360),
        duration: const Duration(seconds: 12)));
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events.stream;
  @override
  Future<void> play(int playerId) async {
    playing = true;
  }

  @override
  Future<void> pause(int playerId) async {
    playing = false;
  }

  @override
  Future<void> dispose(int playerId) async {
    disposed = true;
    await events.close();
  }

  @override
  Future<Duration> getPosition(int playerId) async => position;
  @override
  Future<void> seekTo(int playerId, Duration value) async {
    position = value;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Future<void> setAllowBackgroundPlayback(bool allow) async {}
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox(key: ValueKey('video-surface'));
}

void main() {
  testWidgets(
      'video clock follows playback, pauses in background and advances only at video end',
      (tester) async {
    AuthSession.instance.token = 'video-playback-test';
    final previous = VideoPlayerPlatform.instance;
    final platform = _VideoPlatform();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() {
      VideoPlayerPlatform.instance = previous;
      AuthSession.instance.token = null;
    });
    final video = StudentStory.fromJson({
      'id': 'video',
      'text': '',
      'videoUrl': 'https://example.test/video.mp4',
      'videoDuration': 12,
      'author': {'id': 'other', 'name': 'Student'},
      'expiresAt':
          DateTime.now().add(const Duration(hours: 1)).toIso8601String()
    });
    await http.runWithClient(() async {
      await open(tester, [video]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('video-surface')), findsOneWidget);
      expect(platform.playing, true);
      // Six wall-clock seconds with no decoded playback must not expire the video.
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(find.byType(StoryViewer), findsOneWidget);
      expect(
          tester
              .widget<LinearProgressIndicator>(
                  find.byKey(const ValueKey('story-timer-0')))
              .value,
          0);
      platform.position = const Duration(seconds: 6);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(
          tester
              .widget<LinearProgressIndicator>(
                  find.byKey(const ValueKey('story-timer-0')))
              .value,
          closeTo(.5, .01));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(platform.playing, false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(platform.playing, true);
      platform.position = const Duration(seconds: 12);
      platform.events.add(VideoEvent(eventType: VideoEventType.completed));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(StoryViewer), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      expect(platform.playing, false);
    },
        () =>
            MockClient((request) async => request.url.path.endsWith('/updates')
                ? json({
                    'updates': [
                      {'id': 'video', 'loveCount': 0}
                    ]
                  })
                : json({'seen': true})));
  });
}
