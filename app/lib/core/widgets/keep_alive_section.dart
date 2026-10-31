import 'package:flutter/material.dart';

/// Retain a small header section in a lazy list without retaining every post.
class KeepAliveSection extends StatefulWidget {
  final Widget child;
  const KeepAliveSection({super.key, required this.child});
  @override
  State<KeepAliveSection> createState() => _KeepAliveSectionState();
}

class _KeepAliveSectionState extends State<KeepAliveSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
