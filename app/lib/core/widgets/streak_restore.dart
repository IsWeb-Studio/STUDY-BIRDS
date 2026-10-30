import 'dart:async';
import 'package:flutter/material.dart';
import '../network/api_client.dart';
import '../repositories/stories_repository.dart';
import '../services/auth_session.dart';

String _tr(BuildContext c, String ar, String en) =>
    Localizations.localeOf(c).languageCode == 'ar' ? ar : en;
String _owner() =>
    '${AuthSession.instance.currentUser?.id}:${AuthSession.instance.token}';
String _ltr(String value) => '\u2066$value\u2069';
String _remaining(StoryProgress p) {
  final m = (p.remainingUntil(p.recoveryExpiresAt).inSeconds / 60).ceil();
  return '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}';
}

class StreakRestore extends StatefulWidget {
  final StoryProgress progress;
  final ValueChanged<StoryProgress> onRestored;
  final bool allowActions;
  final bool isGameActivity;
  final Future<StoryProgress> Function(String)? restore;
  final VoidCallback? onRefreshNeeded;
  const StreakRestore(
      {super.key,
      required this.progress,
      required this.onRestored,
      this.allowActions = true,
      this.isGameActivity = false,
      this.restore,
      this.onRefreshNeeded});
  @override
  State<StreakRestore> createState() => _StreakRestoreState();
}

class _StreakRestoreState extends State<StreakRestore> {
  bool _busy = false;
  String? _operation;
  bool _failed = false;
  @override
  void didUpdateWidget(covariant StreakRestore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress.recoveryExpiresAt !=
            widget.progress.recoveryExpiresAt &&
        !_busy) {
      _operation = null;
    }
  }

  Future<void> _confirm() async {
    if (_busy || !widget.allowActions || !widget.progress.restoreEligible) {
      return;
    }
    final owner = _owner();
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final yes = await showModalBottomSheet<bool>(
          context: context,
          showDragHandle: true,
          useSafeArea: true,
          isScrollControlled: true,
          constraints: const BoxConstraints(maxWidth: 560),
          sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
              ? AnimationStyle.noAnimation
              : null,
          builder: (_) => _Confirmation(progress: widget.progress));
      if (!mounted ||
          yes != true ||
          owner != _owner() ||
          !widget.progress.restoreEligible) {
        return;
      }
      _operation ??= ApiClient.newOperationId();
      final p = await (widget.restore?.call(_operation!) ??
          StoriesRepository.instance.restoreStreak(operationId: _operation));
      if (!mounted || owner != _owner()) return;
      _operation = null;
      widget.onRestored(p);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content: Text(_tr(
              context, 'تمت استعادة سلسلة نشاطك', 'Your streak is restored'))));
    } catch (_) {
      if (mounted && owner == _owner()) {
        setState(() => _failed = true);
        widget.onRefreshNeeded?.call();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress;
    final scheme = Theme.of(context).colorScheme;
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              _tr(
                  context,
                  'متبقي هذا الشهر: ${p.restoresRemaining} من ${p.restoreLimit} استرجاعات',
                  '${p.restoresRemaining} of ${p.restoreLimit} restores left this month'),
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
              _tr(
                  context,
                  'يتجدد الرصيد أول الشهر حسب ${_ltr(p.timeZone)}، دون ترحيل المتبقي.',
                  'Resets on the first of the month in ${p.timeZone}; unused restores do not roll over.'),
              style: Theme.of(context).textTheme.bodySmall),
          if (p.monthResetsAt != null)
            Text(
                _tr(
                    context,
                    'التجديد: ${_ltr('${p.monthResetsAt!.toUtc().toIso8601String().substring(0, 16).replaceFirst('T', ' ')} UTC')}',
                    'Resets: ${p.monthResetsAt!.toUtc().toIso8601String().substring(0, 16)} UTC'),
                style: Theme.of(context).textTheme.bodySmall),
          if (p.serverNow == null && p.recoverableDays > 0)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_tr(
                    context,
                    'لا يمكن تأكيد مهلة الاسترجاع حاليًا. حدّث بيانات النشاط قبل المحاولة.',
                    'Recovery timing could not be verified. Refresh your activity before trying.'))),
          if (p.streakState == 'recoverable') ...[
            const SizedBox(height: 12),
            Text(_tr(
                context,
                'سلسلتك السابقة: ${p.recoverableDays} يوم • المتبقي ${_ltr(_remaining(p))}',
                'Previous streak: ${p.recoverableDays} days · ${_remaining(p)} remaining')),
          ],
          if (p.restoresRemaining == 0)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_tr(
                    context,
                    'استخدمت الاسترجاعات الثلاثة. يتجدد رصيدك أول الشهر؛ يمكنك بدء سلسلة جديدة الآن.',
                    'You have used all three restores. Your allowance resets next month; you can start a new streak now.'))),
          if (p.streakState == 'expired')
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_tr(
                    context,
                    widget.isGameActivity
                        ? 'انتهت مهلة الاسترجاع. شارك في لعبة أونلاين لبدء سلسلة جديدة؛ تجديد الرصيد لا يعيد المهلة.'
                        : 'انتهت مهلة الاسترجاع. انشر ستوري لبدء سلسلة جديدة؛ تجديد الرصيد لا يعيد المهلة.',
                    widget.isGameActivity
                        ? 'The recovery window has closed. Play online to start again; a monthly reset does not reopen it.'
                        : 'The recovery window has closed. Share a story to start again; a monthly reset does not reopen it.'))),
          if (p.restoreEligible)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                        key: const ValueKey('streak-restore'),
                        onPressed:
                            !_busy && widget.allowActions ? _confirm : null,
                        icon: const Icon(Icons.restore_rounded),
                        label: Text(_busy
                            ? _tr(context, 'جارٍ الاسترجاع…', 'Restoring…')
                            : _tr(context, 'استعادة السلسلة',
                                'Restore streak'))))),
          if (_failed)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                    _tr(
                        context,
                        'تعذر الاسترجاع. تحقق من الاتصال وحدّث بيانات السلسلة قبل المحاولة مجددًا.',
                        'Could not restore. Check your connection and refresh before trying again.'),
                    style: TextStyle(color: scheme.error))),
        ]));
  }
}

class _Confirmation extends StatefulWidget {
  final StoryProgress progress;
  const _Confirmation({required this.progress});
  @override
  State<_Confirmation> createState() => _ConfirmationState();
}

class _ConfirmationState extends State<_Confirmation> {
  Timer? _timer;
  late String _scope;
  @override
  void initState() {
    super.initState();
    _scope = _owner();
    AuthSession.instance.addListener(_session);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _session() {
    if (_scope != _owner() && mounted) {
      final route = ModalRoute.of(context);
      if (route != null) Navigator.of(context).removeRoute(route);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    AuthSession.instance.removeListener(_session);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_scope != _owner()) return const SizedBox.shrink();
    final p = widget.progress;
    return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            24, 8, 24, 24 + MediaQuery.paddingOf(context).bottom),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_tr(context, 'استعادة سلسلة نشاطك؟', 'Restore your streak?'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(_tr(
                  context,
                  'استرجاع ${p.recoverableDays} يوم من نشاطك باستخدام استرجاع واحد.',
                  'Bring back your ${p.recoverableDays}-day streak using one restore.')),
              const SizedBox(height: 12),
              Text(_tr(
                  context,
                  'المتبقي: ${_ltr(_remaining(p))} • رصيدك ${p.restoresRemaining} من ${p.restoreLimit}',
                  'Time left: ${_remaining(p)} · ${p.restoresRemaining} of ${p.restoreLimit} restores available')),
              const SizedBox(height: 20),
              FilledButton(
                  key: const ValueKey('confirm-streak-restore'),
                  onPressed: p.restoreEligible
                      ? () => Navigator.pop(context, true)
                      : null,
                  child:
                      Text(_tr(context, 'تأكيد الاسترجاع', 'Confirm restore'))),
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(_tr(context, 'ليس الآن', 'Not now'))),
            ]));
  }
}
