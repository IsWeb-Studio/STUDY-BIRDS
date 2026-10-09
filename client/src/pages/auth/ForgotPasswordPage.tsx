import { useState, type FormEvent } from "react";
import { Link } from "react-router-dom";
import { FormInput } from "../../components/forms/FormInput";
import { PasswordStrengthBar, validatePassword } from "../../components/forms/PasswordStrengthBar";
import { useLanguage } from "../../hooks/useLanguage";
import { api } from "../../lib/api";
import { getErrorMessage } from "../../utils/errors";
import { Seo } from "../../components/seo/Seo";

export const ForgotPasswordPage = () => {
  const { language } = useLanguage();
  const text = (ar: string, en: string) => language === "ar" ? ar : en;
  const [step, setStep] = useState<"email" | "code" | "done">("email");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [password, setPassword] = useState("");
  const [repeat, setRepeat] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [visible, setVisible] = useState(false);
  const submit = async (event: FormEvent) => {
    event.preventDefault(); setError("");
    if (step === "code" && password !== repeat) { setError(text("كلمتا المرور غير متطابقتين", "Passwords do not match")); return; }
    if (step === "code") { const pwErr = validatePassword(password); if (pwErr) { setError(pwErr); return; } }
    setBusy(true);
    try {
      if (step === "email") {
        await api.post("/mobile-security/reset/request", { email: email.trim() });
        setStep("code");
      } else {
        await api.post("/mobile-security/reset/confirm", { email: email.trim(), code, password });
        setPassword(""); setRepeat(""); setStep("done");
      }
    } catch (e) { setError(getErrorMessage(e, text("تعذر إكمال الطلب. حاول مجددًا.", "Unable to complete the request. Try again."))); }
    finally { setBusy(false); }
  };
  return <section className="panel mx-auto max-w-xl p-6 sm:p-8">
    <Seo title={text("استعادة كلمة المرور", "Reset password")} description="Study Birds account security" noIndex />
    <h1 className="text-2xl font-semibold text-slate-900">{text("استعادة كلمة المرور", "Reset password")}</h1>
    <p className="mt-3 text-slate-600">{step === "email" ? text("أدخل بريد حسابك لإرسال رمز الاستعادة.", "Enter your account email to request a reset code.") : step === "code" ? text("إذا كان البريد مسجلًا، ستصلك رسالة برمز صالح لمدة 10 دقائق.", "If this email is registered, a code valid for 10 minutes will arrive.") : text("تم تغيير كلمة المرور. سجّل الدخول بكلمتك الجديدة.", "Password changed. Sign in with your new password.")}</p>
    {error ? <p role="alert" className="mt-5 rounded-xl bg-rose-50 p-4 text-rose-700">{error}</p> : null}
    {step !== "done" ? <form onSubmit={submit} className="mt-6 space-y-5">
      <fieldset disabled={busy} className="space-y-5">
        <FormInput label={text("البريد الإلكتروني", "Email")} type="email" autoComplete="email" value={email} readOnly={step === "code"} onChange={e => setEmail(e.target.value)} required />
        {step === "code" ? <>
          <FormInput label={text("رمز التحقق", "Verification code")} inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6}" maxLength={6} value={code} onChange={e => setCode(e.target.value)} required />
          <div><FormInput label={text("كلمة المرور الجديدة", "New password")} type={visible ? "text" : "password"} autoComplete="new-password" minLength={8} maxLength={200} value={password} onChange={e => setPassword(e.target.value)} required /><PasswordStrengthBar value={password} language={language} /></div>
          <FormInput label={text("تأكيد كلمة المرور", "Confirm password")} type={visible ? "text" : "password"} autoComplete="new-password" minLength={8} value={repeat} onChange={e => setRepeat(e.target.value)} required />
          <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={visible} onChange={e => setVisible(e.target.checked)} />{text("إظهار كلمة المرور", "Show password")}</label>
          <button type="button" className="text-sm text-brand-700 underline" onClick={() => { setStep("email"); setCode(""); setError(""); }}>{text("تغيير البريد أو طلب رمز آخر", "Change email or request another code")}</button>
        </> : null}
        <button className="w-full rounded-full bg-brand-900 px-5 py-3 font-semibold text-white disabled:opacity-50">{busy ? text("جارٍ التنفيذ…", "Please wait…") : step === "email" ? text("إرسال رمز الاستعادة", "Send reset code") : text("حفظ كلمة المرور", "Save password")}</button>
      </fieldset>
    </form> : null}
    <Link to="/login" className="mt-6 inline-block font-medium text-brand-700">{text("العودة لتسجيل الدخول", "Back to sign in")}</Link>
  </section>;
};
