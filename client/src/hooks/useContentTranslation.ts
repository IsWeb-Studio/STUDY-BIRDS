import { useSyncExternalStore } from "react";
import { getTranslationVersion, subscribeTranslations, translateToArabic, translateToEnglish } from "../lib/contentTranslation";

type Lang = "ar" | "en";

/**
 * Returns `tr(text)`: machine-translates catalog text into the site language -
 * Arabic text -> English in English mode, English-only text -> Arabic in Arabic
 * mode (re-rendering when the translation arrives).
 */
export const useContentTranslation = (language: Lang) => {
  useSyncExternalStore(subscribeTranslations, getTranslationVersion);
  return (text?: string | null) => (language === "en" ? translateToEnglish(text) : translateToArabic(text));
};
