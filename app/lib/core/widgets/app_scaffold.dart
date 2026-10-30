import '../../l10n/l10n.dart';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../utils/responsive.dart';

/// Standard scaffold wrapper: navy app bar, RTL, background color.
class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomBar;
  final bool showBackButton;
  final TextDirection? textDirection;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottomBar,
    this.showBackButton = true,
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
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: showBackButton,
          iconTheme: const IconThemeData(color: AppColors.navy),
          title: Text(
            title,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          actions: actions,
        ),
        body: SafeArea(
          child: MaxWidthBody(child: body),
        ),
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomBar,
      ),
    );
  }
}

