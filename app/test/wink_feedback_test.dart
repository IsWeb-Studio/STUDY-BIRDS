import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:study_birds/screens/games/wink_feedback.dart';

class AudioPlatform extends VideoPlayerPlatform {
  final sources = <DataSource>[], played = <int>[], disposed = <int>[];
  final streams = <int, StreamController<VideoEvent>>{};
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    sources.add(options.dataSource);
    final id = sources.length;
    streams[id] = StreamController<VideoEvent>()
      ..add(VideoEvent(
          eventType: VideoEventType.initialized,
          size: Size.zero,
          duration: const Duration(milliseconds: 800)));
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int id) => streams[id]!.stream;
  @override
  Future<void> play(int id) async {
    played.add(id);
  }

  @override
  Future<void> pause(int id) async {}
  @override
  Future<void> dispose(int id) async {
    disposed.add(id);
    await streams[id]?.close();
  }

  @override
  Future<void> seekTo(int id, Duration position) async {}
  @override
  Future<Duration> getPosition(int id) async => Duration.zero;
  @override
  Future<void> setLooping(int id, bool value) async {}
  @override
  Future<void> setVolume(int id, double value) async {}
  @override
  Future<void> setPlaybackSpeed(int id, double value) async {}
  @override
  Future<void> setMixWithOthers(bool value) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('unavailable audio never prevents gameplay or disposal', () async {
    final old = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = UnavailableAudio();
    final feedback = WinkFeedback();
    try {
      await feedback.play(WinkCue.deal, sound: true, vibration: false);
      await feedback.stop();
    } finally {
      feedback.dispose();
      VideoPlayerPlatform.instance = old;
    }
  });
  test(
      'all effects are bundled PCM WAV files; audio and haptics are independently controlled',
      () async {
    final old = VideoPlayerPlatform.instance, platform = AudioPlatform();
    VideoPlayerPlatform.instance = platform;
    final haptics = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      haptics.add(call.method);
      return null;
    });
    final feedback = WinkFeedback();
    try {
      await feedback.play(WinkCue.deal, sound: false, vibration: false);
      expect(platform.sources, isEmpty);
      await feedback.play(WinkCue.notice, sound: false, vibration: true);
      expect(platform.sources, isEmpty);
      expect(haptics, contains('HapticFeedback.vibrate'));
      for (final cue in WinkCue.values) {
        final path = 'assets/audio/wink/${cue.name}.wav';
        final bytes = await rootBundle.load(path);
        expect(
            String.fromCharCodes(
                bytes.buffer.asUint8List(bytes.offsetInBytes, 4)),
            'RIFF');
        expect(bytes.getUint16(20, Endian.little), 1);
        await feedback.play(cue, sound: true, vibration: false);
        expect(platform.sources.last.asset, path);
        expect(platform.sources.last.sourceType, DataSourceType.asset);
      }
      expect(platform.played, hasLength(6));
      await feedback.stop();
      expect(platform.disposed, hasLength(6));
      feedback.dispose();
      await feedback.play(WinkCue.deal, sound: true, vibration: true);
      expect(platform.played, hasLength(6));
    } finally {
      feedback.dispose();
      VideoPlayerPlatform.instance = old;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    }
  });
  test(
      'state effects are deduplicated, respect inactivity and do not inspect secret roles',
      () async {
    final feedback = RecordingFeedback();
    Map<String, dynamic> state(String phase,
            {int round = 1, bool out = false, String role = 'player'}) =>
        {
          'code': 'room',
          'round': round,
          'phase': phase,
          'players': [
            {'id': 'one', 'eliminated': out}
          ],
          'me': {'role': role}
        };
    void observe(Map<String, dynamic> room, {bool active = true}) =>
        feedback.observe(room, sound: true, vibration: false, active: active);
    observe(state('lobby'));
    observe(state('reveal'));
    observe(state('reveal'));
    expect(feedback.cues, [WinkCue.deal]);
    observe(state('playing'));
    observe(state('playing', role: 'winker'));
    expect(feedback.cues, hasLength(1));
    observe(state('voting'));
    observe(state('playing', out: true));
    observe(state('finished', out: true));
    expect(feedback.cues,
        [WinkCue.deal, WinkCue.vote, WinkCue.elimination, WinkCue.finish]);
    observe(state('reveal', round: 2), active: false);
    observe(state('reveal', round: 2));
    expect(feedback.cues, hasLength(4));
    feedback.dispose();
  });
}

class RecordingFeedback extends WinkFeedback {
  final cues = <WinkCue>[];
  @override
  Future<void> play(WinkCue cue,
      {required bool sound, required bool vibration}) async {
    cues.add(cue);
  }
}

class UnavailableAudio extends AudioPlatform {
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async =>
      throw StateError('Audio unavailable');
}
