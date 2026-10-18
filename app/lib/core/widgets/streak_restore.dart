import 'package:flutter/material.dart';
import '../network/api_client.dart';
import '../repositories/stories_repository.dart';

class StreakRestore extends StatefulWidget {
  final StoryProgress progress;
  final ValueChanged<StoryProgress> onRestored;
  const StreakRestore(
      {super.key, required this.progress, required this.onRestored});
  @override
  State<StreakRestore> createState() => _StreakRestoreState();
}

class _StreakRestoreState extends State<StreakRestore> {
  bool _busy = false;
  String? _error;
  Future<void> _restore() async {
    if (_busy || !widget.progress.canRestore) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final progress = await StoriesRepository.instance.restoreStreak();
      if (mounted) widget.onRestored(progress);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiException
            ? error.message
            : 'تعذر استرجاع الستريك. حاول مجددًا.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(children: [
          Text(
              'استرجاع الستريك: متبقي ${p.restoresRemaining} من ${p.restoreLimit} هذا الشهر.',
              textAlign: TextAlign.center),
          Text('يتجدد الرصيد بداية كل شهر حسب ${p.timeZone}.',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
          if (p.recoverableDays > 0) ...[
            Text(
                p.restoresRemaining == 0
                    ? 'استخدمت الاسترجاعات الثلاثة لهذا الشهر. ابدأ ستريك جديدًا من الصفر.'
                    : 'استرجع أيامك السابقة قبل أن تبدأ ستريك جديدًا.',
                textAlign: TextAlign.center),
            FilledButton.icon(
                onPressed: !_busy && p.canRestore ? _restore : null,
                icon: const Icon(Icons.restore),
                label: Text(_busy
                    ? 'جارٍ الاسترجاع...'
                    : 'استرجاع الستريك (${p.recoverableDays} يوم)')),
          ],
          if (_error != null)
            Text(_error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center),
        ]));
  }
}
