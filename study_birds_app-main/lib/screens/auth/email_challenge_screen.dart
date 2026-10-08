import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/feature_ui.dart';

class EmailChallengeScreen extends StatefulWidget {
  final Future<void> Function(String) confirm;
  final Future<void> Function()? resend;
  const EmailChallengeScreen({super.key, required this.confirm, this.resend});
  @override
  State<EmailChallengeScreen> createState() => _EmailChallengeScreenState();
}

class _EmailChallengeScreenState extends State<EmailChallengeScreen> {
  final code = TextEditingController();
  bool busy = false, resending = false;
  String? error;
  int _secondsLeft = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.resend != null) _startCountdown();
  }

  void _startCountdown() {
    _secondsLeft = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() { _timer?.cancel(); code.dispose(); super.dispose(); }

  Future<void> confirm() async {
    if (!RegExp(r'^\d{6}$').hasMatch(code.text.trim())) { setState(() => error = 'أدخل رمزًا من 6 أرقام'); return; }
    setState(() { busy = true; error = null; });
    try {
      await widget.confirm(code.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) { if (mounted) setState(() => error = e is ApiException ? e.message : 'تعذر التحقق. حاول مجددًا.'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> _doResend() async {
    setState(() { resending = true; error = null; });
    try {
      await widget.resend!();
      _startCountdown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إعادة إرسال رمز التحقق')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e is ApiException ? e.message : 'تعذر إعادة الإرسال. حاول مجددًا.');
    } finally {
      if (mounted) setState(() => resending = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'التحقق من الهوية',
    body: FeatureBody(children: [
      const FeatureIntro(title: 'خطوة أخيرة لحماية حسابك', subtitle: 'أدخل رمز التحقق المرسل إلى بريدك الإلكتروني.', icon: Icons.shield_outlined),
      if (error != null) InlineNotice(error!, error: true),
      FeaturePanel(child: Column(children: [
        TextField(controller: code, enabled: !busy, keyboardType: TextInputType.number, textDirection: TextDirection.ltr, autofillHints: const [AutofillHints.oneTimeCode], decoration: featureInput('رمز التحقق', hint: '000000')),
        const SizedBox(height: 24),
        PrimaryButton(label: busy ? 'جاري التحقق...' : 'تأكيد', onPressed: busy ? null : confirm),
        if (widget.resend != null) ...[
          const SizedBox(height: 16),
          if (_secondsLeft > 0)
            Text('إعادة الإرسال بعد $_secondsLeft ثانية',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center)
          else
            TextButton(
              onPressed: resending ? null : _doResend,
              child: Text(resending ? 'جاري الإرسال...' : 'أعد إرسال الرمز',
                  style: const TextStyle(fontSize: 14)),
            ),
        ],
      ])),
    ]),
  );
}
