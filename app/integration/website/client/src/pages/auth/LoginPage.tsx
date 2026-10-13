import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { useNavigate } from "react-router-dom";
import { Link } from "react-router-dom";
import { useEffect, useState } from "react";
import { GoogleSignInButton } from "../../components/auth/GoogleSignInButton";
import { FormInput } from "../../components/forms/FormInput";
import { Seo } from "../../components/seo/Seo";
import { useAuth } from "../../hooks/useAuth";
import { useLanguage } from "../../hooks/useLanguage";
import { getErrorMessage } from "../../utils/errors";
import { SITE_NAME, seoText } from "../../seo/site";

const schema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
});

type LoginValues = z.infer<typeof schema>;

export const LoginPage = () => {
  const navigate = useNavigate();
  const { login, googleLogin, user } = useAuth();
  const { t, language } = useLanguage();
  const [formError, setFormError] = useState("");
  const [googleSubmitting, setGoogleSubmitting] = useState(false);
  const [twoFactor, setTwoFactor] = useState(false);
  const [twoFactorCode, setTwoFactorCode] = useState('');
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<LoginValues>({ resolver: zodResolver(schema) });

  useEffect(() => {
    if (user) {
      navigate(user.role === "admin" ? "/admin" : user.role === "partner" ? "/partner/dashboard" : "/student", {
        replace: true,
      });
    }
  }, [navigate, user]);

  const onSubmit = async (values: LoginValues) => {
    setFormError("");
    try {
      const user = await login(values.email, values.password, twoFactor ? twoFactorCode : undefined);
      navigate(user.role === "admin" ? "/admin" : user.role === "partner" ? "/partner/dashboard" : "/student");
    } catch (error) {
      if ((error as { response?: { status: number } }).response?.status === 428) setTwoFactor(true);
      setFormError(getErrorMessage(error, t("authFailed")));
    }
  };

  const handleGoogleCredential = async (credential: string) => {
    setFormError("");
    setGoogleSubmitting(true);

    try {
      const user = await googleLogin(credential);
      navigate(user.role === "admin" ? "/admin" : user.role === "partner" ? "/partner/dashboard" : "/student");
    } catch (error) {
      setFormError(
        getErrorMessage(
          error,
          language === "ar"
            ? "تعذر تسجيل الدخول عبر Google. حاول مرة أخرى."
            : "Unable to sign in with Google. Please try again."
        )
      );
    } finally {
      setGoogleSubmitting(false);
    }
  };

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
      <form onSubmit={handleSubmit(onSubmit)} className="mt-8 space-y-5">
        {formError ? (
          <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">
            {formError}
          </div>
        ) : null}
        <FormInput label={t("email")} type="email" {...register("email")} error={errors.email?.message} />
        <FormInput label={t("password")} type="password" {...register("password")} error={errors.password?.message} />
        {twoFactor && <label className="block space-y-2"><span>{language === 'ar' ? 'رمز التحقق من البريد' : 'Email verification code'}</span><input required inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6}" maxLength={6} className="w-full rounded-xl border p-3" value={twoFactorCode} onChange={e => setTwoFactorCode(e.target.value)} /></label>}
        {twoFactor && <button type="button" disabled={isSubmitting} className="text-sm underline" onClick={() => { setTwoFactor(false); setTwoFactorCode(''); }}>{language === 'ar' ? 'إعادة إرسال الرمز' : 'Resend code'}</button>}
        <button type="submit" disabled={isSubmitting} className="w-full rounded-full bg-brand-900 px-5 py-3 font-semibold text-white">
          {isSubmitting ? t("signingIn") : t("login")}
        </button>
      </form>

      <div className="my-6 flex items-center gap-4 text-xs uppercase tracking-[0.2em] text-slate-400">
        <div className="h-px flex-1 bg-slate-200" />
        <span>{language === "ar" ? "أو" : "Or"}</span>
        <div className="h-px flex-1 bg-slate-200" />
      </div>

      <GoogleSignInButton language={language} onCredential={handleGoogleCredential} />
      {googleSubmitting ? (
        <p className="mt-3 text-center text-sm text-slate-500">
          {language === "ar" ? "جارٍ تسجيل الدخول عبر Google..." : "Signing in with Google..."}
        </p>
      ) : null}

      <p className="mt-5 text-center text-sm text-slate-600">
        {t("registerPrompt")}{" "}
        <Link to="/register" className="font-semibold text-brand-700">
          {t("register")}
        </Link>
      </p>
    </div>
  );
};
