import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../repositories/community_repository.dart';

const communityReactionEmoji = {
  'love': '❤️',
  'like': '👍',
  'hundred': '💯',
  'laugh': '😂',
  'wow': '🤯',
  'trophy': '🏆',
  'clap': '👏',
};

const _emojiFonts = ['Apple Color Emoji', 'Noto Color Emoji', 'Segoe UI Emoji'];

class CommunityReactions extends StatefulWidget {
  final Map<String, dynamic> post;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool enabled;
  final Key? buttonKey;
  const CommunityReactions(
      {super.key,
      required this.post,
      required this.onChanged,
      this.enabled = true,
      this.buttonKey});
  @override
  State<CommunityReactions> createState() => _CommunityReactionsState();
}

class _CommunityReactionsState extends State<CommunityReactions> {
  bool _busy = false;
  Future<void> _choose() async {
    if (_busy || !widget.enabled) return;
    final postId = '${widget.post['_id']}';
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final selected = widget.post['myReaction'] ??
        (widget.post['likedByMe'] == true ? 'like' : null);
    final choice = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(ar ? 'تفاعل مع المنشور' : 'React to post',
                      style: AppTextStyles.cardTitle),
                  const SizedBox(height: 16),
                  Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final entry in communityReactionEmoji.entries)
                          Semantics(
                              button: true,
                              selected: selected == entry.key,
                              label: entry.key,
                              child: InkWell(
                                  key: ValueKey('reaction-choice-${entry.key}'),
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () =>
                                      Navigator.pop(context, entry.key),
                                  child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                          color: selected == entry.key
                                              ? AppColors.greenSoft
                                              : null,
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                      child: Text(entry.value,
                                          style: const TextStyle(
                                              fontSize: 28,
                                              fontFamilyFallback:
                                                  _emojiFonts))))),
                      ]),
                  if (selected != null)
                    TextButton(
                        onPressed: () => Navigator.pop(context, 'remove'),
                        child:
                            Text(ar ? 'إلغاء تفاعلي' : 'Remove my reaction')),
                ]))));
    if (choice == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await CommunityRepository.instance.react(
          postId, choice == 'remove' || choice == selected ? null : choice);
      if (mounted) widget.onChanged(result);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ar
                ? 'تعذر حفظ التفاعل. حاول مجددًا.'
                : 'Could not save reaction. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final counts = widget.post['reactionCounts'] is Map
        ? widget.post['reactionCounts'] as Map
        : const {};
    final selected = widget.post['myReaction'] ??
        (widget.post['likedByMe'] == true ? 'like' : null);
    return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          TextButton.icon(
              key: widget.buttonKey,
              onPressed: widget.enabled && !_busy ? _choose : null,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : selected == null
                      ? const Icon(Icons.add_reaction_outlined, size: 22)
                      : Text(communityReactionEmoji[selected] ?? '👍',
                          style: const TextStyle(
                              fontSize: 22, fontFamilyFallback: _emojiFonts)),
              label: Text(
                  '${widget.post['reactionTotal'] ?? widget.post['likeCount'] ?? 0} ${ar ? 'تفاعل' : 'reactions'}')),
          for (final entry in communityReactionEmoji.entries)
            if ((counts[entry.key] as num? ?? 0) > 0)
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('${entry.value} ${counts[entry.key]}',
                      style: const TextStyle(fontFamilyFallback: _emojiFonts))),
        ]);
  }
}
