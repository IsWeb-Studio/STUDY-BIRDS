import 'package:flutter/material.dart';

/// Short pulsing story segments; no rotating spinner.
class StoryLoadingIndicator extends StatefulWidget {
  final Color color;
  final String label;
  const StoryLoadingIndicator(
      {super.key,
      this.color = Colors.white,
      this.label = 'جارٍ تحميل الستوري…'});
  @override
  State<StoryLoadingIndicator> createState() => _StoryLoadingIndicatorState();
}

class _StoryLoadingIndicatorState extends State<StoryLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))
    ..repeat();
  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
      label: widget.label,
      liveRegion: true,
      child: AnimatedBuilder(
          animation: _animation,
          builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < 3; i++)
                  Container(
                      width: 15,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: widget.color.withValues(
                              alpha: ((_animation.value * 3).floor() % 3 == i)
                                  ? 1
                                  : .3))),
              ])));
}
