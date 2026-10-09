const translations = {
  'invalid credentials': 'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
  'email already in use': 'هذا البريد مرتبط بحساب آخر. سجّل الدخول أو استعد كلمة المرور.',
  'name, email, and password are required': 'أدخل الاسم والبريد الإلكتروني وكلمة المرور.',
  'email and password are required': 'أدخل البريد الإلكتروني وكلمة المرور.',
  'current password is required': 'أدخل كلمة المرور الحالية لتأكيد التغيير.',
  'current password is incorrect': 'كلمة المرور الحالية غير صحيحة.',
  'new password is required': 'أدخل كلمة المرور الجديدة.',
  'new password must be at least 8 characters': 'استخدم كلمة مرور من 8 أحرف على الأقل.',
  'this account has been deactivated by an administrator': 'الحساب موقوف حاليًا. تواصل مع الدعم.',
  'unsupported file type': 'نوع الملف غير مدعوم. اختر صورة أو مستندًا من الأنواع المسموحة.',
  'user not found': 'تعذّر العثور على الحساب. راجع بياناتك أو تواصل مع الدعم.',
  'invalid or expired refresh token': 'انتهت جلسة الدخول. سجّل الدخول مجددًا.',
  'unable to verify google account': 'تعذّر تأكيد حساب Google. أعد اختيار الحساب وحاول مجددًا.',
};
const defaults = {
  400: 'راجع البيانات المدخلة وأكمل الحقول المطلوبة.',
  401: 'تعذّر التحقق من الحساب. سجّل الدخول مجددًا.',
  403: 'هذه العملية غير متاحة لحسابك. تواصل مع الدعم للمساعدة.',
  404: 'المحتوى المطلوب غير متاح حاليًا.',
  408: 'الاتصال يستغرق وقتًا أطول من المعتاد. حاول مجددًا.',
  409: 'تغيّرت البيانات أو تم تنفيذ الطلب مسبقًا. حدّث الصفحة ثم حاول مجددًا.',
  413: 'حجم الملف أو البيانات أكبر من المسموح.',
  415: 'نوع الملف غير مدعوم أو لا يتطابق مع محتواه.',
  422: 'راجع البيانات المدخلة وأكمل الحقول المطلوبة.',
  428: 'أكمل التحقق من بريدك الإلكتروني للمتابعة.',
  429: 'محاولات كثيرة خلال وقت قصير. انتظر قليلًا ثم حاول مجددًا.',
};
function publicMessage(status, raw) {
  if (status >= 500) return 'الخدمة غير متاحة مؤقتًا. حاول مجددًا بعد قليل.';
  const message = typeof raw === 'string' ? raw.trim() : '';
  if (translations[message.toLowerCase()]) return translations[message.toLowerCase()];
  if (message.length <= 450 && /[\u0600-\u06ff]/.test(message) &&
      !/<[^>]*>|https?:\/\/|exception|stack|trace|cast.?error|mongoose|mongodb|e11000|sql|socket|errno|\b[45]\d\d\b|\$\w+|[\x00-\x08\x0b\x0c\x0e-\x1f]/i.test(message)) return message;
  return defaults[status] || 'تعذّر إكمال العملية. حاول مجددًا أو تواصل مع الدعم.';
}
module.exports = { publicMessage };
