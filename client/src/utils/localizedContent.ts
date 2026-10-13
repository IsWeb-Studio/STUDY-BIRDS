import type { ArticleContent } from "../types";

type Lang = "ar" | "en";
/** Machine-translation fallback from useContentTranslation(); identity when omitted. */
type Tr = (text?: string | null) => string;

const clean = (value?: string | null) => (typeof value === "string" ? value.trim() : "");
const identity: Tr = (text) => text || "";

/**
 * Text in the site language. English: hand-written English first, then machine
 * translation of the Arabic. Arabic: the Arabic/base text, falling back to the
 * English text; English-only content is machine-translated into Arabic.
 */
export const pickLocalized = (language: Lang, base?: string | null, en?: string | null, tr: Tr = identity) => {
  if (language === "en") return clean(en) || tr(clean(base));
  return tr(clean(base) || clean(en));
};

export const universityName = (language: Lang, university?: { name?: string; nameEn?: string } | null, tr: Tr = identity) =>
  pickLocalized(language, university?.name, university?.nameEn, tr);

export const programTitle = (language: Lang, program?: { title?: string; titleEn?: string } | null, tr: Tr = identity) =>
  pickLocalized(language, program?.title, program?.titleEn, tr);

export const localizedArticle = (language: Lang, article: ArticleContent, tr: Tr = identity): ArticleContent => {
  if (language !== "en") {
    // Arabic mode: the Arabic text, or the English one (machine-translated into Arabic).
    const list = (arabic?: string[], english?: string[]) => ((arabic || []).some(Boolean) ? arabic || [] : english || []);
    return {
      ...article,
      articleTitle: tr(clean(article.articleTitle) || clean(article.articleTitleEn)),
      articleHeadings: list(article.articleHeadings, article.articleHeadingsEn).map((item) => tr(item)),
      articleBodies: list(article.articleBodies, article.articleBodiesEn).map((item) => tr(item)),
    };
  }
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
