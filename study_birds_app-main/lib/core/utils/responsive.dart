import 'package:flutter/material.dart';

/// Window-width based size classes (Material 3 window size classes).
/// Based on the app's *window* width, not the device type, so iPad Split View,
/// Slide Over, Android multi-window and foldables all behave correctly.
enum ScreenSize { compact, medium, expanded }

class Responsive {
  Responsive._();

  static const double mediumBreakpoint = 600;
  static const double expandedBreakpoint = 840;

  static ScreenSize ofWidth(double width) {
    if (width < mediumBreakpoint) return ScreenSize.compact;
    if (width < expandedBreakpoint) return ScreenSize.medium;
    return ScreenSize.expanded;
  }

  /// Uses `sizeOf` so the caller only rebuilds when the size changes
  /// (not on every keyboard / inset change).
  static ScreenSize of(BuildContext context) =>
      ofWidth(MediaQuery.sizeOf(context).width);

  static bool isCompact(BuildContext context) =>
      of(context) == ScreenSize.compact;

  /// Number of grid columns for card grids at the current width.
  static int columns(BuildContext context,
      {int compact = 1, int medium = 2, int expanded = 3}) {
    switch (of(context)) {
      case ScreenSize.compact:
        return compact;
      case ScreenSize.medium:
        return medium;
      case ScreenSize.expanded:
        return expanded;
    }
  }
}

/// Caps content width and centers it on large screens. On phones (width at or
/// below [maxWidth]) it returns [child] untouched, so existing layouts do not
/// change at all.
class MaxWidthBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const MaxWidthBody({super.key, required this.child, this.maxWidth = 720});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth <= maxWidth) return child;
      return Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: maxWidth,
          height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
          child: child,
        ),
      );
    });
  }
}

/// Two-pane "master-detail" on wide windows, a single pane on phones.
///
/// * wide: [master] on the leading side (fixed [masterWidth]) and [detail] (or
///   [placeholder] when nothing is selected) filling the rest.
/// * compact: only [master] is shown; the caller keeps pushing a route for the
///   detail exactly as before, so phone behaviour is unchanged.
class MasterDetail extends StatelessWidget {
  final Widget master;
  final Widget? detail;
  final Widget placeholder;
  final double masterWidth;
  const MasterDetail({
    super.key,
    required this.master,
    required this.detail,
    required this.placeholder,
    this.masterWidth = 340,
  });

  /// Whether the two-pane layout applies at this width.
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= Responsive.mediumBreakpoint + 120;

  @override
  Widget build(BuildContext context) {
    if (!isWide(context)) return master;
    return Row(
      children: [
        SizedBox(width: masterWidth, child: master),
        const VerticalDivider(width: 1),
        Expanded(child: detail ?? placeholder),
      ],
    );
  }
}

/// Keeps a bottom navigation bar a sensible width on tablets: centered and
/// capped, instead of stretching its tabs across a 1000px+ window. Phones are
/// unaffected (the bar is already narrower than [maxWidth]).
class AdaptiveBottomBar extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const AdaptiveBottomBar({super.key, required this.child, this.maxWidth = 600});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).bottomNavigationBarTheme.backgroundColor ??
          Theme.of(context).colorScheme.surface,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      ),
    );
  }
}
