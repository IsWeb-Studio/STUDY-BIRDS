import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import '../../core/widgets/feature_ui.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_session.dart';

class VerifyContactScreen extends StatefulWidget {
  final bool isEmail;
  final String contact;
  final VoidCallback? onVerify;
  const VerifyContactScreen(
      {super.key, this.isEmail = true, this.contact = '', this.onVerify});
  @override
  State<VerifyContactScreen> createState() => _VerifyContactScreenState();
}

class _VerifyContactScreenState extends State<VerifyContactScreen> {
  final code = TextEditingController();
  bool sent = false, busy = false, verified = false;
  String? error;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> submit({bool resend = false}) async {
    final confirm = sent && !resend;
    if (confirm && !RegExp(r'^\d{6}$').hasMatch(code.text.trim())) {
      setState(() => error = 'أدخل الرمز المكون من 6 أرقام');
      return;
    }
    final token = AuthSession.instance.token;
    if (token == null) {
      setState(() => error = 'سجّل الدخول أولًا');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ApiClient.instance.post(
          '/mobile-security/email/${confirm ? 'confirm' : 'request'}',
          token: token,
          body: confirm ? {'code': code.text.trim()} : {});
      if (!mounted) return;
      setState(() {
        sent = true;
        verified = confirm;
      });
      if (confirm) {
        AuthSession.instance.patchEmailVerified();
        widget.onVerify?.call();
      }
    } on ApiException catch (e) {
      if (mounted)
        setState(() => error = e.statusCode == 404
            ? 'تأكيد البريد غير متاح حاليًا. يرجى المحاولة لاحقًا.'
            : e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر الاتصال. حاول مجددًا.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
          title: 'تأكيد التواصل',
          body: FeatureBody(children: [
            FeatureIntro(
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
                    TextField(
                        controller: code,
                        enabled: !busy,
                        textDirection: TextDirection.ltr,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        decoration: featureInput('رمز التحقق', hint: '000000')),
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
          ]));
}
