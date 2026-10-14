import { useCallback, useEffect, useId, useRef, useState, type ChangeEvent } from "react";
import { createPortal } from "react-dom";
import { useLanguage } from "../../hooks/useLanguage";
import { DOCUMENT_UPLOAD_ACCEPT } from "../../constants/upload";

type Props = { onSelect: (file: File) => void; accept?: string; disabled?: boolean; selectedName?: string };

export function DocumentPicker({ onSelect, accept = DOCUMENT_UPLOAD_ACCEPT, disabled = false, selectedName }: Props) {
  const { language } = useLanguage();
  const ar = language === "ar";
  const titleId = useId();
  const nativeCamera = useRef<HTMLInputElement>(null);
  const photos = useRef<HTMLInputElement>(null);
  const files = useRef<HTMLInputElement>(null);
  const trigger = useRef<HTMLButtonElement>(null);
  const cancel = useRef<HTMLButtonElement>(null);
  const video = useRef<HTMLVideoElement>(null);
  const stream = useRef<MediaStream | null>(null);
  const session = useRef(0);
  const preview = useRef<string | null>(null);
  const [name, setName] = useState("");
  const [cameraOpen, setCameraOpen] = useState(false);
  const [ready, setReady] = useState(false);
  const [capturing, setCapturing] = useState(false);
  const [photo, setPhoto] = useState<File | null>(null);
  const [error, setError] = useState("");
  const [liveStream, setLiveStream] = useState<MediaStream | null>(null);
  const imageAccept = "image/jpeg,image/png,image/webp";

  const stopStream = useCallback(() => {
    stream.current?.getTracks().forEach(track => track.stop());
    stream.current = null;
    if (video.current) video.current.srcObject = null;
  }, []);
  const release = useCallback(() => {
    session.current += 1;
    stopStream();
    if (preview.current) URL.revokeObjectURL(preview.current);
    preview.current = null;
  }, [stopStream]);
  const closeCamera = useCallback(() => {
    release();
    setCameraOpen(false); setReady(false); setPhoto(null); setCapturing(false); setError(""); setLiveStream(null);
    trigger.current?.focus();
  }, [release]);
  useEffect(() => release, [release]);
  useEffect(() => {
    if (!cameraOpen || !liveStream || !video.current || photo) return;
    const current = session.current;
    video.current.srcObject = liveStream;
    void video.current.play().catch(() => {
      if (current !== session.current) return;
      stopStream();
      setError(ar ? "تعذر عرض الكاميرا؛ أعد المحاولة." : "Unable to show the camera. Please retry.");
    });
  }, [cameraOpen, liveStream, photo, ar, stopStream]);
  useEffect(() => {
    if (!cameraOpen) return;
    cancel.current?.focus();
    function key(event: KeyboardEvent) {
      if (event.key === "Escape") { event.preventDefault(); closeCamera(); }
      if (event.key === "Tab") {
        const dialog = document.getElementById(titleId)?.closest('[role="dialog"]');
        const controls = dialog?.querySelectorAll<HTMLButtonElement>('button:not(:disabled)');
        if (!controls?.length) return;
        const first = controls[0], last = controls[controls.length - 1];
        if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
        else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
      }
    }
    function hidden() { if (document.visibilityState === "hidden") closeCamera(); }
    document.addEventListener("keydown", key);
    document.addEventListener("visibilitychange", hidden);
    return () => { document.removeEventListener("keydown", key); document.removeEventListener("visibilitychange", hidden); };
  }, [cameraOpen, closeCamera, titleId]);
  useEffect(() => { if (disabled && cameraOpen) closeCamera(); }, [disabled, cameraOpen, closeCamera]);

  async function openCamera() {
    if (disabled) return;
    release();
    const current = session.current;
    setCameraOpen(true); setPhoto(null); setReady(false); setCapturing(false); setError(""); setLiveStream(null);
    if (!navigator.mediaDevices?.getUserMedia) {
      setError(ar ? "الكاميرا المباشرة غير متاحة في هذا المتصفح. افتح الموقع في Chrome أو Safari، أو استخدم كاميرا الهاتف بالزر أدناه." : "Live camera is unavailable in this browser. Open Chrome or Safari, or use your phone camera below.");
      return;
    }
    try {
      const media = await navigator.mediaDevices.getUserMedia({ audio: false,
        video: { facingMode: { ideal: "environment" }, width: { ideal: 1920 }, height: { ideal: 1080 } } });
      if (current !== session.current) { media.getTracks().forEach(track => track.stop()); return; }
      stream.current = media;
      setLiveStream(media);
    } catch (cause) {
      if (current !== session.current) return;
      stopStream();
      const denied = cause instanceof DOMException && ["NotAllowedError", "SecurityError"].includes(cause.name);
      setError(denied
        ? (ar ? "اسمح للموقع باستخدام الكاميرا من إعدادات المتصفح ثم أعد المحاولة." : "Allow camera access in your browser settings, then retry.")
        : (ar ? "تعذر فتح الكاميرا. أغلق التطبيقات التي تستخدمها ثم أعد المحاولة." : "Unable to open the camera. Close other apps using it, then retry."));
    }
  }
  async function capture() {
    const live = video.current;
    if (!live || !ready || capturing || !live.videoWidth || !live.videoHeight) return;
    const current = session.current;
    setCapturing(true); setError("");
    try {
      const canvas = document.createElement("canvas");
      const scale = Math.min(1, 2200 / Math.max(live.videoWidth, live.videoHeight));
      canvas.width = Math.round(live.videoWidth * scale); canvas.height = Math.round(live.videoHeight * scale);
      const context = canvas.getContext("2d");
      if (!context) throw new Error("Capture unavailable");
      context.drawImage(live, 0, 0, canvas.width, canvas.height);
      const blob = await new Promise<Blob>((resolve, reject) => canvas.toBlob(value => value ? resolve(value) : reject(new Error("Capture failed")), "image/jpeg", 0.92));
      if (current !== session.current) return;
      const file = new File([blob], `document-${Date.now()}.jpg`, { type: "image/jpeg" });
      preview.current = URL.createObjectURL(file);
      setPhoto(file); setReady(false); stopStream();
    } catch {
      if (current === session.current) setError(ar ? "تعذر التقاط الصورة؛ حاول مجددًا." : "Unable to take the photo. Please retry.");
    } finally { if (current === session.current) setCapturing(false); }
  }
  function select(file: File) { setName(file.name); onSelect(file); }
  function picked(event: ChangeEvent<HTMLInputElement>) {
    const file = event.currentTarget.files?.[0];
    event.currentTarget.value = "";
    if (!file) return;
    closeCamera(); select(file);
  }
  const buttonClass = "min-h-11 rounded-xl border border-slate-300 bg-white px-4 py-2 text-sm font-semibold text-slate-700 disabled:opacity-50";
  return <div className="space-y-2 rounded-2xl border border-dashed border-slate-300 bg-slate-50 p-3">
    <div className="flex flex-wrap gap-2">
      <button ref={trigger} type="button" disabled={disabled} className={buttonClass} onClick={() => void openCamera()}>{ar ? "تصوير بالكاميرا" : "Take a photo"}</button>
      <button type="button" disabled={disabled} className={buttonClass} onClick={() => photos.current?.click()}>{ar ? "اختيار من الصور" : "Choose photos"}</button>
      <button type="button" disabled={disabled} className={buttonClass} onClick={() => files.current?.click()}>{ar ? "رفع من الملفات" : "Choose a file"}</button>
    </div>
    <input ref={nativeCamera} type="file" accept="image/*" capture="environment" disabled={disabled} hidden onChange={picked} />
    <input ref={photos} type="file" accept={imageAccept} disabled={disabled} hidden onChange={picked} />
    <input ref={files} type="file" accept={accept} disabled={disabled} hidden onChange={picked} />
    {(selectedName ?? name) && <p role="status" className="break-words text-sm text-slate-600">{selectedName ?? name}</p>}
    {cameraOpen && createPortal(<div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/70 p-3" dir={ar ? "rtl" : "ltr"}>
      <section role="dialog" aria-modal="true" aria-labelledby={titleId} className="max-h-[95dvh] w-full max-w-xl space-y-4 overflow-y-auto rounded-2xl bg-white p-4">
        <div className="flex items-center justify-between gap-3">
          <h2 id={titleId} className="text-lg font-semibold">{ar ? "تصوير المستند الآن" : "Take a document photo now"}</h2>
          <button ref={cancel} type="button" className={buttonClass} onClick={closeCamera}>{ar ? "إلغاء" : "Cancel"}</button>
        </div>
        {photo && preview.current ? <img src={preview.current} alt={ar ? "معاينة الصورة الملتقطة" : "Captured photo preview"} className="max-h-[55dvh] w-full rounded-xl object-contain" />
          : <video ref={video} autoPlay muted playsInline onLoadedData={() => setReady(true)} className="max-h-[55dvh] w-full rounded-xl bg-black object-contain" />}
        {error ? <p role="alert" className="text-sm text-red-700">{error}</p> : !ready && !photo ? <p role="status">{ar ? "جارٍ فتح الكاميرا؛ وافق على الإذن إذا طُلب منك." : "Opening camera. Allow access if prompted."}</p> : null}
        <p className="text-sm text-slate-500">{ar ? "أظهر المستند كاملًا بإضاءة واضحة. لن تُختار الصورة قبل تأكيدك." : "Keep the whole document visible in good light. Confirm before selecting the photo."}</p>
        <div className="flex flex-wrap gap-2">
          {photo ? <>
            <button type="button" className={buttonClass} onClick={() => { const chosen = photo; closeCamera(); select(chosen); }}>{ar ? "استخدام هذه الصورة" : "Use this photo"}</button>
            <button type="button" className={buttonClass} onClick={() => void openCamera()}>{ar ? "إعادة التصوير" : "Retake photo"}</button>
          </> : <button type="button" disabled={!ready || capturing || !!error} className={buttonClass} onClick={() => void capture()}>{ar ? "التقاط الصورة" : "Capture photo"}</button>}
          {error && <>
            <button type="button" className={buttonClass} onClick={() => void openCamera()}>{ar ? "إعادة المحاولة" : "Retry camera"}</button>
            <button type="button" className={buttonClass} onClick={() => nativeCamera.current?.click()}>{ar ? "استخدام كاميرا الهاتف" : "Use phone camera"}</button>
          </>}
        </div>
      </section>
    </div>, document.body)}
  </div>;
}
