import { useSyncExternalStore } from "react";
import { getTranslationVersion, subscribeTranslations, translateToEnglish } from "../lib/contentTranslation";

type Lang = "ar" | "en";

/** Returns `tr(text)`: in English mode, machine-translates Arabic catalog text (re-rendering when it arrives). */
export const useContentTranslation = (language: Lang) => {
  useSyncExternalStore(subscribeTranslations, getTranslationVersion);
  return (text?: string | null) => (language === "en" ? translateToEnglish(text) : text || "");
};
