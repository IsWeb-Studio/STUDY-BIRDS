import '../../core/services/error_reporter.dart';
import '../../core/widgets/security_fields.dart';
import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import '../../core/widgets/feature_ui.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_session.dart';

class VerifyContactScreen extends StatefulWidget {
  final bool isEmail;
  final String contact;
  final VoidCallback? onVerify;
  final bool mandatory, autoSend;
  const VerifyContactScreen(
      {super.key,
      this.isEmail = true,
      this.contact = '',
      this.onVerify,
      this.mandatory = false,
      this.autoSend = false});
  @override
  State<VerifyContactScreen> createState() => _VerifyContactScreenState();
}

class _VerifyContactScreenState extends State<VerifyContactScreen> {
  final code = TextEditingController();
  bool sent = false, busy = false, verified = false;
  String? error;
  @override
  void initState() {
    super.initState();
    if (widget.autoSend) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) submit();
      });
    }
  }

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> submit({bool resend = false}) async {
    if (busy) return;
    final confirm = sent && !resend;
    if (confirm && !RegExp(r'^\d{6}$').hasMatch(code.text.trim())) {
      setState(() => error = 'أدخل الرمز المكون من 6 أرقام');
      return;
    }
    final token = AuthSession.instance.token;
    final owner = AuthSession.instance.currentUser?.id;
    if (token == null) {
      setState(() => error = 'سجّل الدخول أولًا');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await ApiClient.instance.post(
          '/mobile-security/email/${confirm ? 'confirm' : 'request'}',
          token: token,
          body: confirm ? {'code': code.text.trim()} : {});
      if (!mounted ||
          AuthSession.instance.token != token ||
          AuthSession.instance.currentUser?.id != owner) {
        return;
      }
      final confirmed = result is Map && result['emailVerified'] == true;
      if (confirm && !confirmed) {
        setState(() => error = 'تعذر تأكيد توثيق البريد. حاول مجددًا.');
        return;
      }
      setState(() {
        sent = true;
        verified = confirmed;
      });
      if (confirmed) {
        AuthSession.instance.patchEmailVerified();
        widget.onVerify?.call();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => error = e.statusCode == 404
            ? 'تأكيد البريد غير متاح حاليًا. يرجى المحاولة لاحقًا.'
            : e.message);
      }
    } catch (swallowedError, swallowedStack) {
      ErrorReporter.swallowed(swallowedError, swallowedStack,
          'screens/auth/verify_contact_screen.dart:62');
      if (mounted) setState(() => error = 'تعذر الاتصال. حاول مجددًا.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !widget.mandatory,
      child: AppScaffold(
          showBackButton: !widget.mandatory,
          title: 'تأكيد التواصل',
          body: FeatureBody(children: [
            SecurityIntro(
                title: verified ? 'تم تأكيد بريدك' : 'بريد موثوق لحسابك',
                subtitle: verified
                    ? 'تم التحقق بنجاح من البريد المرتبط بحسابك.'
                    : 'يساعد تأكيد البريد في حماية حسابك والوصول إلى رسائلك المهمة.',
                icon: verified
                    ? Icons.mark_email_read_outlined
                    : Icons.mail_outline),
            ...[
              if (error != null) InlineNotice(error!, error: true),
              if (!verified)
                FeaturePanel(
                    child: Column(children: [
                  Text(
                      widget.contact.isNotEmpty
                          ? widget.contact
                          : AuthSession.instance.currentUser?.email ?? '',
                      textDirection: TextDirection.ltr,
                      style: AppTextStyles.cardTitle),
                  const SizedBox(height: 20),
                  if (sent) ...[
                    const Text('أدخل الرمز الذي وصلك في البريد.',
                        style: AppTextStyles.caption),
                    const SizedBox(height: 16),
                    VerificationCodeField(controller: code, enabled: !busy),
                    const SizedBox(height: 24),
                  ],
                  PrimaryButton(
                      label: busy
                          ? 'جاري المعالجة...'
                          : sent
                              ? 'تأكيد البريد'
                              : 'إرسال رمز التحقق',
                      onPressed: busy ? null : submit),
                  if (sent)
                    TextButton(
                        onPressed: busy ? null : () => submit(resend: true),
                        child: const Text('إعادة إرسال الرمز')),
                ])),
            ],
            if (widget.mandatory)
              TextButton(
                  onPressed: busy ? null : () => AuthSession.instance.logout(),
                  child: const Text('تسجيل الخروج')),
          ])));
}
