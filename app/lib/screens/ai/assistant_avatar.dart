import 'package:flutter/material.dart';

class AssistantAvatar extends StatelessWidget {
  final double size;
  const AssistantAvatar({super.key, this.size = 32});
  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/images/assistant/robot.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round());
}
