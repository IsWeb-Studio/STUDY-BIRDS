import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../utils/app_error.dart';

/// Shared floating notice for successes and recoverable errors.
class AppSnackBar extends SnackBar {
  AppSnackBar({
    super.key,
    required Widget content,
    super.action,
    super.duration,
    super.onVisible,
    super.dismissDirection,
    super.margin,
    super.padding,
    super.width,
    super.elevation,
    Color? backgroundColor = Colors.white,
    super.behavior = SnackBarBehavior.floating,
    super.shape = const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18))),
    super.showCloseIcon = true,
    Color? closeIconColor,
  }) : super(
            backgroundColor: backgroundColor,
            closeIconColor: closeIconColor ??
                ((backgroundColor?.computeLuminance() ?? 1) < .4
                    ? Colors.white
                    : AppColors.navy),
            content: _NoticeContent(
                child: content, backgroundColor: backgroundColor));
}

class _NoticeContent extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  const _NoticeContent({required this.child, this.backgroundColor});
  @override
  Widget build(BuildContext context) {
    final text = child is Text ? (child as Text).data : null;
    final error = text != null &&
        RegExp(r'تعذّر|تعذر|خطأ|غير صحيح|غير صالح|لا يمكن|انتهت|فشل|راجع|محاولات كثيرة|غير متاح|حجم الملف|غير مدعوم|غير مسموح|exception|error|failed|socket|mongodb|\b[45]\d\d\b',
                caseSensitive: false)
            .hasMatch(text);
    final dark = (backgroundColor?.computeLuminance() ?? 1) < .4;
    final foreground = dark ? Colors.white : AppColors.navy;
    final color =
        error ? (dark ? AppColors.orange : AppColors.danger) : foreground;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(
                error
                    ? Icons.info_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: color,
                size: 22)),
        const SizedBox(width: 12),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: DefaultTextStyle(
                    style:
                        TextStyle(fontFamily: 'Tajawal', color: foreground, fontSize: 14, height: 1.6),
                    child: text == null
                        ? child
                        : Text(error ? AppError.safeText(text) : text)))),
      ]),
    );
  }
}
