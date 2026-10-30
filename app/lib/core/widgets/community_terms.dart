import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_session.dart';
import 'privacy_links.dart';

const communityRulesArabic =
    'استخدم المجتمع باحترام. يُمنع التحرش والتنمر وخطاب الكراهية والتهديدات والمحتوى الجنسي واستغلال الأطفال أو الاعتداء عليهم وأي محتوى غير قانوني. لا تنشر معلومات خاصة أو مستندات هوية أو محتوى لا تملك حق نشره. يمكن للفريق إزالة المحتوى وإيقاف الحسابات المخالفة. أبلغ عن المخالفات من زر الإبلاغ، واحظر المستخدم المسيء من ملفه الشخصي، أو تواصل مع الدعم. تنطبق هذه القواعد على المنشورات والتعليقات والستوريات والرسائل.';
const communityRulesEnglish =
    'Treat others respectfully. Harassment, bullying, hate speech, threats, sexual content, child sexual abuse or exploitation, and illegal content are prohibited. Do not publish private information, identity documents or content you have no right to share. Moderators may remove content and suspend offending accounts. Use Report for violations, block abusive users from their profile, or contact Support. These rules apply to posts, comments, stories and messages.';

Future<bool> requireCommunityTerms(BuildContext context) async {
  final owner = AuthSession.instance.currentUser?.id;
  final token = AuthSession.instance.token;
  final prefs = await SharedPreferences.getInstance();
  final key = 'community_terms_v1:${owner ?? 'anonymous'}';
  if (prefs.getBool(key) == true) return true;
  if (!context.mounted) return false;
  final ar = Localizations.localeOf(context).languageCode == 'ar';
  final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
            title: Text(
                ar ? 'قواعد مجتمع COVEY' : 'COVEY community rules'),
            content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(ar ? communityRulesArabic : communityRulesEnglish),
              const PrivacyLinks(),
            ])),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(ar ? 'إلغاء' : 'Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(ar
                      ? 'أوافق على قواعد المجتمع'
                      : 'Agree to community rules'))
            ],
          ));
  if (accepted != true ||
      !context.mounted ||
      owner != AuthSession.instance.currentUser?.id ||
      token != AuthSession.instance.token) {
    return false;
  }
  await prefs.setBool(key, true);
  return true;
}
