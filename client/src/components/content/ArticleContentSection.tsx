import type { ArticleContent } from "../../types";
import { renderRichTextLines } from "../../utils/richText";
import { localizedArticle } from "../../utils/localizedContent";

interface ArticleContentSectionProps {
  article: ArticleContent;
  language: "ar" | "en";
}

export const ArticleContentSection = ({ article: rawArticle, language }: ArticleContentSectionProps) => {
  const article = localizedArticle(language, rawArticle);
  const headings = (article.articleHeadings || []).filter(Boolean);
  const bodies = article.articleBodies || [];

  if (!article.articleTitle && !headings.length && !bodies.filter(Boolean).length) {
    return null;
  }

  return (
    <section className="panel p-8">
      <p className="text-sm font-semibold uppercase tracking-[0.3em] text-brand-700">
        {language === "ar" ? "مقال مختصر" : "Article outline"}
      </p>
      {article.articleTitle ? (
        <h2 className="mt-3 text-2xl font-semibold" style={{ color: article.articleTitleColor || "#0f172a" }}>
          {article.articleTitle}
        </h2>
      ) : null}
      {headings.length ? (
        <div className="mt-6 grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {headings.map((heading, index) => (
            <div key={`${heading}-${index}`} className="rounded-3xl bg-slate-50 p-5">
              <p className="text-lg font-bold leading-8" style={{ color: article.articleHeadingColor || "#0f172a" }}>
                {heading}
              </p>
              {bodies[index] ? (
                <div className="mt-3 space-y-3 text-sm leading-7" style={{ color: article.articleBodyColor || "#475569" }}>
                  {renderRichTextLines(bodies[index])}
                </div>
              ) : null}
            </div>
          ))}
        </div>
      ) : null}
    </section>
  );
};
