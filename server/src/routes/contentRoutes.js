const express = require("express");
const {
  getCountries,
  getHomePageContent,
  getExhibitionArticles,
  getExhibitionArticleBySlug,
  getBlogCategories,
  getFaqs,
  getRecognitions,
  getRecognitionBySlug,
  getOurServices,
  getOurServiceBySlug,
  getOurStory,
  getUpcomingEvent,
  getPastEvents,
  createEventRegistration,
  createContactMessage,
  getSiteSettings,
  getStudyFields,
  getTestimonials,
  getNotifications,
  openCloudinaryDocument,
  getRobotsTxt,
  getSitemapXml,
} = require("../controllers/contentController");
const { protect } = require("../middleware/authMiddleware");
const { cacheRoute } = require("../utils/responseCache");

const router = express.Router();

// Student-facing status copy (labels, meaning, next step) for every client.
router.get("/status-catalog", cacheRoute(300_000), (req, res) => {
  const { APPLICATION_STATUS_COPY, DOCUMENT_STATUS_COPY } = require("../constants/statusCatalog");
  res.json({ applications: APPLICATION_STATUS_COPY, documents: DOCUMENT_STATUS_COPY });
});
router.get("/home", cacheRoute(60_000), getHomePageContent);
router.get("/countries", cacheRoute(60_000), getCountries);
router.get("/testimonials", cacheRoute(60_000), getTestimonials);
router.get("/recognitions", cacheRoute(60_000), getRecognitions);
router.get("/recognitions/:slug", getRecognitionBySlug);
router.get("/our-services", cacheRoute(60_000), getOurServices);
router.get("/our-services/:slug", getOurServiceBySlug);
router.get("/our-story", cacheRoute(120_000), getOurStory);
router.get("/upcoming-event", cacheRoute(60_000), getUpcomingEvent);
router.get("/past-events", cacheRoute(60_000), getPastEvents);
router.post("/event-registrations", createEventRegistration);
router.post("/contact-messages", createContactMessage);
router.get("/faqs", cacheRoute(60_000), getFaqs);
router.get("/blog/categories", cacheRoute(60_000), getBlogCategories);
router.get("/blog", cacheRoute(60_000), getExhibitionArticles);
router.get("/blog/:slug", getExhibitionArticleBySlug);
router.get("/exhibitions", cacheRoute(60_000), getExhibitionArticles);
router.get("/exhibitions/:slug", getExhibitionArticleBySlug);
router.get("/site-settings", cacheRoute(300_000), getSiteSettings);
router.get("/study-fields", cacheRoute(120_000), getStudyFields);
router.get("/notifications", protect, getNotifications);
router.get("/file-open", openCloudinaryDocument);
router.get("/seo/sitemap.xml", cacheRoute(120_000), getSitemapXml);
router.get("/seo/robots.txt", cacheRoute(300_000), getRobotsTxt);

// #36+74: Dynamic currency conversion — cached for 1 hour, no API key needed.
let _ratesCache = null;
let _ratesCachedAt = 0;
router.get('/exchange-rates', cacheRoute(3_600_000), async (req, res) => {
  const base = (typeof req.query.base === 'string' ? req.query.base.toUpperCase() : null) || 'USD';
  const allowed = ['USD', 'EUR', 'GBP', 'SAR', 'AED', 'KWD', 'QAR', 'JOD', 'TRY', 'EGP'];
  if (!allowed.includes(base)) return res.status(400).json({ message: 'Unsupported base currency' });
  const now = Date.now();
  if (_ratesCache && now - _ratesCachedAt < 3_600_000) {
    return res.json({ base: _ratesCache.base, date: _ratesCache.date, rates: _ratesCache.rates });
  }
  try {
    const targets = allowed.filter(c => c !== base).join(',');
    const r = await fetch(`https://api.frankfurter.app/latest?from=${base}&to=${targets}`, { signal: AbortSignal.timeout(8000) });
    if (!r.ok) throw new Error('upstream');
    const data = await r.json();
    _ratesCache = data;
    _ratesCachedAt = now;
    res.json({ base: data.base, date: data.date, rates: data.rates });
  } catch {
    if (_ratesCache) return res.json({ base: _ratesCache.base, date: _ratesCache.date, rates: _ratesCache.rates, stale: true });
    res.status(502).json({ message: 'تعذر جلب أسعار الصرف. حاول لاحقًا.' });
  }
});

module.exports = router;
