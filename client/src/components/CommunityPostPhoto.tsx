import { useEffect, useState } from "react";
import { api } from "../lib/api";

export function CommunityPostPhoto({ path, alt }: { path: string; alt: string }) {
  const [url, setUrl] = useState<string>();
  const [failed, setFailed] = useState(false);
  useEffect(() => {
    if (!/^\/community\/posts\/[a-f\d]{24}\/image$/i.test(path)) return;
    const controller = new AbortController();
    let local: string | undefined;
    api.get<Blob>(path, { responseType: 'blob', signal: controller.signal })
      .then(({ data }) => { if (!controller.signal.aborted) { local = URL.createObjectURL(data); setUrl(local); } })
      .catch(() => { if (!controller.signal.aborted) setFailed(true); });
    return () => { controller.abort(); if (local) URL.revokeObjectURL(local); };
  }, [path]);
  if (failed) return <p role="status">{alt}: —</p>;
  return url ? <img src={url} alt={alt} className="mt-3 max-h-96 max-w-full rounded-xl object-contain" /> : <p>{alt}…</p>;
}
