import 'package:flutter/material.dart';
import 'privacy_links.dart';

/// Consent is deliberately scoped to the current assistant screen session.
Future<bool> requestAiConsent(BuildContext context) async {
  final ar = Localizations.localeOf(context).languageCode == 'ar';
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title:
              Text(ar ? 'قبل استخدام المساعد' : 'Before using the assistant'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(ar
                  ? 'تُرسل رسائلك وسياق الشاشة إلى خوادم COVEY وتُحفظ المحادثة في حسابك. تستخدم الخدمة مزود ذكاء اصطناعي خارجي لمعالجة المواضيع المعتمدة. لا ترسل كلمات مرور أو جوازات أو بيانات حساسة. قد تكون الإجابات غير دقيقة؛ تحقق من التفاصيل مع فريق الدعم. المتابعة اختيارية، ويمكنك التوقف بإغلاق المساعد واستخدام الدعم.'
                  : 'Your messages and screen context are sent to COVEY servers and conversations are saved to your account. The service uses an external AI provider to process approved topics. Do not send passwords, passports or sensitive information. Answers may be inaccurate; verify details with Support. Use is optional. Close the assistant to stop and use Support instead.'),
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
}
