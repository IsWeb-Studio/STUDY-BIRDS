import { IdentityLogin } from "../../components/auth/IdentityLogin";
import { isAxiosError } from "axios";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { useNavigate } from "react-router-dom";
import { Link } from "react-router-dom";
import { useEffect, useRef, useState } from "react";
import { GoogleSignInButton } from "../../components/auth/GoogleSignInButton";
import { FormInput } from "../../components/forms/FormInput";
import { PasswordStrengthBar, validatePassword } from "../../components/forms/PasswordStrengthBar";
import { Seo } from "../../components/seo/Seo";
import { useAuth } from "../../hooks/useAuth";
import { useLanguage } from "../../hooks/useLanguage";
import { getErrorMessage } from "../../utils/errors";
import { getHomeRouteForRole } from "../../utils/roleHome";
import { SITE_NAME, seoText } from "../../seo/site";
import { authService } from "../../services/authService";
import type { User } from "../../types";

const schema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
  twoFactorCode: z.string().optional(),
});

type LoginValues = z.infer<typeof schema>;

export const LoginPage = () => {
  const navigate = useNavigate();
  const { login, googleLogin, emailOtpLogin, user } = useAuth();
  const { t, language } = useLanguage();
  const ar = language === "ar";

  const [showPassword, setShowPassword] = useState(false);
  const [requiresCode, setRequiresCode] = useState(false);
  const [formError, setFormError] = useState("");
  const [googleSubmitting, setGoogleSubmitting] = useState(false);

  // Set-password modal after Google login
  const [pendingRedirectUser, setPendingRedirectUser] = useState<import("../../types").User | null>(null);
  const [newPass, setNewPass] = useState("");
  const [newPassConfirm, setNewPassConfirm] = useState("");
  const [passError, setPassError] = useState("");
  const [passSaving, setPassSaving] = useState(false);

  // Google email verification state (428 flow)
  const [pendingGoogleCredential, setPendingGoogleCredential] = useState<string | null>(null);
  const [googleEmailCode, setGoogleEmailCode] = useState("");
  const [googleCodeError, setGoogleCodeError] = useState("");
  const [googleCodeCountdown, setGoogleCodeCountdown] = useState(0);
  const googleCountdownRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const startGoogleCountdown = () => {
    setGoogleCodeCountdown(60);
    if (googleCountdownRef.current) clearInterval(googleCountdownRef.current);
    googleCountdownRef.current = setInterval(() => {
      setGoogleCodeCountdown(s => { if (s <= 1) { clearInterval(googleCountdownRef.current!); return 0; } return s - 1; });
    }, 1000);
  };

  // OTP state
  const [otpMode, setOtpMode] = useState(false);
  const [otpStep, setOtpStep] = useState<"email" | "code">("email");
  const [otpEmail, setOtpEmail] = useState("");
  const [otpCode, setOtpCode] = useState("");
  const [otpSubmitting, setOtpSubmitting] = useState(false);
  const [otpError, setOtpError] = useState("");

  const {
    register,
    setValue,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<LoginValues>({ resolver: zodResolver(schema) });

  const mobileRequest = sessionStorage.getItem("mobileSignInRequest");
  const redirectAfterLogin = (u: Pick<User, "role" | "permissions">) =>
    navigate(
      mobileRequest
        ? `/mobile-sign-in?request=${encodeURIComponent(mobileRequest)}`
        : getHomeRouteForRole(u.role, u.permissions),
      { replace: true }
    );

  useEffect(() => {
    if (!user) return;
    if (!user.hasPassword) {
      setPendingRedirectUser(user);
    } else {
      redirectAfterLogin(user);
    }
  }, [navigate, user]);

  const onSubmit = async (values: LoginValues) => {
    setFormError("");
    try {
      const u = await login(values.email, values.password, values.twoFactorCode);
      redirectAfterLogin(u);
    } catch (error) {
      if (isAxiosError(error) && error.response?.status === 428) setRequiresCode(true);
      setFormError(getErrorMessage(error, t("authFailed")));
    }
  };

  const handleGoogleCredential = async (credential: string) => {
    setFormError("");
    setGoogleSubmitting(true);
    try {
      const u = await googleLogin(credential);
      if (!u.hasPassword) {
        setPendingRedirectUser(u);
      } else {
        redirectAfterLogin(u);
      }
    } catch (error) {
      if (isAxiosError(error) && error.response?.status === 428) {
        setPendingGoogleCredential(credential);
        setGoogleCodeError("");
        setGoogleEmailCode("");
        startGoogleCountdown();
        return;
      }
      setFormError(
        getErrorMessage(error, ar ? "تعذر تسجيل الدخول عبر Google. حاول مرة أخرى." : "Unable to sign in with Google. Please try again.")
      );
    } finally {
      setGoogleSubmitting(false);
    }
  };

  const handleGoogleCodeSubmit = async () => {
    setGoogleCodeError("");
    if (googleEmailCode.length !== 6) {
      setGoogleCodeError(ar ? "الرمز مكون من 6 أرقام" : "Code must be 6 digits");
      return;
    }
    setGoogleSubmitting(true);
    try {
      const u = await googleLogin(pendingGoogleCredential!, googleEmailCode.trim());
      setPendingGoogleCredential(null);
      if (!u.hasPassword) {
        setPendingRedirectUser(u);
      } else {
        redirectAfterLogin(u);
      }
    } catch (error) {
      setGoogleCodeError(getErrorMessage(error, ar ? "الرمز غير صحيح أو منتهي الصلاحية." : "Invalid or expired code."));
    } finally {
      setGoogleSubmitting(false);
    }
  };

  const handleSetPassword = async () => {
    setPassError("");
    const pwErr = validatePassword(newPass);
    if (pwErr) { setPassError(pwErr); return; }
    if (newPass !== newPassConfirm) { setPassError(ar ? "كلمتا المرور غير متطابقتين" : "Passwords do not match"); return; }
    setPassSaving(true);
    try {
      await authService.changePassword({ newPassword: newPass });
      redirectAfterLogin(pendingRedirectUser!);
    } catch (error) {
      setPassError(getErrorMessage(error, ar ? "تعذر حفظ كلمة المرور" : "Failed to save password"));
    } finally {
      setPassSaving(false);
    }
  };

  const handleOtpRequest = async () => {
    setOtpError("");
    if (!otpEmail.trim()) {
      setOtpError(ar ? "أدخل بريدك الإلكتروني" : "Enter your email address");
      return;
    }
    setOtpSubmitting(true);
    try {
      await authService.requestEmailOtp(otpEmail.trim());
      setOtpStep("code");
    } catch (error) {
      setOtpError(getErrorMessage(error, ar ? "تعذر إرسال الرمز، تحقق من البريد الإلكتروني." : "Failed to send code. Check your email."));
    } finally {
      setOtpSubmitting(false);
    }
  };

  const handleOtpVerify = async () => {
    setOtpError("");
    if (otpCode.length !== 6) {
      setOtpError(ar ? "الرمز مكون من 6 أرقام" : "Code must be 6 digits");
      return;
    }
    setOtpSubmitting(true);
    try {
      const u = await emailOtpLogin(otpEmail.trim(), otpCode.trim());
      redirectAfterLogin(u);
    } catch (error) {
      setOtpError(getErrorMessage(error, ar ? "الرمز غير صحيح أو منتهي الصلاحية." : "Invalid or expired code."));
    } finally {
      setOtpSubmitting(false);
    }
  };

  if (pendingGoogleCredential) {
    return (
      <div className="mx-auto max-w-xl panel p-8">
        <h1 className="text-2xl font-semibold text-slate-900">
          {ar ? "تحقق من بريدك الإلكتروني" : "Verify your email"}
        </h1>
        <p className="mt-2 text-sm text-slate-500">
          {ar
            ? "أُرسل رمز تحقق مكون من 6 أرقام إلى بريد حساب Google. أدخله أدناه لإتمام تسجيل الدخول."
            : "A 6-digit verification code was sent to your Google account email. Enter it below to complete sign-in."}
        </p>
        <div className="mt-6 space-y-4">
          {googleCodeError ? (
            <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{googleCodeError}</div>
          ) : null}
          <FormInput
            label={ar ? "رمز التحقق" : "Verification Code"}
            type="text"
            inputMode="numeric"
            autoComplete="one-time-code"
            maxLength={6}
            pattern="[0-9]{6}"
            value={googleEmailCode}
            onChange={e => setGoogleEmailCode(e.target.value.replace(/\D/g, ""))}
            onKeyDown={e => { if (e.key === "Enter") { e.preventDefault(); void handleGoogleCodeSubmit(); } }}
          />
          <button
            type="button"
            disabled={googleSubmitting}
            onClick={() => void handleGoogleCodeSubmit()}
            className="w-full rounded-full bg-brand-900 px-5 py-3 font-semibold text-white disabled:opacity-60"
          >
            {googleSubmitting ? (ar ? "جارٍ التحقق..." : "Verifying...") : (ar ? "تحقق وسجّل الدخول" : "Verify & Sign In")}
          </button>
          <div className="flex items-center gap-4 text-sm">
            {googleCodeCountdown > 0
              ? <span className="text-slate-400">{ar ? `إعادة الإرسال بعد ${googleCodeCountdown}ث` : `Resend in ${googleCodeCountdown}s`}</span>
              : <button type="button" disabled={googleSubmitting} className="text-brand-700 underline"
                  onClick={() => { void handleGoogleCredential(pendingGoogleCredential!); }}>
                  {ar ? "أعد إرسال الرمز" : "Resend code"}
                </button>}
            <button
              type="button"
              className="text-slate-500 underline"
              onClick={() => { setPendingGoogleCredential(null); setGoogleEmailCode(""); setGoogleCodeError(""); if (googleCountdownRef.current) clearInterval(googleCountdownRef.current); }}
            >
              {ar ? "إلغاء" : "Cancel"}
            </button>
          </div>
        </div>
      </div>
    );
  }

  if (pendingRedirectUser) {
    return (
      <div className="mx-auto max-w-xl panel p-8">
        <h1 className="text-2xl font-semibold text-slate-900">
          {ar ? "أضف كلمة مرور لحسابك" : "Set a password for your account"}
        </h1>
        <p className="mt-2 text-sm text-slate-500">
          {ar
            ? "يجب إضافة كلمة مرور لتأمين حسابك قبل المتابعة. ستتمكن لاحقًا من الدخول بكلمة المرور أو عبر Google."
            : "You must set a password to secure your account before continuing. You can later sign in with your password or Google."}
        </p>
        <div className="mt-6 space-y-4">
          {passError ? (
            <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{passError}</div>
          ) : null}
          <div>
            <FormInput
              label={ar ? "كلمة المرور الجديدة" : "New password"}
              type="password"
              autoComplete="new-password"
              value={newPass}
              onChange={e => setNewPass(e.target.value)}
            />
            <PasswordStrengthBar value={newPass} language={language} />
          </div>
          <FormInput
            label={ar ? "تأكيد كلمة المرور" : "Confirm password"}
            type="password"
            autoComplete="new-password"
            value={newPassConfirm}
            onChange={e => setNewPassConfirm(e.target.value)}
          />
          <button
            type="button"
            disabled={passSaving}
            onClick={() => void handleSetPassword()}
            className="w-full rounded-full bg-brand-900 px-5 py-3 font-semibold text-white disabled:opacity-60"
          >
            {passSaving ? (ar ? "جارٍ الحفظ..." : "Saving...") : (ar ? "حفظ كلمة المرور" : "Save password")}
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-xl panel p-8">
      <Seo
        title={seoText(language, "Login", "تسجيل الدخول")}
        description={seoText(
          language,
          `Sign in to manage your ${SITE_NAME} profile and applications.`,
          `سجّل الدخول لإدارة ملفك وطلباتك في ${SITE_NAME}.`
        )}
        noIndex
      />
      <h1 className="text-3xl font-semibold text-slate-900">{t("welcomeBack")}</h1>

      {/* Toggle between password and OTP */}
      <div className="mt-5 flex rounded-2xl border border-slate-200 overflow-hidden text-sm font-medium">
        <button
          type="button"
          onClick={() => { setOtpMode(false); setFormError(""); setOtpError(""); }}
          className={`flex-1 py-2.5 transition-colors ${!otpMode ? "bg-brand-900 text-white" : "text-slate-600 hover:bg-slate-50"}`}
        >
          {ar ? "كلمة المرور" : "Password"}
        </button>
        <button
          type="button"
          onClick={() => { setOtpMode(true); setOtpStep("email"); setFormError(""); setOtpError(""); }}
          className={`flex-1 py-2.5 transition-colors ${otpMode ? "bg-brand-900 text-white" : "text-slate-600 hover:bg-slate-50"}`}
        >
          {ar ? "رمز التحقق" : "OTP Code"}
        </button>
      </div>

      {!otpMode ? (
        <form onSubmit={handleSubmit(onSubmit)} className="mt-6 space-y-5">
          {formError ? (
            <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{formError}</div>
          ) : null}
          <FormInput label={t("email")} type="email" {...register("email")} error={errors.email?.message} />
          <FormInput label={t("password")} type={showPassword ? "text" : "password"} autoComplete="current-password" {...register("password")} error={errors.password?.message} />
          <div className="flex flex-wrap items-center justify-between gap-3 text-sm">
            <label className="flex items-center gap-2">
              <input type="checkbox" checked={showPassword} onChange={e => setShowPassword(e.target.checked)} />
              {ar ? "إظهار كلمة المرور" : "Show password"}
            </label>
            <Link to="/forgot-password" className="font-medium text-brand-700">{ar ? "نسيت كلمة المرور؟" : "Forgot password?"}</Link>
          </div>
          {requiresCode ? (
            <FormInput
              label={ar ? "رمز التحقق المرسل إلى بريدك" : "Verification code sent to your email"}
              inputMode="numeric" autoComplete="one-time-code" maxLength={6} pattern="[0-9]{6}" required
              {...register("twoFactorCode")}
            />
          ) : null}
          {requiresCode ? (
            <button type="button" disabled={isSubmitting} className="text-sm text-brand-700 underline"
              onClick={() => { setRequiresCode(false); setValue("twoFactorCode", ""); setFormError(""); }}>
              {ar ? "العودة لبيانات الدخول أو طلب رمز آخر" : "Back to sign-in details or request another code"}
            </button>
          ) : null}
          <button type="submit" disabled={isSubmitting} className="w-full rounded-full bg-brand-900 px-5 py-3 font-semibold text-white">
            {isSubmitting ? t("signingIn") : t("login")}
          </button>
        </form>
      ) : (
        <div className="mt-6 space-y-5">
          {otpError ? (
            <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{otpError}</div>
          ) : null}

          {otpStep === "email" ? (
            <>
              <FormInput
                label={t("email")}
                type="email"
                value={otpEmail}
                onChange={e => setOtpEmail(e.target.value)}
                onKeyDown={e => { if (e.key === "Enter") { e.preventDefault(); void handleOtpRequest(); } }}
              />
              <button
                type="button"
                disabled={otpSubmitting}
                onClick={() => void handleOtpRequest()}
                className="w-full rounded-full bg-brand-900 px-5 py-3 font-semibold text-white disabled:opacity-60"
              >
                {otpSubmitting
                  ? (ar ? "جارٍ الإرسال..." : "Sending...")
                  : (ar ? "إرسال رمز التحقق" : "Send Verification Code")}
              </button>
            </>
          ) : (
            <>
              <p className="text-sm text-slate-500">
                {ar ? `تم إرسال رمز مكون من 6 أرقام إلى ${otpEmail}` : `A 6-digit code was sent to ${otpEmail}`}
              </p>
              <FormInput
                label={ar ? "رمز التحقق" : "Verification Code"}
                type="text"
                inputMode="numeric"
                autoComplete="one-time-code"
                maxLength={6}
                pattern="[0-9]{6}"
                value={otpCode}
                onChange={e => setOtpCode(e.target.value.replace(/\D/g, ""))}
                onKeyDown={e => { if (e.key === "Enter") { e.preventDefault(); void handleOtpVerify(); } }}
              />
              <button
                type="button"
                disabled={otpSubmitting}
                onClick={() => void handleOtpVerify()}
                className="w-full rounded-full bg-brand-900 px-5 py-3 font-semibold text-white disabled:opacity-60"
              >
                {otpSubmitting
                  ? (ar ? "جارٍ التحقق..." : "Verifying...")
                  : (ar ? "تحقق وسجّل الدخول" : "Verify & Sign In")}
              </button>
              <button type="button" className="text-sm text-brand-700 underline"
                onClick={() => { setOtpStep("email"); setOtpCode(""); setOtpError(""); }}>
                {ar ? "تغيير البريد الإلكتروني أو إعادة الإرسال" : "Change email or resend code"}
              </button>
            </>
          )}
        </div>
      )}

      {import.meta.env.VITE_GOOGLE_CLIENT_ID ? (
        <>
          <div className="my-6 flex items-center gap-4 text-xs uppercase tracking-[0.2em] text-slate-400">
            <div className="h-px flex-1 bg-slate-200" />
            <span>{ar ? "أو" : "Or"}</span>
            <div className="h-px flex-1 bg-slate-200" />
          </div>
          <GoogleSignInButton language={language} onCredential={handleGoogleCredential} />
        </>
      ) : null}
      {googleSubmitting ? (
        <p className="mt-3 text-center text-sm text-slate-500">
          {ar ? "جارٍ تسجيل الدخول عبر Google..." : "Signing in with Google..."}
        </p>
      ) : null}

      <IdentityLogin />
      <p className="mt-5 text-center text-sm text-slate-600">
        {t("registerPrompt")}{" "}
        <Link to="/register" className="font-semibold text-brand-700">
          {t("register")}
        </Link>
      </p>
    </div>
  );
};
