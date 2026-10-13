import { useEffect, useRef, useState } from "react";
import { RefreshCw, WifiOff } from "lucide-react";
import { connectivity } from "../lib/connectivity";
import { useLanguage } from "../hooks/useLanguage";

/**
 * Full-page "No internet connection" state with a working Try Again button.
 * `onRetry` is called after connectivity was re-verified, and automatically
 * once when the connection returns (never in a loop).
 */
export const OfflineState = ({ onRetry }: { onRetry?: () => void | Promise<void> }) => {
  const { language } = useLanguage();
  const ar = language === "ar";
  const [checking, setChecking] = useState(false);
  const retryRef = useRef(onRetry);
  retryRef.current = onRetry;

  useEffect(() => {
    let fired = false;
    return connectivity.onReconnected(() => {
      if (fired) return;
      fired = true;
      void retryRef.current?.();
    });
  }, []);

  const retry = async () => {
    if (checking) return;
    setChecking(true);
    try {
      await Promise.race([connectivity.checkNow(), new Promise((resolve) => setTimeout(resolve, 4000))]);
      await onRetry?.();
    } finally {
      setChecking(false);
    }
  };

  return (
    <div className="container-shell flex min-h-[50vh] items-center justify-center py-12" dir={ar ? "rtl" : "ltr"}>
      <div className="w-full max-w-md rounded-[2rem] border border-slate-200 bg-white p-8 text-center shadow-lg">
        <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-orange-50 text-orange-500">
          <WifiOff className="h-8 w-8" />
        </div>
        <h2 className="mt-5 text-xl font-semibold text-slate-900">{ar ? "لا يوجد اتصال بالإنترنت" : "No Internet Connection"}</h2>
        <p className="mt-2 text-sm leading-7 text-slate-600">
          {ar ? "يرجى التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى." : "Please check your internet connection and try again."}
        </p>
        <button
          type="button"
          onClick={retry}
          disabled={checking}
          className="mt-6 inline-flex items-center justify-center gap-2 rounded-full bg-slate-900 px-6 py-3 text-sm font-semibold text-white transition hover:bg-slate-800 disabled:opacity-60"
        >
          <RefreshCw className={`h-4 w-4 ${checking ? "animate-spin" : ""}`} />
          {ar ? "إعادة المحاولة" : "Try Again"}
        </button>
      </div>
    </div>
  );
};
