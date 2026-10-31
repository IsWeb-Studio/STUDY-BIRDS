import 'package:just_audio/just_audio.dart';

/// Playback boundary lets the viewer own and stop each story's soundtrack.
abstract class StorySound {
  Future<void> load(String url);
  Future<void> play();
  Future<void> pause();
  Future<void> dispose();
}

class DeviceStorySound implements StorySound {
  final _player = AudioPlayer();
  @override
  Future<void> load(String url) async {
    await _player.setUrl(url);
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> dispose() => _player.dispose();
}
