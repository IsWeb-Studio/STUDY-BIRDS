import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class FeatureIntro extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  const FeatureIntro(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 24, top: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppIconTile(icon),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: AppTextStyles.screenTitle.copyWith(fontSize: 22)),
                const SizedBox(height: 6),
                Text(subtitle,
                    style: AppTextStyles.caption
                        .copyWith(height: 1.7, fontSize: 13)),
              ])),
        ]),
      );
}

class FeaturePanel extends StatelessWidget {
  final String? title, subtitle;
  final Widget child;
  const FeaturePanel(
      {super.key, this.title, this.subtitle, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null)
            Text(title!,
                style: AppTextStyles.cardTitle.copyWith(color: AppColors.navy)),
          if (subtitle != null)
            Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(subtitle!, style: AppTextStyles.caption)),
          if (title != null || subtitle != null) const SizedBox(height: 20),
          Material(color: Colors.transparent, child: child),
        ]),
      );
}

class FeatureBody extends StatelessWidget {
  final List<Widget> children;
  const FeatureBody({super.key, required this.children});
  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: children),
      ));
}

class InlineNotice extends StatelessWidget {
  final String text;
  final bool error;
  const InlineNotice(this.text, {super.key, this.error = false});
  @override
  Widget build(BuildContext context) {
    final color = error ? AppColors.danger : AppColors.info;
    return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(error ? Icons.error_outline : Icons.info_outline,
              color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: error ? AppColors.danger : AppColors.navy,
                      height: 1.6,
                      fontSize: 13))),
        ]));
  }
}

InputDecoration featureInput(String label,
        {String? hint, Widget? suffix, IconData? icon}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: const Color(0xFFF9FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      suffixIcon: suffix,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.navy, width: 1.5)),
    );

const arabicMonths = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر'
];
String readableDate(DateTime date) =>
    '${date.day} ${arabicMonths[date.month - 1]} ${date.year}';
