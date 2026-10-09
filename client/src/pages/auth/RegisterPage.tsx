import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { useNavigate, useSearchParams } from "react-router-dom";
import { Link } from "react-router-dom";
import { useEffect, useState } from "react";
import { GoogleSignInButton } from "../../components/auth/GoogleSignInButton";
import { FormInput } from "../../components/forms/FormInput";
import { PasswordStrengthBar, validatePassword } from "../../components/forms/PasswordStrengthBar";
import { Seo } from "../../components/seo/Seo";
import { useAuth } from "../../hooks/useAuth";
import { useLanguage } from "../../hooks/useLanguage";
import { getErrorMessage } from "../../utils/errors";
import { getHomeRouteForRole } from "../../utils/roleHome";
import { SITE_NAME, seoText } from "../../seo/site";

const schema = z.object({
  name: z.string().min(2),
  email: z.string().email(),
  password: z.string().refine(v => !validatePassword(v), { message: "كلمة المرور لا تستوفي متطلبات الأمان" }),
});

type RegisterValues = z.infer<typeof schema>;

export const RegisterPage = () => {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const referralCode = searchParams.get("ref") || undefined;
  const { register: registerUser, googleLogin, user } = useAuth();
  const { t, language } = useLanguage();
  const [formError, setFormError] = useState("");
  const [googleSubmitting, setGoogleSubmitting] = useState(false);
  const {
    register,
    handleSubmit,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<RegisterValues>({ resolver: zodResolver(schema) });
  const passwordValue = watch("password", "");

  useEffect(() => {
    if (user) {
      navigate(getHomeRouteForRole(user.role, user.permissions), {
        replace: true,
      });
    }
  }, [navigate, user]);

  const onSubmit = async (values: RegisterValues) => {
    setFormError("");
    try {
      const user = await registerUser({ ...values, referralCode });
      navigate(getHomeRouteForRole(user.role, user.permissions));
    } catch (error) {
      setFormError(getErrorMessage(error, t("authFailed")));
    }
  };

  const handleGoogleCredential = async (credential: string) => {
    setFormError("");
    setGoogleSubmitting(true);

    try {
      const user = await googleLogin(credential);
      navigate(getHomeRouteForRole(user.role, user.permissions));
    } catch (error) {
      setFormError(
        getErrorMessage(
          error,
          language === "ar"
            ? "تعذر إنشاء الحساب عبر Google. حاول مرة أخرى."
            : "Unable to continue with Google. Please try again."
        )
      );
    } finally {
      setGoogleSubmitting(false);
    }
  };

  return (
    <div className="mx-auto max-w-xl panel p-8">
      <Seo
        title={seoText(language, "Create Account", "إنشاء حساب")}
        description={seoText(
          language,
          `Create your student account on ${SITE_NAME} to begin applying to universities abroad.`,
          `أنشئ حسابك الطلابي على ${SITE_NAME} لبدء التقديم على الجامعات في الخارج.`
        )}
        noIndex
      />
      <h1 className="text-3xl font-semibold text-slate-900">{t("createAccount")}</h1>
      <form onSubmit={handleSubmit(onSubmit)} className="mt-8 space-y-5">
        {formError ? (
          <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">
            {formError}
          </div>
        ) : null}
        <FormInput label={t("name")} {...register("name")} error={errors.name?.message} />
        <FormInput label={t("email")} type="email" {...register("email")} error={errors.email?.message} />
        <div>
          <FormInput label={t("password")} type="password" autoComplete="new-password" {...register("password")} error={errors.password?.message} />
          <PasswordStrengthBar value={passwordValue} language={language} />
        </div>
        <button type="submit" disabled={isSubmitting} className="w-full rounded-full bg-brand-900 px-5 py-3 font-semibold text-white">
          {isSubmitting ? t("creatingAccount") : t("register")}
        </button>
      </form>

      <div className="my-6 flex items-center gap-4 text-xs uppercase tracking-[0.2em] text-slate-400">
        <div className="h-px flex-1 bg-slate-200" />
        <span>{language === "ar" ? "أو" : "Or"}</span>
        <div className="h-px flex-1 bg-slate-200" />
      </div>

      <GoogleSignInButton language={language} mode="register" onCredential={handleGoogleCredential} />
      {googleSubmitting ? (
        <p className="mt-3 text-center text-sm text-slate-500">
          {language === "ar" ? "جارٍ إنشاء الجلسة عبر Google..." : "Signing in with Google..."}
        </p>
      ) : null}

      <p className="mt-5 text-center text-sm text-slate-600">
        {t("loginPrompt")}{" "}
        <Link to="/login" className="font-semibold text-brand-700">
          {t("login")}
        </Link>
      </p>
    </div>
  );
};
