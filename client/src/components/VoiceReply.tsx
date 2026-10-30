import { useEffect, useState } from "react";
import { api } from "../lib/api";
import { useLanguage } from "../hooks/useLanguage";

export function VoiceReply({ path }: { path: string }) {
  const { language } = useLanguage();
  const ar = language === "ar";
  const [url, setUrl] = useState<string>();
  const [busy, setBusy] = useState(false);
  const [failed, setFailed] = useState(false);
  const [requested, setRequested] = useState(0);
  useEffect(() => {
    if (!requested || !/^\/voice\/tickets\/[a-f\d]{24}\/replies\/[a-f\d]{24}\/audio$/i.test(path)) return;
    const controller = new AbortController();
    let objectUrl: string | undefined;
    setBusy(true);
    setFailed(false);
    api.get<Blob>(path, { responseType: "blob", signal: controller.signal })
      .then(({ data }) => {
        if (controller.signal.aborted) return;
        objectUrl = URL.createObjectURL(data);
        setUrl(objectUrl);
      })
      .catch(() => { if (!controller.signal.aborted) setFailed(true); })
      .finally(() => { if (!controller.signal.aborted) setBusy(false); });
    return () => {
      controller.abort();
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [path, requested]);
  if (url) return <audio controls preload="metadata" src={url} aria-label={ar ? "رسالة صوتية" : "Voice message"} className="mt-2 max-w-full" />;
  return <button type="button" disabled={busy} className="mt-2 text-sm underline" onClick={() => {
    setRequested((value) => value + 1);
  }}>{busy ? (ar ? "جارٍ التحميل…" : "Loading…") : failed ? (ar ? "تعذر التحميل؛ اضغط ثم أعد المحاولة" : "Load failed; retry") : (ar ? "تحميل الرسالة الصوتية" : "Load voice message")}</button>;
}
