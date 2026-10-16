import 'package:flutter/material.dart';

/// Uses the actual brand artwork, cropped at paint time to remove its margins.
class BirdPointsIcon extends StatelessWidget {
  final double size;
  const BirdPointsIcon({super.key, this.size = 24});
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'Study Birds',
      image: true,
      child: SizedBox.square(
          dimension: size,
          child: ClipRect(
              child: OverflowBox(
            maxWidth: size * 1.7,
            maxHeight: size * 1.7,
            child: Image.asset('assets/images/logo_mark.png',
                width: size * 1.7,
                height: size * 1.7,
                excludeFromSemantics: true),
          ))));
}

class BirdPoints extends StatelessWidget {
  final String value;
  final double iconSize;
  final TextStyle? style;
  const BirdPoints(this.value, {super.key, this.iconSize = 22, this.style});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        BirdPointsIcon(size: iconSize),
        const SizedBox(width: 5),
        Text(value, textDirection: TextDirection.ltr, style: style),
      ]);
}
