import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_session.dart';
import '../../core/app_theme.dart';
import '../../core/feature_ui.dart';

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
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
        body: {'password': _passwordCtrl.text},
        token: AuthSession.instance.token,
      );
      await AuthSession.instance.logout();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      setState(() {
        _error = e.statusCode == 401
            ? 'كلمة المرور غير صحيحة. تحقق منها وحاول مجدداً.'
            : e.message;
      });
    } catch (_) {
      setState(() => _error = 'تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مجدداً.');
    } finally {
      if (mounted) setState(() => _busy = false);
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
                'سيتم حذف حسابك وجميع بياناتك بشكل نهائي ولا يمكن التراجع عن هذه العملية.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
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
                'هذا الإجراء دائم ولا يمكن التراجع عنه. سيتم حذف حسابك وجميع بياناتك الشخصية والمستندات والطلبات المرتبطة به.',
            icon: Icons.delete_forever_rounded,
          ),
          const FeaturePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DangerPoint('لن تتمكن من استعادة حسابك بعد الحذف.'),
                _DangerPoint('ستُحذف جميع طلباتك ومستنداتك ورسائلك.'),
                _DangerPoint('سيتم إلغاء ربط أولياء الأمور وأي مستخدمين مرتبطين.'),
              ],
            ),
          ),
          FeaturePanel(
            title: 'تأكيد هويتك',
            subtitle: 'أدخل كلمة مرورك الحالية للمتابعة.',
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'كلمة المرور مطلوبة' : null,
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
