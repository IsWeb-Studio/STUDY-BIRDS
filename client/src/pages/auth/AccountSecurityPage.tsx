import { IdentitySettings } from "../../components/auth/IdentitySettings";
import { useEffect, useState, type FormEvent } from "react";
import { useNavigate, Link } from "react-router-dom";
import { ShieldCheck, Mail, Monitor } from "lucide-react";
import { api } from "../../lib/api";
import { useAuth } from "../../hooks/useAuth";
import { useLanguage } from "../../hooks/useLanguage";
import { FormInput } from "../../components/forms/FormInput";
import { PasswordStrengthBar, validatePassword } from "../../components/forms/PasswordStrengthBar";
import { getErrorMessage } from "../../utils/errors";
import { Seo } from "../../components/seo/Seo";

type Session = { _id: string; device: string; lastSeen: string; current: boolean };
export const AccountSecurityPage = () => {
  const { user, logout, refreshSession } = useAuth();
  const { language } = useLanguage();
  const navigate = useNavigate();
  const text = (ar: string, en: string) => language === "ar" ? ar : en;
  const [enabled, setEnabled] = useState<boolean | null>(null);
  const [verified, setVerified] = useState(user?.emailVerified === true);
  const [sessions, setSessions] = useState<Session[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [challenge, setChallenge] = useState<"email" | "two-factor" | null>(null);
  const [code, setCode] = useState("");
  const [revoke, setRevoke] = useState<Session | null>(null);
  const [password, setPassword] = useState({ currentPassword: "", newPassword: "", confirm: "" });

  // Email change state
  const [emailChangeStep, setEmailChangeStep] = useState<"idle" | "input" | "code">("idle");
  const [newEmail, setNewEmail] = useState("");
  const [emailChangeCode, setEmailChangeCode] = useState("");
  const [emailChangeBusy, setEmailChangeBusy] = useState(false);
  const [emailChangeError, setEmailChangeError] = useState("");
  const load = async () => {
    const [security, devices] = await Promise.all([api.get<{ enabled: boolean }>("/mobile-security/two-factor"), api.get<Session[]>("/mobile-security/sessions")]);
    setEnabled(security.data.enabled); setSessions(devices.data);
  };
  useEffect(() => { let active = true;
    Promise.all([api.get<{ enabled: boolean }>("/mobile-security/two-factor"), api.get<Session[]>("/mobile-security/sessions")])
      .then(([security, devices]) => { if (active) { setEnabled(security.data.enabled); setSessions(devices.data); } })
      .catch(e => { if (active) setError(getErrorMessage(e, "Unable to load account security / تعذر تحميل إعدادات الأمان")); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, []);
  const perform = async (work: () => Promise<void>) => {
    setBusy(true); setError(""); setNotice("");
    try { await work(); } catch (e) { setError(getErrorMessage(e, text("تعذر إكمال الطلب. حاول مجددًا.", "Unable to complete the request. Try again."))); }
    finally { setBusy(false); }
  };
  const request = (kind: "email") => perform(async () => {
    const res = await api.post<{ alreadyVerified?: boolean }>(`/mobile-security/${kind}/request`);
    if (res.data.alreadyVerified) { setVerified(true); setNotice(text("بريدك الإلكتروني موثّق بالفعل.", "Your email is already verified.")); return; }
    setChallenge(kind); setCode("");
    setNotice(text("تم إرسال الرمز إلى بريدك. صلاحيته 10 دقائق.", "A code was sent to your email. It expires in 10 minutes."));
  });
  const enableTwoFactor = () => perform(async () => {
    await api.post("/mobile-security/two-factor/request");
    setChallenge("two-factor"); setCode("");
    setNotice(text("تم إرسال الرمز إلى بريدك. أدخله لتفعيل التحقق بخطوتين.", "A code was sent to your email. Enter it to enable two-step verification."));
  });
  const disableTwoFactor = () => perform(async () => {
    await api.post("/mobile-security/two-factor/disable");
    setEnabled(false); setChallenge(null); setCode("");
    setNotice(text("تم إيقاف التحقق بخطوتين.", "Two-step verification disabled."));
  });
  const confirm = (event: FormEvent) => { event.preventDefault(); void perform(async () => {
    if (!challenge) return;
    await api.post(`/mobile-security/${challenge}/confirm`, { code, ...(challenge === "two-factor" ? { enabled: true } : {}) });
    if (challenge === "two-factor") setEnabled(true);
    setVerified(true); setChallenge(null); setCode("");
    setNotice(text("تم حفظ إعدادات الأمان.", "Security settings saved."));
    await refreshSession();
  }); };

  const requestEmailChange = async (e: FormEvent) => {
    e.preventDefault(); setEmailChangeError(""); setEmailChangeBusy(true);
    try {
      await api.post("/mobile-security/email/change/request", { email: newEmail });
      setEmailChangeStep("code"); setEmailChangeCode("");
    } catch (err) { setEmailChangeError(getErrorMessage(err, text("تعذر إرسال الرمز", "Failed to send code"))); }
    finally { setEmailChangeBusy(false); }
  };
  const confirmEmailChange = async (e: FormEvent) => {
    e.preventDefault(); setEmailChangeError(""); setEmailChangeBusy(true);
    try {
      await api.post("/mobile-security/email/change/confirm", { code: emailChangeCode });
      setEmailChangeStep("idle"); setNewEmail(""); setEmailChangeCode(""); setVerified(true);
      setNotice(text("تم تغيير بريدك الإلكتروني بنجاح.", "Your email has been changed successfully."));
      await refreshSession();
    } catch (err) { setEmailChangeError(getErrorMessage(err, text("رمز خاطئ أو منتهي الصلاحية", "Invalid or expired code"))); }
    finally { setEmailChangeBusy(false); }
  };
  const changePassword = (event: FormEvent) => { event.preventDefault();
    if (password.newPassword !== password.confirm) { setError(text("كلمتا المرور غير متطابقتين", "Passwords do not match")); return; }
    const pwErr = validatePassword(password.newPassword);
    if (pwErr) { setError(pwErr); return; }
    void perform(async () => {
      await api.post("/auth/change-password", { currentPassword: password.currentPassword, newPassword: password.newPassword });
      setPassword({ currentPassword: "", newPassword: "", confirm: "" });
      setNotice(text("تم تغيير كلمة المرور.", "Password changed."));
    });
  };
  const revokeAll = () => void perform(async () => {
    await api.post("/mobile-security/sessions/revoke-all");
    logout(); navigate("/login", { replace: true });
  });
  const button = "rounded-full bg-brand-900 px-5 py-3 text-sm font-semibold text-white disabled:opacity-50";
  return <div className="mx-auto max-w-3xl space-y-6 py-4">
    <Seo title={text("أمان الحساب", "Account security")} description="Study Birds account security" noIndex />
    <header><h1 className="text-3xl font-semibold text-slate-900">{text("أمان الحساب", "Account security")}</h1><p className="mt-2 text-slate-600">{text("تحكّم في طرق التحقق والأجهزة التي تستخدم حسابك.", "Manage verification and the devices using your account.")}</p></header>
    {error ? <p role="alert" className="rounded-2xl bg-rose-50 p-4 text-rose-700">{error}</p> : null}
    {notice ? <p role="status" className="rounded-2xl bg-emerald-50 p-4 text-emerald-800">{notice}</p> : null}
    {loading ? <p role="status">{text("جارٍ تحميل إعدادات الأمان…", "Loading security settings…")}</p> : null}
    <section className="panel space-y-4 p-6">
      <Mail className="text-brand-700" aria-hidden="true" />
      <h2 className="text-xl font-semibold">{text("البريد الإلكتروني", "Email address")}</h2>
      <div className="flex flex-wrap items-center gap-3">
        <p className="break-all text-slate-700 font-medium">{user?.email}</p>
        {verified
          ? <span className="flex items-center gap-1 rounded-full bg-emerald-50 px-3 py-1 text-sm font-medium text-emerald-700">
              <svg className="h-4 w-4" viewBox="0 0 20 20" fill="currentColor"><path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" /></svg>
              {text("موثّق", "Verified")}
            </span>
          : <span className="rounded-full bg-amber-50 px-3 py-1 text-sm font-medium text-amber-700">{text("غير موثّق", "Not verified")}</span>}
      </div>
      {!verified
        ? <button className={button} disabled={busy || !!challenge} onClick={() => void request("email")}>{text("توثيق البريد", "Verify email")}</button>
        : null}
      {emailChangeStep === "idle"
        ? <button className="text-sm text-brand-700 underline" disabled={busy} onClick={() => { setEmailChangeStep("input"); setEmailChangeError(""); setNewEmail(""); }}>{text("تغيير البريد الإلكتروني", "Change email")}</button>
        : null}
      {emailChangeStep !== "idle"
        ? <div className="rounded-xl border border-slate-200 p-4 space-y-3">
            <h3 className="font-semibold text-slate-800">{text("تغيير البريد الإلكتروني", "Change email")}</h3>
            {emailChangeError ? <p className="text-sm text-rose-600">{emailChangeError}</p> : null}
            {emailChangeStep === "input"
              ? <form onSubmit={e => void requestEmailChange(e)} className="space-y-3">
                  <FormInput label={text("البريد الجديد", "New email")} type="email" value={newEmail} onChange={e => setNewEmail(e.target.value)} required disabled={emailChangeBusy} />
                  <div className="flex gap-3">
                    <button className={button} disabled={emailChangeBusy}>{emailChangeBusy ? text("جارٍ الإرسال…", "Sending…") : text("إرسال رمز التحقق", "Send code")}</button>
                    <button type="button" className="text-sm text-slate-500" onClick={() => setEmailChangeStep("idle")}>{text("إلغاء", "Cancel")}</button>
                  </div>
                </form>
              : <form onSubmit={e => void confirmEmailChange(e)} className="space-y-3">
                  <p className="text-sm text-slate-600">{text(`تم إرسال رمز إلى ${newEmail}`, `A code was sent to ${newEmail}`)}</p>
                  <FormInput label={text("رمز التحقق", "Verification code")} inputMode="numeric" autoComplete="one-time-code" maxLength={6} pattern="[0-9]{6}" value={emailChangeCode} onChange={e => setEmailChangeCode(e.target.value.replace(/\D/g, ""))} required disabled={emailChangeBusy} />
                  <div className="flex gap-3">
                    <button className={button} disabled={emailChangeBusy}>{emailChangeBusy ? text("جارٍ التحقق…", "Verifying…") : text("تأكيد", "Confirm")}</button>
                    <button type="button" className="text-sm text-slate-500" onClick={() => setEmailChangeStep("input")}>{text("تغيير البريد", "Change email")}</button>
                    <button type="button" className="text-sm text-slate-500" onClick={() => { setEmailChangeStep("idle"); setEmailChangeError(""); }}>{text("إلغاء", "Cancel")}</button>
                  </div>
                </form>}
          </div>
        : null}
    </section>
    <section className="panel space-y-4 p-6"><ShieldCheck className="text-brand-700" aria-hidden="true" /><h2 className="text-xl font-semibold">{text("التحقق بخطوتين", "Two-step verification")}</h2><p className="text-slate-600">{text("عند التفعيل، يتطلب الدخول كلمة المرور ورمزًا يصل إلى بريدك.", "When enabled, sign-in requires your password and an email code.")}</p><p>{enabled === null ? text("الحالة غير متاحة", "Status unavailable") : enabled ? text("مفعّل", "Enabled") : text("غير مفعّل", "Disabled")}</p><button className={button} disabled={busy || enabled === null || !!challenge} onClick={() => enabled ? void disableTwoFactor() : void enableTwoFactor()}>{enabled ? text("إيقاف التحقق بخطوتين", "Disable two-step verification") : text("تفعيل التحقق بخطوتين", "Enable two-step verification")}</button></section>
    {challenge ? <form onSubmit={confirm} className="panel space-y-4 border-brand-200 p-6"><h2 className="text-xl font-semibold">{text("تأكيد التغيير", "Confirm this change")}</h2><FormInput label={text("رمز التحقق من البريد", "Email verification code")} value={code} onChange={e => setCode(e.target.value)} inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6}" maxLength={6} required disabled={busy} /><div className="flex gap-4"><button className={button} disabled={busy}>{text("تأكيد", "Confirm")}</button><button type="button" disabled={busy} onClick={() => { setChallenge(null); setCode(""); setNotice(""); }}>{text("إلغاء", "Cancel")}</button></div></form> : null}
    <section className="panel space-y-4 p-6"><Monitor className="text-brand-700" aria-hidden="true" /><h2 className="text-xl font-semibold">{text("الجلسات والأجهزة", "Sessions and devices")}</h2><p className="text-sm text-slate-600">{text("تظهر الجلسات عند استخدام النسخة المحدثة من الموقع أو التطبيق.", "Sessions appear when using the updated website or app.")}</p>
      <div className="flex flex-wrap gap-4">
        <button className="text-brand-700 underline" disabled={busy} onClick={() => void perform(load)}>{text("تحديث القائمة", "Refresh list")}</button>
        {sessions.length > 1 ? <button className="text-sm font-medium text-rose-700 underline" disabled={busy} onClick={revokeAll}>{text("تسجيل الخروج من جميع الأجهزة", "Sign out of all devices")}</button> : null}
      </div>
      {!loading && sessions.length === 0 ? <p>{text("لا توجد جلسات مسجلة لعرضها.", "No recorded sessions to display.")}</p> : null}
      <ul className="divide-y divide-slate-100">{sessions.map(session => <li key={session._id} className="space-y-3 py-4"><p className="break-all text-sm text-slate-700">{session.device}</p><p className="text-sm text-slate-500">{new Date(session.lastSeen).toLocaleString(language === "ar" ? "ar" : "en")}{session.current ? text(" — الجلسة الحالية", " — Current session") : ""}</p><button disabled={busy} className="text-sm font-medium text-rose-700" onClick={() => setRevoke(session)}>{text("إنهاء الجلسة", "End session")}</button></li>)}</ul>
      {revoke ? <div className="space-y-3 rounded-xl bg-rose-50 p-4"><p>{revoke.current ? text("سيتم تسجيل خروجك من هذا الجهاز. هل تريد المتابعة؟", "This will sign you out of this device. Continue?") : text("هل تريد إنهاء الجلسة على هذا الجهاز؟", "End this device's session?")}</p><div className="flex gap-4"><button disabled={busy} className="font-semibold text-rose-700" onClick={() => void perform(async () => { await api.delete(`/mobile-security/sessions/${revoke._id}`); if (revoke.current) { logout(); navigate("/login", { replace: true }); } else { setSessions(rows => rows.filter(row => row._id !== revoke._id)); setRevoke(null); } })}>{text("نعم، إنهاء الجلسة", "Yes, end session")}</button><button disabled={busy} onClick={() => setRevoke(null)}>{text("إلغاء", "Cancel")}</button></div></div> : null}
    </section>
    <IdentitySettings />
    <section className="panel space-y-4 p-6 border-rose-100"><h2 className="text-xl font-semibold text-rose-700">{text("حذف الحساب", "Delete account")}</h2><p className="text-sm text-slate-600">{text("حذف الحساب نهائي ولا يمكن التراجع عنه.", "Account deletion is permanent and cannot be undone.")}</p><Link to="/account/delete" className="inline-block rounded-full border border-rose-300 px-5 py-2.5 text-sm font-semibold text-rose-700 hover:bg-rose-50">{text("حذف حسابي", "Delete my account")}</Link></section>
    <form onSubmit={changePassword} className="panel space-y-5 p-6"><h2 className="text-xl font-semibold">{text("تغيير كلمة المرور", "Change password")}</h2><fieldset disabled={busy} className="space-y-4"><FormInput label={text("كلمة المرور الحالية", "Current password")} type="password" autoComplete="current-password" value={password.currentPassword} onChange={e => setPassword({ ...password, currentPassword: e.target.value })} required /><div><FormInput label={text("كلمة المرور الجديدة", "New password")} type="password" autoComplete="new-password" minLength={8} maxLength={200} value={password.newPassword} onChange={e => setPassword({ ...password, newPassword: e.target.value })} required /><PasswordStrengthBar value={password.newPassword} language={language} /></div><FormInput label={text("تأكيد كلمة المرور", "Confirm password")} type="password" autoComplete="new-password" value={password.confirm} onChange={e => setPassword({ ...password, confirm: e.target.value })} required /><button className={button}>{text("حفظ كلمة المرور", "Save password")}</button></fieldset></form>
  </div>;
};
