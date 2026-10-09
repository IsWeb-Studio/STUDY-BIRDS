import '../../core/widgets/app_notice.dart';
import '../../core/widgets/security_fields.dart';
import 'account_security_screen.dart';
import '../auth/verify_contact_screen.dart';
import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import '../../core/widgets/feature_ui.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_session.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});
  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final user = AuthSession.instance.currentUser;
    final isVerified = user?.emailVerified == true;
    final email = user?.email ?? '';
    return AppScaffold(
        title: 'الأمان',
        body: FeatureBody(children: [
          const SecurityIntro(
              title: 'حسابك تحت سيطرتك',
              subtitle: 'راجع وسائل حماية حسابك وحافظ على خصوصية بياناتك.',
              icon: Icons.shield_outlined),
          FeaturePanel(
              title: 'البريد الإلكتروني',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(email,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.navy),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isVerified
                            ? const Color(0xFFD1FAE5)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                            isVerified ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                            size: 14,
                            color: isVerified ? const Color(0xFF065F46) : const Color(0xFF92400E)),
                        const SizedBox(width: 4),
                        Text(
                            isVerified ? 'موثّق' : 'غير موثّق',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isVerified ? const Color(0xFF065F46) : const Color(0xFF92400E))),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  if (!isVerified)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.mark_email_read_outlined, color: AppColors.navy),
                        title: const Text('توثيق البريد الإلكتروني', style: AppTextStyles.cardTitle),
                        subtitle: const Text('تحقق من البريد المرتبط بحسابك', style: AppTextStyles.caption),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const VerifyContactScreen()))
                            .then((_) => setState(() {}))),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.edit_outlined, color: AppColors.navy),
                      title: const Text('تغيير البريد الإلكتروني', style: AppTextStyles.cardTitle),
                      subtitle: const Text('غيّر البريد المرتبط بحسابك', style: AppTextStyles.caption),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const ChangeEmailScreen()))
                          .then((_) { AuthSession.instance.refreshCurrentUser(); setState(() {}); })),
                ],
              )),
          FeaturePanel(
              title: 'تسجيل الدخول',
              child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.lock_outline, color: AppColors.navy)),
                  title: const Text('تغيير كلمة المرور', style: AppTextStyles.cardTitle),
                  subtitle: const Text('استخدم كلمة مرور خاصة بهذا الحساب', style: AppTextStyles.caption),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen())))),
          FeaturePanel(
              child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.devices_outlined, color: AppColors.navy),
                  title: const Text('التحقق بخطوتين والأجهزة', style: AppTextStyles.cardTitle),
                  subtitle: const Text('راجع حماية حسابك والجلسات النشطة', style: AppTextStyles.caption),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AccountSecurityScreen())))),
        ]));
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final current = TextEditingController(),
      next = TextEditingController(),
      confirmation = TextEditingController();
  final form = GlobalKey<FormState>();
  bool saving = false;
  String? error;
  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final token = AuthSession.instance.token;
      if (token == null) throw const ApiException(401, 'يرجى تسجيل الدخول');
      await ApiClient.instance.post('/auth/change-password',
          token: token,
          body: {'currentPassword': current.text, 'newPassword': next.text});
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(AppSnackBar(content: Text('تم تغيير كلمة المرور')));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted)
        setState(() =>
            error = e is ApiException ? e.message : 'تعذر تغيير كلمة المرور');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'تغيير كلمة المرور',
        bottomBar: SafeArea(
            top: false,
            child: Container(
                color: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: PrimaryButton(
                    label: saving ? 'جاري الحفظ...' : 'حفظ كلمة المرور',
                    icon: Icons.lock_reset_rounded,
                    onPressed: saving ? null : save))),
        body: Form(
            key: form,
            child: FeatureBody(children: [
              const SecurityIntro(
                  title: 'كلمة مرور جديدة',
                  subtitle:
                      'اختر كلمة يصعب تخمينها ولا تستخدمها في حسابات أخرى.',
                  icon: Icons.key_outlined),
              if (error != null) InlineNotice(error!, error: true),
              FeaturePanel(
                  child: Column(children: [
                for (final entry in [
                  (current, 'كلمة المرور الحالية'),
                  (next, 'كلمة المرور الجديدة'),
                  (confirmation, 'تأكيد كلمة المرور')
                ])
                  Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: SecureTextField(
                        controller: entry.$1,
                        requireStrong: entry.$1 == next,
                        obscureText: true,
                        enabled: !saving,
                        enableSuggestions: false,
                        autocorrect: false,
                        textDirection: TextDirection.ltr,
                        autofillHints: [
                          entry.$1 == current
                              ? AutofillHints.password
                              : AutofillHints.newPassword
                        ],
                        decoration: featureInput(entry.$2,
                            ),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'هذا الحقل مطلوب';
                          if (entry.$1 == confirmation && value != next.text)
                            return 'كلمتا المرور غير متطابقتين';
                          return null;
                        },
                      )),
                const Row(children: [
                  Icon(Icons.check_circle_outline,
                      size: 16, color: AppColors.textSecondary),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          'اختر كلمة قوية من 8 أحرف و3 أنواع على الأقل.',
                          style: AppTextStyles.caption))
                ]),
              ])),
            ])),
      );
}

class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});
  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final newEmailCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  bool busy = false;
  String? error;
  bool codeSent = false;
  String sentTo = '';

  @override
  void dispose() {
    newEmailCtrl.dispose();
    codeCtrl.dispose();
    super.dispose();
  }

  Future<void> requestCode() async {
    final email = newEmailCtrl.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => error = 'أدخل بريدًا إلكترونيًا صحيحًا');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final token = AuthSession.instance.token;
      if (token == null) throw const ApiException(401, 'يرجى تسجيل الدخول');
      await ApiClient.instance.post('/mobile-security/email/change/request',
          token: token, body: {'email': email});
      setState(() { codeSent = true; sentTo = email; });
    } catch (e) {
      setState(() => error = e is ApiException ? e.message : 'تعذر إرسال الرمز');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> confirmCode() async {
    final code = codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => error = 'أدخل الرمز المكون من 6 أرقام');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final token = AuthSession.instance.token;
      if (token == null) throw const ApiException(401, 'يرجى تسجيل الدخول');
      await ApiClient.instance.post('/mobile-security/email/change/confirm',
          token: token, body: {'code': code});
      await AuthSession.instance.refreshCurrentUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
          content: Text('تم تغيير البريد الإلكتروني بنجاح ✓'),
          backgroundColor: Color(0xFF065F46)));
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => error = e is ApiException ? e.message : 'رمز غير صحيح أو منتهي الصلاحية');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'تغيير البريد الإلكتروني',
        bottomBar: SafeArea(
            top: false,
            child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: PrimaryButton(
                    label: busy
                        ? (codeSent ? 'جارٍ التحقق...' : 'جارٍ الإرسال...')
                        : (codeSent ? 'تأكيد' : 'إرسال رمز التحقق'),
                    icon: codeSent ? Icons.check_rounded : Icons.send_rounded,
                    onPressed: busy ? null : (codeSent ? confirmCode : requestCode)))),
        body: FeatureBody(children: [
          SecurityIntro(
              title: codeSent ? 'أدخل رمز التحقق' : 'البريد الجديد',
              subtitle: codeSent
                  ? 'أرسلنا رمزًا مؤقتًا إلى $sentTo. صالح 10 دقائق.'
                  : 'سنرسل رمز تحقق إلى البريد الجديد للتأكد من ملكيتك له.',
              icon: Icons.mark_email_read_outlined),
          if (error != null) InlineNotice(error!, error: true),
          FeaturePanel(
              child: !codeSent
                  ? TextFormField(
                      controller: newEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      enabled: !busy,
                      decoration: featureInput('البريد الإلكتروني الجديد'),
                      autofillHints: const [AutofillHints.email],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VerificationCodeField(controller: codeCtrl, enabled: !busy),
                        TextButton(
                            onPressed: busy ? null : () => setState(() { codeSent = false; codeCtrl.clear(); error = null; }),
                            child: const Text('تغيير البريد المدخل')),
                      ],
                    )),
        ]),
      );
}
