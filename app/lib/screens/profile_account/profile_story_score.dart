import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/repositories/stories_repository.dart';
import '../../core/services/realtime_sync_service.dart';
import '../../core/widgets/bird_points.dart';
import '../stories/student_stories.dart';
import '../community/student_community_hub.dart';

class ProfileStoryScore extends StatefulWidget {
  final bool isActive;
  final ValueChanged<StoryProgress>? onProgress;
  const ProfileStoryScore({super.key, this.isActive = true, this.onProgress});
  @override
  State<ProfileStoryScore> createState() => _ProfileStoryScoreState();
}

class _ProfileStoryScoreState extends State<ProfileStoryScore> {
  StoryProgress? _progress;
  bool _loading = false, _failed = false, _opening = false;
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
    if (_loading) return;
    _loading = true;
    try {
      final progress = await StoriesRepository.instance.progress();
      if (mounted) {
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

  Future<void> _openProgress() async {
    if (_opening) return;
    if (_progress == null) {
      await _load();
      if (!mounted || _progress == null) return;
    }
    _opening = true;
    bool visitCommunity = false;
    try {
      await showModalBottomSheet(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (ctx) => StoryProgressSheet(
              progress: _progress!,
              onPost: () {
                visitCommunity = true;
                Navigator.pop(ctx);
              }));
      if (mounted) await _load();
      if (visitCommunity && mounted) {
        await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StudentCommunityHub()));
      }
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) => Tooltip(
      message:
          _failed ? 'تعذر تحديث السكور، اضغط للمحاولة' : 'السكور والاستمرارية',
      child: Semantics(
          button: true,
          label: 'السكور: ${_progress?.points ?? 'جارٍ التحميل'}، عرض التقدم',
          child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                  onTap: _openProgress,
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                      width: 72,
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 7),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            if (_progress == null && !_failed)
                              const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                            else
                              const BirdPointsIcon(size: 30),
                            const SizedBox(height: 3),
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
                                        color: Color(0xFF06244B)))),
                          ])))))));
}
