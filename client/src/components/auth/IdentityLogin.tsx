import { sessionStore } from '../../lib/sessionStore';
import { useEffect, useState } from "react";
import { startAuthentication } from "@simplewebauthn/browser";
import { isAxiosError } from "axios";
import { useNavigate } from "react-router-dom";
import { api } from "../../lib/api";
import { useAuth } from "../../hooks/useAuth";
import { getHomeRouteForRole } from "../../utils/roleHome";
import { getErrorMessage } from "../../utils/errors";
import { FormInput } from "../forms/FormInput";
import { useLanguage } from "../../hooks/useLanguage";

type Config = {
  passkeys: boolean;
  apple: boolean;
  appleClientId: string;
  appleRedirectUri: string;
};
type AppleSDK = {
  auth: {
    init: (options: Record<string, unknown>) => void;
    signIn: () => Promise<{
      authorization: { id_token: string; state: string };
      user?: { name?: { firstName?: string; lastName?: string } };
    }>;
  };
};
let appleScript: Promise<AppleSDK> | undefined;
function loadApple(): Promise<AppleSDK> {
  const existing = (window as unknown as { AppleID?: AppleSDK }).AppleID;
  if (existing) return Promise.resolve(existing);
  if (!appleScript)
    appleScript = new Promise<AppleSDK>((resolve, reject) => {
      const script = document.createElement("script");
      script.src =
        "https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js";
      script.onload = () => {
        const sdk = (window as unknown as { AppleID?: AppleSDK }).AppleID;
        if (sdk) resolve(sdk);
        else reject(new Error("Apple unavailable"));
      };
      script.onerror = () => {
        script.remove();
        reject(new Error("Apple unavailable"));
      };
      document.head.appendChild(script);
    }).catch((error) => {
      appleScript = undefined;
      throw error;
    });
  return appleScript;
}
export const IdentityLogin = () => {
  const [config, setConfig] = useState<Config | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [needsCode, setNeedsCode] = useState(false);
  const [code, setCode] = useState("");
  const { acceptIdentity } = useAuth();
  const navigate = useNavigate();
  const { language } = useLanguage();
  const text = (ar: string, en: string) => (language === "ar" ? ar : en);
  useEffect(() => {
    let active = true;
    api
      .get<Config>("/identity/config")
      .then(({ data }) => {
        if (active) setConfig(data);
      })
      .catch(() => {});
    return () => {
      active = false;
    };
  }, []);
  const signIn = async (provider: "apple" | "passkeys") => {
    if (localStorage.getItem("studyBirdsLogoutPending")) return;
    const generation = sessionStore.begin();
    setBusy(true);
    setError("");
    try {
      let response;
      if (provider === "passkeys") {
        const { data } = await api.post("/identity/passkeys/login/options");
        const credential = await startAuthentication({
          optionsJSON: data.options,
        });
        if (generation !== sessionStore.generation()) return;
        response = await api.post("/identity/passkeys/login/verify", {
          challengeId: data.challengeId,
          response: credential,
          twoFactorCode: code || undefined,
        });
      } else {
        const sdk = await loadApple();
        const { data } = await api.post("/identity/apple/options");
        sdk.auth.init({
          clientId: config!.appleClientId,
          redirectURI: config!.appleRedirectUri,
          scope: "name email",
          state: data.state,
          nonce: data.nonce,
          usePopup: true,
        });
        const result = await sdk.auth.signIn();
        if (result.authorization.state !== data.state)
          throw new Error("Invalid Apple state");
        if (generation !== sessionStore.generation()) return;
        response = await api.post("/identity/apple/verify", {
          challengeId: data.state,
          identityToken: result.authorization.id_token,
          twoFactorCode: code || undefined,
          name:
            [result.user?.name?.firstName, result.user?.name?.lastName]
              .filter(Boolean)
              .join(" ") || undefined,
        });
      }
      if (generation !== sessionStore.generation()) return;
      const user = await acceptIdentity(response.data);
      navigate(
        sessionStorage.getItem("mobileSignInRequest")
          ? `/mobile-sign-in?request=${encodeURIComponent(sessionStorage.getItem("mobileSignInRequest")!)}`
          : getHomeRouteForRole(user.role, user.permissions),
      );
    } catch (e) {
      if (isAxiosError(e) && e.response?.status === 428) setNeedsCode(true);
      setError(
        getErrorMessage(
          e,
          text(
            "لم يكتمل الدخول. يمكنك المحاولة مجددًا أو استخدام كلمة المرور.",
            "Sign-in was not completed. Try again or use your password.",
          ),
        ),
      );
    } finally {
      setBusy(false);
    }
  };
  if (!config?.apple && !config?.passkeys) return null;
  return (
    <div className="mt-6 space-y-3">
      {error ? (
        <p
          role="alert"
          className="rounded-xl bg-rose-50 p-3 text-sm text-rose-700"
        >
          {error}
        </p>
      ) : null}
      {needsCode ? (
        <FormInput
          label={text(
            "رمز البريد، ثم اضغط طريقة الدخول مجددًا",
            "Email code, then select sign-in again",
          )}
          value={code}
          onChange={(e) => setCode(e.target.value)}
          inputMode="numeric"
          autoComplete="one-time-code"
          maxLength={6}
        />
      ) : null}
      {config.apple ? (
        <button
          disabled={busy || (needsCode && !/^\d{6}$/.test(code))}
          onClick={() => void signIn("apple")}
          className="w-full rounded-full bg-black px-5 py-3 font-semibold text-white disabled:opacity-50"
        >
          {text("المتابعة باستخدام Apple", "Continue with Apple")}
        </button>
      ) : null}
      {config.passkeys ? (
        <button
          disabled={
            busy ||
            !window.PublicKeyCredential ||
            (needsCode && !/^\d{6}$/.test(code))
          }
          onClick={() => void signIn("passkeys")}
          className="w-full rounded-full border border-slate-300 px-5 py-3 font-semibold disabled:opacity-50"
        >
          {text("الدخول بمفتاح مرور", "Sign in with a passkey")}
        </button>
      ) : null}
    </div>
  );
};
