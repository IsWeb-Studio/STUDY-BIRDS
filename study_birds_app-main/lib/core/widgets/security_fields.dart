import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
import '../utils/password_policy.dart';

import 'password_strength_inline.dart';

InputDecoration securityDecoration(InputDecoration input) => input.copyWith(
      filled: true,
      fillColor: const Color(0xFFF3F6FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.navy, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.danger)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.danger, width: 2)),
    );

class SecureTextField extends StatefulWidget {
  final TextEditingController? controller;
  final bool obscureText, enabled, autocorrect, enableSuggestions;
  final bool showStrength, requireStrong;
  final bool compactStrength;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextDirection? textDirection;
  final TextAlign textAlign;
  final Iterable<String>? autofillHints;
  final InputDecoration decoration;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final AutovalidateMode? autovalidateMode;
  const SecureTextField(
      {super.key,
      this.controller,
      this.obscureText = true,
      this.enabled = true,
      this.autocorrect = false,
      this.enableSuggestions = false,
      this.showStrength = false,
      this.requireStrong = false,
      this.compactStrength = true,
      this.maxLines = 1,
      this.keyboardType,
      this.textInputAction,
      this.textDirection,
      this.textAlign = TextAlign.start,
      this.autofillHints,
      this.decoration = const InputDecoration(),
      this.validator,
      this.onFieldSubmitted,
      this.autovalidateMode});
  @override
  State<SecureTextField> createState() => _SecureTextFieldState();
}

class _SecureTextFieldState extends State<SecureTextField> {
  bool visible = false;
  final _fallbackController = TextEditingController();
  TextEditingController get controller =>
      widget.controller ?? _fallbackController;
  @override
  void dispose() {
    _fallbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextFormField(
          controller: controller,
          enabled: widget.enabled,
          obscureText: widget.obscureText && !visible,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textDirection:
              widget.obscureText ? TextDirection.ltr : widget.textDirection,
          textAlign: widget.textAlign,
          autocorrect: widget.autocorrect,
          enableSuggestions: widget.enableSuggestions,
          autofillHints: widget.autofillHints,
          validator: (value) =>
              (widget.requireStrong ? PasswordPolicy.validate(value) : null) ??
              widget.validator?.call(value),
          onFieldSubmitted: widget.onFieldSubmitted,
          autovalidateMode: widget.autovalidateMode,
          decoration: widget.obscureText
              ? securityDecoration(widget.decoration).copyWith(
                  prefixIcon: const Icon(Icons.lock_outline_rounded,
                      color: AppColors.navy, size: 21),
                  suffixIcon: IconButton(
                    tooltip:
                        visible ? 'إخفاء كلمة المرور' : 'إظهار كلمة المرور',
                    onPressed: widget.enabled
                        ? () => setState(() => visible = !visible)
                        : null,
                    icon: Icon(
                        visible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.navy),
                  ),
                )
              : widget.decoration,
        ),
        if (widget.showStrength || widget.requireStrong)
          ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, child) =>
                  PasswordStrengthInline(password: value.text)),
      ]);
}

class VerificationCodeField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String? Function(String?)? validator;
  const VerificationCodeField(
      {super.key,
      required this.controller,
      this.enabled = true,
      this.validator});
  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        enabled: enabled,
        validator: validator,
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [
          _CodeFormatter(),
          LengthLimitingTextInputFormatter(6)
        ],
        style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 10,
            color: AppColors.navy),
        decoration: securityDecoration(const InputDecoration(
          labelText: 'رمز التحقق',
          hintText: '------',
          floatingLabelBehavior: FloatingLabelBehavior.always,
          helperText: 'أدخل الرمز المكوّن من 6 أرقام',
          helperMaxLines: 2,
        )),
      );
}

class _CodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String normalize(String text) => text.runes
        .map((r) => r >= 0x660 && r <= 0x669
            ? String.fromCharCode(r - 0x660 + 48)
            : r >= 0x6f0 && r <= 0x6f9
                ? String.fromCharCode(r - 0x6f0 + 48)
                : String.fromCharCode(r))
        .join()
        .replaceAll(RegExp(r'[^0-9]'), '');
    final text = normalize(newValue.text);
    final before = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(
            offset: normalize(newValue.text.substring(0, before)).length));
  }
}

class SecurityIntro extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  const SecurityIntro(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
                colors: [AppColors.navy, Color(0xFF174D80)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: const Color(0xFFFFAD42), size: 30)),
          const SizedBox(height: 20),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(subtitle,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: .85),
                  fontSize: 14,
                  height: 1.7)),
        ]),
      );
}
