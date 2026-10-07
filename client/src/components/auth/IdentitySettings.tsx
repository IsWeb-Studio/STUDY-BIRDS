import { useEffect, useState, type FormEvent } from "react";
import { startRegistration } from "@simplewebauthn/browser";
import { api } from "../../lib/api";
import { FormInput } from "../forms/FormInput";
import { getErrorMessage } from "../../utils/errors";
import { useLanguage } from "../../hooks/useLanguage";

type Key = { _id: string; name: string; createdAt: string };
export const IdentitySettings = () => {
  const { language } = useLanguage();
  const text = (ar: string, en: string) => (language === "ar" ? ar : en);
  const [config, setConfig] = useState<{
    passkeys: boolean;
    phone: boolean;
  } | null>(null);
  const [keys, setKeys] = useState<Key[]>([]);
  const [password, setPassword] = useState("");
  const [phone, setPhone] = useState("");
  const [verifiedPhone, setVerifiedPhone] = useState("");
  const [sent, setSent] = useState(false);
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  useEffect(() => {
    let active = true;
    Promise.all([
      api.get("/identity/config"),
      api.get<Key[]>("/identity/passkeys"),
      api.get("/auth/me"),
    ])
      .then(([c, k, u]) => {
        if (active) {
          setConfig(c.data);
          setKeys(k.data);
          setVerifiedPhone(u.data.user.verifiedPhone || "");
        }
      })
      .catch(() => {
        if (active)
          setError(
            text(
              "تعذر تحميل طرق التحقق الإضافية.",
              "Unable to load additional verification methods.",
            ),
          );
      });
    return () => {
      active = false;
    };
  }, []);
  const run = async (work: () => Promise<void>) => {
    setBusy(true);
    setError("");
    setNotice("");
    try {
      await work();
    } catch (e) {
      setError(
        getErrorMessage(
          e,
          text("تعذر إكمال الطلب.", "Unable to complete the request."),
        ),
      );
    } finally {
      setBusy(false);
    }
  };
  const register = (event: FormEvent) => {
    event.preventDefault();
    void run(async () => {
      const { data } = await api.post("/identity/passkeys/register/options", {
        currentPassword: password,
      });
      setPassword("");
      const response = await startRegistration({ optionsJSON: data.options });
      await api.post("/identity/passkeys/register/verify", {
        challengeId: data.challengeId,
        response,
      });
      setKeys((await api.get<Key[]>("/identity/passkeys")).data);
      setNotice(text("تم تسجيل مفتاح المرور.", "Passkey registered."));
    });
  };
  const verifyPhone = (event: FormEvent) => {
    event.preventDefault();
    void run(async () => {
      if (!sent) {
        await api.post("/identity/phone/request", { phone });
        setSent(true);
        setNotice(
          text(
            "أُرسل رمز واتساب إلى الرقم الذي أدخلته.",
            "A WhatsApp code was sent to the number you entered.",
          ),
        );
      } else {
        const { data } = await api.post("/identity/phone/confirm", { code });
        setVerifiedPhone(data.verifiedPhone);
        setSent(false);
        setCode("");
        setNotice(text("تم تأكيد رقم الهاتف.", "Phone verified."));
      }
    });
  };
  const button =
    "rounded-full bg-brand-900 px-5 py-3 font-semibold text-white disabled:opacity-50";
  return (
    <div className="space-y-6">
      {error ? (
        <p role="alert" className="rounded-xl bg-rose-50 p-4 text-rose-700">
          {error}
        </p>
      ) : null}
      {notice ? (
        <p
          role="status"
          className="rounded-xl bg-emerald-50 p-4 text-emerald-800"
        >
          {notice}
        </p>
      ) : null}
      <section className="panel space-y-4 p-6">
        <h2 className="text-xl font-semibold">
          {text("مفاتيح المرور والبصمة", "Passkeys and biometrics")}
        </h2>
        <p className="text-sm text-slate-600">
          {text(
            "استخدم بصمة الإصبع أو الوجه أو رمز جهازك. بيانات البصمة تبقى على جهازك. لتسجيل مفتاح جديد أكّد كلمة مرور حسابك.",
            "Use your fingerprint, face or device PIN. Biometrics stay on your device. Confirm your account password to register a new key.",
          )}
        </p>
        {!config?.passkeys ? (
          <p>
            {text(
              "الخدمة تحتاج إعداد نطاق مفاتيح المرور على السيرفر.",
              "Passkey domain configuration is required on the server.",
            )}
          </p>
        ) : (
          <form onSubmit={register} className="space-y-4">
            <FormInput
              label={text("كلمة المرور الحالية", "Current password")}
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              disabled={busy}
            />
            <button
              className={button}
              disabled={busy || !window.PublicKeyCredential}
            >
              {text("إضافة مفتاح مرور", "Add passkey")}
            </button>
          </form>
        )}
        <ul className="divide-y">
          {keys.map((key) => (
            <li
              key={key._id}
              className="flex flex-wrap items-center justify-between gap-3 py-3"
            >
              <span>{key.name}</span>
              <button
                disabled={busy}
                className="text-rose-700"
                onClick={() => {
                  if (
                    window.confirm(
                      text("حذف مفتاح المرور؟", "Remove this passkey?"),
                    )
                  )
                    void run(async () => {
                      await api.delete(`/identity/passkeys/${key._id}`);
                      setKeys((rows) =>
                        rows.filter((row) => row._id !== key._id),
                      );
                    });
                }}
              >
                {text("حذف", "Remove")}
              </button>
            </li>
          ))}
        </ul>
      </section>
      <section className="panel space-y-4 p-6">
        <h2 className="text-xl font-semibold">
          {text("تأكيد الهاتف", "Phone verification")}
        </h2>
        {verifiedPhone ? <p dir="ltr">{verifiedPhone} ✓</p> : null}
        {!config?.phone ? (
          <p>
            {text(
              "الخدمة تحتاج إعداد Twilio على السيرفر.",
              "Twilio configuration is required on the server.",
            )}
          </p>
        ) : (
          <form onSubmit={verifyPhone} className="space-y-4">
            <FormInput
              label={text(
                "الهاتف بالصيغة الدولية",
                "International phone number",
              )}
              type="tel"
              dir="ltr"
              placeholder="+905..."
              pattern="\+[1-9][0-9]{7,14}"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              required
              readOnly={sent}
              disabled={busy}
            />
            {sent ? (
              <>
                <FormInput
                  label={text("رمز واتساب", "WhatsApp code")}
                  value={code}
                  onChange={(e) => setCode(e.target.value)}
                  inputMode="numeric"
                  autoComplete="one-time-code"
                  pattern="[0-9]{4,10}"
                  required
                  disabled={busy}
                />
                <button
                  type="button"
                  disabled={busy}
                  onClick={() => {
                    setSent(false);
                    setCode("");
                  }}
                  className="text-brand-700 underline"
                >
                  {text(
                    "تغيير الرقم أو إعادة الطلب",
                    "Change number or request again",
                  )}
                </button>
              </>
            ) : null}
            <div>
              <button className={button} disabled={busy}>
                {sent
                  ? text("تأكيد الرقم", "Verify number")
                  : text("إرسال رمز", "Send code")}
              </button>
            </div>
          </form>
        )}
      </section>
    </div>
  );
};
