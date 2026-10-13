import '../../l10n/l10n.dart';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../utils/responsive.dart';
import '../../screens/ai/birds_ai_screen.dart';

/// Standard scaffold wrapper: navy app bar, RTL, background color.
class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomBar;
  final bool showBackButton;
  final bool hideAiButton;
  final TextDirection? textDirection;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottomBar,
    this.showBackButton = true,
    this.hideAiButton = false,
    this.textDirection,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: textDirection ?? appTextDirection,
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: showBackButton,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          actions: actions,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              MaxWidthBody(child: body),
              if (!hideAiButton) const _DraggableAiButton(),
            ],
          ),
        ),
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomBar,
      ),
    );
  }
}

class _DraggableAiButton extends StatefulWidget {
  const _DraggableAiButton();
  @override
  State<_DraggableAiButton> createState() => _DraggableAiButtonState();
}

class _DraggableAiButtonState extends State<_DraggableAiButton> {
  // Static so position persists while navigating between screens
  static double? _sx;
  static double? _sy;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      _sx ??= constraints.maxWidth - 68;
      _sy ??= constraints.maxHeight - 68;
      return Stack(
        children: [
          Positioned(
            left: _sx,
            top: _sy,
            child: GestureDetector(
              onPanUpdate: (d) => setState(() {
                _sx = (_sx! + d.delta.dx)
                    .clamp(0.0, constraints.maxWidth - 52);
                _sy = (_sy! + d.delta.dy)
                    .clamp(0.0, constraints.maxHeight - 52);
              }),
              onTap: () => Navigator.push(
                ctx,
                MaterialPageRoute(
                    builder: (_) => const BirdsAiScreen(),
                    fullscreenDialog: true),
              ),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.navy.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 5))
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: AppColors.orange, size: 24),
              ),
            ),
          ),
        ],
      );
    });
  }
}

