import fs from "fs";
import path from "path";

const clientRoot = process.cwd();
const distDir = path.join(clientRoot, "dist");
const envPath = path.join(clientRoot, ".env");

const parseEnvFile = (filePath) => {
  if (!fs.existsSync(filePath)) {
    return {};
  }

  return fs
    .readFileSync(filePath, "utf8")
    .split(/\r?\n/)
    .reduce((accumulator, line) => {
      const trimmed = line.trim();

      if (!trimmed || trimmed.startsWith("#")) {
        return accumulator;
      }

      const separatorIndex = trimmed.indexOf("=");
      if (separatorIndex === -1) {
        return accumulator;
      }

      const key = trimmed.slice(0, separatorIndex).trim();
      const value = trimmed.slice(separatorIndex + 1).trim();
      accumulator[key] = value;
      return accumulator;
    }, {});
};

const envValues = {
  ...parseEnvFile(envPath),
  ...process.env,
};

const siteUrl = (
  envValues.NEXT_PUBLIC_SITE_URL ||
  envValues.VITE_SITE_URL ||
  envValues.SITE_URL ||
  "https://studybirds.net"
).replace(/\/+$/, "");
const apiUrl = (envValues.VITE_API_URL || "https://study-birds-api.onrender.com/api").replace(/\/+$/, "");

const ensureDir = (targetPath) => fs.mkdirSync(targetPath, { recursive: true });
const writeFile = (targetPath, content) => {
  ensureDir(path.dirname(targetPath));
  fs.writeFileSync(targetPath, content, "utf8");
};

const escapeHtml = (value = "") =>
  String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");

const setOrInsert = (html, pattern, replacement, fallbackTag) => {
  if (pattern.test(html)) {
    return html.replace(pattern, replacement);
  }

  return html.replace("</head>", `${fallbackTag}\n</head>`);
};

const buildArticleHtml = (template, article) => {
  const seo = article.resolvedSeo || {};
  const schema = article.articleSchema
    ? `<script type="application/ld+json">${JSON.stringify(article.articleSchema)}</script>`
    : "";

  let html = template;
  html = html.replace(/<title>[\s\S]*?<\/title>/i, `<title>${escapeHtml(seo.seoTitle || article.title)}</title>`);
  html = setOrInsert(
    html,
    /<meta\s+name="description"[^>]*>/i,
    `<meta name="description" content="${escapeHtml(seo.metaDescription || article.summary)}">`,
    `<meta name="description" content="${escapeHtml(seo.metaDescription || article.summary)}">`
  );
  html = setOrInsert(
    html,
    /<link\s+rel="canonical"[^>]*>/i,
    `<link rel="canonical" href="${escapeHtml(seo.canonicalUrl || `${siteUrl}/blog/${article.slug}`)}">`,
    `<link rel="canonical" href="${escapeHtml(seo.canonicalUrl || `${siteUrl}/blog/${article.slug}`)}">`
  );

  const extraTags = [
    `<meta property="og:title" content="${escapeHtml(seo.ogTitle || article.title)}">`,
    `<meta property="og:description" content="${escapeHtml(seo.ogDescription || seo.metaDescription || article.summary)}">`,
    `<meta property="og:image" content="${escapeHtml(seo.ogImage || article.image || "")}">`,
    `<meta property="og:url" content="${escapeHtml(seo.canonicalUrl || `${siteUrl}/blog/${article.slug}`)}">`,
    `<meta property="og:type" content="article">`,
    `<meta name="twitter:card" content="summary_large_image">`,
    `<meta name="twitter:title" content="${escapeHtml(seo.twitterTitle || seo.ogTitle || article.title)}">`,
    `<meta name="twitter:description" content="${escapeHtml(seo.twitterDescription || seo.ogDescription || seo.metaDescription || article.summary)}">`,
    `<meta name="twitter:image" content="${escapeHtml(seo.twitterImage || seo.ogImage || article.image || "")}">`,
    `<meta name="robots" content="${escapeHtml(`${seo.robotsIndex || "index"}, ${seo.robotsFollow || "follow"}, max-image-preview:large`)}">`,
    schema,
  ]
    .filter(Boolean)
    .join("\n");

  return html.replace("</head>", `${extraTags}\n</head>`);
};

const buildCategoryHtml = (template, categoryName, categoryUrl) => {
  const title = `${categoryName} | Study Birds`;
  const description = `Browse ${categoryName} articles in the Study Birds blog.`;
  let html = template.replace(/<title>[\s\S]*?<\/title>/i, `<title>${escapeHtml(title)}</title>`);
  html = setOrInsert(
    html,
    /<meta\s+name="description"[^>]*>/i,
    `<meta name="description" content="${escapeHtml(description)}">`,
    `<meta name="description" content="${escapeHtml(description)}">`
  );
  html = setOrInsert(
    html,
    /<link\s+rel="canonical"[^>]*>/i,
    `<link rel="canonical" href="${escapeHtml(categoryUrl)}">`,
    `<link rel="canonical" href="${escapeHtml(categoryUrl)}">`
  );
  return html;
};

const buildListingHtml = (template) => {
  const title = "Study Abroad Blog | Study Birds";
  const description = "Explore study abroad articles, university updates, and student guidance from Study Birds.";
  let html = template.replace(/<title>[\s\S]*?<\/title>/i, `<title>${escapeHtml(title)}</title>`);
  html = setOrInsert(
    html,
    /<meta\s+name="description"[^>]*>/i,
    `<meta name="description" content="${escapeHtml(description)}">`,
    `<meta name="description" content="${escapeHtml(description)}">`
  );
  html = setOrInsert(
    html,
    /<link\s+rel="canonical"[^>]*>/i,
    `<link rel="canonical" href="${siteUrl}/blog">`,
    `<link rel="canonical" href="${siteUrl}/blog">`
  );
  return html;
};

const publicRoutes = [
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
  "/privacy-policy",
  "/partner",
];

const buildSitemapXml = (articles) => {
  const categoryUrls = [...new Set(
    articles
      .map((article) => article.resolvedSeo?.categorySlug)
      .filter(Boolean)
  )].map((categorySlug) => `${siteUrl}/blog/category/${categorySlug}`);
  const urls = [
    ...publicRoutes.map((route) => `${siteUrl}${route}`),
    ...articles.map((article) => article.resolvedSeo?.canonicalUrl || `${siteUrl}/blog/${article.slug}`),
    ...categoryUrls,
  ];

  return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls
  .map(
    (url) => `  <url>
    <loc>${escapeHtml(url)}</loc>
  </url>`
  )
  .join("\n")}
</urlset>
`;
};

const robotsTxt = `User-agent: *
Allow: /
Disallow: /admin
Disallow: /student
Disallow: /login
Disallow: /register
Disallow: /forgot-password
Disallow: /api/

Sitemap: ${siteUrl}/sitemap.xml
`;

const main = async () => {
  const templatePath = path.join(distDir, "index.html");

  if (!fs.existsSync(templatePath)) {
    throw new Error(`Missing build template at ${templatePath}`);
  }

  const template = fs.readFileSync(templatePath, "utf8");
  let articles = [];

  try {
    const response = await fetch(`${apiUrl}/content/blog`);
    if (response.ok) {
      articles = await response.json();
    }
  } catch (error) {
    console.warn("Unable to fetch blog articles for static SEO generation.", error);
  }

  writeFile(path.join(distDir, "robots.txt"), robotsTxt);
  writeFile(path.join(distDir, "sitemap.xml"), buildSitemapXml(articles));
  writeFile(path.join(distDir, "blog", "index.html"), buildListingHtml(template));

  const categoryMap = new Map();

  for (const article of articles) {
    const articleHtml = buildArticleHtml(template, article);
    writeFile(path.join(distDir, "blog", article.slug, "index.html"), articleHtml);

    if (article.resolvedSeo?.categorySlug) {
      categoryMap.set(article.resolvedSeo.categorySlug, article.resolvedSeo.category || article.resolvedSeo.categorySlug);
    }
  }

  for (const [categorySlug, categoryName] of categoryMap.entries()) {
    const categoryUrl = `${siteUrl}/blog/category/${categorySlug}`;
    const categoryHtml = buildCategoryHtml(template, categoryName, categoryUrl);
    writeFile(path.join(distDir, "blog", "category", categorySlug, "index.html"), categoryHtml);
  }
};

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
