import { api } from "./api";

// On-demand machine translation of catalog text in BOTH directions:
//  - English site language: Arabic text with no hand-written English version -> English
//  - Arabic site language:  English-only text -> Arabic
// The server caches results; this keeps a per-session copy.
export type TranslationTarget = "en" | "ar";

const ARABIC = /[؀-ۿ]/;
const LATIN = /[A-Za-z]/;

/** Only text that is actually in the other language needs translating. */
export const needsTranslation = (text: string, target: TranslationTarget) =>
  target === "en" ? ARABIC.test(text) : LATIN.test(text) && !ARABIC.test(text);

const keyOf = (target: TranslationTarget, text: string) => `${target}|${text}`;
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
const publicTranslate = async (text: string, target: TranslationTarget): Promise<string | null> => {
  try {
    const parts: string[] = [];
    for (const chunk of chunkText(text)) {
      if (!needsTranslation(chunk, target)) { parts.push(chunk); continue; }
      const params = new URLSearchParams({ client: "gtx", sl: target === "en" ? "ar" : "en", tl: target, dt: "t" });
      const response = await fetch(`https://translate.googleapis.com/translate_a/single?${params}`, {
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
  for (const target of ["en", "ar"] as const) {
    const texts = pending.filter((key) => key.startsWith(`${target}|`)).map((key) => key.slice(3));
    for (let index = 0; index < texts.length;) {
      const batch: string[] = [];
      let size = 0;
      while (index < texts.length && batch.length < 40 && (batch.length === 0 || size + texts[index].length < 50000)) {
        size += texts[index].length;
        batch.push(texts[index++]);
      }
      batch.forEach((text) => inFlight.add(keyOf(target, text)));
      try {
        const { data } = await api.post<{ translations?: Array<string | null> }>("/translate", { texts: batch, target });
        batch.forEach((text, i) => {
          const value = data.translations?.[i];
          if (typeof value === "string" && value.trim()) { translated.set(keyOf(target, text), value.trim()); changed = true; }
        });
      } catch {
        // fall through to the public endpoint below
      }
      await Promise.all(batch.filter((text) => !translated.has(keyOf(target, text))).map(async (text) => {
        const value = await publicTranslate(text, target);
        if (value) { translated.set(keyOf(target, text), value); changed = true; }
        else failed.add(keyOf(target, text));
      }));
      batch.forEach((text) => inFlight.delete(keyOf(target, text)));
    }
  }
  if (changed) { version += 1; listeners.forEach((listener) => listener()); }
};

/** The translation if known, otherwise the input (and a fetch is scheduled that re-renders subscribers). */
export const translateText = (text: string | null | undefined, target: TranslationTarget) => {
  const value = (text || "").trim();
  if (!value || !needsTranslation(value, target)) return text || "";
  const key = keyOf(target, value);
  const known = translated.get(key);
  if (known) return known;
  if (!failed.has(key) && !inFlight.has(key) && !queued.has(key)) {
    queued.add(key);
    if (!timer) timer = setTimeout(flush, 150);
  }
  return text || "";
};

/** English text for Arabic input. */
export const translateToEnglish = (text?: string | null) => translateText(text, "en");
/** Arabic text for English-only input. */
export const translateToArabic = (text?: string | null) => translateText(text, "ar");

/** Test helper: forget everything (module state is shared across tests). */
export const resetTranslationsForTest = () => {
  translated.clear(); failed.clear(); inFlight.clear(); queued.clear();
  if (timer) clearTimeout(timer);
  timer = null; version = 0;
};
