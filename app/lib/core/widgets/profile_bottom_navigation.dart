import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import 'current_user_avatar.dart';

/// Keeps destination IDs stable while placing the account between Explore and
/// Services. The entire raised avatar is inside the hit-test area.
class ProfileBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final List<String> labels;
  final ValueChanged<int> onTap;
  const ProfileBottomNavigation(
      {super.key,
      required this.currentIndex,
      required this.labels,
      required this.onTap});
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
                                            color: Color(0x22011E46),
                                            blurRadius: 12,
                                            offset: Offset(0, 3))
                                      ]),
                                  child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: AppColors.navy,
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
                                        size: 23, color: AppColors.navy)),
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
                                          color: AppColors.navy,
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
    canvas.drawShadow(path, const Color(0x40011E46), 8, false);
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
