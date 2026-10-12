import type { ArticleContent } from "../types";

type Lang = "ar" | "en";

const clean = (value?: string | null) => (typeof value === "string" ? value.trim() : "");

/** Picks the English text when the site language is English and it has been filled in; otherwise the Arabic/base text. */
export const pickLocalized = (language: Lang, base?: string | null, en?: string | null) =>
  language === "en" && clean(en) ? clean(en) : clean(base) || clean(en);

export const universityName = (language: Lang, university?: { name?: string; nameEn?: string } | null) =>
  pickLocalized(language, university?.name, university?.nameEn);

export const programTitle = (language: Lang, program?: { title?: string; titleEn?: string } | null) =>
  pickLocalized(language, program?.title, program?.titleEn);

export const localizedArticle = (language: Lang, article: ArticleContent): ArticleContent => {
  const hasEnglish =
    Boolean(clean(article.articleTitleEn)) ||
    (article.articleHeadingsEn || []).some(Boolean) ||
    (article.articleBodiesEn || []).some(Boolean);
  if (language !== "en" || !hasEnglish) return article;
  return {
    ...article,
    articleTitle: article.articleTitleEn,
    articleHeadings: article.articleHeadingsEn,
    articleBodies: article.articleBodiesEn,
  };
};
