import { useEffect, useState } from "react";
import { CloudOff, Wifi, WifiOff } from "lucide-react";
import { connectivity } from "../lib/connectivity";
import { useConnectivity } from "../hooks/useConnectivity";
import { useLanguage } from "../hooks/useLanguage";

const copy = {
  offline: { ar: "لا يوجد اتصال بالإنترنت — تُعرض آخر بيانات محمّلة", en: "No internet connection — showing the last loaded data" },
  unreachable: { ar: "متصل بالشبكة لكن تعذّر الوصول إلى الخدمة — نحاول إعادة الاتصال", en: "Connected, but the service can't be reached — retrying" },
  unstable: { ar: "الاتصال غير مستقر — نحاول إعادة الاتصال", en: "Your connection is unstable — retrying" },
  restored: { ar: "عاد الاتصال بالإنترنت", en: "You're back online" },
};

/**
 * One slim, animated banner for the whole app. Driven by verified
 * reachability (debounced), so it does not flash on brief fluctuations.
 * No dialogs or toasts: nothing can stack when the connection flaps.
 */
export const ConnectivityBanner = () => {
  const { status, unstable } = useConnectivity();
  const { language } = useLanguage();
  const [restored, setRestored] = useState(false);

  useEffect(() => {
    connectivity.start();
    let timer: ReturnType<typeof setTimeout> | undefined;
    const off = connectivity.onReconnected(() => {
      setRestored(true);
      clearTimeout(timer);
      timer = setTimeout(() => setRestored(false), 2500);
    });
    return () => {
      off();
      clearTimeout(timer);
    };
  }, []);

  const view =
    status === "offline"
      ? { text: copy.offline, tone: "bg-slate-700", Icon: WifiOff }
      : status === "unreachable"
        ? { text: unstable ? copy.unstable : copy.unreachable, tone: "bg-amber-600", Icon: CloudOff }
        : restored
          ? { text: copy.restored, tone: "bg-emerald-600", Icon: Wifi }
          : null;

  return (
    <div
      aria-live="polite"
      role="status"
      className={`pointer-events-none fixed inset-x-0 top-0 z-[70] flex justify-center transition-all duration-300 ${view ? "translate-y-0 opacity-100" : "-translate-y-full opacity-0"}`}
    >
      {view ? (
        <div className={`pointer-events-auto flex w-full items-center justify-center gap-2 px-4 py-2 text-sm font-medium text-white shadow-md sm:mt-3 sm:w-auto sm:rounded-full sm:px-5 ${view.tone}`}>
          <view.Icon className="h-4 w-4 shrink-0" />
          <span>{view.text[language]}</span>
        </div>
      ) : null}
    </div>
  );
};
