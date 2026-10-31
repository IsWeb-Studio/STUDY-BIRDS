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
const { getBannersPublic } = require("../controllers/bannerController");
const { protect } = require("../middleware/authMiddleware");
const { cacheRoute } = require("../utils/responseCache");
const notificationInbox = require("../controllers/notificationInboxController");

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
router.patch("/notifications/read-all", protect, notificationInbox.markAllNotificationsRead);
router.patch("/notifications/:id/read", protect, notificationInbox.markNotificationRead);
router.get("/file-open", openCloudinaryDocument);
router.get("/seo/sitemap.xml", cacheRoute(120_000), getSitemapXml);
router.get("/seo/robots.txt", cacheRoute(300_000), getRobotsTxt);
router.get("/banners", cacheRoute(60_000), getBannersPublic);

// Rates are cached separately for each base currency.
router.get('/exchange-rates', require('../controllers/exchangeRatesController').getExchangeRates);

module.exports = router;
