import 'package:flutter/material.dart';
import 'birds_ai_screen.dart';

/// An explicit help action, not a floating overlay on nested screens.
class AssistantHelpButton extends StatelessWidget {
  final String screen;
  const AssistantHelpButton({super.key, required this.screen});
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: Localizations.localeOf(context).languageCode == 'en'
            ? 'Help with this screen'
            : 'مساعدة في هذه الشاشة',
        icon: const Icon(Icons.help_outline_rounded),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => BirdsAiScreen(originScreen: screen))),
      );
}
