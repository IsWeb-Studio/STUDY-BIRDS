import 'package:flutter/material.dart';
import 'assistant_navigation.dart';
import '../../core/widgets/safety_controls.dart';

/// Plain text keeps old provider Markdown out of both current and saved chats.
String assistantPlainText(String text) => text
    .replaceAll(RegExp(r'^```[^\n]*$', multiLine: true), '')
    .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (match) => match[1]!)
    .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
    .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*|__(.+?)__|\*(.+?)\*|_(.+?)_'),
        (match) => match[1] ?? match[2] ?? match[3] ?? match[4]!)
    .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '• ')
    .replaceAll('`', '')
    .trim();

/// Expands locally received reviewed guidance in the same answer bubble.
class AssistantAnswer extends StatefulWidget {
  final String content, details;
  final String? knowledgeVersion;
  final TextStyle? style;
  final bool reportable;
  const AssistantAnswer(
      {super.key,
      required this.content,
      this.details = '',
      this.knowledgeVersion,
      this.reportable = false,
      this.style});
  @override
  State<AssistantAnswer> createState() => _AssistantAnswerState();
}

class _AssistantAnswerState extends State<AssistantAnswer> {
  bool expanded = false;
  @override
  void didUpdateWidget(covariant AssistantAnswer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content ||
        oldWidget.details != widget.details ||
        oldWidget.knowledgeVersion != widget.knowledgeVersion) {
      expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final useful =
        widget.knowledgeVersion == AssistantNavigation.knowledgeVersion &&
            widget.details.trim().isNotEmpty &&
            widget.details.trim() != widget.content.trim();
    final en = Localizations.localeOf(context).languageCode == 'en';
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(
              assistantPlainText(
                  expanded && useful ? widget.details : widget.content),
              style: widget.style),
          if (useful)
            TextButton.icon(
              onPressed: () => setState(() => expanded = !expanded),
              icon: Icon(expanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded),
              label: Text(expanded
                  ? (en ? 'Show less' : 'عرض أقل')
                  : (en ? 'Explain More' : 'اشرح أكثر')),
            ),
          if (widget.reportable && widget.content.trim().isNotEmpty)
            TextButton.icon(onPressed: () => reportUnsafeContent(context,
                'COVEY AI answer:\n${widget.content}\n${widget.details}'),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text(en ? 'Report answer' : 'إبلاغ عن الإجابة')),
        ]);
  }
}
