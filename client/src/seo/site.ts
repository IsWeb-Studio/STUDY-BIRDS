import type { Language } from "../context/LanguageContext";

export const SITE_NAME = "Study Birds";
export const BRAND_LOGO_PATH = "/logo.jpeg";
const DEFAULT_SITE_URL = "https://studybirds.net";
const env = import.meta.env as Record<string, string | undefined>;
const configuredSiteUrl =
  env.NEXT_PUBLIC_SITE_URL?.trim().replace(/\/+$/, "") ||
  env.VITE_SITE_URL?.trim().replace(/\/+$/, "");

export const getSiteUrl = () => {
  if (configuredSiteUrl) {
    return configuredSiteUrl;
  }

  return DEFAULT_SITE_URL;
};

export const buildLocalizedUrl = (pathname: string, language: Language) => {
  const url = new URL(getSiteUrl());
  url.pathname = pathname || "/";
  url.searchParams.set("lang", language);
  return url.toString();
};

export const seoText = (language: Language, en: string, ar: string) =>
  language === "ar" ? ar : en;

export const normalizeSeoDescription = (value: string) =>
  value.replace(/\s+/g, " ").trim().slice(0, 180);
