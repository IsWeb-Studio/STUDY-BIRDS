import 'browser_sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/config/app_theme.dart';
import '../../core/services/google_sign_in_service.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_session.dart';

class _AppTextField extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
  final String? Function(String?)? validator;

  const _AppTextField({
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.controller,
    this.validator,
  });

  static final _borderRadius = BorderRadius.circular(AppRadius.button);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          textAlign: TextAlign.right,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            prefixIcon: Icon(icon, color: AppColors.navy, size: 20),
            border: OutlineInputBorder(
                borderRadius: _borderRadius,
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: _borderRadius,
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: _borderRadius,
                borderSide:
                    const BorderSide(color: AppColors.navy, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: _borderRadius,
                borderSide: const BorderSide(color: AppColors.danger)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: _borderRadius,
                borderSide:
                    const BorderSide(color: AppColors.danger, width: 1.5)),
          ),
        ),
      ],
    );
  }
}

class LoginScreen extends StatefulWidget {
  /// Called with the entered email/password. Return true if login should
  /// proceed (the caller does the actual auth + role check); the screen
  /// shows its own error message on failure via [errorText].
  final Future<bool> Function(String email, String password)? onLoginAttempt;
  final VoidCallback? onGoRegister;
  final VoidCallback? onForgotPassword;
  final String? prefillHint;
  /// Called after a successful Google Sign-In to navigate to the home screen.
  final VoidCallback? onGoogleSignInSuccess;

  const LoginScreen(
      {super.key,
      this.onLoginAttempt,
      this.onGoRegister,
      this.onForgotPassword,
      this.prefillHint,
      this.onGoogleSignInSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _googleSignIn() async {
    setState(() { _googleLoading = true; _error = null; });
    try {
      await GoogleSignInService.instance.init();
      if (!mounted) return;
      if (!GoogleSignInService.instance.isAvailable) {
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BrowserSignInScreen()));
        return;
      }
      final ok = await GoogleSignInService.instance.signIn();
      if (!mounted) return;
      if (ok) {
        await _maybeSetPassword();
        if (mounted) widget.onGoogleSignInSuccess?.call();
      } else {
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BrowserSignInScreen()));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'حدث خطأ أثناء تسجيل الدخول عبر Google');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _maybeSetPassword() async {
    final user = AuthSession.instance.currentUser;
    if (user == null || user.hasPassword) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _SetPasswordSheet(),
    );
  }

  Future<void> _submit() async {
    if (widget.onLoginAttempt == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await widget.onLoginAttempt!(
        _emailController.text.trim(), _passwordController.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!ok) _error = 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text('أهلاً بعودتك 👋', style: AppTextStyles.screenTitle),
                const SizedBox(height: 6),
                const Text('سجّل دخولك لمتابعة رحلتك الدراسية',
                    style: AppTextStyles.caption),
                if (widget.prefillHint != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppColors.navy.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8)),
                    child:
                        Text(widget.prefillHint!, style: AppTextStyles.caption),
                  ),
                ],
                const SizedBox(height: 28),
                _AppTextField(
                  label: 'البريد الإلكتروني',
                  icon: Icons.person_outline_rounded,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'أدخل بريدك الإلكتروني';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) {
                      return 'صيغة البريد الإلكتروني غير صحيحة';
                    }
                    return null;
                  },
                )
                    .animate()
                    .fadeIn(delay: 80.ms, duration: 350.ms)
                    .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
                const SizedBox(height: 14),
                _AppTextField(
                  label: 'كلمة المرور',
                  icon: Icons.lock_outline_rounded,
                  obscure: true,
                  controller: _passwordController,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'أدخل كلمة المرور' : null,
                )
                    .animate()
                    .fadeIn(delay: 160.ms, duration: 350.ms)
                    .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 12.5)),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: widget.onForgotPassword,
                    child: const Text('نسيت كلمة المرور؟',
                        style: TextStyle(color: AppColors.orange)),
                  ),
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                    label: _loading ? 'جاري الدخول...' : 'تسجيل الدخول',
                    onPressed: _loading ? null : _submit),
                const SizedBox(height: 16),
                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('أو', style: AppTextStyles.caption),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: (_loading || _googleLoading) ? null : _googleSignIn,
                  icon: _googleLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.g_mobiledata_rounded, size: 24),
                  label: Text(_googleLoading ? 'جارٍ الدخول...' : 'المتابعة عبر Google'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const BrowserSignInScreen())),
                  icon: const Icon(Icons.apple_rounded, size: 20),
                  label: const Text('المتابعة عبر Apple'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: widget.onGoRegister,
                    child: RichText(
                      text: const TextSpan(
                        style: AppTextStyles.body,
                        children: [
                          TextSpan(text: 'ليس لديك حساب؟ '),
                          TextSpan(
                            text: 'إنشاء حساب جديد',
                            style: TextStyle(
                                color: AppColors.orange,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  /// Called with the entered name/email/password. Return true if
  /// registration succeeded; the screen shows its own error on failure.
  final Future<bool> Function(String name, String email, String password)?
      onRegisterAttempt;
  final VoidCallback? onGoLogin;

  const RegisterScreen({super.key, this.onRegisterAttempt, this.onGoLogin});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _passwordText = '';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(
        () => setState(() => _passwordText = _passwordController.text));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.onRegisterAttempt == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await widget.onRegisterAttempt!(_nameController.text.trim(),
        _emailController.text.trim(), _passwordController.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!ok) {
        _error =
            'تعذر إنشاء الحساب — تأكد إن البريد الإلكتروني غير مستخدم من قبل';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'إنشاء حساب',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('لنبدأ رحلتك 🎓', style: AppTextStyles.screenTitle),
            const SizedBox(height: 6),
            const Text(
                'التسجيل بسيط، وتقدر تكمل باقي بياناتك لاحقًا من ملفك الشخصي',
                style: AppTextStyles.caption),
            const SizedBox(height: 24),
            _AppTextField(
                    label: 'الاسم الكامل',
                    icon: Icons.badge_outlined,
                    controller: _nameController,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'أدخل اسمك الكامل'
                        : null)
                .animate()
                .fadeIn(delay: 60.ms, duration: 350.ms)
                .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 14),
            _AppTextField(
              label: 'البريد الإلكتروني',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              controller: _emailController,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'أدخل بريدك الإلكتروني';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) {
                  return 'صيغة البريد الإلكتروني غير صحيحة';
                }
                return null;
              },
            )
                .animate()
                .fadeIn(delay: 140.ms, duration: 350.ms)
                .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 14),
            _AppTextField(
                    label: 'كلمة المرور',
                    icon: Icons.lock_outline_rounded,
                    obscure: true,
                    controller: _passwordController,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'أدخل كلمة المرور';
                      if (v.length < 8) return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
                      return null;
                    })
                .animate()
                .fadeIn(delay: 220.ms, duration: 350.ms)
                .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
            PasswordStrengthBar(password: _passwordText),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style:
                      const TextStyle(color: AppColors.danger, fontSize: 12.5)),
            ],
            const SizedBox(height: 20),
            PrimaryButton(
                label: _loading ? 'جاري الإنشاء...' : 'إنشاء الحساب',
                onPressed: _loading ? null : _submit),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: widget.onGoLogin,
                child: RichText(
                  text: const TextSpan(
                    style: AppTextStyles.body,
                    children: [
                      TextSpan(text: 'لديك حساب بالفعل؟ '),
                      TextSpan(
                        text: 'تسجيل الدخول',
                        style: TextStyle(
                            color: AppColors.orange,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _SetPasswordSheet extends StatefulWidget {
  const _SetPasswordSheet();
  @override
  State<_SetPasswordSheet> createState() => _SetPasswordSheetState();
}

class _SetPasswordSheetState extends State<_SetPasswordSheet> {
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false, _obscure = true;
  String? _error;

  @override
  void dispose() { _pass.dispose(); _confirm.dispose(); super.dispose(); }

  Future<void> _save() async {
    final p = _pass.text.trim();
    if (p.length < 6) { setState(() => _error = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل'); return; }
    if (p != _confirm.text.trim()) { setState(() => _error = 'كلمتا المرور غير متطابقتين'); return; }
    setState(() { _busy = true; _error = null; });
    try {
      await ApiClient.instance.post('/auth/change-password',
          token: AuthSession.instance.token,
          body: {'newPassword': p});
      AuthSession.instance.patchHasPassword();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر حفظ كلمة المرور. حاول مجددًا.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24,
          24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('أضف كلمة مرور لحسابك', style: AppTextStyles.screenTitle),
          const SizedBox(height: 6),
          const Text(
              'اختياري — يمكنك تخطي هذه الخطوة وإضافتها لاحقًا من الإعدادات.',
              style: AppTextStyles.caption),
          const SizedBox(height: 20),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _pass,
            obscureText: _obscure,
            enabled: !_busy,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: 'كلمة المرور الجديدة',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button)),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _confirm,
            obscureText: _obscure,
            enabled: !_busy,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: 'تأكيد كلمة المرور',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button)),
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _busy ? null : _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.button))),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('حفظ كلمة المرور',
                        style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('تخطي',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ]),
        ],
      ),
    );
  }
}
