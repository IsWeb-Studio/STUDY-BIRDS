import type { ArticleContent } from "../types";

type Lang = "ar" | "en";
/** Machine-translation fallback from useContentTranslation(); identity when omitted. */
type Tr = (text?: string | null) => string;

const clean = (value?: string | null) => (typeof value === "string" ? value.trim() : "");
const identity: Tr = (text) => text || "";

/** English text when the site language is English (hand-written first, then machine translation); otherwise the Arabic/base text. */
export const pickLocalized = (language: Lang, base?: string | null, en?: string | null, tr: Tr = identity) => {
  if (language === "en") return clean(en) || tr(clean(base));
  return clean(base) || clean(en);
};

export const universityName = (language: Lang, university?: { name?: string; nameEn?: string } | null, tr: Tr = identity) =>
  pickLocalized(language, university?.name, university?.nameEn, tr);

export const programTitle = (language: Lang, program?: { title?: string; titleEn?: string } | null, tr: Tr = identity) =>
  pickLocalized(language, program?.title, program?.titleEn, tr);

export const localizedArticle = (language: Lang, article: ArticleContent, tr: Tr = identity): ArticleContent => {
  if (language !== "en") return article;
  const hasEnglish =
    Boolean(clean(article.articleTitleEn)) ||
    (article.articleHeadingsEn || []).some(Boolean) ||
    (article.articleBodiesEn || []).some(Boolean);
  if (hasEnglish) {
    return {
      ...article,
      articleTitle: article.articleTitleEn,
      articleHeadings: article.articleHeadingsEn,
      articleBodies: article.articleBodiesEn,
    };
  }
  return {
    ...article,
    articleTitle: tr(article.articleTitle),
    articleHeadings: (article.articleHeadings || []).map((item) => tr(item)),
    articleBodies: (article.articleBodies || []).map((item) => tr(item)),
  };
};
