import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import 'current_user_avatar.dart';

/// Shared navigation with stable destination IDs.
class ProfileBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final List<String> labels;
  final ValueChanged<int> onTap;
  final List<int>? visibleDestinations;
  const ProfileBottomNavigation(
      {super.key,
      required this.currentIndex,
      required this.labels,
      required this.onTap,
      this.visibleDestinations});
  static const order = [0, 1, 2, 6, 3, 4, 5];
  static const icons = [
    Icons.home_outlined,
    Icons.route_outlined,
    Icons.explore_outlined,
    Icons.grid_view_outlined,
    Icons.forum_outlined,
    Icons.sports_esports_outlined
  ];

  @override
  Widget build(BuildContext context) {
    if (visibleDestinations != null) {
      return DecoratedBox(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              boxShadow: [
                BoxShadow(
                    color: Color(0x12041E4A),
                    blurRadius: 20,
                    offset: Offset(0, -4))
              ]),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Row(children: [
                for (final index in visibleDestinations!)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: currentIndex == index,
                      label: labels[index],
                      excludeSemantics: true,
                      child: InkWell(
                          key: ValueKey('main-tab-$index'),
                          onTap: () => onTap(index),
                          borderRadius: BorderRadius.circular(16),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 64),
                            child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 4),
                                decoration: BoxDecoration(
                                    color: currentIndex == index
                                        ? AppColors.navy
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16)),
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedScale(
                                          scale:
                                              currentIndex == index ? 1.08 : 1,
                                          duration:
                                              const Duration(milliseconds: 180),
                                          child: Icon(
                                              index == 0
                                                  ? Icons.home_rounded
                                                  : index == 4
                                                      ? Icons.forum_rounded
                                                      : Icons
                                                          .sports_esports_rounded,
                                              size: 25,
                                              color: currentIndex == index
                                                  ? AppColors.green
                                                  : AppColors.textSecondary)),
                                      const SizedBox(height: 4),
                                      Text(labels[index],
                                          maxLines: 2,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: currentIndex == index
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: currentIndex == index
                                                  ? Colors.white
                                                  : AppColors.textSecondary)),
                                    ])),
                          )),
                    ),
                  )
              ]),
            ),
          ));
    }
    final extra =
        (MediaQuery.textScalerOf(context).scale(10) - 10).clamp(0.0, 18.0);
    final safe = MediaQuery.paddingOf(context).bottom;
    return LayoutBuilder(builder: (context, constraints) {
      final diameter = (constraints.maxWidth / 7).clamp(0.0, 64.0);
      return SizedBox(
          height: 100 + extra + safe,
          child: CustomPaint(
            painter: const _NotchedBarPainter(),
            child: Padding(
                padding: EdgeInsets.only(bottom: safe),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: order.map((index) {
                    final account = index == 6;
                    final selected = currentIndex == index;
                    return Expanded(
                        child: Semantics(
                      selected: selected,
                      button: true,
                      onTap: () => onTap(index),
                      label: labels[index],
                      excludeSemantics: true,
                      child: InkWell(
                        key: ValueKey('main-tab-$index'),
                        splashColor: AppColors.green.withValues(alpha: .18),
                        highlightColor: AppColors.green.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => onTap(index),
                        child: SizedBox(
                            height: 100 + extra,
                            child: Column(children: [
                              if (account) ...[
                                SizedBox(height: (64 - diameter) / 2),
                                Container(
                                  key: const ValueKey('main-account-avatar'),
                                  width: diameter,
                                  height: diameter,
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                            color: Color(0x22041E4A),
                                            blurRadius: 12,
                                            offset: Offset(0, 3))
                                      ]),
                                  child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: selected
                                                  ? AppColors.greenInk
                                                  : AppColors.navy,
                                              width: selected ? 2 : 1.3)),
                                      child:
                                          const CurrentUserAvatar(radius: 24)),
                                ),
                                SizedBox(height: 7 + (64 - diameter) / 2),
                              ] else ...[
                                const SizedBox(height: 43),
                                AnimatedScale(
                                    scale: selected ? 1.08 : 1,
                                    duration: const Duration(milliseconds: 180),
                                    child: Icon(icons[index],
                                        size: 23,
                                        color: selected
                                            ? AppColors.greenInk
                                            : AppColors.navy)),
                                const SizedBox(height: 5),
                              ],
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 1),
                                  child: Text(labels[index],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: selected
                                              ? AppColors.greenInk
                                              : AppColors.navy,
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w500))),
                            ])),
                      ),
                    ));
                  }).toList(),
                )),
          ));
    });
  }
}

class _NotchedBarPainter extends CustomPainter {
  const _NotchedBarPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.width / 2;
    final path = Path()
      ..moveTo(0, 44)
      ..quadraticBezierTo(0, 25, 20, 25)
      ..lineTo(c - 59, 25)
      ..cubicTo(c - 42, 25, c - 40, 39, c - 33, 51)
      ..cubicTo(c - 20, 73, c + 20, 73, c + 33, 51)
      ..cubicTo(c + 40, 39, c + 42, 25, c + 59, 25)
      ..lineTo(size.width - 20, 25)
      ..quadraticBezierTo(size.width, 25, size.width, 44)
      ..lineTo(size.width, size.height - 30)
      ..quadraticBezierTo(size.width, size.height, size.width - 30, size.height)
      ..lineTo(30, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - 30)
      ..close();
    canvas.drawShadow(path, const Color(0x40041E4A), 8, false);
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
