import { useState } from "react";
import { api } from "../lib/api";
import { useAuth } from "../hooks/useAuth";
import { useLanguage } from "../hooks/useLanguage";
import { getErrorMessage } from "../utils/errors";

export function AdminCommunityComposer({ onPublished }: { onPublished: () => void }) {
  const { user } = useAuth();
  const { language } = useLanguage();
  const ar = language === "ar";
  const [body, setBody] = useState("");
  const [photo, setPhoto] = useState<File>();
  const [operation, setOperation] = useState(() => crypto.randomUUID());
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [posted, setPosted] = useState(false);
  if (user?.role !== "admin") return null;
  return <details className="rounded-2xl border border-green-200 bg-white p-4">
    <summary className="cursor-pointer font-semibold">{ar ? "منشور إدارة جديد" : "New administration post"}</summary>
    <form className="mt-4 space-y-3" onSubmit={async (event) => {
      event.preventDefault();
      if (busy || !body.trim()) return;
      if (photo && (!['image/jpeg', 'image/png', 'image/webp'].includes(photo.type) || photo.size > 5 * 1024 * 1024)) {
        setError(ar ? "اختر صورة JPEG أو PNG أو WebP بحجم لا يتجاوز 5 ميجابايت." : "Choose a JPEG, PNG or WebP image up to 5 MB.");
        return;
      }
      setBusy(true); setError(""); setPosted(false);
      try {
        if (photo) {
          const data = new FormData(); data.set('body', body.trim()); data.set('operationId', operation); data.set('file', photo);
          await api.post('/community/posts/image', data);
        } else await api.post('/community/posts', { body: body.trim(), operationId: operation });
        setBody(""); setPhoto(undefined); setOperation(crypto.randomUUID()); setPosted(true); onPublished();
      } catch (failure) { setError(getErrorMessage(failure, ar ? 'تعذر نشر المنشور' : 'Could not publish post')); }
      finally { setBusy(false); }
    }}>
      <p className="text-sm text-slate-500">{ar ? "يظهر المنشور باسمك مع علامة الإدارة في المجتمع وتبويب منشورات الإدارة." : "This post appears under your name with the administration badge and in Administration posts."}</p>
      <textarea required maxLength={5000} disabled={busy} value={body} aria-label={ar ? "نص المنشور" : "Post text"}
        className="min-h-32 w-full rounded-xl border p-3" onChange={(event) => { setBody(event.target.value); setOperation(crypto.randomUUID()); setPosted(false); }} />
      <label className="block text-sm">{ar ? "صورة اختيارية" : "Optional photo"}
        <input key={photo ? 'selected-photo' : operation} type="file" accept="image/jpeg,image/png,image/webp" disabled={busy}
          onChange={(event) => { setPhoto(event.target.files?.[0]); setOperation(crypto.randomUUID()); setPosted(false); }} className="mt-2 block max-w-full" />
      </label>
      {photo && <p className="text-sm">{photo.name} <button type="button" disabled={busy} className="underline" onClick={() => { setPhoto(undefined); setOperation(crypto.randomUUID()); }}>{ar ? 'إزالة الصورة' : 'Remove photo'}</button></p>}
      {error && <p role="alert" className="text-sm text-red-700">{error}</p>}
      {posted && <p role="status" className="text-sm text-green-700">{ar ? "تم نشر منشور الإدارة" : "Administration post published"}</p>}
      <button type="submit" disabled={busy || !body.trim()} className="rounded-xl bg-brand-primary px-5 py-2 text-white disabled:opacity-50">{busy ? (ar ? "جارٍ النشر…" : "Publishing…") : (ar ? "نشر" : "Publish")}</button>
    </form>
  </details>;
}
