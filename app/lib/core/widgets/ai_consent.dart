import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_session.dart';
import 'privacy_links.dart';

/// Increment only when the disclosed AI processing or consent terms change.
const aiConsentVersion = 2;

/// Both assistant entry points share an account-scoped, durable consent.
Future<bool> requestAiConsent(BuildContext context) async {
  final owner = AuthSession.instance.currentUser?.id;
  final token = AuthSession.instance.token;
  bool sameSession() =>
      AuthSession.instance.currentUser?.id == owner &&
      AuthSession.instance.token == token;
  final key = 'ai_consent_v$aiConsentVersion:$owner';
  final SharedPreferences prefs;
  try {
    prefs = await SharedPreferences.getInstance();
    if (!context.mounted || !sameSession()) return false;
    if (owner != null && owner.isNotEmpty && prefs.getBool(key) == true) {
      return true;
    }
  } catch (_) {
    if (context.mounted) _storageError(context);
    return false;
  }
  final ar = Localizations.localeOf(context).languageCode == 'ar';
  final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title:
              Text(ar ? 'قبل استخدام المساعد' : 'Before using the assistant'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(ar
                  ? 'تُرسل رسائلك وسياق الشاشة إلى خوادم COVEY وتُحفظ المحادثة في حسابك. هذه النسخة تجيب من دليل التطبيق المعتمد وتطلب توضيحًا عند الالتباس؛ لا ترسل محادثتك إلى مزود ذكاء اصطناعي خارجي ضمن هذا المسار. لا ترسل كلمات مرور أو جوازات أو بيانات حساسة. قد تكون الإجابات غير دقيقة؛ تحقق من التفاصيل مع فريق الدعم. المتابعة اختيارية، ويمكنك التوقف بإغلاق المساعد واستخدام الدعم.'
                  : 'Your messages and screen context are sent to COVEY servers and conversations are saved to your account. This version uses the reviewed app guide and asks for clarification when needed; this flow does not send your conversation to an external AI provider. Do not send passwords, passports or sensitive information. Answers may be inaccurate; verify details with Support. Use is optional. Close the assistant to stop and use Support instead.'),
              const PrivacyLinks(),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(ar ? 'إلغاء' : 'Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(ar ? 'أوافق وأتابع' : 'Agree and continue')),
          ],
        ),
      ) ??
      false;
  if (!accepted || !context.mounted || !sameSession()) return false;
  // Anonymous acceptance is not inherited by any signed-in account.
  if (owner == null || owner.isEmpty) return true;
  try {
    final saved = await prefs.setBool(key, true);
    if (!saved) throw StateError('Consent was not saved');
    return context.mounted && sameSession();
  } catch (_) {
    if (context.mounted) _storageError(context);
    return false;
  }
}

void _storageError(BuildContext context) {
  final ar = Localizations.localeOf(context).languageCode == 'ar';
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(ar
          ? 'تعذر حفظ موافقتك. حاول مجددًا.'
          : 'Could not save your consent. Please try again.')));
}
