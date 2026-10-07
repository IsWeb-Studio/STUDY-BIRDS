import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/feature_ui.dart';

class EmailChallengeScreen extends StatefulWidget {
  final Future<void> Function(String) confirm;
  const EmailChallengeScreen({super.key, required this.confirm});
  @override
  State<EmailChallengeScreen> createState() => _EmailChallengeScreenState();
}
class _EmailChallengeScreenState extends State<EmailChallengeScreen> {
  final code = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() { code.dispose(); super.dispose(); }
  Future<void> confirm() async {
    if (!RegExp(r'^\d{6}$').hasMatch(code.text.trim())) { setState(() => error = 'أدخل رمزًا من 6 أرقام'); return; }
    setState(() { busy = true; error = null; });
    try {
      await widget.confirm(code.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) { if (mounted) setState(() => error = e is ApiException ? e.message : 'تعذر التحقق. حاول مجددًا.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => AppScaffold(title: 'التحقق من الهوية', body: FeatureBody(children: [
    const FeatureIntro(title: 'خطوة أخيرة لحماية حسابك', subtitle: 'أدخل رمز التحقق المرسل إلى بريدك الإلكتروني.', icon: Icons.shield_outlined),
    if (error != null) InlineNotice(error!, error: true),
    FeaturePanel(child: Column(children: [
      TextField(controller: code, enabled: !busy, keyboardType: TextInputType.number, textDirection: TextDirection.ltr, autofillHints: const [AutofillHints.oneTimeCode], decoration: featureInput('رمز التحقق', hint: '000000')),
      const SizedBox(height: 24), PrimaryButton(label: busy ? 'جاري التحقق...' : 'تأكيد', onPressed: busy ? null : confirm),
    ])),
  ]));
}
