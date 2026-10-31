import { AlertTriangle, CalendarDays, PencilLine, Plus, Search, Trash2, Video } from "lucide-react";
import { useEffect, useMemo, useState, type FormEvent } from "react";
import { Link } from "react-router-dom";
import { ArticleContentFields } from "../../components/admin/ArticleContentFields";
import {
  createEmptyArticleBodies,
  createEmptyArticleHeadings,
  normalizeArticleBodies,
  normalizeArticleHeadings,
} from "../../constants/articleContent";
import { useLanguage } from "../../hooks/useLanguage";
import { getApiAssetUrl } from "../../lib/api";
import { getSiteUrl } from "../../seo/site";
import { adminService } from "../../services/adminService";
import type { Country, ExhibitionArticle } from "../../types";
import { getErrorMessage } from "../../utils/errors";
import { formatDate } from "../../utils/format";
import { getYoutubeEmbedUrl } from "../../utils/youtube";

type ExhibitionForm = {
  title: string;
  summary: string;
  body: string;
  image: string;
  titleColor: string;
  articleTitle: string;
  articleTitleColor: string;
  articleHeadingColor: string;
  articleBodyColor: string;
  articleHeadings: string[];
  articleBodies: string[];
  youtubeUrl: string;
  featured: boolean;
  published: boolean;
  seoTitle: string;
  metaDescription: string;
  focusKeyword: string;
  seoKeywordsInput: string;
  customSlug: string;
  canonicalUrl: string;
  ogTitle: string;
  ogDescription: string;
  ogImage: string;
  twitterTitle: string;
  twitterDescription: string;
  twitterImage: string;
  imageAltText: string;
  robotsIndex: "index" | "noindex";
  robotsFollow: "follow" | "nofollow";
  category: string;
  country: string;
  authorName: string;
  publishedAt: string;
  seoUpdatedAt: string;
};

const SITE_NAME = "Study Birds";
const SITE_URL = getSiteUrl();

const emptyForm: ExhibitionForm = {
  title: "",
  summary: "",
  body: "",
  image: "",
  titleColor: "#0f172a",
  articleTitle: "",
  articleTitleColor: "#0f172a",
  articleHeadingColor: "#0f172a",
  articleBodyColor: "#475569",
  articleHeadings: createEmptyArticleHeadings(),
  articleBodies: createEmptyArticleBodies(),
  youtubeUrl: "",
  featured: true,
  published: true,
  seoTitle: "",
  metaDescription: "",
  focusKeyword: "",
  seoKeywordsInput: "",
  customSlug: "",
  canonicalUrl: "",
  ogTitle: "",
  ogDescription: "",
  ogImage: "",
  twitterTitle: "",
  twitterDescription: "",
  twitterImage: "",
  imageAltText: "",
  robotsIndex: "index",
  robotsFollow: "follow",
  category: "",
  country: "",
  authorName: "",
  publishedAt: "",
  seoUpdatedAt: "",
};

const appendArticleItem = (items: string[]) => [...items, ""];
const removeArticleItem = (items: string[], index: number) =>
  items.length > 1 ? items.filter((_, itemIndex) => itemIndex !== index) : items;

const toPlainText = (value: string) =>
  value
    .replace(/\[button:[^\]]+\]/gi, " ")
    .replace(/\s+/g, " ")
    .trim();

const clipText = (value: string, maxLength: number) => {
  const normalized = toPlainText(value);
  if (normalized.length <= maxLength) {
    return normalized;
  }
  return `${normalized.slice(0, Math.max(0, maxLength - 1)).trim()}...`;
};

const slugifyValue = (value: string) =>
  value
    .normalize("NFKC")
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, "-")
    .replace(/^-+|-+$/g, "");

const toDatetimeLocalValue = (value?: string | null) => {
  if (!value) {
    return "";
  }

  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return "";
  }

  const offset = parsed.getTimezoneOffset();
  const localDate = new Date(parsed.getTime() - offset * 60000);
  return localDate.toISOString().slice(0, 16);
};

const isDemoLikeArticle = (article: ExhibitionArticle) =>
  /(demo|test|sample|dummy)/i.test(
    [article.title, article.summary, article.slug, article.category].filter(Boolean).join(" ")
  );

const mapSectionsToArticleContent = (article: ExhibitionArticle) => {
  const headings = article.articleHeadings?.length
    ? article.articleHeadings
    : (article.sections || []).map((section) => section.title || "").filter((item) => item.trim());
  const bodies = article.articleBodies?.length
    ? article.articleBodies
    : (article.sections || []).map((section) => section.body || "");
  const articleItemCount = Math.max(1, headings.length || 0, bodies.length || 0);

  return {
    articleTitle: article.articleTitle || "",
    articleTitleColor: article.articleTitleColor || "#0f172a",
    articleHeadingColor: article.articleHeadingColor || "#0f172a",
    articleBodyColor: article.articleBodyColor || "#475569",
    articleHeadings: normalizeArticleHeadings(headings, articleItemCount),
    articleBodies: normalizeArticleBodies(bodies, articleItemCount),
  };
};

export const AdminExhibitionsPage = () => {
  const { language } = useLanguage();
  const [countries, setCountries] = useState<Country[]>([]);
  const [articles, setArticles] = useState<ExhibitionArticle[]>([]);
  const [form, setForm] = useState<ExhibitionForm>(emptyForm);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [formError, setFormError] = useState("");
  const [uploadingImage, setUploadingImage] = useState(false);
  const labels = {
    title: language === "ar" ? "إدارة محطة المعارض" : "Blog manager",
    intro:
      language === "ar"
        ? "أضف المقال مع محتواه وحقول SEO اليدوية أو اتركها فارغة ليتم توليدها تلقائيًا."
        : "Add the article content and optional SEO fields, or leave them blank to auto-generate.",
    preview: language === "ar" ? "فتح محطة المعارض" : "Open blog",
    create: language === "ar" ? "إضافة المقال" : "Create article",
    update: language === "ar" ? "تحديث المقال" : "Update article",
    reset: language === "ar" ? "مسح النموذج" : "Clear form",
  };

  const loadArticles = async () => {
    const [articlesData, countriesData] = await Promise.all([adminService.getExhibitions(), adminService.getCountries()]);
    setArticles(articlesData);
    setCountries(countriesData);
  };

  useEffect(() => {
    loadArticles().catch((error) =>
      setFormError(
        getErrorMessage(
          error,
          language === "ar" ? "تعذر تحميل مقالات محطة المعارض." : "Unable to load blog articles."
        )
      )
    );
  }, [language]);

  const resetForm = () => {
    setEditingId(null);
    setForm(emptyForm);
  };

  const effectiveSlug = useMemo(
    () => slugifyValue(form.customSlug.trim() || form.title.trim()),
    [form.customSlug, form.title]
  );
  const effectiveDescription = useMemo(
    () => form.metaDescription.trim() || clipText(form.summary || form.body, 160),
    [form.metaDescription, form.summary, form.body]
  );
  const effectiveSeoTitle = useMemo(
    () => form.seoTitle.trim() || `${form.title.trim() || "Article"} | ${SITE_NAME}`,
    [form.seoTitle, form.title]
  );
  const effectiveOgTitle = form.ogTitle.trim() || form.title.trim();
  const effectiveOgDescription = form.ogDescription.trim() || effectiveDescription;
  const effectiveOgImage = form.ogImage.trim() || form.image;
  const effectiveTwitterTitle = form.twitterTitle.trim() || effectiveOgTitle;
  const effectiveTwitterDescription = form.twitterDescription.trim() || effectiveOgDescription;
  const effectiveTwitterImage = form.twitterImage.trim() || effectiveOgImage;
  const effectiveAltText = form.imageAltText.trim() || form.title.trim();
  const effectiveCanonical = form.canonicalUrl.trim() || `${SITE_URL}/blog/${effectiveSlug}`;

  const slugExists = useMemo(
    () =>
      Boolean(
        effectiveSlug &&
          articles.some(
            (article) => article.slug === effectiveSlug && article._id !== editingId
          )
      ),
    [articles, editingId, effectiveSlug]
  );

  const warnings = useMemo(() => {
    const items: string[] = [];

    if (effectiveSeoTitle.length > 60) {
      items.push(language === "ar" ? "عنوان SEO طويل جدًا ويفضل أن يكون أقل من 60 حرفًا." : "SEO title is long; keep it under 60 characters.");
    }
    if (effectiveDescription.length < 150 || effectiveDescription.length > 160) {
      items.push(language === "ar" ? "الوصف التعريفي يفضل أن يكون بين 150 و160 حرفًا." : "Meta description should be between 150 and 160 characters.");
    }
    if (form.image && !form.imageAltText.trim()) {
      items.push(language === "ar" ? "لا يوجد نص بديل للصورة مكتوب يدويًا، وسيتم استخدام عنوان المقال تلقائيًا." : "Image alt text is empty; the article title will be used automatically.");
    }
    if (!form.focusKeyword.trim()) {
      items.push(language === "ar" ? "لا توجد كلمة مفتاحية رئيسية للمقال." : "Focus keyword is missing.");
    }
    if (slugExists) {
      items.push(language === "ar" ? "الرابط الحالي مكرر. عدله قبل الحفظ." : "The current slug is duplicated. Change it before saving.");
    }

    return items;
  }, [
    effectiveDescription.length,
    effectiveSeoTitle.length,
    form.focusKeyword,
    form.image,
    form.imageAltText,
    language,
    slugExists,
  ]);

  const handleImageUpload = async (fileList: FileList | null) => {
    if (!fileList?.length) return;
    setFormError("");
    setUploadingImage(true);
    try {
      const image = await adminService.uploadExhibitionImage(fileList[0]);
      setForm((current) => ({ ...current, image }));
    } catch (error) {
      setFormError(getErrorMessage(error, language === "ar" ? "تعذر رفع صورة المقال." : "Unable to upload the article image."));
    } finally {
      setUploadingImage(false);
    }
  };

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setFormError("");

    if (slugExists) {
      setFormError(language === "ar" ? "لا يمكن حفظ المقال لأن الرابط مكرر." : "Cannot save the article because the slug is duplicated.");
      return;
    }

    const payload = {
      ...form,
      articleTitle: form.articleTitle.trim(),
      articleHeadings: form.articleHeadings.map((item) => item.trim()),
      articleBodies: form.articleBodies.map((item) => item.trim()),
      seoKeywords: form.seoKeywordsInput
        .split(",")
        .map((item) => item.trim())
        .filter(Boolean),
      publishedAt: form.publishedAt || null,
      country: form.country || null,
      seoUpdatedAt: form.seoUpdatedAt || null,
    };

    try {
      if (editingId) {
        await adminService.updateExhibition(editingId, payload);
      } else {
        await adminService.createExhibition(payload);
      }

      resetForm();
      await loadArticles();
    } catch (error) {
      setFormError(
        getErrorMessage(
          error,
          language === "ar" ? "تعذر حفظ المقال." : "Unable to save the article."
        )
      );
    }
  };

  return (
    <div className="space-y-6">
      {formError ? <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{formError}</div> : null}

      <section className="panel p-6">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="rounded-2xl bg-slate-100 p-3 text-slate-700">
              <Video className="h-5 w-5" />
            </div>
            <div>
              <h1 className="text-2xl font-semibold text-slate-900">{labels.title}</h1>
              <p className="mt-1 text-sm text-slate-500">{labels.intro}</p>
            </div>
          </div>

          <Link to="/blog" className="rounded-full border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700">
            {labels.preview}
          </Link>
        </div>

        <form onSubmit={submit} className="mt-6 space-y-6">
          <div className="grid gap-4 md:grid-cols-[1fr_180px]">
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "عنوان المقال" : "Article title"}</span>
              <input value={form.title} onChange={(event) => setForm((current) => ({ ...current, title: event.target.value }))} required className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
            </label>

            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "لون العنوان" : "Title color"}</span>
              <input type="color" value={form.titleColor} onChange={(event) => setForm((current) => ({ ...current, titleColor: event.target.value }))} className="h-[52px] w-full rounded-2xl border border-slate-200 bg-white px-2 py-2 outline-none focus:ring" />
            </label>
          </div>

          <div className="grid gap-4 md:grid-cols-3">
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "التصنيف" : "Category"}</span>
              <input value={form.category} onChange={(event) => setForm((current) => ({ ...current, category: event.target.value }))} placeholder={language === "ar" ? "مثال: الدراسة في تركيا" : "Example: Study in Turkey"} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "الدولة" : "Country"}</span>
              <select value={form.country} onChange={(event) => setForm((current) => ({ ...current, country: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring">
                <option value="">{language === "ar" ? "مقال عام لكل الدول" : "General article for all countries"}</option>
                {countries.map((country) => (
                  <option key={country._id} value={country._id}>{country.name}</option>
                ))}
              </select>
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "اسم الكاتب" : "Author"}</span>
              <input value={form.authorName} onChange={(event) => setForm((current) => ({ ...current, authorName: event.target.value }))} placeholder="Study Birds" className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
            </label>
          </div>

          <label className="block">
            <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "ملخص المقال" : "Article summary"}</span>
            <textarea value={form.summary} onChange={(event) => setForm((current) => ({ ...current, summary: event.target.value }))} rows={3} required className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
          </label>

          <label className="block">
            <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "صورة الغلاف" : "Cover image"}</span>
            <input type="file" accept="image/*" onChange={(event) => handleImageUpload(event.target.files)} className="w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm outline-none focus:ring" />
            <p className="mt-2 text-xs text-slate-500">
              {uploadingImage ? (language === "ar" ? "جاري رفع الصورة..." : "Uploading image...") : language === "ar" ? "الصورة الأساسية ستستخدم تلقائيًا في OG/Twitter إذا لم تدخل صورًا مخصصة." : "The main image will be reused for OG/Twitter if custom images are empty."}
            </p>
          </label>

          {form.image ? (
            <div className="rounded-2xl border border-slate-200 p-4">
              <img src={getApiAssetUrl(form.image)} alt={effectiveAltText || "Article"} className="h-48 w-full rounded-2xl object-cover" />
              <button type="button" onClick={() => setForm((current) => ({ ...current, image: "" }))} className="mt-3 rounded-full border border-rose-200 px-3 py-1 text-xs font-medium text-rose-700">
                {language === "ar" ? "حذف الصورة" : "Remove image"}
              </button>
            </div>
          ) : null}

          <label className="block">
            <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "محتوى المقال" : "Article body"}</span>
            <textarea value={form.body} onChange={(event) => setForm((current) => ({ ...current, body: event.target.value }))} rows={6} required className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
            <p className="mt-2 text-xs text-slate-500">{language === "ar" ? "يمكنك إضافة زر داخل النص بهذه الصيغة: [button:نص الزر|https://example.com]" : "You can place a button inside the text using: [button:Button text|https://example.com]"}</p>
          </label>

          <label className="block">
            <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "رابط YouTube" : "YouTube URL"}</span>
            <input value={form.youtubeUrl} onChange={(event) => setForm((current) => ({ ...current, youtubeUrl: event.target.value }))} placeholder="https://www.youtube.com/watch?v=..." className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
          </label>

          <ArticleContentFields
            articleTitle={form.articleTitle}
            articleTitleColor={form.articleTitleColor}
            articleHeadingColor={form.articleHeadingColor}
            articleBodyColor={form.articleBodyColor}
            articleHeadings={form.articleHeadings}
            articleBodies={form.articleBodies}
            onArticleTitleChange={(value) => setForm((current) => ({ ...current, articleTitle: value }))}
            onArticleTitleColorChange={(value) => setForm((current) => ({ ...current, articleTitleColor: value }))}
            onArticleHeadingColorChange={(value) => setForm((current) => ({ ...current, articleHeadingColor: value }))}
            onArticleBodyColorChange={(value) => setForm((current) => ({ ...current, articleBodyColor: value }))}
            onArticleHeadingChange={(index, value) =>
              setForm((current) => ({
                ...current,
                articleHeadings: current.articleHeadings.map((item, itemIndex) => (itemIndex === index ? value : item)),
              }))
            }
            onArticleBodyChange={(index, value) =>
              setForm((current) => ({
                ...current,
                articleBodies: current.articleBodies.map((item, itemIndex) => (itemIndex === index ? value : item)),
              }))
            }
            onAddArticleItem={() =>
              setForm((current) => ({
                ...current,
                articleHeadings: appendArticleItem(current.articleHeadings),
                articleBodies: appendArticleItem(current.articleBodies),
              }))
            }
            onRemoveArticleItem={(index) =>
              setForm((current) => ({
                ...current,
                articleHeadings: removeArticleItem(current.articleHeadings, index),
                articleBodies: removeArticleItem(current.articleBodies, index),
              }))
            }
            language={language}
            titleLabel={language === "ar" ? "العنوان الداخلي" : "Inner article title"}
          />

          <section className="rounded-[1.75rem] border border-slate-200 p-5">
            <div className="flex items-center gap-2">
              <Search className="h-5 w-5 text-slate-600" />
              <h2 className="text-lg font-semibold text-slate-900">{language === "ar" ? "إعدادات SEO" : "SEO settings"}</h2>
            </div>

            <div className="mt-5 grid gap-4 md:grid-cols-2">
              <label className="block">
                <span className="mb-2 block text-sm font-medium text-slate-700">SEO Title</span>
                <input value={form.seoTitle} onChange={(event) => setForm((current) => ({ ...current, seoTitle: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
              </label>
              <label className="block">
                <span className="mb-2 block text-sm font-medium text-slate-700">Focus Keyword</span>
                <input value={form.focusKeyword} onChange={(event) => setForm((current) => ({ ...current, focusKeyword: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
              </label>
              <label className="block md:col-span-2">
                <span className="mb-2 block text-sm font-medium text-slate-700">Meta Description</span>
                <textarea value={form.metaDescription} onChange={(event) => setForm((current) => ({ ...current, metaDescription: event.target.value }))} rows={3} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
              </label>
              <label className="block md:col-span-2">
                <span className="mb-2 block text-sm font-medium text-slate-700">SEO Keywords / Tags</span>
                <input value={form.seoKeywordsInput} onChange={(event) => setForm((current) => ({ ...current, seoKeywordsInput: event.target.value }))} placeholder="study abroad, turkey, scholarships" className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
              </label>
              <label className="block">
                <span className="mb-2 block text-sm font-medium text-slate-700">Custom Slug</span>
                <input value={form.customSlug} onChange={(event) => setForm((current) => ({ ...current, customSlug: event.target.value }))} placeholder="study-in-turkey-2026" className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
              </label>
              <label className="block">
                <span className="mb-2 block text-sm font-medium text-slate-700">Canonical URL</span>
                <input value={form.canonicalUrl} onChange={(event) => setForm((current) => ({ ...current, canonicalUrl: event.target.value }))} placeholder={`${SITE_URL}/blog/${effectiveSlug || "article-slug"}`} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
              </label>
              <label className="block">
                <span className="mb-2 block text-sm font-medium text-slate-700">OG Title</span>
                <input value={form.ogTitle} onChange={(event) => setForm((current) => ({ ...current, ogTitle: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
              </label>
              <label className="block">
                <span className="mb-2 block text-sm font-medium text-slate-700">OG Image</span>
                <input value={form.ogImage} onChange={(event) => setForm((current) => ({ ...current, ogImage: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
              </label>
              <label className="block md:col-span-2">
                <span className="mb-2 block text-sm font-medium text-slate-700">OG Description</span>
                <textarea value={form.ogDescription} onChange={(event) => setForm((current) => ({ ...current, ogDescription: event.target.value }))} rows={2} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
              </label>
              <label className="block">
                <span className="mb-2 block text-sm font-medium text-slate-700">Twitter Title</span>
                <input value={form.twitterTitle} onChange={(event) => setForm((current) => ({ ...current, twitterTitle: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
              </label>
              <label className="block">
                <span className="mb-2 block text-sm font-medium text-slate-700">Twitter Image</span>
                <input value={form.twitterImage} onChange={(event) => setForm((current) => ({ ...current, twitterImage: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
              </label>
              <label className="block md:col-span-2">
                <span className="mb-2 block text-sm font-medium text-slate-700">Twitter Description</span>
                <textarea value={form.twitterDescription} onChange={(event) => setForm((current) => ({ ...current, twitterDescription: event.target.value }))} rows={2} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
              </label>
              <label className="block">
                <span className="mb-2 block text-sm font-medium text-slate-700">Image Alt Text</span>
                <input value={form.imageAltText} onChange={(event) => setForm((current) => ({ ...current, imageAltText: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
              </label>
              <div className="grid gap-4 md:grid-cols-2">
                <label className="block">
                  <span className="mb-2 block text-sm font-medium text-slate-700">Robots Index</span>
                  <select value={form.robotsIndex} onChange={(event) => setForm((current) => ({ ...current, robotsIndex: event.target.value as "index" | "noindex" }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring">
                    <option value="index">index</option>
                    <option value="noindex">noindex</option>
                  </select>
                </label>
                <label className="block">
                  <span className="mb-2 block text-sm font-medium text-slate-700">Robots Follow</span>
                  <select value={form.robotsFollow} onChange={(event) => setForm((current) => ({ ...current, robotsFollow: event.target.value as "follow" | "nofollow" }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring">
                    <option value="follow">follow</option>
                    <option value="nofollow">nofollow</option>
                  </select>
                </label>
              </div>
              <label className="block">
                <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "تاريخ النشر" : "Published date"}</span>
                <input type="datetime-local" value={form.publishedAt} onChange={(event) => setForm((current) => ({ ...current, publishedAt: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
              </label>
              <label className="block">
                <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "تاريخ التحديث" : "Updated date"}</span>
                <input type="datetime-local" value={form.seoUpdatedAt} onChange={(event) => setForm((current) => ({ ...current, seoUpdatedAt: event.target.value }))} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring" />
              </label>
            </div>
          </section>

          {warnings.length ? (
            <section className="rounded-[1.75rem] border border-amber-200 bg-amber-50 p-5">
              <div className="flex items-center gap-2 text-amber-800">
                <AlertTriangle className="h-5 w-5" />
                <h2 className="text-sm font-semibold">{language === "ar" ? "تنبيهات SEO" : "SEO warnings"}</h2>
              </div>
              <div className="mt-3 space-y-2 text-sm text-amber-900">
                {warnings.map((warning) => (
                  <p key={warning}>{warning}</p>
                ))}
              </div>
            </section>
          ) : null}

          <section className="rounded-[1.75rem] border border-slate-200 bg-slate-50 p-5">
            <h2 className="text-lg font-semibold text-slate-900">{language === "ar" ? "معاينة Google" : "Google preview"}</h2>
            <div className="mt-4 rounded-3xl border border-slate-200 bg-white p-5 shadow-sm">
              <p className="text-xs text-emerald-700">{effectiveCanonical}</p>
              <p className="mt-2 text-xl leading-7 text-blue-700">{effectiveSeoTitle}</p>
              <p className="mt-2 text-sm leading-6 text-slate-600">{effectiveDescription}</p>
            </div>
          </section>

          <div className="grid gap-3 md:grid-cols-2">
            <label className="flex items-center gap-3 rounded-2xl border border-slate-200 px-4 py-3">
              <input type="checkbox" checked={form.featured} onChange={(event) => setForm((current) => ({ ...current, featured: event.target.checked }))} />
              <span className="text-sm font-medium text-slate-700">{language === "ar" ? "إظهار كمقال مميز" : "Show as featured article"}</span>
            </label>

            <label className="flex items-center gap-3 rounded-2xl border border-slate-200 px-4 py-3">
              <input type="checkbox" checked={form.published} onChange={(event) => setForm((current) => ({ ...current, published: event.target.checked }))} />
              <span className="text-sm font-medium text-slate-700">{language === "ar" ? "نشر المقال" : "Publish article"}</span>
            </label>
          </div>

          <div className="flex flex-wrap gap-3">
            <button type="submit" className="inline-flex items-center gap-2 rounded-full bg-slate-950 px-5 py-3 font-semibold text-white">
              <Plus className="h-4 w-4" />
              {editingId ? labels.update : labels.create}
            </button>
            <button type="button" onClick={resetForm} className="rounded-full border border-slate-200 px-5 py-3 font-semibold text-slate-700">
              {labels.reset}
            </button>
          </div>
        </form>
      </section>

      <section className="space-y-4">
        {articles.length === 0 ? <div className="panel p-6 text-sm text-slate-500">{language === "ar" ? "لا توجد مقالات حتى الآن." : "No articles yet."}</div> : null}

        {articles.map((article) => {
          const articleContent = mapSectionsToArticleContent(article);
          const articleCount = articleContent.articleHeadings.filter(Boolean).length;
          const embedUrl = getYoutubeEmbedUrl(article.youtubeUrl);
          const demoLike = isDemoLikeArticle(article);

          return (
            <div key={article._id} className="panel overflow-hidden p-0">
              <div className="grid gap-0 xl:grid-cols-[1fr_360px]">
                <div className="p-6">
                  <div className="flex flex-wrap items-center gap-2">
                    <h2 className="text-xl font-semibold" style={{ color: article.titleColor || "#0f172a" }}>{article.title}</h2>
                    {article.featured ? <span className="rounded-full bg-amber-100 px-3 py-1 text-xs font-semibold text-amber-700">{language === "ar" ? "مميز" : "Featured"}</span> : null}
                    {article.published ? <span className="rounded-full bg-emerald-100 px-3 py-1 text-xs font-semibold text-emerald-700">{language === "ar" ? "منشور" : "Published"}</span> : <span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-600">{language === "ar" ? "مسودة" : "Draft"}</span>}
                    {article.category ? <span className="rounded-full bg-sky-100 px-3 py-1 text-xs font-semibold text-sky-700">{article.category}</span> : null}
                    {demoLike ? <span className="rounded-full bg-rose-100 px-3 py-1 text-xs font-semibold text-rose-700">{language === "ar" ? "مقال تجريبي" : "Demo-like article"}</span> : null}
                  </div>

                  {article.image ? <img src={getApiAssetUrl(article.image)} alt={article.resolvedSeo?.imageAltText || article.title} className="mt-4 h-44 w-full rounded-3xl object-cover" /> : null}
                  <p className="mt-3 text-sm leading-7 text-slate-600">{article.summary}</p>

                  <div className="mt-4 rounded-2xl border border-slate-200 bg-slate-50 p-4 text-sm text-slate-600">
                    <p className="font-semibold text-slate-900">{article.resolvedSeo?.seoTitle || article.title}</p>
                    <p className="mt-2 break-all text-emerald-700">{article.resolvedSeo?.canonicalUrl || `${SITE_URL}/blog/${article.slug}`}</p>
                    <p className="mt-2">{article.resolvedSeo?.metaDescription || article.summary}</p>
                  </div>

                  <div className="mt-4 flex flex-wrap items-center gap-3 text-xs text-slate-500">
                    {(article.publishedAt || article.createdAt) ? <span className="inline-flex items-center gap-2"><CalendarDays className="h-4 w-4" />{formatDate(article.publishedAt || article.createdAt || "")}</span> : null}
                    <span>{language === "ar" ? `عدد الأقسام: ${articleCount}` : `Sections: ${articleCount}`}</span>
                    {article.focusKeyword ? <span>{language === "ar" ? `الكلمة المفتاحية: ${article.focusKeyword}` : `Focus keyword: ${article.focusKeyword}`}</span> : null}
                  </div>

                  <div className="mt-5 flex flex-wrap gap-2">
                    <button
                      onClick={() => {
                        setEditingId(article._id);
                        setForm({
                          title: article.title,
                          summary: article.summary,
                          body: article.body,
                          image: article.image || "",
                          titleColor: article.titleColor || "#0f172a",
                          ...mapSectionsToArticleContent(article),
                          youtubeUrl: article.youtubeUrl,
                          featured: Boolean(article.featured),
                          published: Boolean(article.published),
                          seoTitle: article.seoTitle || "",
                          metaDescription: article.metaDescription || "",
                          focusKeyword: article.focusKeyword || "",
                          seoKeywordsInput: (article.seoKeywords || []).join(", "),
                          customSlug: article.customSlug || "",
                          canonicalUrl: article.canonicalUrl || "",
                          ogTitle: article.ogTitle || "",
                          ogDescription: article.ogDescription || "",
                          ogImage: article.ogImage || "",
                          twitterTitle: article.twitterTitle || "",
                          twitterDescription: article.twitterDescription || "",
                          twitterImage: article.twitterImage || "",
                          imageAltText: article.imageAltText || "",
                          robotsIndex: article.robotsIndex || "index",
                          robotsFollow: article.robotsFollow || "follow",
                          country: article.country && typeof article.country !== "string" ? article.country._id : typeof article.country === "string" ? article.country : "",
                          category: article.category || "",
                          authorName: article.authorName || "",
                          publishedAt: toDatetimeLocalValue(article.publishedAt || article.createdAt),
                          seoUpdatedAt: toDatetimeLocalValue(article.seoUpdatedAt || article.updatedAt),
                        });
                      }}
                      className="inline-flex items-center gap-2 rounded-full border border-slate-200 px-4 py-2 font-medium text-slate-700"
                    >
                      <PencilLine className="h-4 w-4" />
                      {language === "ar" ? "تعديل" : "Edit"}
                    </button>
                    <button onClick={() => adminService.removeExhibition(article._id).then(loadArticles)} className="inline-flex items-center gap-2 rounded-full border border-rose-200 px-4 py-2 font-medium text-rose-700">
                      <Trash2 className="h-4 w-4" />
                      {language === "ar" ? "حذف" : "Delete"}
                    </button>
                  </div>
                </div>

                <div className="border-t border-slate-200 bg-slate-950 p-5 xl:border-l xl:border-t-0">
                  <div className="overflow-hidden rounded-[1.25rem] bg-black">
                    {embedUrl ? (
                      <iframe
                        src={embedUrl}
                        title={article.title}
                        className="aspect-video w-full"
                        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
                        referrerPolicy="strict-origin-when-cross-origin"
                        allowFullScreen
                      />
                    ) : (
                      <div className="flex aspect-video items-center justify-center p-6 text-center text-sm text-slate-300">
                        {language === "ar" ? "لا يوجد فيديو صالح للعرض." : "No embeddable video is available."}
                      </div>
                    )}
                  </div>
                  <div className="mt-4 rounded-2xl border border-white/10 bg-white/5 p-4 text-xs leading-6 text-slate-300">
                    <p>Slug: {article.slug}</p>
                    <p>OG: {article.resolvedSeo?.ogTitle || article.title}</p>
                    <p>Twitter: {article.resolvedSeo?.twitterTitle || article.title}</p>
                    <p>Robots: {article.resolvedSeo?.robotsIndex || "index"}, {article.resolvedSeo?.robotsFollow || "follow"}</p>
                  </div>
                </div>
              </div>
            </div>
          );
        })}
      </section>
    </div>
  );
};




