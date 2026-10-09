import { useState, type FormEvent } from "react";
import { useNavigate } from "react-router-dom";
import { FormInput } from "../../components/forms/FormInput";
import { useAuth } from "../../hooks/useAuth";
import { useLanguage } from "../../hooks/useLanguage";
import { getErrorMessage } from "../../utils/errors";
import { Seo } from "../../components/seo/Seo";
import { api } from "../../lib/api";

export const DeleteAccountPage = () => {
  const { user, logout } = useAuth();
  const { language } = useLanguage();
  const navigate = useNavigate();
  const text = (ar: string, en: string) => language === "ar" ? ar : en;

  const [step, setStep] = useState<"confirm" | "password">("confirm");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const deleteAccount = async (event: FormEvent) => {
    event.preventDefault();
    setError("");
    setBusy(true);
    try {
      await api.delete("/auth/account", { data: { password: password || undefined } });
      logout();
      navigate("/login", { replace: true });
    } catch (e) {
      setError(getErrorMessage(e, text("تعذر حذف الحساب. حاول مجددًا.", "Unable to delete the account. Please try again.")));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="mx-auto max-w-xl space-y-6 py-4">
      <Seo title={text("حذف الحساب", "Delete account")} description="Delete your Study Birds account" noIndex />
      <header>
        <h1 className="text-3xl font-semibold text-slate-900">{text("حذف الحساب", "Delete account")}</h1>
        <p className="mt-2 text-slate-600">
          {text(
            "سيتم حذف حسابك وجميع بياناتك المرتبطة به بشكل نهائي. لا يمكن التراجع عن هذه العملية.",
            "Your account and all associated data will be permanently deleted. This action cannot be undone."
          )}
        </p>
      </header>

      {error ? <p role="alert" className="rounded-2xl bg-rose-50 p-4 text-rose-700">{error}</p> : null}

      {step === "confirm" ? (
        <div className="panel space-y-4 p-6">
          <p className="font-medium text-slate-800">
            {text(`هل أنت متأكد من حذف حساب "${user?.email}"؟`, `Are you sure you want to delete the account "${user?.email}"?`)}
          </p>
          <div className="flex gap-4">
            <button
              type="button"
              onClick={() => setStep("password")}
              className="rounded-full bg-rose-600 px-5 py-3 text-sm font-semibold text-white"
            >
              {text("نعم، أريد حذف حسابي", "Yes, I want to delete my account")}
            </button>
            <button
              type="button"
              onClick={() => navigate(-1)}
              className="rounded-full border border-slate-300 px-5 py-3 text-sm font-semibold text-slate-700"
            >
              {text("إلغاء", "Cancel")}
            </button>
          </div>
        </div>
      ) : (
        <form onSubmit={deleteAccount} className="panel space-y-5 p-6">
          <p className="text-sm text-slate-600">
            {text("أدخل كلمة مرور حسابك لتأكيد الحذف النهائي.", "Enter your account password to confirm permanent deletion.")}
          </p>
          {user?.authProvider !== "google" ? (
            <FormInput
              label={text("كلمة المرور", "Password")}
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={e => setPassword(e.target.value)}
              required
              disabled={busy}
            />
          ) : (
            <p className="rounded-xl bg-amber-50 p-3 text-sm text-amber-800">
              {text("حسابك مرتبط بـ Google/هاتف ولا يحتاج كلمة مرور للتأكيد.", "Your account is linked via Google/phone and requires no password to confirm.")}
            </p>
          )}
          <div className="flex gap-4">
            <button
              type="submit"
              disabled={busy}
              className="rounded-full bg-rose-600 px-5 py-3 text-sm font-semibold text-white disabled:opacity-50"
            >
              {busy ? text("جارٍ الحذف...", "Deleting...") : text("حذف الحساب نهائيًا", "Permanently delete account")}
            </button>
            <button
              type="button"
              disabled={busy}
              onClick={() => setStep("confirm")}
              className="rounded-full border border-slate-300 px-5 py-3 text-sm font-semibold text-slate-700"
            >
              {text("رجوع", "Back")}
            </button>
          </div>
        </form>
      )}
    </div>
  );
};
