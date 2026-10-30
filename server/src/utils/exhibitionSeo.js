const ExhibitionArticle = require("../models/ExhibitionArticle");

const SITE_NAME = process.env.SITE_NAME || "COVEY";
const DEFAULT_SITE_URL = "https://studybirds.net";

const getSiteUrl = () =>
  String(
    process.env.SITE_URL ||
      process.env.NEXT_PUBLIC_SITE_URL ||
      process.env.CLIENT_URL ||
      DEFAULT_SITE_URL
  )
    .trim()
    .replace(/\/+$/, "");

const toPlainText = (value) =>
  String(value || "")
    .replace(/\[button:[^\]]+\]/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();

const clipText = (value, maxLength) => {
  const normalized = toPlainText(value);

  if (normalized.length <= maxLength) {
    return normalized;
  }

  return `${normalized.slice(0, Math.max(0, maxLength - 1)).trim()}…`;
};

const normalizeKeywords = (value) => {
  if (Array.isArray(value)) {
    return value
      .map((item) => String(item || "").trim())
      .filter(Boolean);
  }

  return String(value || "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
};

const normalizeSlugInput = (value) =>
  String(value || "")
    .trim()
    .normalize("NFKC")
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, "-")
    .replace(/^-+|-+$/g, "");

const buildUniqueSlug = async (title, currentId, preferredSlug) => {
  const candidate = normalizeSlugInput(preferredSlug || title || "blog");
  const baseSlug = candidate || "blog";
  let slug = baseSlug;
  let suffix = 2;

  while (
    await ExhibitionArticle.exists({
      slug,
      ...(currentId ? { _id: { $ne: currentId } } : {}),
    })
  ) {
    slug = `${baseSlug}-${suffix}`;
    suffix += 1;
  }

  return slug;
};

const encodePathSegment = (value) => encodeURIComponent(String(value || "").trim());

const buildArticleUrl = (slug) => `${getSiteUrl()}/blog/${encodePathSegment(slug)}`;
const buildCategoryUrl = (categorySlug) => `${getSiteUrl()}/blog/category/${encodePathSegment(categorySlug)}`;

const resolveExhibitionSeo = (article) => {
  const slug = String(article.slug || "").trim();
  const title = String(article.title || "").trim();
  const summary = String(article.summary || "").trim();
  const body = String(article.body || "").trim();
  const image = String(article.image || "").trim();
  const category = String(article.category || "").trim();
  const categorySlug = normalizeSlugInput(category);
  const descriptionSource = article.metaDescription || summary || body;
  const description = clipText(descriptionSource, 160);
  const articleUrl = buildArticleUrl(slug);
  const canonicalUrl = String(article.canonicalUrl || "").trim() || articleUrl;
  const seoTitle = String(article.seoTitle || "").trim() || `${title} | ${SITE_NAME}`;
  const ogTitle = String(article.ogTitle || "").trim() || title;
  const ogDescription = String(article.ogDescription || "").trim() || description;
  const ogImage = String(article.ogImage || "").trim() || image;
  const twitterTitle = String(article.twitterTitle || "").trim() || ogTitle;
  const twitterDescription =
    String(article.twitterDescription || "").trim() || ogDescription;
  const twitterImage = String(article.twitterImage || "").trim() || ogImage;
  const imageAltText = String(article.imageAltText || "").trim() || title;
  const publishedAt = article.publishedAt || article.createdAt || null;
  const updatedAt = article.seoUpdatedAt || article.updatedAt || publishedAt || null;
  const authorName = String(article.authorName || "").trim() || SITE_NAME;
  const focusKeyword = String(article.focusKeyword || "").trim();
  const seoKeywords = normalizeKeywords(article.seoKeywords);
  const robotsIndex = article.robotsIndex === "noindex" ? "noindex" : "index";
  const robotsFollow = article.robotsFollow === "nofollow" ? "nofollow" : "follow";

  return {
    articleUrl,
    canonicalUrl,
    seoTitle,
    metaDescription: description,
    focusKeyword,
    seoKeywords,
    ogTitle,
    ogDescription,
    ogImage,
    twitterTitle,
    twitterDescription,
    twitterImage,
    imageAltText,
    robotsIndex,
    robotsFollow,
    category,
    categorySlug,
    authorName,
    publishedAt,
    updatedAt,
  };
};

const buildExhibitionPayload = async (body, currentArticle = null) => {
  const title = String(body.title || currentArticle?.title || "").trim();
  const summary = String(body.summary || currentArticle?.summary || "").trim();
  const articleBody = String(body.body || currentArticle?.body || "").trim();
  const customSlug = normalizeSlugInput(body.customSlug);
  const slug = await buildUniqueSlug(title, currentArticle?._id, customSlug);

  return {
    customSlug,
    slug,
    seoTitle: String(body.seoTitle || "").trim(),
    metaDescription: String(body.metaDescription || "").trim(),
    focusKeyword: String(body.focusKeyword || "").trim(),
    seoKeywords: normalizeKeywords(body.seoKeywords),
    canonicalUrl: String(body.canonicalUrl || "").trim(),
    ogTitle: String(body.ogTitle || "").trim(),
    ogDescription: String(body.ogDescription || "").trim(),
    ogImage: String(body.ogImage || "").trim(),
    twitterTitle: String(body.twitterTitle || "").trim(),
    twitterDescription: String(body.twitterDescription || "").trim(),
    twitterImage: String(body.twitterImage || "").trim(),
    imageAltText: String(body.imageAltText || "").trim(),
    robotsIndex: body.robotsIndex === "noindex" ? "noindex" : "index",
    robotsFollow: body.robotsFollow === "nofollow" ? "nofollow" : "follow",
    category: String(body.category || "").trim(),
    authorName: String(body.authorName || "").trim(),
    publishedAt: body.publishedAt ? new Date(body.publishedAt) : currentArticle?.publishedAt || null,
    seoUpdatedAt: body.seoUpdatedAt ? new Date(body.seoUpdatedAt) : new Date(),
    title,
    summary,
    body: articleBody,
  };
};

const buildArticleSchema = (article) => {
  const seo = resolveExhibitionSeo(article);

  return {
    "@context": "https://schema.org",
    "@type": "Article",
    headline: seo.ogTitle,
    description: seo.metaDescription,
    image: seo.ogImage ? [seo.ogImage] : [],
    author: {
      "@type": "Person",
      name: seo.authorName,
    },
    publisher: {
      "@type": "Organization",
      name: SITE_NAME,
    },
    datePublished: seo.publishedAt ? new Date(seo.publishedAt).toISOString() : undefined,
    dateModified: seo.updatedAt ? new Date(seo.updatedAt).toISOString() : undefined,
    mainEntityOfPage: seo.canonicalUrl,
  };
};

const importantPaths = [
  "/",
  "/blog",
  "/programs",
  "/universities",
  "/destinations",
  "/services",
  "/about",
  "/our-story",
  "/our-event",
  "/contact",
  "/partner",
];

const buildSitemapXml = (articles) => {
  const siteUrl = getSiteUrl();
  const staticUrls = importantPaths.map((pathname) => ({
    loc: `${siteUrl}${pathname}`,
    lastmod: new Date().toISOString(),
  }));

  const articleUrls = articles.map((article) => {
    const seo = resolveExhibitionSeo(article);
    return {
      loc: seo.canonicalUrl,
      lastmod: new Date(seo.updatedAt || article.updatedAt || article.createdAt || Date.now()).toISOString(),
    };
  });

  const categoryUrls = [...new Set(
    articles
      .map((article) => resolveExhibitionSeo(article))
      .filter((seo) => seo.categorySlug)
      .map((seo) => seo.categorySlug)
  )].map((categorySlug) => ({
    loc: buildCategoryUrl(categorySlug),
    lastmod: new Date().toISOString(),
  }));

  const urls = [...staticUrls, ...articleUrls, ...categoryUrls];

  return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls
  .map(
    (entry) => `  <url>
    <loc>${entry.loc}</loc>
    <lastmod>${entry.lastmod}</lastmod>
  </url>`
  )
  .join("\n")}
</urlset>
`;
};

const buildRobotsTxt = () => `User-agent: *
Allow: /
Disallow: /admin
Disallow: /student
Disallow: /login
Disallow: /register
Disallow: /forgot-password
Disallow: /api/

Sitemap: ${getSiteUrl()}/sitemap.xml
`;

const attachResolvedSeo = (article) => {
  if (!article) {
    return article;
  }

  return {
    ...article,
    resolvedSeo: resolveExhibitionSeo(article),
    articleSchema: buildArticleSchema(article),
  };
};

module.exports = {
  SITE_NAME,
  attachResolvedSeo,
  buildArticleSchema,
  buildExhibitionPayload,
  buildRobotsTxt,
  buildSitemapXml,
  buildUniqueSlug,
  clipText,
  getSiteUrl,
  normalizeKeywords,
  normalizeSlugInput,
  resolveExhibitionSeo,
  toPlainText,
};
