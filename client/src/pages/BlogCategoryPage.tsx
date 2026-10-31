import { useEffect, useMemo, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { Seo } from "../components/seo/Seo";
import { useLanguage } from "../hooks/useLanguage";
import { contentService } from "../services/contentService";
import type { ExhibitionArticle } from "../types";
import { getErrorMessage } from "../utils/errors";
import { getPaginatedItems } from "../utils/pagination";

const slugifyCategory = (value: string) =>
  value
    .normalize("NFKC")
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, "-")
    .replace(/^-+|-+$/g, "");

export const BlogCategoryPage = () => {
  const { language } = useLanguage();
  const { categorySlug = "" } = useParams();
  const [articles, setArticles] = useState<ExhibitionArticle[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const loadArticles = async () => {
      setLoading(true);
      setError("");

      try {
        setArticles(getPaginatedItems(await contentService.getExhibitionArticles({ page: 1, limit: 24, paginate: true })));
      } catch (loadError) {
        setError(
          getErrorMessage(
            loadError,
            language === "ar" ? "تعذر تحميل تصنيف المدونة." : "Unable to load this blog category."
          )
        );
      } finally {
        setLoading(false);
      }
    };

    loadArticles();
  }, [language]);

  const filteredArticles = useMemo(
    () => articles.filter((article) => slugifyCategory(article.category || "") === categorySlug),
    [articles, categorySlug]
  );
  const categoryName = filteredArticles[0]?.category || categorySlug.replace(/-/g, " ");

  return (
    <div className="space-y-6">
      <Seo
        title={language === "ar" ? `تصنيف ${categoryName}` : `${categoryName} Articles`}
        description={
          language === "ar"
            ? `تصفح مقالات تصنيف ${categoryName} داخل مدونة Study Birds.`
            : `Browse ${categoryName} articles in the Study Birds blog.`
        }
        canonicalPath={`/blog/category/${categorySlug}`}
      />

      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-sm font-semibold uppercase tracking-[0.2em] text-brand-700">
            {language === "ar" ? "تصنيف المدونة" : "Blog category"}
          </p>
          <h1 className="mt-2 text-3xl font-semibold text-slate-900">{categoryName}</h1>
        </div>
        <Link to="/blog" className="rounded-full border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700">
          {language === "ar" ? "العودة إلى المدونة" : "Back to blog"}
        </Link>
      </div>

      {loading ? <div className="panel p-8 text-sm text-slate-500">{language === "ar" ? "جاري التحميل..." : "Loading..."}</div> : null}
      {error ? <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div> : null}

      {!loading && !error && filteredArticles.length === 0 ? (
        <div className="panel p-8 text-sm text-slate-600">
          {language === "ar" ? "لا توجد مقالات في هذا التصنيف حاليًا." : "There are no articles in this category yet."}
        </div>
      ) : null}

      <div className="grid gap-4">
        {filteredArticles.map((article) => (
          <Link
            key={article._id}
            to={`/blog/${article.slug}`}
            className="panel block p-6 transition hover:-translate-y-0.5 hover:shadow-lg"
          >
            <h2 className="text-xl font-semibold text-slate-900">{article.title}</h2>
            <p className="mt-3 text-sm leading-7 text-slate-600">
              {article.resolvedSeo?.metaDescription || article.summary}
            </p>
          </Link>
        ))}
      </div>
    </div>
  );
};
