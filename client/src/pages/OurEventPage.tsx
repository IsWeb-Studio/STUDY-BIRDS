import { AnimatePresence, motion } from "framer-motion";
import { CalendarDays, ChevronLeft, ChevronRight, Clock3, MapPin, PlayCircle, Users2, X } from "lucide-react";
import { useEffect, useMemo, useState, type FormEvent, type TouchEvent } from "react";
import { PhoneNumberField } from "../components/forms/PhoneNumberField";
import { Seo } from "../components/seo/Seo";
import { useLanguage } from "../hooks/useLanguage";
import { getApiAssetUrl } from "../lib/api";
import { SITE_NAME, seoText } from "../seo/site";
import { contentService } from "../services/contentService";
import type { PastEvent, UpcomingEvent } from "../types";
import { getErrorMessage } from "../utils/errors";
import { formatDate } from "../utils/format";
import { buildPhoneNumber, DEFAULT_PHONE_DIAL_CODE } from "../utils/phoneCountryOptions";
import { getPaginatedItems } from "../utils/pagination";

const eventCategoryOptions = [
  { value: "all", en: "All Events", ar: "كل الفعاليات" },
  { value: "expos-fairs", en: "Expos & Fairs", ar: "الملتقيات والمعارض" },
  { value: "our-community", en: "Our Community", ar: "مجتمع الطلاب" },
  { value: "webinars", en: "Webinars", ar: "الندوات والويبينارات" },
  { value: "partnerships", en: "Partnerships", ar: "بروتوكولات الشراكة" },
] as const;

const getCountryFlag = (countryCode?: string) => {
  const normalized = String(countryCode || "").trim().toUpperCase();
  if (!/^[A-Z]{2}$/.test(normalized)) return "";
  return String.fromCodePoint(...normalized.split("").map((char) => 127397 + char.charCodeAt(0)));
};

const getTimeLeft = (eventDate?: string | null) => {
  if (!eventDate) {
    return { days: 0, hours: 0, minutes: 0, seconds: 0 };
  }

  const targetDate = new Date(eventDate).getTime();
  const now = Date.now();
  const difference = Math.max(targetDate - now, 0);

  return {
    days: Math.floor(difference / (1000 * 60 * 60 * 24)),
    hours: Math.floor((difference / (1000 * 60 * 60)) % 24),
    minutes: Math.floor((difference / (1000 * 60)) % 60),
    seconds: Math.floor((difference / 1000) % 60),
  };
};

const formatTimeLabel = (value: number) => String(value).padStart(2, "0");

export const OurEventPage = () => {
  const { language } = useLanguage();
  const [upcomingEvent, setUpcomingEvent] = useState<UpcomingEvent | null>(null);
  const [pastEvents, setPastEvents] = useState<PastEvent[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [selectedCategory, setSelectedCategory] = useState<(typeof eventCategoryOptions)[number]["value"]>("all");
  const [registrationOpen, setRegistrationOpen] = useState(false);
  const [registrationLoading, setRegistrationLoading] = useState(false);
  const [registrationSuccess, setRegistrationSuccess] = useState("");
  const [selectedEvent, setSelectedEvent] = useState<PastEvent | null>(null);
  const [selectedMediaIndex, setSelectedMediaIndex] = useState(0);
  const [touchStartX, setTouchStartX] = useState<number | null>(null);
  const [registrationForm, setRegistrationForm] = useState({
    name: "",
    dialCode: DEFAULT_PHONE_DIAL_CODE,
    phoneNumber: "",
    fieldOfInterest: "",
    currentCountry: "",
    desiredStudyCountry: "",
  });
  const [timeLeft, setTimeLeft] = useState(getTimeLeft(null));

  useEffect(() => {
    const loadContent = async () => {
      setLoading(true);
      setError("");

      try {
        const [upcomingEventData, pastEventsData] = await Promise.all([
          contentService.getUpcomingEvent(),
          contentService.getPastEvents({ page: 1, limit: 9, paginate: true, featuredOnly: true }),
        ]);

        setUpcomingEvent(upcomingEventData);
        setPastEvents(getPaginatedItems(pastEventsData).filter((event) => event.featured !== false));
      } catch (loadError) {
        setError(
          getErrorMessage(
            loadError,
            language === "ar" ? "تعذر تحميل محتوى الفعاليات حاليًا." : "Unable to load the events content right now."
          )
        );
      } finally {
        setLoading(false);
      }
    };

    loadContent();
  }, [language]);

  useEffect(() => {
    setTimeLeft(getTimeLeft(upcomingEvent?.eventDate));
    const interval = window.setInterval(() => {
      setTimeLeft(getTimeLeft(upcomingEvent?.eventDate));
    }, 1000);

    return () => window.clearInterval(interval);
  }, [upcomingEvent?.eventDate]);

  const filteredPastEvents = useMemo(() => {
    if (selectedCategory === "all") return pastEvents;
    return pastEvents.filter((event) => event.category === selectedCategory);
  }, [pastEvents, selectedCategory]);

  const selectedMedia = selectedEvent?.mediaItems?.[selectedMediaIndex] || null;
  const upcomingEventBackground = getApiAssetUrl(upcomingEvent?.backgroundImage);

  const openEventLightbox = (event: PastEvent) => {
    setSelectedEvent(event);
    setSelectedMediaIndex(0);
  };

  const closeEventLightbox = () => {
    setSelectedEvent(null);
    setSelectedMediaIndex(0);
    setTouchStartX(null);
  };

  const moveMedia = (direction: "next" | "prev") => {
    if (!selectedEvent?.mediaItems?.length) return;
    const itemCount = selectedEvent.mediaItems.length;
    setSelectedMediaIndex((current) =>
      direction === "next" ? (current + 1) % itemCount : (current - 1 + itemCount) % itemCount
    );
  };

  const handleLightboxTouchStart = (event: TouchEvent<HTMLDivElement>) => {
    setTouchStartX(event.changedTouches[0]?.clientX ?? null);
  };

  const handleLightboxTouchEnd = (event: TouchEvent<HTMLDivElement>) => {
    if (touchStartX === null) return;
    const touchEndX = event.changedTouches[0]?.clientX ?? touchStartX;
    const delta = touchEndX - touchStartX;

    if (Math.abs(delta) > 40) {
      moveMedia(delta < 0 ? "next" : "prev");
    }

    setTouchStartX(null);
  };

  const submitRegistration = async (event: FormEvent) => {
    event.preventDefault();
    setRegistrationLoading(true);
    setRegistrationSuccess("");
    setError("");

    try {
      await contentService.registerForEvent({
        name: registrationForm.name.trim(),
        phone: buildPhoneNumber(registrationForm.dialCode, registrationForm.phoneNumber),
        fieldOfInterest: registrationForm.fieldOfInterest.trim(),
        currentCountry: registrationForm.currentCountry.trim(),
        desiredStudyCountry: registrationForm.desiredStudyCountry.trim(),
      });

      setRegistrationSuccess(
        language === "ar" ? "تم تسجيل بياناتك بنجاح. سنرسل لك تفاصيل الفعالية قريبًا." : "Your registration has been submitted successfully."
      );
      setRegistrationForm({
        name: "",
        dialCode: DEFAULT_PHONE_DIAL_CODE,
        phoneNumber: "",
        fieldOfInterest: "",
        currentCountry: "",
        desiredStudyCountry: "",
      });
    } catch (submitError) {
      setError(
        getErrorMessage(
          submitError,
          language === "ar" ? "تعذر إرسال التسجيل حاليًا." : "Unable to submit your registration right now."
        )
      );
    } finally {
      setRegistrationLoading(false);
    }
  };

  return (
    <div className="space-y-8">
      <Seo
        title={seoText(language, `Our Event | ${SITE_NAME}`, `فعاليتنا | ${SITE_NAME}`)}
        description={seoText(
          language,
          `Discover the next ${SITE_NAME} event, register quickly, and browse our previous fairs, webinars, and student community activities.`,
          `اكتشف فعالية ${SITE_NAME} القادمة، وسجل بسرعة، واستعرض معارضنا وندواتنا وأنشطة مجتمع الطلاب السابقة.`
        )}
      />

      {error ? <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div> : null}

      <section
        className="relative overflow-hidden rounded-[2.5rem] px-8 py-10 text-white sm:px-10"
        style={{
          backgroundImage: upcomingEventBackground
            ? `linear-gradient(135deg, rgba(10,25,49,0.96), rgba(16,42,86,0.92)), url(${upcomingEventBackground})`
            : "linear-gradient(135deg, rgba(10,25,49,1), rgba(16,42,86,1))",
          backgroundSize: "cover",
          backgroundPosition: "center",
        }}
      >
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_top_right,rgba(249,115,22,0.22),transparent_28%)]" />
        <div className="relative grid gap-8 xl:grid-cols-[1.1fr_0.9fr] xl:items-center">
          <div>
            <div className="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-4 py-2 text-xs font-semibold uppercase tracking-[0.3em] text-orange-200">
              <Users2 className="h-4 w-4" />
              {language === "ar" ? "فعاليتنا" : "Our Event"}
            </div>
            <h1 className="mt-5 text-4xl font-semibold leading-tight sm:text-5xl">
              {upcomingEvent?.title || (language === "ar" ? "الفعالية القادمة من Study Birds" : "The next Study Birds event")}
            </h1>
            <p className="mt-5 max-w-3xl text-base leading-8 text-slate-200 sm:text-lg">
              {upcomingEvent?.subtitle ||
                (language === "ar"
                  ? "مساحة واحدة لعرض الندوات، المعارض، والويبينارات القادمة مع دعوة واضحة للتسجيل السريع."
                  : "A dedicated space to highlight upcoming webinars, fairs, and community events with a strong registration call-to-action.")}
            </p>

            <div className="mt-6 flex flex-wrap items-center gap-3 text-sm text-slate-200">
              {upcomingEvent?.eventType ? (
                <span className="rounded-full border border-white/15 bg-white/10 px-4 py-2">{upcomingEvent.eventType}</span>
              ) : null}
              {upcomingEvent?.eventDate ? (
                <span className="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-4 py-2">
                  <CalendarDays className="h-4 w-4 text-orange-300" />
                  {formatDate(upcomingEvent.eventDate)}
                </span>
              ) : null}
              {upcomingEvent?.eventDate ? (
                <span className="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-4 py-2">
                  <Clock3 className="h-4 w-4 text-orange-300" />
                  {new Date(upcomingEvent.eventDate).toLocaleTimeString(language === "ar" ? "ar-EG" : "en-US", {
                    hour: "2-digit",
                    minute: "2-digit",
                  })}
                </span>
              ) : null}
            </div>

            <button
              onClick={() => setRegistrationOpen(true)}
              className="mt-8 inline-flex items-center justify-center rounded-full bg-orange-500 px-6 py-3 text-sm font-semibold text-white transition hover:bg-orange-400"
            >
              {upcomingEvent?.ctaText || (language === "ar" ? "احجز مقعدك الآن" : "Reserve your seat now")}
            </button>
          </div>

          <div className="grid grid-cols-4 gap-4 rounded-[2rem] border border-white/10 bg-white/5 p-5 backdrop-blur-md">
            {[
              { key: "days", label: language === "ar" ? "يوم" : "Days", value: timeLeft.days },
              { key: "hours", label: language === "ar" ? "ساعة" : "Hours", value: timeLeft.hours },
              { key: "minutes", label: language === "ar" ? "دقيقة" : "Minutes", value: timeLeft.minutes },
              { key: "seconds", label: language === "ar" ? "\u062b\u0627\u0646\u064a\u0629" : "Seconds", value: timeLeft.seconds },
            ].map((item) => (
              <motion.div
                key={item.key}
                initial={{ opacity: 0, y: 14 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                className="rounded-[1.6rem] border border-white/10 bg-slate-950/35 px-2 py-4 text-center shadow-2xl sm:px-4 sm:py-5"
              >
                <div className="text-2xl font-semibold tracking-tight text-white sm:text-4xl">{formatTimeLabel(item.value)}</div>
                <div className="mt-2 text-[10px] font-semibold uppercase tracking-[0.18em] text-orange-200 sm:text-xs sm:tracking-[0.28em]">{item.label}</div>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      <section className="panel overflow-hidden p-8">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.3em] text-brand-700">
              {language === "ar" ? "فعالياتنا السابقة" : "Past Events"}
            </p>
            <h2 className="mt-3 text-3xl font-semibold text-slate-900">
              {language === "ar" ? "استعرض أنشطتنا، معارضنا، وندواتنا السابقة" : "Browse our fairs, community moments, and webinars"}
            </h2>
            <p className="mt-3 max-w-2xl text-sm leading-7 text-slate-600">
              {language === "ar"
                ? "صفّ الفعاليات حسب النوع، ثم افتح أي حدث لتشاهد ألبوم الصور والفيديوهات بدون تحميل صفحة جديدة."
                : "Filter events by category, then open any card to view its photos and videos instantly without leaving the page."}
            </p>
          </div>
          <div className="flex flex-wrap gap-2">
            {eventCategoryOptions.map((option) => {
              const isActive = selectedCategory === option.value;
              return (
                <button
                  key={option.value}
                  onClick={() => setSelectedCategory(option.value)}
                  className={`rounded-full px-4 py-2 text-sm font-semibold transition ${
                    isActive ? "bg-orange-500 text-white shadow-lg" : "border border-slate-200 bg-white text-slate-700 hover:border-orange-200 hover:text-orange-600"
                  }`}
                >
                  {language === "ar" ? option.ar : option.en}
                </button>
              );
            })}
          </div>
        </div>

        {loading ? <div className="mt-8 text-sm text-slate-500">{language === "ar" ? "جارٍ تحميل الفعاليات..." : "Loading events..."}</div> : null}

        {!loading && filteredPastEvents.length === 0 ? (
          <div className="mt-8 rounded-[2rem] border border-dashed border-slate-300 px-6 py-12 text-center text-slate-500">
            {language === "ar" ? "لا توجد فعاليات في هذا التصنيف حاليًا." : "No events are available in this category yet."}
          </div>
        ) : null}

        <motion.div layout className="mt-8 grid gap-6 md:grid-cols-2 xl:grid-cols-3">
          <AnimatePresence mode="popLayout">
            {filteredPastEvents.map((event) => {
              const coverImage = getApiAssetUrl(event.coverImage);
              const flag = getCountryFlag(event.countryCode);
              return (
                <motion.button
                  layout
                  initial={{ opacity: 0, y: 18 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: 18 }}
                  transition={{ duration: 0.25 }}
                  key={event._id}
                  onClick={() => openEventLightbox(event)}
                  className="group overflow-hidden rounded-[2rem] border border-slate-200 bg-white text-left shadow-sm transition hover:-translate-y-1 hover:shadow-2xl"
                >
                  <div className="relative h-64 overflow-hidden bg-[linear-gradient(135deg,#0f172a_0%,#1e3a8a_100%)]">
                    {coverImage ? <img src={coverImage} alt={event.title} loading="lazy" className="h-full w-full object-cover transition duration-500 group-hover:scale-105" /> : null}
                    <div className="absolute inset-0 bg-gradient-to-t from-slate-950 via-slate-950/35 to-transparent" />
                    <div className="absolute left-4 right-4 top-4 flex items-center justify-between">
                      <span className="rounded-full border border-white/15 bg-slate-950/45 px-3 py-1 text-xs font-semibold text-white backdrop-blur">
                        {eventCategoryOptions.find((option) => option.value === event.category)?.[language === "ar" ? "ar" : "en"]}
                      </span>
                      {flag ? (
                        <span className="rounded-full border border-white/15 bg-slate-950/45 px-3 py-1 text-lg leading-none backdrop-blur">{flag}</span>
                      ) : null}
                    </div>
                    <div className="absolute bottom-0 left-0 right-0 p-5 text-white">
                      <h3 className="text-2xl font-semibold leading-tight">{event.title}</h3>
                    </div>
                  </div>
                  <div className="space-y-4 p-5">
                    <div className="flex flex-wrap items-center gap-3 text-sm text-slate-500">
                      {event.eventDate ? (
                        <span className="inline-flex items-center gap-2">
                          <CalendarDays className="h-4 w-4 text-orange-500" />
                          {formatDate(event.eventDate)}
                        </span>
                      ) : null}
                      {event.countryCode ? (
                        <span className="inline-flex items-center gap-2">
                          <MapPin className="h-4 w-4 text-orange-500" />
                          {event.countryCode}
                        </span>
                      ) : null}
                    </div>
                    <p className="line-clamp-3 text-sm leading-7 text-slate-600">{event.summary}</p>
                    <div className="inline-flex items-center gap-2 text-sm font-semibold text-brand-700">
                      {language === "ar" ? "عرض الألبوم" : "Open gallery"}
                      <PlayCircle className="h-4 w-4" />
                    </div>
                  </div>
                </motion.button>
              );
            })}
          </AnimatePresence>
        </motion.div>
      </section>

      <AnimatePresence>
        {registrationOpen ? (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/70 p-4"
          >
            <motion.div
              initial={{ opacity: 0, y: 20, scale: 0.98 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: 20, scale: 0.98 }}
              className="w-full max-w-2xl rounded-[2rem] bg-white p-6 shadow-2xl"
            >
              <div className="flex items-start justify-between gap-4">
                <div>
                  <p className="text-sm font-semibold uppercase tracking-[0.3em] text-orange-500">
                    {language === "ar" ? "تسجيل سريع" : "Quick Registration"}
                  </p>
                  <h3 className="mt-2 text-2xl font-semibold text-slate-900">
                    {upcomingEvent?.ctaText || (language === "ar" ? "احجز مقعدك الآن" : "Reserve your seat now")}
                  </h3>
                </div>
                <button onClick={() => setRegistrationOpen(false)} className="rounded-full bg-slate-100 p-2 text-slate-600">
                  <X className="h-5 w-5" />
                </button>
              </div>

              <form onSubmit={submitRegistration} className="mt-6 space-y-4">
                <div className="grid gap-4 md:grid-cols-2">
                  <label className="block">
                    <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "الاسم" : "Name"}</span>
                    <input
                      value={registrationForm.name}
                      required
                      onChange={(event) => setRegistrationForm((current) => ({ ...current, name: event.target.value }))}
                      className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
                    />
                  </label>
                  <label className="block">
                    <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "\u0639\u0646\u0648\u0627\u0646\u0643 \u0627\u0644\u062d\u0627\u0644\u064a" : "Your current address"}</span>
                    <input
                      value={registrationForm.currentCountry}
                      required
                      onChange={(event) => setRegistrationForm((current) => ({ ...current, currentCountry: event.target.value }))}
                      className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
                    />
                  </label>
                </div>

                <PhoneNumberField
                  label={language === "ar" ? "رقم الهاتف" : "Phone number"}
                  dialCode={registrationForm.dialCode}
                  phoneNumber={registrationForm.phoneNumber}
                  onDialCodeChange={(value) => setRegistrationForm((current) => ({ ...current, dialCode: value }))}
                  onPhoneNumberChange={(value) => setRegistrationForm((current) => ({ ...current, phoneNumber: value }))}
                  required
                />

                <label className="block">
                  <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "\u0627\u0644\u062f\u0648\u0644\u0629 \u0627\u0644\u0645\u0631\u0627\u062f \u0627\u0644\u062f\u0631\u0627\u0633\u0629 \u0628\u0647\u0627" : "Desired study country"}</span>
                  <input
                    value={registrationForm.desiredStudyCountry}
                    required
                    onChange={(event) => setRegistrationForm((current) => ({ ...current, desiredStudyCountry: event.target.value }))}
                    className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
                  />
                </label>
                <label className="block">
                  <span className="mb-2 block text-sm font-medium text-slate-700">{language === "ar" ? "التخصص المهتم به" : "Field of interest"}</span>
                  <input
                    value={registrationForm.fieldOfInterest}
                    required
                    onChange={(event) => setRegistrationForm((current) => ({ ...current, fieldOfInterest: event.target.value }))}
                    className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:ring"
                  />
                </label>

                {registrationSuccess ? <div className="rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{registrationSuccess}</div> : null}

                <div className="flex flex-wrap gap-3">
                  <button
                    type="submit"
                    disabled={registrationLoading}
                    className="rounded-full bg-orange-500 px-6 py-3 text-sm font-semibold text-white transition hover:bg-orange-400 disabled:cursor-not-allowed disabled:opacity-70"
                  >
                    {registrationLoading
                      ? language === "ar"
                        ? "جارٍ الإرسال..."
                        : "Submitting..."
                      : language === "ar"
                        ? "إرسال التسجيل"
                        : "Submit registration"}
                  </button>
                  <button type="button" onClick={() => setRegistrationOpen(false)} className="rounded-full border border-slate-200 px-6 py-3 text-sm font-semibold text-slate-700">
                    {language === "ar" ? "إغلاق" : "Close"}
                  </button>
                </div>
              </form>
            </motion.div>
          </motion.div>
        ) : null}
      </AnimatePresence>

      <AnimatePresence>
        {selectedEvent && selectedMedia ? (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 bg-slate-950/85 p-3 sm:p-6"
          >
            <div className="mx-auto flex h-full max-w-6xl flex-col justify-center gap-4">
              <div className="flex items-center justify-between text-white">
                <div>
                  <p className="text-sm font-semibold uppercase tracking-[0.28em] text-orange-300">
                    {eventCategoryOptions.find((option) => option.value === selectedEvent.category)?.[language === "ar" ? "ar" : "en"]}
                  </p>
                  <h3 className="mt-2 text-2xl font-semibold">{selectedEvent.title}</h3>
                </div>
                <button onClick={closeEventLightbox} className="rounded-full border border-white/15 bg-white/10 p-2 text-white">
                  <X className="h-5 w-5" />
                </button>
              </div>

              <div
                className="relative overflow-hidden rounded-[2rem] bg-slate-900"
                onTouchStart={handleLightboxTouchStart}
                onTouchEnd={handleLightboxTouchEnd}
              >
                {selectedMedia.type === "video" ? (
                  <video src={getApiAssetUrl(selectedMedia.url)} className="max-h-[70vh] w-full bg-black object-contain" controls autoPlay />
                ) : (
                  <img src={getApiAssetUrl(selectedMedia.url)} alt={selectedEvent.title} loading="lazy" className="max-h-[70vh] w-full object-contain" />
                )}

                {selectedEvent.mediaItems && selectedEvent.mediaItems.length > 1 ? (
                  <>
                    <button onClick={() => moveMedia("prev")} className="absolute left-4 top-1/2 -translate-y-1/2 rounded-full border border-white/10 bg-slate-950/55 p-3 text-white backdrop-blur">
                      <ChevronLeft className="h-5 w-5" />
                    </button>
                    <button onClick={() => moveMedia("next")} className="absolute right-4 top-1/2 -translate-y-1/2 rounded-full border border-white/10 bg-slate-950/55 p-3 text-white backdrop-blur">
                      <ChevronRight className="h-5 w-5" />
                    </button>
                  </>
                ) : null}
              </div>

              {selectedEvent.mediaItems?.length ? (
                <div className="flex gap-3 overflow-x-auto pb-1">
                  {selectedEvent.mediaItems.map((item, index) => (
                    <button
                      key={`${item.url}-${index}`}
                      onClick={() => setSelectedMediaIndex(index)}
                      className={`overflow-hidden rounded-2xl border ${index === selectedMediaIndex ? "border-orange-400" : "border-white/10"} bg-white/5`}
                    >
                      {item.type === "video" ? (
                        <div className="flex h-20 w-24 items-center justify-center bg-slate-900 text-orange-300">
                          <PlayCircle className="h-8 w-8" />
                        </div>
                      ) : (
                        <img src={getApiAssetUrl(item.url)} alt={`Media ${index + 1}`} loading="lazy" className="h-20 w-24 object-cover" />
                      )}
                    </button>
                  ))}
                </div>
              ) : null}
            </div>
          </motion.div>
        ) : null}
      </AnimatePresence>
    </div>
  );
};
