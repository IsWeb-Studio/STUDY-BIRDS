import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/repositories/stories_repository.dart';
import 'package:study_birds/screens/stories/story_sound.dart';
import 'package:study_birds/screens/stories/story_viewer.dart';
import 'story_viewer_test.dart' show json;

class FakeSound implements StorySound {
  String? loaded;
  bool playing = false, disposed = false;
  @override
  Future<void> load(String url) async {
    loaded = url;
  }

  @override
  Future<void> play() async {
    playing = true;
  }

  @override
  Future<void> pause() async {
    playing = false;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    playing = false;
  }
}

void main() {
  testWidgets(
      'soundtrack loads, pauses in background, resumes and disposes on exit',
      (tester) async {
    final sound = FakeSound();
    final story = StudentStory.fromJson({
      'id': 'audio-story',
      'text': 'Photo with audio',
      'audioUrl': 'https://example.test/sound.mp3',
      'audioDuration': 12,
      'author': {'id': 'other', 'name': 'Student'},
      'expiresAt':
          DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          home: StoryViewer(
              stories: [story], onSeen: (_) {}, soundFactory: () => sound)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(sound.loaded, story.audioUrl);
      expect(sound.playing, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(sound.playing, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(sound.playing, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(sound.disposed, isTrue);
      expect(sound.playing, isFalse);
    }, () => MockClient((_) async => json({})));
  });
}
