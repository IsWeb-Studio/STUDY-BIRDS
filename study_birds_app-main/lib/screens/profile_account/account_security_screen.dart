import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_session.dart';
import '../../core/app_theme.dart';
import '../../core/feature_ui.dart';
import '../auth/email_challenge_screen.dart';

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});
  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}
class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  bool loading = true, enabled = false, busy = false;
  String? error;
  List<dynamic> sessions = [];
  String? get token => AuthSession.instance.token;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final values = await Future.wait([ApiClient.instance.get('/mobile-security/two-factor', token: token), ApiClient.instance.get('/mobile-security/sessions', token: token)]);
      if (mounted) setState(() { enabled = values[0]['enabled'] == true; sessions = values[1] as List; });
    } catch (e) { if (mounted) setState(() => error = e is ApiException && e.statusCode == 404 ? 'خدمات الأمان الإضافية لم تُفعّل على السيرفر بعد.' : 'تعذر تحميل إعدادات الأمان.'); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> change(bool value) async {
    setState(() => busy = true);
    try {
      await ApiClient.instance.post('/mobile-security/two-factor/request', token: token, body: {});
      if (!mounted) return;
      final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => EmailChallengeScreen(confirm: (code) async {
        await ApiClient.instance.post('/mobile-security/two-factor/confirm', token: token, body: {'code':code,'enabled':value});
      })));
      if (ok == true && mounted) setState(() => enabled = value);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'تعذر إرسال رمز التحقق'))); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> revoke(Map row) async {
    if (!await showAppConfirmDialog(context, title: 'إنهاء الجلسة', message: row['current'] == true ? 'سيتم تسجيل خروجك من هذا الجهاز. متابعة؟' : 'سيحتاج هذا الجهاز إلى تسجيل الدخول مجددًا.', confirmLabel: 'إنهاء الجلسة', danger: true) || !mounted) return;
    setState(() => busy = true);
    try {
      await ApiClient.instance.delete('/mobile-security/sessions/${row['_id']}', token: token);
      if (row['current'] == true) {
        await AuthSession.instance.logout();
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      } else { await load(); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر إنهاء الجلسة'))); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> revokeAll() async {
    if (!await showAppConfirmDialog(context, title: 'تسجيل الخروج من كل الأجهزة', message: 'سيتم إنهاء جميع الجلسات النشطة بما فيها هذا الجهاز. ستحتاج لتسجيل الدخول مجددًا.', confirmLabel: 'تسجيل الخروج من الكل', danger: true) || !mounted) return;
    setState(() => busy = true);
    try {
      await ApiClient.instance.post('/mobile-security/sessions/revoke-all', token: token, body: {});
      await AuthSession.instance.logout();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'تعذر إنهاء الجلسات')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(title: 'حماية الحساب والأجهزة', actions: [IconButton(onPressed: busy ? null : load, tooltip: 'تحديث', icon: const Icon(Icons.refresh))], body: RefreshIndicator(onRefresh: load, color: AppColors.navy, child: loading ? const LoadingState() : error != null ? ErrorState(message: error!, onRetry: load) : FeatureBody(children: [
    const FeatureIntro(title: 'طبقة حماية إضافية', subtitle: 'تحكم في التحقق بخطوتين والأجهزة التي تستخدم حسابك.', icon: Icons.verified_user_outlined),
    FeaturePanel(child: SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('التحقق بخطوتين', style: AppTextStyles.cardTitle), subtitle: const Text('رمز بالبريد بعد كلمة المرور'), value: enabled, onChanged: busy ? null : change)),
    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('الجلسات النشطة', style: AppTextStyles.cardTitle)),
    if (sessions.isEmpty) const InlineNotice('لا توجد جلسات مسجلة.'),
    for (final row in sessions) FeaturePanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.devices_outlined, color: AppColors.navy), const SizedBox(width: 12), Expanded(child: Text(row['current'] == true ? 'هذا الجهاز' : row['device']?.toString() ?? 'جهاز آخر', style: AppTextStyles.cardTitle))]),
      const SizedBox(height: 8), Text('آخر نشاط: ${DateTime.tryParse(row['lastSeen']?.toString() ?? '')?.toLocal().toString().split('.').first ?? 'غير محدد'}', style: AppTextStyles.caption),
      TextButton(onPressed: busy ? null : () => revoke(row as Map), child: const Text('إنهاء الجلسة', style: TextStyle(color: AppColors.danger))),
    ])),
    if (sessions.length > 1) ...[
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 18),
        label: const Text('تسجيل الخروج من جميع الأجهزة', style: TextStyle(color: AppColors.danger)),
        style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44), side: const BorderSide(color: AppColors.danger), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button))),
        onPressed: busy ? null : revokeAll,
      ),
    ],
  ])));
}
