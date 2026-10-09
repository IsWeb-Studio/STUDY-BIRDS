const types = [/\p{Lu}/u, /[\p{Ll}\p{Lo}]/u, /\p{N}/u, /[^\p{L}\p{N}\s]/u];
function passwordError(password) {
  if (typeof password !== 'string' || !password) return 'أدخل كلمة المرور';
  if (password.length < 8) return 'استخدم 8 أحرف على الأقل';
  if (Buffer.byteLength(password, 'utf8') > 72) return 'كلمة المرور طويلة جدًا. استخدم واحدة أقصر.';
  const common = /^(password|qwerty|welcome|letmein|admin|studybirds|abcdefgh|12345678|87654321)\d*$/i.test(password.replace(/[^a-zA-Z0-9]/g, ''));
  if (common || new Set([...password]).size < 4) return 'هذه الكلمة سهلة التخمين. اختر كلمة أقل شيوعًا وتجنب التكرار.';
  if (types.filter(type => type.test(password)).length < 3) return 'اخلط 3 أنواع على الأقل: أحرف كبيرة، أحرف صغيرة أو عربية، أرقام، رموز.';
  return null;
}
module.exports = { passwordError };
