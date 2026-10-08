import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import '../../core/utils/country_data.dart';
import '../../core/widgets/feature_ui.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_session.dart';

class PhoneVerificationScreen extends StatefulWidget {
  final void Function(String verifiedPhone)? onVerified;
  final List<Widget>? actions;
  const PhoneVerificationScreen({super.key, this.onVerified, this.actions});
  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  Country _country = kDefaultCountry;
  final _localPhone = TextEditingController();
  final _code = TextEditingController();
  bool _sent = false, _busy = false, _verified = false;
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

  Future<void> _submit() async {
    if (!_sent) {
      final digits = _localPhone.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length < 5) {
        setState(() => _phoneError = 'أدخل رقم الهاتف بشكل صحيح');
        return;
      }
      if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(_fullPhone)) {
        setState(() => _phoneError = 'الرقم غير صالح — تحقق من رمز الدولة');
        return;
      }
    }
    if (_sent && !RegExp(r'^\d{4,10}$').hasMatch(_code.text.trim())) {
      setState(() => _codeError = 'أدخل رمز SMS الصحيح');
      return;
    }
    setState(() {
      _busy = true;
      _phoneError = null;
      _codeError = null;
    });
    try {
      await ApiClient.instance.post(
          '/identity/phone/${_sent ? 'confirm' : 'request'}',
          token: AuthSession.instance.token,
          body: _sent
              ? {'code': _code.text.trim()}
              : {'phone': _fullPhone});
      if (mounted) {
        setState(() {
          _verified = _sent;
          _sent = true;
        });
        if (_verified) widget.onVerified?.call(_fullPhone);
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException ? e.message : 'تعذر الاتصال، حاول مجددًا';
        setState(() => _sent ? _codeError = msg : _phoneError = msg);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'تأكيد الهاتف',
        actions: widget.actions,
        body: FeatureBody(children: [
          const FeatureIntro(
              title: 'رقم هاتف موثوق',
              subtitle: 'سيصلك رمز SMS للتحقق من ملكيتك للرقم.',
              icon: Icons.phone_android),
          if (_verified)
            const InlineNotice('تم تأكيد رقم الهاتف بنجاح')
          else
            FeaturePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Phone row: country picker + local number
                  const Text('رقم الهاتف', style: AppTextStyles.caption),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: _sent ? null : _pickCountry,
                        child: Container(
                          height: 52,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
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
                              if (!_sent) ...[
                                const SizedBox(width: 2),
                                Icon(Icons.expand_more_rounded,
                                    size: 16,
                                    color: Colors.grey.shade400),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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

                  if (_sent) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.navy.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sms_rounded,
                              color: Color(0xFF1E88E5), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'تم إرسال رمز SMS إلى $_fullPhone',
                              style: AppTextStyles.caption,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('رمز SMS', style: AppTextStyles.caption),
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
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 8),
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

                  const SizedBox(height: 20),
                  PrimaryButton(
                      label: _busy
                          ? 'جارٍ التحقق…'
                          : _sent
                              ? 'تأكيد الرقم'
                              : 'إرسال رمز SMS',
                      onPressed: _busy ? null : _submit),
                  if (_sent)
                    TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _sent = false;
                                  _code.clear();
                                  _codeError = null;
                                }),
                        child: const Text(
                            'تغيير الرقم أو إعادة الإرسال')),
                ],
              ),
            ),
        ]),
      );
}
