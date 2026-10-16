import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/repositories/stories_repository.dart';
import '../../core/services/realtime_sync_service.dart';
import '../../core/widgets/app_notice.dart';

/// A small account badge, separate from avatar editing. Preferences live on the
/// account so the selected emoji follows the student across devices.
class ProfileStoryScore extends StatefulWidget {
  final bool isActive;
  final ValueChanged<StoryProgress>? onProgress;
  const ProfileStoryScore({super.key, this.isActive = true, this.onProgress});
  @override
  State<ProfileStoryScore> createState() => _ProfileStoryScoreState();
}

class _ProfileStoryScoreState extends State<ProfileStoryScore> {
  StoryProgress? _progress;
  bool _loading = false, _saving = false, _failed = false, _choosing = false;
  int _preferenceRevision = 0;
  StreamSubscription<DateTime>? _subscription;
  @override
  void initState() {
    super.initState();
    if (widget.isActive) _load();
    _subscription = RealtimeSyncService.instance.onTick.listen((_) {
      if (mounted &&
          widget.isActive &&
          (ModalRoute.isCurrentOf(context) ?? true) &&
          (WidgetsBinding.instance.lifecycleState == null ||
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed)) {
        _load();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ProfileStoryScore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _load();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || _saving) return;
    _loading = true;
    final revision = _preferenceRevision;
    try {
      final progress = await StoriesRepository.instance.progress();
      if (mounted && revision == _preferenceRevision) {
        setState(() {
          _progress = progress;
          _failed = false;
        });
        widget.onProgress?.call(progress);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _loading = false;
    }
  }

  Future<void> _choose() async {
    if (_saving || _choosing) return;
    if (_progress == null) {
      await _load();
      return;
    }
    _choosing = true;
    final emoji = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheet) => SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('إيموجي السكور',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('${_progress!.points} نقطة'),
                  const SizedBox(height: 6),
                  const Text('اختار الرمز اللي يظهر جنب نقاطك',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final choice in StoryProgress.scoreEmojis)
                          Semantics(
                              selected: choice == _progress!.scoreEmoji,
                              child: OutlinedButton(
                                  onPressed: () => Navigator.pop(sheet, choice),
                                  style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(58, 54),
                                      padding: const EdgeInsets.all(8),
                                      backgroundColor:
                                          choice == _progress!.scoreEmoji
                                              ? const Color(0xFFFFF0DD)
                                              : null),
                                  child: Text(choice,
                                      style: const TextStyle(fontSize: 26)))),
                      ]),
                ])))).whenComplete(() => _choosing = false);
    if (!mounted || emoji == null || emoji == _progress?.scoreEmoji) return;
    setState(() => _saving = true);
    _preferenceRevision++;
    try {
      final progress = await StoriesRepository.instance.setScoreEmoji(emoji);
      if (mounted) {
        setState(() {
          _progress = progress;
          _failed = false;
        });
        widget.onProgress?.call(progress);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
            content: const Text('تعذر حفظ الإيموجي. حاول مرة أخرى.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Tooltip(
        message: _failed
            ? 'تعذر تحديث النقاط، اضغط للمحاولة'
            : 'نقاط يومياتك • اضغط لاختيار الإيموجي',
        child: Semantics(
            button: true,
            label:
                'نقاط اليوميات: ${_progress?.points ?? 'جارٍ التحميل'}، اختيار الإيموجي',
            child: Material(
              color: const Color(0xFFFFF3E6),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                  onTap: _saving ? null : _choose,
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                      width: 72,
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 7),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            if (_saving || (_progress == null && !_failed))
                              const SizedBox(
                                  width: 21,
                                  height: 21,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                            else
                              Text(_progress?.scoreEmoji ?? '🔥',
                                  style: const TextStyle(fontSize: 22)),
                            const SizedBox(height: 2),
                            FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                    _progress == null
                                        ? '—'
                                        : '${_progress!.points}',
                                    textDirection: TextDirection.ltr,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF8C4800)))),
                          ])))),
            )),
      );
}
