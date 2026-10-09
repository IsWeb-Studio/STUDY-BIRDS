import 'dart:async';

/// Exceptions may opt in to a safe, actionable message without exposing internals.
abstract interface class UserFacingFailure {
  String get message;
}

class AppError {
  static const unexpected =
      'تعذّر إكمال العملية. حاول مرة أخرى، وإذا استمرت المشكلة تواصل مع الدعم.';
  static const connection =
      'تعذّر الاتصال. تأكد من اتصالك بالإنترنت ثم أعد المحاولة.';
  static const timeout =
      'الاتصال يستغرق وقتًا أطول من المعتاد. أعد المحاولة بعد قليل.';
  static const uncertain =
      'تعذّر التأكد من نتيجة العملية بسبب تأخر الاتصال. راجع طلباتك أو حدّث الصفحة قبل إعادة الإرسال.';
  static const unavailable = 'الخدمة غير متاحة مؤقتًا. حاول مرة أخرى بعد قليل.';

  static String message(Object? error) {
    if (error is UserFacingFailure) return error.message;
    if (error is TimeoutException) return timeout;
    if (error is String) return safeText(error);
    return unexpected;
  }

  static String response(int? status, String? raw) {
    if (status == 0) return connection;
    if (status == 408 || status == 504)
      return raw == uncertain ? uncertain : timeout;
    if (status != null && status >= 500) return unavailable;
    final text = raw?.trim() ?? '';
    final translated = _translations[text.toLowerCase()];
    if (translated != null) return translated;
    if (_isSafeArabic(text)) return text;
    return switch (status) {
      400 ||
      422 =>
        'راجع البيانات المدخلة وأكمل الحقول المطلوبة ثم حاول مجددًا.',
      401 => 'انتهت جلسة الدخول أو تعذّر التحقق من الحساب. سجّل الدخول مجددًا.',
      403 =>
        'لا يمكنك تنفيذ هذه العملية من حسابك. تواصل مع الدعم إذا احتجت مساعدة.',
      404 =>
        'المحتوى المطلوب غير متاح حاليًا. حدّث الصفحة أو ارجع للصفحة السابقة.',
      409 =>
        'تغيّرت البيانات أو تم تنفيذ الطلب مسبقًا. حدّث الصفحة قبل المحاولة مجددًا.',
      413 => 'حجم الملف أو البيانات أكبر من المسموح. اختر ملفًا أصغر.',
      415 => 'نوع الملف غير مدعوم. اختر ملفًا من الأنواع المسموحة.',
      428 => 'أكمل التحقق من بريدك الإلكتروني للمتابعة.',
      429 => 'محاولات كثيرة خلال وقت قصير. انتظر قليلًا ثم حاول مجددًا.',
      499 => 'تم إلغاء العملية. يمكنك المحاولة مجددًا عندما تكون جاهزًا.',
      _ => unexpected,
    };
  }

  static String safeText(String text) {
    final value = text.trim();
    if (value == connection ||
        value == timeout ||
        value == unavailable ||
        value == unexpected) return value;
    return _translations[value.toLowerCase()] ??
        (_isSafeArabic(value) ? value : unexpected);
  }

  static bool _isSafeArabic(String value) =>
      value.isNotEmpty &&
      value.length <= 450 &&
      RegExp(r'[\u0600-\u06ff]').hasMatch(value) &&
      !RegExp(r'<[^>]*>|https?://|exception|stack|trace|cast.?error|mongoose|mongodb|e11000|sql|socket|errno|status.?code|\b[45]\d\d\b|\$\w+|[\x00-\x08\x0b\x0c\x0e-\x1f]',
              caseSensitive: false)
          .hasMatch(value);

  static const _translations = {
    'invalid credentials':
        'البريد الإلكتروني أو كلمة المرور غير صحيحة. راجعهما وحاول مجددًا.',
    'email already in use':
        'هذا البريد مرتبط بحساب آخر. سجّل الدخول أو استخدم استعادة كلمة المرور.',
    'name, email, and password are required':
        'أدخل الاسم والبريد الإلكتروني وكلمة المرور لإكمال التسجيل.',
    'email and password are required': 'أدخل البريد الإلكتروني وكلمة المرور.',
    'current password is required': 'أدخل كلمة المرور الحالية لتأكيد تغييرها.',
    'current password is incorrect':
        'كلمة المرور الحالية غير صحيحة. راجعها وحاول مجددًا.',
    'new password is required': 'أدخل كلمة المرور الجديدة.',
    'new password must be at least 8 characters':
        'استخدم كلمة مرور من 8 أحرف على الأقل.',
    'this account has been deactivated by an administrator':
        'هذا الحساب موقوف حاليًا. تواصل مع الدعم للمساعدة.',
    'unsupported file type':
        'نوع الملف غير مدعوم. اختر صورة أو مستندًا من الأنواع المسموحة.',
    'file too large': 'الملف كبير جدًا. اختر ملفًا لا يتجاوز 5 ميجابايت.',
    'user not found':
        'تعذّر العثور على الحساب. راجع بياناتك أو تواصل مع الدعم.',
    'invalid or expired refresh token':
        'انتهت جلسة الدخول. سجّل الدخول مجددًا.',
    'unable to verify google account':
        'تعذّر تأكيد حساب Google. أعد اختيار الحساب وحاول مجددًا.',
    'not authorized, no token': 'سجّل الدخول للمتابعة.',
    'not authorized, token failed': 'انتهت جلسة الدخول. سجّل الدخول مجددًا.',
    'forbidden': 'هذه العملية غير متاحة لحسابك.',
  };
}
