import 'browser_sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/app_theme.dart';
import '../../core/country_data.dart';
import '../../core/google_sign_in_service.dart';
import '../../core/api_client.dart';
import '../../core/auth_session.dart';
import '../../core/analytics_service.dart';

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
      // Wait for init to complete before deciding native vs browser path.
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
        widget.onGoogleSignInSuccess?.call();
      } else {
        // Native sign-in was dismissed or rejected (e.g. SHA1 not registered).
        // Fall back to the PKCE browser flow so the user can still sign in.
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
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PhoneOtpLoginScreen(onSuccess: widget.onGoogleSignInSuccess))),
                  icon: const Icon(Icons.phone_android_rounded, size: 20),
                  label: const Text('المتابعة برقم الهاتف'),
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

// #6: Phone OTP login screen
class PhoneOtpLoginScreen extends StatefulWidget {
  final VoidCallback? onSuccess;
  const PhoneOtpLoginScreen({super.key, this.onSuccess});
  @override
  State<PhoneOtpLoginScreen> createState() => _PhoneOtpLoginScreenState();
}

class _PhoneOtpLoginScreenState extends State<PhoneOtpLoginScreen> {
  Country _country = kDefaultCountry;
  final _localPhone = TextEditingController();
  final _code = TextEditingController();
  bool _sent = false, _busy = false;
  String? _phoneError, _codeError;

  @override
  void dispose() {
    _localPhone.dispose();
    _code.dispose();
    super.dispose();
  }

  String get _fullPhone {
    final digits = _localPhone.text.replaceAll(RegExp(r'[^0-9]'), '');
    return '+${_country.dialCode}$digits';
  }

  Future<void> _pickCountry() async {
    final picked = await showCountryPicker(context);
    if (picked != null && mounted) setState(() => _country = picked);
  }

  Future<void> _requestOtp() async {
    final digits = _localPhone.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 5) {
      setState(() => _phoneError = 'أدخل رقم الهاتف بشكل صحيح');
      return;
    }
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(_fullPhone)) {
      setState(() => _phoneError = 'الرقم غير صالح — تحقق من رمز الدولة والرقم');
      return;
    }
    setState(() { _busy = true; _phoneError = null; });
    try {
      await ApiClient.instance.post('/auth/otp/request', body: {'phone': _fullPhone});
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _phoneError = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _code.text.trim();
    if (!RegExp(r'^\d{4,10}$').hasMatch(code)) {
      setState(() => _codeError = 'أدخل رمز واتساب الصحيح');
      return;
    }
    setState(() { _busy = true; _codeError = null; });
    try {
      final data = await ApiClient.instance.post('/auth/otp/verify',
          body: {'phone': _fullPhone, 'code': code});
      final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
      await AuthSession.instance.login(user,
          authToken: data['token'] as String,
          refreshToken: data['refreshToken'] as String?);
      AnalyticsService.instance.loginCompleted(user.role.name);
      if (mounted) widget.onSuccess?.call();
    } on ApiException catch (e) {
      if (mounted) setState(() => _codeError = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تسجيل الدخول برقم الهاتف'),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.navy,
          elevation: 0,
        ),
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text('رقم هاتفك', style: AppTextStyles.screenTitle),
                const SizedBox(height: 6),
                const Text('سنرسل رمز التحقق عبر واتساب',
                    style: AppTextStyles.caption),
                const SizedBox(height: 28),

                // Phone row: country picker + local number field
                const Text('رقم الهاتف', style: AppTextStyles.caption),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Country code button
                    GestureDetector(
                      onTap: _sent ? null : _pickCountry,
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppRadius.button),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_country.flag,
                                style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 6),
                            Text('+${_country.dialCode}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.navy)),
                            const SizedBox(width: 2),
                            if (!_sent)
                              Icon(Icons.expand_more_rounded,
                                  size: 16,
                                  color: Colors.grey.shade400),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Local number field
                    Expanded(
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppRadius.button),
                          border: Border.all(
                              color: _phoneError != null
                                  ? AppColors.danger
                                  : AppColors.border),
                        ),
                        child: TextField(
                          controller: _localPhone,
                          readOnly: _sent,
                          enabled: !_busy,
                          textDirection: TextDirection.ltr,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(
                              fontSize: 15, letterSpacing: 1),
                          onChanged: (_) {
                            if (_phoneError != null) {
                              setState(() => _phoneError = null);
                            }
                          },
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 14, horizontal: 12),
                            hintText: '5xxxxxxxx',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_phoneError != null) ...[
                  const SizedBox(height: 6),
                  Text(_phoneError!,
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 12.5)),
                ],

                // OTP code field — appears after sending
                if (_sent) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.chat_rounded,
                            color: Color(0xFF25D366), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تم إرسال رمز التحقق إلى $_fullPhone عبر واتساب',
                            style: AppTextStyles.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('رمز واتساب', style: AppTextStyles.caption),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppRadius.button),
                      border: Border.all(
                          color: _codeError != null
                              ? AppColors.danger
                              : AppColors.border),
                    ),
                    child: TextField(
                      controller: _code,
                      enabled: !_busy,
                      textDirection: TextDirection.ltr,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 8),
                      textAlign: TextAlign.center,
                      onChanged: (_) {
                        if (_codeError != null) {
                          setState(() => _codeError = null);
                        }
                      },
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            vertical: 14, horizontal: 12),
                        hintText: '------',
                        hintStyle: TextStyle(letterSpacing: 8),
                      ),
                    ),
                  ),
                  if (_codeError != null) ...[
                    const SizedBox(height: 6),
                    Text(_codeError!,
                        style: const TextStyle(
                            color: AppColors.danger, fontSize: 12.5)),
                  ],
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed:
                        _busy ? null : (_sent ? _verifyOtp : _requestOtp),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.button)),
                    ),
                    child: Text(
                      _busy
                          ? 'جارٍ...'
                          : (_sent ? 'تأكيد الرمز' : 'إرسال رمز واتساب'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15),
                    ),
                  ),
                ),

                if (_sent) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _sent = false;
                                _code.clear();
                                _codeError = null;
                              }),
                      child: const Text('تغيير الرقم أو إعادة الإرسال',
                          style: TextStyle(color: AppColors.orange)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
