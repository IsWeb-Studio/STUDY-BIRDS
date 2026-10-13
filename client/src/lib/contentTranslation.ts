import { api } from "./api";

// On-demand machine translation of Arabic catalog text that has no hand-written
// English version. The server caches results; this keeps a per-session copy.
const ARABIC = /[؀-ۿ]/;
const translated = new Map<string, string>();
const failed = new Set<string>();
const inFlight = new Set<string>();
const queued = new Set<string>();
const listeners = new Set<() => void>();
let version = 0;
let timer: ReturnType<typeof setTimeout> | null = null;

export const subscribeTranslations = (listener: () => void) => {
  listeners.add(listener);
  return () => { listeners.delete(listener); };
};
export const getTranslationVersion = () => version;

const chunkText = (text: string) => {
  const chunks: string[] = [];
  let current = "";
  for (const line of text.split("\n")) {
    if (current && current.length + line.length + 1 > 1200) { chunks.push(current); current = line; }
    else current = current ? `${current}\n${line}` : line;
  }
  if (current) chunks.push(current);
  return chunks;
};

// Used when the site's own /translate endpoint is unavailable (older deployment, no provider configured).
const publicTranslate = async (text: string): Promise<string | null> => {
  try {
    const parts: string[] = [];
    for (const chunk of chunkText(text)) {
      if (!ARABIC.test(chunk)) { parts.push(chunk); continue; }
      const response = await fetch("https://translate.googleapis.com/translate_a/single?client=gtx&sl=ar&tl=en&dt=t", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ q: chunk }),
      });
      if (!response.ok) return null;
      const data = await response.json();
      if (!Array.isArray(data?.[0])) return null;
      parts.push((data[0] as unknown[]).map((segment) => (Array.isArray(segment) && typeof segment[0] === "string" ? segment[0] : "")).join(""));
    }
    const result = parts.join("\n").trim();
    return result || null;
  } catch {
    return null;
  }
};

const flush = async () => {
  timer = null;
  const pending = [...queued];
  queued.clear();
  let changed = false;
  for (let index = 0; index < pending.length;) {
    const batch: string[] = [];
    let size = 0;
    while (index < pending.length && batch.length < 40 && (batch.length === 0 || size + pending[index].length < 50000)) {
      size += pending[index].length;
      batch.push(pending[index++]);
    }
    batch.forEach((text) => inFlight.add(text));
    try {
      const { data } = await api.post<{ translations?: Array<string | null> }>("/translate", { texts: batch, target: "en" });
      batch.forEach((text, i) => {
        const value = data.translations?.[i];
        if (typeof value === "string" && value.trim()) { translated.set(text, value.trim()); changed = true; }
      });
    } catch {
      // fall through to the public endpoint below
    }
    await Promise.all(batch.filter((text) => !translated.has(text)).map(async (text) => {
      const value = await publicTranslate(text);
      if (value) { translated.set(text, value); changed = true; }
      else failed.add(text);
    }));
    batch.forEach((text) => inFlight.delete(text));
  }
  if (changed) { version += 1; listeners.forEach((listener) => listener()); }
};

/** English text for Arabic input: the translation if known, otherwise the input (and a fetch is scheduled). */
export const translateToEnglish = (text?: string | null) => {
  const value = (text || "").trim();
  if (!value || !ARABIC.test(value)) return text || "";
  const known = translated.get(value);
  if (known) return known;
  if (!failed.has(value) && !inFlight.has(value) && !queued.has(value)) {
    queued.add(value);
    if (!timer) timer = setTimeout(flush, 150);
  }
  return text || "";
};
