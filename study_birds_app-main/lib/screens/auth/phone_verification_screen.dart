import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/feature_ui.dart';
import '../../core/api_client.dart';
import '../../core/auth_session.dart';

class PhoneVerificationScreen extends StatefulWidget {
  final void Function(String verifiedPhone)? onVerified;
  final List<Widget>? actions;
  const PhoneVerificationScreen({super.key, this.onVerified, this.actions});
  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final phone = TextEditingController(), code = TextEditingController();
  bool sent = false, busy = false, verified = false;
  String? error;
  @override
  void dispose() {
    phone.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!sent && !RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone.text.trim())) {
      setState(() => error = 'أدخل رقمًا دوليًا يبدأ بـ + ورمز الدولة');
      return;
    }
    if (sent && !RegExp(r'^\d{4,10}$').hasMatch(code.text.trim())) {
      setState(() => error = 'أدخل رمز واتساب الصحيح');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ApiClient.instance.post(
          '/identity/phone/${sent ? 'confirm' : 'request'}',
          token: AuthSession.instance.token,
          body:
              sent ? {'code': code.text.trim()} : {'phone': phone.text.trim()});
      if (mounted) {
        setState(() {
          verified = sent;
          sent = true;
        });
        if (verified) widget.onVerified?.call(phone.text.trim());
      }
    } catch (e) {
      if (mounted)
        setState(() => error =
            e is ApiException ? e.message : 'تعذر الاتصال، حاول مجددًا');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
      title: 'تأكيد الهاتف',
      actions: widget.actions,
      body: FeatureBody(children: [
        const FeatureIntro(
            title: 'رقم هاتف موثوق',
            subtitle: 'سيصلك رمز عبر واتساب للتحقق من ملكيتك للرقم.',
            icon: Icons.phone_android),
        if (error != null) InlineNotice(error!, error: true),
        if (verified)
          const InlineNotice('تم تأكيد رقم الهاتف بنجاح')
        else
          FeaturePanel(
              child: Column(children: [
            TextField(
                controller: phone,
                readOnly: sent,
                enabled: !busy,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.phone,
                decoration: featureInput('رقم الهاتف الدولي', hint: '+905...')),
            if (sent) ...[
              const SizedBox(height: 16),
              TextField(
                  controller: code,
                  enabled: !busy,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  decoration: featureInput('رمز واتساب'))
            ],
            const SizedBox(height: 20),
            PrimaryButton(
                label: busy
                    ? 'جارٍ التحقق…'
                    : sent
                        ? 'تأكيد الرقم'
                        : 'إرسال الرمز',
                onPressed: busy ? null : submit),
            if (sent)
              TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                            sent = false;
                            code.clear();
                          }),
                  child: const Text('تغيير الرقم أو إعادة الإرسال')),
          ])),
      ]));
}
