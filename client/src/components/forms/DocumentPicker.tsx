import { useRef, useState, type ChangeEvent } from "react";
import { useLanguage } from "../../hooks/useLanguage";
import { DOCUMENT_UPLOAD_ACCEPT } from "../../constants/upload";

type Props = {
  onSelect: (file: File) => void;
  accept?: string;
  disabled?: boolean;
  selectedName?: string;
};

export function DocumentPicker({ onSelect, accept = DOCUMENT_UPLOAD_ACCEPT, disabled = false, selectedName }: Props) {
  const { language } = useLanguage();
  const ar = language === "ar";
  const camera = useRef<HTMLInputElement>(null);
  const photos = useRef<HTMLInputElement>(null);
  const files = useRef<HTMLInputElement>(null);
  const [name, setName] = useState("");
  const imageAccept = "image/jpeg,image/png,image/webp";
  function picked(event: ChangeEvent<HTMLInputElement>) {
    const file = event.currentTarget.files?.[0];
    event.currentTarget.value = "";
    if (!file) return;
    setName(file.name);
    onSelect(file);
  }
  const buttonClass = "min-h-11 rounded-xl border border-slate-300 bg-white px-4 py-2 text-sm font-semibold text-slate-700 disabled:opacity-50";
  return <div className="space-y-2 rounded-2xl border border-dashed border-slate-300 bg-slate-50 p-3">
    <div className="flex flex-wrap gap-2">
      <button type="button" disabled={disabled} className={buttonClass} onClick={() => camera.current?.click()}>{ar ? "تصوير بالكاميرا" : "Take a photo"}</button>
      <button type="button" disabled={disabled} className={buttonClass} onClick={() => photos.current?.click()}>{ar ? "اختيار من الصور" : "Choose photos"}</button>
      <button type="button" disabled={disabled} className={buttonClass} onClick={() => files.current?.click()}>{ar ? "رفع من الملفات" : "Choose a file"}</button>
    </div>
    <input ref={camera} type="file" accept={imageAccept} capture="environment" disabled={disabled} hidden onChange={picked} />
    <input ref={photos} type="file" accept={imageAccept} disabled={disabled} hidden onChange={picked} />
    <input ref={files} type="file" accept={accept} disabled={disabled} hidden onChange={picked} />
    {(selectedName ?? name) && <p role="status" className="break-words text-sm text-slate-600">{selectedName ?? name}</p>}
  </div>;
}