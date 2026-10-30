import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_theme.dart';
import '../network/api_client.dart';
import '../services/auth_session.dart';

String _copy(BuildContext c, String ar, String en) =>
    Localizations.localeOf(c).languageCode == 'ar' ? ar : en;
String _time(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

class VoiceNotePlayer extends StatefulWidget {
  final String? audioPath, localPath;
  final double? duration;
  final bool onDark;
  const VoiceNotePlayer(
      {super.key,
      this.audioPath,
      this.localPath,
      this.duration,
      this.onDark = false});
  static AudioPlayer? _active;
  static Future<void> pauseAll() async {
    await _active?.pause();
  }

  @override
  State<VoiceNotePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoiceNotePlayer>
    with WidgetsBindingObserver {
  AudioPlayer? _player;
  Directory? _directory;
  bool _busy = false, _playing = false;
  String? _error;
  Duration _position = Duration.zero;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  late final String? _owner = AuthSession.instance.currentUser?.id;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthSession.instance.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (_owner != AuthSession.instance.currentUser?.id) {
      unawaited(_player?.stop() ?? Future.value());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_player?.pause() ?? Future.value());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!(ModalRoute.isCurrentOf(context) ?? true)) {
      unawaited(_player?.pause() ?? Future.value());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AuthSession.instance.removeListener(_sessionChanged);
    _stateSub?.cancel();
    _positionSub?.cancel();
    if (identical(VoiceNotePlayer._active, _player)) {
      VoiceNotePlayer._active = null;
    }
    unawaited(_cleanup());
    super.dispose();
  }

  Future<void> _cleanup() async {
    try {
      await _player?.dispose();
    } catch (_) {/* The platform player may already have been released. */}
    try {
      await _directory?.delete(recursive: true);
    } catch (_) {/* Temporary cache only. */}
  }

  Future<void> _toggle() async {
    if (_busy || (_owner != AuthSession.instance.currentUser?.id)) return;
    if (_player?.playing == true) {
      await _player!.pause();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await VoiceNotePlayer.pauseAll();
      if (_player == null) {
        String? path = widget.localPath;
        if (path == null) {
          final token = AuthSession.instance.token;
          if (token == null ||
              !(widget.audioPath?.startsWith('/mobile-workspace/messages/') ==
                      true ||
                  widget.audioPath?.startsWith('/voice/tickets/') == true)) {
            throw StateError('session');
          }
          final bytes = await ApiClient.instance
              .download(widget.audioPath!, token: token);
          if (!mounted ||
              _owner != AuthSession.instance.currentUser?.id ||
              AuthSession.instance.token == null) {
            return;
          }
          if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
            throw StateError('size');
          }
          _directory =
              await (await getTemporaryDirectory()).createTemp('sb-playback-');
          path = '${_directory!.path}/voice.m4a';
          await File(path).writeAsBytes(bytes, flush: true);
        }
        if (!mounted) return;
        _player = AudioPlayer();
        _stateSub = _player!.playerStateStream.listen((state) {
          if (mounted) {
            setState(() => _playing = state.playing &&
                state.processingState != ProcessingState.completed);
          }
        });
        _positionSub = _player!.positionStream.listen((value) {
          if (mounted) setState(() => _position = value);
        });
        await _player!.setFilePath(path);
      }
      if (!mounted || _owner != AuthSession.instance.currentUser?.id) return;
      if (_player!.processingState == ProcessingState.completed) {
        await _player!.seek(Duration.zero);
      }
      VoiceNotePlayer._active = _player;
      unawaited(_player!.play().catchError((Object error) {
        if (mounted) {
          setState(() => _error =
              _copy(context, 'تعذر تشغيل الفويس', 'Unable to play voice'));
        }
      }));
    } catch (_) {
      if (identical(VoiceNotePlayer._active, _player)) {
        VoiceNotePlayer._active = null;
      }
      await _player?.dispose();
      _player = null;
      await _stateSub?.cancel();
      await _positionSub?.cancel();
      if (mounted) {
        setState(() {
          _playing = false;
          _error = _copy(
              context,
              'تعذر تحميل الفويس. تحقق من الاتصال والصلاحية وحاول مجددًا.',
              'Unable to load voice. Check your connection and access, then retry.');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.onDark ? Colors.white : AppColors.navy;
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
                tooltip: _playing
                    ? _copy(context, 'إيقاف مؤقت', 'Pause voice')
                    : _copy(context, 'تشغيل الفويس', 'Play voice'),
                onPressed: _busy ? null : _toggle,
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(
                        _playing
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                        color: color,
                        size: 32)),
            Icon(Icons.graphic_eq_rounded, color: color),
            const SizedBox(width: 8),
            Flexible(
                child: Text(
                    '${_time(_position)} / ${_time(_player?.duration ?? Duration(seconds: (widget.duration ?? 0).round()))}',
                    style: TextStyle(color: color, fontSize: 12))),
          ]),
          if (_error != null)
            Text(_error!, style: TextStyle(color: color, fontSize: 12)),
        ]);
  }
}
