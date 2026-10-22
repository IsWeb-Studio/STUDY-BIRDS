import 'dart:async';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../core/services/error_reporter.dart';

enum WinkCue { deal, reveal, elimination, vote, finish, notice }

/// Bundled, offline effects. One player at a time; no network/media downloads.
class WinkFeedback {
  VideoPlayerController? _player;
  bool _disposed = false;
  int _generation = 0;
  String? _room, _phase, _notice;
  int? _round;
  Set<String> _out = {};

  Future<void> play(WinkCue cue,
      {required bool sound, required bool vibration}) async {
    if (_disposed) return;
    final generation = ++_generation;
    if (vibration) unawaited(HapticFeedback.lightImpact());
    final old = _player;
    _player = null;
    if (old != null) await _release(old);
    if (!sound || _disposed || generation != _generation) return;
    final player = VideoPlayerController.asset(
        'assets/audio/wink/${cue.name}.wav',
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    _player = player;
    try {
      await player.initialize().timeout(const Duration(seconds: 3));
      if (_disposed || generation != _generation) return;
      await player.setVolume(0.65);
      await player.play();
    } catch (error, stack) {
      ErrorReporter.swallowed(error, stack, 'wink.audio');
    }
  }

  /// Events are derived from public state changes, never from secret roles.
  void observe(Map<String, dynamic>? room,
      {required bool sound,
      required bool vibration,
      required bool active,
      bool emit = true}) {
    final code = room?['code']?.toString();
    final phase = room?['phase']?.toString();
    final round = (room?['round'] as num?)?.toInt();
    final notice = (room?['me'] as Map?)?['notice']?.toString();
    final out = ((room?['players'] as List?) ?? [])
        .whereType<Map>()
        .where((p) => p['eliminated'] == true || p['left'] == true)
        .map((p) => '${p['id']}')
        .toSet();
    WinkCue? cue;
    final sameRound = code == _room && round == _round;
    if (phase == 'finished' && (phase != _phase || !sameRound)) {
      cue = WinkCue.finish;
    } else if (phase == 'reveal' && (phase != _phase || !sameRound)) {
      cue = WinkCue.deal;
    } else if (sameRound && phase == 'voting' && phase != _phase) {
      cue = WinkCue.vote;
    } else if (sameRound && out.difference(_out).isNotEmpty) {
      cue = WinkCue.elimination;
    } else if (sameRound && notice != null && notice != _notice) {
      cue = WinkCue.notice;
    }
    _room = code;
    _phase = phase;
    _round = round;
    _notice = notice;
    _out = out;
    if (!active) {
      unawaited(stop());
      return;
    }
    if (emit && cue != null) {
      unawaited(play(cue, sound: sound, vibration: vibration));
    }
  }

  Future<void> stop() async {
    ++_generation;
    final player = _player;
    _player = null;
    if (player != null) await _release(player);
  }

  Future<void> _release(VideoPlayerController player) async {
    try {
      await player.dispose().timeout(const Duration(seconds: 2));
    } catch (error, stack) {
      ErrorReporter.swallowed(error, stack, 'wink.audio.dispose');
    }
  }

  void dispose() {
    _disposed = true;
    unawaited(stop());
  }
}
