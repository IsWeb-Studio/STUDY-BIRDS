import 'account_security_screen.dart';
import '../auth/verify_contact_screen.dart';
import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import '../../core/widgets/feature_ui.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_session.dart';

class SecuritySettingsScreen extends StatelessWidget {
  const SecuritySettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => AppScaffold(
      title: 'الأمان',
      body: FeatureBody(children: [
        const FeatureIntro(
            title: 'حسابك تحت سيطرتك',
            subtitle: 'راجع وسائل حماية حسابك وحافظ على خصوصية بياناتك.',
            icon: Icons.shield_outlined),
        FeaturePanel(
            title: 'تسجيل الدخول',
            child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12)),
                    child:
                        const Icon(Icons.lock_outline, color: AppColors.navy)),
                title: const Text('تغيير كلمة المرور',
                    style: AppTextStyles.cardTitle),
                subtitle: const Text('استخدم كلمة مرور خاصة بهذا الحساب',
                    style: AppTextStyles.caption),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen())))),
        FeaturePanel(
            child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mark_email_read_outlined,
                    color: AppColors.navy),
                title: const Text('تأكيد البريد الإلكتروني',
                    style: AppTextStyles.cardTitle),
                subtitle: const Text('تحقق من البريد المرتبط بحسابك',
                    style: AppTextStyles.caption),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const VerifyContactScreen())))),
        FeaturePanel(
            child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.devices_outlined, color: AppColors.navy),
                title: const Text('التحقق بخطوتين والأجهزة',
                    style: AppTextStyles.cardTitle),
                subtitle: const Text('راجع حماية حسابك والجلسات النشطة',
                    style: AppTextStyles.caption),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AccountSecurityScreen())))),
      ]));
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
  final visible = <TextEditingController>{};
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
          .showSnackBar(const SnackBar(content: Text('تم تغيير كلمة المرور')));
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
              const FeatureIntro(
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
                      child: TextFormField(
                        controller: entry.$1,
                        obscureText: !visible.contains(entry.$1),
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
                            suffix: IconButton(
                                tooltip: visible.contains(entry.$1)
                                    ? 'إخفاء كلمة المرور'
                                    : 'إظهار كلمة المرور',
                                onPressed: () => setState(() {
                                      if (!visible.add(entry.$1))
                                        visible.remove(entry.$1);
                                    }),
                                icon: Icon(
                                    visible.contains(entry.$1)
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20))),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'هذا الحقل مطلوب';
                          if (entry.$1 == next && value.length < 6)
                            return 'استخدم 6 أحرف على الأقل';
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
                          '6 أحرف على الأقل، ويفضل مزج الأحرف والأرقام.',
                          style: AppTextStyles.caption))
                ]),
              ])),
            ])),
      );
}
