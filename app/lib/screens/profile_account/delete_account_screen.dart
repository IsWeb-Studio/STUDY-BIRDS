import '../../core/services/error_reporter.dart';
import '../../core/widgets/security_fields.dart';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_session.dart';
import '../../core/config/app_theme.dart';
import '../../core/widgets/feature_ui.dart';

/// Permanent account deletion — requires the user to re-enter their password
/// so a stolen unlocked phone cannot silently wipe an account.
///
/// Endpoint: DELETE /auth/account  { "password": "..." }
/// On 200: clears the local session and pops to the root route.
/// On 401: shows "كلمة المرور غير صحيحة" without logging out.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  bool _sendingCode = false;
  bool get _hasPassword =>
      AuthSession.instance.currentUser?.hasPassword ?? true;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _sendingCode) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final confirmed = await _showFinalConfirm();
    if (!confirmed || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ApiClient.instance.deleteWithBody(
        '/auth/account',
        body: {_hasPassword ? 'password' : 'emailCode': _passwordCtrl.text},
        token: AuthSession.instance.token,
      );
      await AuthSession.instance.logout();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.statusCode == 401
            ? (_hasPassword ? 'كلمة المرور غير صحيحة. تحقق منها وحاول مجدداً.' : 'تعذر تأكيد هويتك. حاول مجدداً.')
            : e.message;
      });
    } catch (swallowedError, swallowedStack) {
      ErrorReporter.swallowed(swallowedError, swallowedStack,
          'screens/profile_account/delete_account_screen.dart:57');
      if (!mounted) return;
      setState(() =>
          _error = 'تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مجدداً.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    if (_sendingCode || _busy) return;
    setState(() => _sendingCode = true);
    try {
      await ApiClient.instance.post('/auth/account/verification',
          token: AuthSession.instance.token);
      if (mounted)
        setState(() => _error = 'تم إرسال رمز التأكيد إلى بريد حسابك.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر إرسال الرمز. حاول مجدداً.');
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<bool> _showFinalConfirm() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('تأكيد نهائي'),
              content: const Text(
                'سيتم حذف حسابك وبياناتك الشخصية. تُحتفظ سجلات المعاملات المالية اللازمة للمحاسبة دون ملفك الشخصي. لا يمكن التراجع عن الحذف.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.danger),
                  child: const Text('نعم، احذف حسابي'),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'حذف الحساب',
      body: FeatureBody(
        children: [
          FeatureIntro(
            title: 'حذف الحساب نهائياً',
            subtitle:
                'سيتم حذف الحساب والبيانات الشخصية والمستندات والطلبات المرتبطة به. تبقى سجلات المعاملات المالية اللازمة للمحاسبة، وتُعاد محاولة إزالة الملفات تلقائياً عند تعطل التخزين.',
            icon: Icons.delete_forever_rounded,
          ),
          const FeaturePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DangerPoint('لن تتمكن من استعادة حسابك بعد الحذف.'),
                _DangerPoint('ستُحذف جميع طلباتك ومستنداتك ورسائلك.'),
                _DangerPoint(
                    'سيتم إلغاء ربط أولياء الأمور وأي مستخدمين مرتبطين.'),
              ],
            ),
          ),
          FeaturePanel(
            title: 'تأكيد هويتك',
            subtitle: _hasPassword
                ? 'أدخل كلمة مرورك الحالية للمتابعة.'
                : 'أكد هويتك برمز يُرسل إلى بريد حسابك.',
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_hasPassword)
                    TextButton(
                      onPressed: _sendingCode || _busy ? null : _sendCode,
                      child: Text(_sendingCode
                          ? 'جارٍ إرسال الرمز...'
                          : 'إرسال رمز التأكيد'),
                    ),
                  SecureTextField(
                    controller: _passwordCtrl,
                    obscureText: _hasPassword,
                    decoration: InputDecoration(
                      labelText: _hasPassword ? 'كلمة المرور' : 'رمز التأكيد',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'أدخل بيانات التأكيد' : null,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _busy ? null : _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    InlineNotice(_error!, error: true),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _submit,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.delete_forever_rounded,
                            color: Colors.white, size: 18),
                    label: const Text('حذف الحساب نهائياً'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.button)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DangerPoint extends StatelessWidget {
  final String text;
  const _DangerPoint(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 3),
              child: Icon(Icons.warning_amber_rounded,
                  color: AppColors.danger, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Text(text,
                    style: const TextStyle(
                        color: AppColors.danger, fontSize: 13))),
          ],
        ),
      );
}
