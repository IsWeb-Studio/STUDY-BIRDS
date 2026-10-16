import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

String mediaPickerError(Object error) {
  if (error is PlatformException) {
    if (error.code.contains('denied') || error.code.contains('restricted')) {
      return 'لم تسمح بالوصول للصور أو الكاميرا. يمكنك تعديل الصلاحية من إعدادات التطبيق على جهازك.';
    }
    return 'تعذر فتح الصور والفيديوهات. أغلق المعرض وحاول مجددًا.';
  }
  return error.toString();
}

/// App confirmation only. The system picker manages access to selected files.
Future<bool> confirmGalleryAccess(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('gallery_picker_confirmed') == true) return true;
  if (!context.mounted) return false;
  final allow = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
            title: const Text('فتح معرض الصور والفيديوهات؟'),
            content: const Text(
                'اختر الصورة أو الفيديو الذي تريد مشاركته. سيستخدم التطبيق الملف الذي تختاره فقط.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('السماح وفتح المعرض')),
            ],
          ));
  if (allow != true) return false;
  await prefs.setBool('gallery_picker_confirmed', true);
  return context.mounted;
}
