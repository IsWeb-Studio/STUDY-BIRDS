import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/api_client.dart';
import '../../core/config/app_theme.dart';
import '../../core/widgets/feature_ui.dart';

class AccountRecoveryScreen extends StatefulWidget {
  const AccountRecoveryScreen({super.key});
  @override
  State<AccountRecoveryScreen> createState() => _AccountRecoveryScreenState();
}

class _AccountRecoveryScreenState extends State<AccountRecoveryScreen> {
  late Future<dynamic> settings =
      ApiClient.instance.get('/content/site-settings');
  Future<void> open(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication))
        throw Exception();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر فتح وسيلة التواصل')));
    }
  }

  final emailController = TextEditingController();
  final codeController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmationController = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false, sent = false, complete = false, unavailable = false;
  String? error;
  String requestedEmail = '';
  @override
  void dispose() {
    emailController.dispose();
    codeController.dispose();
    passwordController.dispose();
    confirmationController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ApiClient.instance
          .post('/mobile-security/reset/${sent ? 'confirm' : 'request'}',
              body: sent
                  ? {
                      'email': requestedEmail,
                      'code': codeController.text.trim(),
                      'password': passwordController.text
                    }
                  : {'email': emailController.text.trim().toLowerCase()});
      if (!mounted) return;
      setState(() {
        if (sent) {
          complete = true;
          passwordController.clear();
          confirmationController.clear();
        } else {
          requestedEmail = emailController.text.trim().toLowerCase();
          sent = true;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        unavailable = e.statusCode == 404 || e.statusCode == 405;
        error = unavailable
            ? 'الاستعادة بالرمز غير متاحة حاليًا. تواصل مع الدعم بالوسائل أدناه.'
            : e.message;
      });
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر الاتصال. حاول مجددًا.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget contacts() => FutureBuilder<dynamic>(
      future: settings,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const LinearProgressIndicator();
        if (snapshot.hasError)
          return TextButton.icon(
              onPressed: () => setState(() =>
                  settings = ApiClient.instance.get('/content/site-settings')),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة تحميل وسائل الدعم'));
        final data = snapshot.data is Map ? snapshot.data as Map : {};
        final email = data['contactEmail']?.toString().trim() ?? '';
        final whatsapp = Uri.tryParse(data['whatsappUrl']?.toString() ?? '');
        final validWhatsapp = whatsapp != null &&
            whatsapp.scheme == 'https' &&
            whatsapp.host.isNotEmpty;
        return Column(children: [
          if (email.isNotEmpty)
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mail_outline),
                title: const Text('مراسلة الدعم'),
                subtitle: Text(email),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => open(Uri(
                    scheme: 'mailto',
                    path: email,
                    queryParameters: {'subject': 'استعادة حساب Study Birds'}))),
          if (validWhatsapp)
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('التواصل عبر واتساب'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => open(whatsapp)),
          if (email.isEmpty && !validWhatsapp)
            const Text('لا توجد وسائل تواصل منشورة حاليًا.',
                style: AppTextStyles.caption),
        ]);
      });
  @override
  Widget build(BuildContext context) => AppScaffold(
      title: 'استعادة الحساب',
      body: Form(
          key: form,
          child: FeatureBody(children: [
            FeatureIntro(
                title: complete
                    ? 'تم تحديث كلمة المرور'
                    : sent
                        ? 'تحقق من بريدك'
                        : 'لنستعد حسابك',
                subtitle: complete
                    ? 'يمكنك الآن تسجيل الدخول باستخدام كلمة المرور الجديدة.'
                    : sent
                        ? 'إذا كان البريد مسجلًا، سيصلك رمز الاستعادة. أدخله وحدد كلمة مرور جديدة.'
                        : 'أدخل البريد المرتبط بحسابك لطلب رمز استعادة.',
                icon: complete
                    ? Icons.check_circle_outline
                    : Icons.lock_open_rounded),
            if (error != null) InlineNotice(error!, error: !unavailable),
            if (complete)
              PrimaryButton(
                  label: 'العودة لتسجيل الدخول',
                  onPressed: () => Navigator.of(context).pop())
            else if (!unavailable)
              FeaturePanel(
                  child: Column(children: [
                if (!sent)
                  TextFormField(
                      controller: emailController,
                      enabled: !busy,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      autofillHints: const [AutofillHints.email],
                      decoration: featureInput('البريد الإلكتروني',
                          hint: 'name@example.com',
                          icon: Icons.alternate_email),
                      validator: (v) => v == null ||
                              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(v.trim())
                          ? 'أدخل بريدًا إلكترونيًا صحيحًا'
                          : null)
                else ...[
                  Text(requestedEmail,
                      textDirection: TextDirection.ltr,
                      style: AppTextStyles.cardTitle),
                  const SizedBox(height: 20),
                  TextFormField(
                      controller: codeController,
                      enabled: !busy,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      decoration: featureInput('رمز التحقق', hint: '000000'),
                      validator: (v) =>
                          v == null || !RegExp(r'^\d{6}$').hasMatch(v.trim())
                              ? 'أدخل الرمز المكون من 6 أرقام'
                              : null),
                  const SizedBox(height: 20),
                  TextFormField(
                      controller: passwordController,
                      enabled: !busy,
                      obscureText: true,
                      decoration: featureInput('كلمة المرور الجديدة'),
                      validator: (v) => v == null || v.length < 8
                          ? 'استخدم 8 أحرف على الأقل'
                          : null),
                  const SizedBox(height: 20),
                  TextFormField(
                      controller: confirmationController,
                      enabled: !busy,
                      obscureText: true,
                      decoration: featureInput('تأكيد كلمة المرور'),
                      validator: (v) => v != passwordController.text
                          ? 'كلمتا المرور غير متطابقتين'
                          : null),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                    label: busy
                        ? 'جاري المعالجة...'
                        : sent
                            ? 'تعيين كلمة المرور'
                            : 'إرسال رمز الاستعادة',
                    onPressed: busy ? null : submit),
                if (sent)
                  TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                                sent = false;
                                codeController.clear();
                                passwordController.clear();
                                confirmationController.clear();
                                error = null;
                              }),
                      child: const Text('تغيير البريد أو طلب رمز جديد')),
              ])),
            if (!complete)
              FeaturePanel(
                  title: 'تحتاج إلى مساعدة؟',
                  subtitle: 'فريق الدعم متاح لمساعدتك في استعادة الوصول.',
                  child: contacts()),
          ])));
}
