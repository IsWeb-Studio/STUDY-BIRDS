import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/auth_session.dart';
import '../../core/app_theme.dart';
import '../../core/feature_ui.dart';
import '../../main.dart' show RootChooserScreen;

class BrowserSignInScreen extends StatefulWidget {
  const BrowserSignInScreen({super.key});
  @override
  State<BrowserSignInScreen> createState() => _BrowserSignInScreenState();
}

class _BrowserSignInScreenState extends State<BrowserSignInScreen> {
  String? verifier, id, url, error;
  bool busy = false;
  Future<void> start() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final secret = base64UrlEncode(
              List.generate(32, (_) => Random.secure().nextInt(256)))
          .replaceAll('=', '');
      final challenge =
          base64UrlEncode(sha256.convert(utf8.encode(secret)).bytes)
              .replaceAll('=', '');
      final data = await ApiClient.instance.post('/identity/mobile/start',
          body: {'challenge': challenge}) as Map;
      if (!mounted) return;
      verifier = secret;
      id = data['challengeId'] as String;
      url = data['url'] as String;
      if (!await launchUrl(Uri.parse(url!),
          mode: LaunchMode.externalApplication)) throw Exception('browser');
    } catch (e) {
      if (mounted)
        setState(() =>
            error = e is ApiException ? e.message : 'تعذر فتح تسجيل الدخول');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> complete() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await ApiClient.instance.post('/identity/mobile/exchange',
          body: {'challengeId': id, 'verifier': verifier}) as Map;
      if (data['pending'] == true) {
        if (mounted)
          setState(() => error = 'أكمل الدخول والموافقة في المتصفح أولًا.');
        return;
      }
      await AuthSession.instance.login(
          AuthUser.fromJson(Map<String, dynamic>.from(data['user'] as Map)),
          authToken: data['token'] as String,
          refreshToken: data['refreshToken'] as String?);
      verifier = null;
      if (mounted)
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const RootChooserScreen()),
            (_) => false);
    } catch (e) {
      if (mounted)
        setState(
            () => error = e is ApiException ? e.message : 'تعذر إكمال الدخول');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
      title: 'دخول آمن',
      body: FeatureBody(children: [
        const FeatureIntro(
            title: 'Google أو Apple أو مفتاح مرور',
            subtitle:
                'أكمل الدخول في الموقع الرسمي، وافق على دخول التطبيق، ثم عُد هنا. الطلب صالح لمدة 5 دقائق.',
            icon: Icons.security),
        if (error != null) InlineNotice(error!, error: true),
        PrimaryButton(
            label: busy
                ? 'جارٍ التنفيذ…'
                : id == null
                    ? 'فتح تسجيل الدخول'
                    : 'بدء طلب جديد',
            onPressed: busy ? null : start),
        if (id != null) ...[
          const SizedBox(height: 16),
          PrimaryButton(
              label: 'أكملت الدخول', onPressed: busy ? null : complete)
        ],
      ]));
}
