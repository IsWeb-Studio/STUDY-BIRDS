import { getHomeRouteForRole } from "../utils/roleHome";
import { useEffect, useRef, useState } from "react";
import { motion } from "framer-motion";
import { ArrowLeft, ArrowRight, Award, BookOpenCheck, Building2, ChevronDown, Globe2, UsersRound } from "lucide-react";
import { Link } from "react-router-dom";
import { HeroSection } from "../components/marketing/HeroSection";
import { Seo } from "../components/seo/Seo";
import { StatsCard } from "../components/dashboard/StatsCard";
import { DestinationCard } from "../components/marketing/DestinationCard";
import { StudyFieldCard } from "../components/marketing/StudyFieldCard";
import { UniversityCard } from "../components/marketing/UniversityCard";
import { TestimonialCard } from "../components/marketing/TestimonialCard";
import { LoadingSpinner } from "../components/LoadingSpinner";
import { useAuth } from "../hooks/useAuth";
import { contentService } from "../services/contentService";
import type { Country, Faq, OurService, Recognition, StudyField, Testimonial, University } from "../types";
import { useLanguage } from "../hooks/useLanguage";
import { SITE_NAME, getSiteUrl, seoText } from "../seo/site";
import { dt } from "../utils/dashboardTranslations";
import { journeyShowcaseImages } from "../utils/marketingVisuals";
import { repairMojibake } from "../utils/textCodec";

const isMeaningfulServiceTitle = (value: string) => {
  const text = repairMojibake(value).trim();

  if (text.length < 4) {
    return false;
  }

  if (/\s/.test(text)) {
    return true;
  }

  const normalizedChars = Array.from(text.replace(/[^\p{L}\p{N}]/gu, ""));
  return new Set(normalizedChars).size >= 5;
};

export const HomePage = () => {
  const { t, tv, language } = useLanguage();
  const { user } = useAuth();
  const [countries, setCountries] = useState<Country[]>([]);
  const [studyFields, setStudyFields] = useState<StudyField[]>([]);
  const [universities, setUniversities] = useState<University[]>([]);
  const [testimonials, setTestimonials] = useState<Testimonial[]>([]);
  const [recognitions, setRecognitions] = useState<Recognition[]>([]);
  const [services, setServices] = useState<OurService[]>([]);
  const [faqs, setFaqs] = useState<Faq[]>([]);
  const [contentLoading, setContentLoading] = useState(true);
  const [contentLoadFailed, setContentLoadFailed] = useState(false);
  const [selectedUniversityCountry, setSelectedUniversityCountry] = useState("all");
  const [openFaqId, setOpenFaqId] = useState<string | null>(null);
  const countriesScrollerRef = useRef<HTMLDivElement | null>(null);
  const studyFieldsScrollerRef = useRef<HTMLDivElement | null>(null);
  const universitiesScrollerRef = useRef<HTMLDivElement | null>(null);
  const recognitionsScrollerRef = useRef<HTMLDivElement | null>(null);
  const servicesScrollerRef = useRef<HTMLDivElement | null>(null);
  const testimonialsScrollerRef = useRef<HTMLDivElement | null>(null);

  const primaryHref = user ? getHomeRouteForRole(user.role, user.permissions) : "/register";

  const primaryLabel =
    !user ? t("startJourney") : user.role === "student" ? t("studentProfile") : user.role === "partner" ? dt(language, "profileHub") : t("dashboard");

  useEffect(() => {
    let active = true;

    contentService
      .getHomePageContent()
      .then((data) => {
        if (!active) {
          return;
        }

        setCountries(data.countries);
        setStudyFields(data.studyFields);
        setUniversities(data.universities);
        setTestimonials(data.testimonials);
        setRecognitions(data.recognitions);
        setServices(data.services);
        setFaqs(data.faqs);
        setContentLoadFailed(false);
      })
      .catch(() => {
        if (active) {
          setContentLoadFailed(true);
        }
      })
      .finally(() => {
        if (active) {
          setContentLoading(false);
        }
      });

    return () => {
      active = false;
    };
  }, []);

  const universityCountries = universities.reduce<Country[]>((list, university) => {
    if (!university.country?._id || list.some((country) => country._id === university.country?._id)) {
      return list;
    }

    return [...list, university.country];
  }, []);

  const visibleUniversities = universities
    .filter((university) => selectedUniversityCountry === "all" || university.country?._id === selectedUniversityCountry);

  const homeDescription = seoText(
    language,
    `Explore universities, compare international programs, and apply to study abroad with ${SITE_NAME} in English and Arabic.`,
    `استكشف الجامعات، وقارن البرامج الدولية، وقدّم للدراسة بالخارج مع ${SITE_NAME} باللغتين العربية والإنجليزية.`
  );

  const normalizedHomeDescription = repairMojibake(homeDescription);

  const structuredData = [
    {
      "@context": "https://schema.org",
      "@type": "Organization",
      name: SITE_NAME,
      url: getSiteUrl(),
      email: import.meta.env.VITE_CONTACT_EMAIL?.trim() || "hello@studybirds.net",
    },
    {
      "@context": "https://schema.org",
      "@type": "WebSite",
      name: SITE_NAME,
      url: getSiteUrl(),
      inLanguage: ["en", "ar"],
      potentialAction: {
        "@type": "SearchAction",
        target: `${getSiteUrl()}/programs?keyword={search_term_string}&lang=${language}`,
        "query-input": "required name=search_term_string",
      },
    },
  ];

  const scrollUniversities = (direction: "left" | "right") => {
    universitiesScrollerRef.current?.scrollBy({
      left: direction === "right" ? 360 : -360,
      behavior: "smooth",
    });
  };

  const scrollRecognitions = (direction: "left" | "right") => {
    recognitionsScrollerRef.current?.scrollBy({
      left: direction === "right" ? 320 : -320,
      behavior: "smooth",
    });
  };

  const scrollCountries = (direction: "left" | "right") => {
    countriesScrollerRef.current?.scrollBy({
      left: direction === "right" ? 320 : -320,
      behavior: "smooth",
    });
  };

  const scrollStudyFields = (direction: "left" | "right") => {
    studyFieldsScrollerRef.current?.scrollBy({
      left: direction === "right" ? 320 : -320,
      behavior: "smooth",
    });
  };

  const scrollServices = (direction: "left" | "right") => {
    servicesScrollerRef.current?.scrollBy({
      left: direction === "right" ? 320 : -320,
      behavior: "smooth",
    });
  };

  const scrollTestimonials = (direction: "left" | "right") => {
    testimonialsScrollerRef.current?.scrollBy({
      left: direction === "right" ? 360 : -360,
      behavior: "smooth",
    });
  };

  const sectionTransition = { duration: 0.55, ease: "easeOut" } as const;
  const displayedFaqs = faqs.slice(0, 4);
  const normalizedServices = services.map((service) => ({
    ...service,
    title: repairMojibake(service.title),
    detailTitle: repairMojibake(service.detailTitle),
    detailBody: repairMojibake(service.detailBody),
  }));
  const fallbackServices: OurService[] = [
    {
      _id: "fallback-service-1",
      title: language === "ar" ? "\u0627\u0644\u0642\u0628\u0648\u0644 \u0627\u0644\u062C\u0627\u0645\u0639\u064A" : "University admissions",
      image: "",
      detailTitle: "",
      detailBody: "",
      detailImage: "",
      featured: true,
      sortOrder: 0,
    },
    {
      _id: "fallback-service-2",
      title: language === "ar" ? "\u062A\u062C\u0647\u064A\u0632 \u0627\u0644\u0645\u0633\u062A\u0646\u062F\u0627\u062A" : "Document preparation",
      image: "",
      detailTitle: "",
      detailBody: "",
      detailImage: "",
      featured: true,
      sortOrder: 1,
    },
    {
      _id: "fallback-service-3",
      title: language === "ar" ? "\u062F\u0639\u0645 \u0627\u0644\u062A\u0623\u0634\u064A\u0631\u0629 \u0648\u0627\u0644\u0625\u0642\u0627\u0645\u0629" : "Visa and residency support",
      image: "",
      detailTitle: "",
      detailBody: "",
      detailImage: "",
      featured: true,
      sortOrder: 2,
    },
  ];
  const visibleServices = normalizedServices.filter((service) => isMeaningfulServiceTitle(service.title));
  const homepageServices = visibleServices.length ? visibleServices : fallbackServices;

  return (
    <div className="space-y-16">
      <Seo
        title={seoText(language, "Study Abroad Platform", "منصة الدراسة بالخارج")}
        description={normalizedHomeDescription}
        keywords={[
          SITE_NAME,
          "study abroad platform",
          "international programs",
          "university applications",
          "الدراسة بالخارج",
          "التقديم على الجامعات",
        ]}
        structuredData={structuredData}
      />

      <HeroSection />

      {contentLoading ? (
        <div aria-busy="true">
          <LoadingSpinner />
        </div>
      ) : null}
      {contentLoadFailed ? (
        <div className="rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
          {language === "ar" ? "تعذر تحميل بعض البيانات الديناميكية حاليًا." : "Some dynamic content could not be loaded right now."}
        </div>
      ) : null}

      <motion.section
        initial={{ opacity: 0, y: 24 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true, amount: 0.25 }}
        transition={sectionTransition}
        className="grid grid-cols-2 gap-2.5 xl:grid-cols-4"
      >
        {[
          { label: t("studentsHelped"), value: "50,000+", icon: <UsersRound size={20} /> },
          { label: t("programs"), value: "10,000+", icon: <BookOpenCheck size={20} /> },
          { label: t("partnerInstitutions"), value: "500+", icon: <Building2 size={20} /> },
          { label: t("studyDestinations"), value: "20+", icon: <Globe2 size={20} /> },
        ].map((stat, index) => (
          <motion.div
            key={stat.label}
            initial={{ opacity: 0, y: 18 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, amount: 0.3 }}
            transition={{ duration: 0.4, delay: index * 0.08 }}
          >
            <StatsCard label={stat.label} value={stat.value} icon={stat.icon} />
          </motion.div>
        ))}
      </motion.section>

      <motion.section
        initial={{ opacity: 0, y: 28 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true, amount: 0.2 }}
        transition={sectionTransition}
        className="panel overflow-hidden rounded-[2.5rem] px-8 py-10 text-slate-900 sm:px-10"
      >
        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <h2 className="text-3xl font-semibold">
            {recognitions.length ? t("recognitionsTitle") : t("homeExperienceTitle")}
          </h2>
        </div>

        <div className="relative mt-6 -mx-2 overflow-hidden sm:mx-0">
          <button
            type="button"
            onClick={() => scrollRecognitions("left")}
            className="absolute left-3 top-1/2 z-20 hidden h-11 w-11 -translate-y-1/2 items-center justify-center rounded-full border border-slate-200 bg-white/95 text-slate-700 shadow-soft transition hover:border-brand-300 hover:text-brand-700 lg:inline-flex"
            aria-label={language === "ar" ? "Ø§Ù„ØªÙ…Ø±ÙŠØ± ÙŠÙ…ÙŠÙ†Ù‹Ø§" : "Scroll left"}
          >
            <ArrowLeft size={18} />
          </button>
          <button
            type="button"
            onClick={() => scrollRecognitions("right")}
            className="absolute right-3 top-1/2 z-20 hidden h-11 w-11 -translate-y-1/2 items-center justify-center rounded-full border border-slate-200 bg-white/95 text-slate-700 shadow-soft transition hover:border-brand-300 hover:text-brand-700 lg:inline-flex"
            aria-label={language === "ar" ? "Ø§Ù„ØªÙ…Ø±ÙŠØ± ÙŠØ³Ø§Ø±Ù‹Ø§" : "Scroll right"}
          >
            <ArrowRight size={18} />
          </button>
          <div className="pointer-events-none absolute inset-y-0 left-0 z-10 w-6 bg-gradient-to-r from-white to-transparent sm:w-10" />
          <div className="pointer-events-none absolute inset-y-0 right-0 z-10 w-6 bg-gradient-to-l from-white to-transparent sm:w-10" />
          <div
            ref={recognitionsScrollerRef}
            className="flex gap-5 overflow-x-auto px-2 pb-2 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden sm:px-0"
          >
            {(recognitions.length
              ? recognitions.map((recognition) => ({
                  key: recognition._id,
                  title: recognition.title,
                  src: recognition.image || "",
                  href: `/recognitions/${recognition.slug || recognition._id}`,
                }))
              : journeyShowcaseImages.map((image) => ({
                  key: image.title,
                  title: image.title,
                  src: image.src,
                  href: "",
                }))).map((item, index) => (
              <motion.div
                key={item.key}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.42, delay: index * 0.1 }}
                className="w-[calc(50%-0.625rem)] min-w-[calc(50%-0.625rem)] overflow-hidden rounded-[1.6rem] border border-slate-200 bg-white p-2 sm:w-[320px] sm:min-w-[320px]"
              >
                {item.href ? (
                  <Link to={item.href} className="block">
                    {item.src ? (
                      <div className="flex h-32 w-full items-center justify-center rounded-[1.2rem] bg-slate-50 p-3 sm:h-40 lg:h-48">
                        <img src={item.src} alt={item.title} className="h-full w-full rounded-[1rem] object-contain" />
                      </div>
                    ) : (
                      <div className="flex h-32 w-full flex-col justify-between rounded-[1.2rem] bg-slate-50 p-4 sm:h-40 sm:p-5 lg:h-48">
                        <span className="inline-flex h-12 w-12 items-center justify-center rounded-2xl border border-slate-200 bg-white text-brand-700">
                          <Award size={22} />
                        </span>
                        <p className="text-lg font-semibold text-slate-900">{item.title}</p>
                      </div>
                    )}
                    <div className="px-1 pb-1 pt-3">
                      <p className="text-sm font-semibold text-slate-900">{item.title}</p>
                      <p className="mt-2 text-xs font-medium text-brand-700">{t("viewRecognition")}</p>
                    </div>
                  </Link>
                ) : item.src ? (
                  <div className="flex h-32 w-full items-center justify-center rounded-[1.2rem] bg-slate-50 p-3 sm:h-40 lg:h-48">
                    <img src={item.src} alt={item.title} className="h-full w-full rounded-[1rem] object-contain" />
                  </div>
                ) : (
                  <div className="flex h-32 w-full flex-col justify-between rounded-[1.2rem] bg-slate-50 p-4 sm:h-40 sm:p-5 lg:h-48">
                    <span className="inline-flex h-12 w-12 items-center justify-center rounded-2xl border border-slate-200 bg-white text-brand-700">
                      <Award size={22} />
                    </span>
                    <p className="text-lg font-semibold text-slate-900">{item.title}</p>
                  </div>
                )}
              </motion.div>
            ))}
          </div>
        </div>
      </motion.section>

      {homepageServices.length ? (
        <motion.section
          initial={{ opacity: 0, y: 28 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.2 }}
          transition={sectionTransition}
          className="panel overflow-hidden rounded-[2.5rem] px-8 py-10 text-slate-900 sm:px-10"
        >
          <div>
            <div>
              <h2 className="text-3xl font-semibold">{t("servicesTitle")}</h2>
              <p className="mt-3 max-w-2xl text-sm leading-7 text-slate-600">{t("servicesBody")}</p>
            </div>
          </div>

          <div className="relative mt-6 -mx-2 overflow-hidden sm:mx-0">
            <button
              type="button"
              onClick={() => scrollServices("left")}
              className="absolute left-3 top-1/2 z-20 hidden h-11 w-11 -translate-y-1/2 items-center justify-center rounded-full border border-slate-200 bg-white/95 text-slate-700 shadow-soft transition hover:border-brand-300 hover:text-brand-700 lg:inline-flex"
              aria-label={language === "ar" ? "??????? ??????" : "Scroll left"}
            >
              <ArrowLeft size={18} />
            </button>
            <button
              type="button"
              onClick={() => scrollServices("right")}
              className="absolute right-3 top-1/2 z-20 hidden h-11 w-11 -translate-y-1/2 items-center justify-center rounded-full border border-slate-200 bg-white/95 text-slate-700 shadow-soft transition hover:border-brand-300 hover:text-brand-700 lg:inline-flex"
              aria-label={language === "ar" ? "??????? ??????" : "Scroll right"}
            >
              <ArrowRight size={18} />
            </button>
            <div className="pointer-events-none absolute inset-y-0 left-0 z-10 w-6 bg-gradient-to-r from-white to-transparent sm:w-10" />
            <div className="pointer-events-none absolute inset-y-0 right-0 z-10 w-6 bg-gradient-to-l from-white to-transparent sm:w-10" />
            <div
              ref={servicesScrollerRef}
              className="flex gap-5 overflow-x-auto px-2 pb-2 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden sm:px-0"
            >
            {homepageServices.map((service, index) => {
              const serviceHref = service._id.startsWith("fallback-service-") ? "/services" : `/services/${service.slug || service._id}`;

              return (
              <motion.div
                key={service._id}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.42, delay: index * 0.1 }}
                className="w-[calc(50%-0.625rem)] min-w-[calc(50%-0.625rem)] overflow-hidden rounded-[1.6rem] border border-slate-200 bg-white p-2 sm:w-[320px] sm:min-w-[320px]"
              >
                <Link to={serviceHref} className="block">
                  {service.image ? (
                    <div className="flex h-32 w-full items-center justify-center rounded-[1.2rem] bg-slate-50 p-3 sm:h-40 lg:h-48">
                      <img src={service.image} alt={service.title} className="h-full w-full rounded-[1rem] object-contain" />
                    </div>
                  ) : (
                    <div className="flex h-32 w-full flex-col justify-between rounded-[1.2rem] bg-slate-50 p-4 sm:h-40 sm:p-5 lg:h-48">
                      <span className="inline-flex h-12 w-12 items-center justify-center rounded-2xl border border-slate-200 bg-white text-brand-700">
                        <Award size={22} />
                      </span>
                      <p className="text-lg font-semibold text-slate-900">{service.title}</p>
                    </div>
                  )}
                  <div className="px-1 pb-1 pt-3">
                    <p className="text-sm font-semibold text-slate-900">{service.title}</p>
                    <p className="mt-2 text-xs font-medium text-brand-700">
                      {language === "ar" ? "\u0639\u0631\u0636 \u062A\u0641\u0627\u0635\u064A\u0644 \u0627\u0644\u062E\u062F\u0645\u0629" : "View service details"}
                    </p>
                  </div>
                </Link>
              </motion.div>
              );
            })}
            </div>
          </div>
        </motion.section>
      ) : null}

      {studyFields.length ? (
        <motion.section
          initial={{ opacity: 0, y: 28 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.2 }}
          transition={sectionTransition}
          className="panel overflow-hidden p-8 sm:p-10"
        >
          <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
            <div className="max-w-2xl">
              <p className="text-sm font-semibold uppercase tracking-[0.3em] text-brand-700">{t("studyFieldsEyebrow")}</p>
              <h2 className="mt-3 text-3xl font-semibold text-slate-900">{t("studyFieldsTitle")}</h2>
              <p className="mt-3 text-sm leading-7 text-slate-600">{t("studyFieldsBody")}</p>
            </div>

          </div>

          <div className="relative mt-8 -mx-2 overflow-hidden sm:mx-0">
            <button
              type="button"
              onClick={() => scrollStudyFields("left")}
              className="absolute left-3 top-1/2 z-20 hidden h-11 w-11 -translate-y-1/2 items-center justify-center rounded-full border border-slate-200 bg-white/95 text-slate-700 shadow-soft transition hover:border-brand-300 hover:text-brand-700 lg:inline-flex"
              aria-label={language === "ar" ? "??????? ??????" : "Scroll left"}
            >
              <ArrowLeft size={18} />
            </button>
            <button
              type="button"
              onClick={() => scrollStudyFields("right")}
              className="absolute right-3 top-1/2 z-20 hidden h-11 w-11 -translate-y-1/2 items-center justify-center rounded-full border border-slate-200 bg-white/95 text-slate-700 shadow-soft transition hover:border-brand-300 hover:text-brand-700 lg:inline-flex"
              aria-label={language === "ar" ? "??????? ??????" : "Scroll right"}
            >
              <ArrowRight size={18} />
            </button>
            <div className="pointer-events-none absolute inset-y-0 left-0 z-10 w-6 bg-gradient-to-r from-white to-transparent sm:w-10" />
            <div className="pointer-events-none absolute inset-y-0 right-0 z-10 w-6 bg-gradient-to-l from-white to-transparent sm:w-10" />
            <div
              ref={studyFieldsScrollerRef}
              className="flex gap-5 overflow-x-auto px-2 pb-2 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden sm:px-0"
            >
            {studyFields.map((studyField) => (
              <motion.div
                key={studyField._id}
                initial={{ opacity: 0, y: 18 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, amount: 0.2 }}
                transition={{ duration: 0.4 }}
                className="w-[calc(100%-0.5rem)] min-w-[calc(100%-0.5rem)] sm:w-[320px] sm:min-w-[320px]"
              >
                <StudyFieldCard studyField={studyField} />
              </motion.div>
            ))}
            </div>
          </div>
        </motion.section>
      ) : null}

      <motion.section
        initial={{ opacity: 0, y: 28 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true, amount: 0.2 }}
        transition={sectionTransition}
        className="panel overflow-hidden p-8 sm:p-10"
      >
        <div className="flex items-end justify-between gap-4">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.3em] text-brand-700">{t("destinations")}</p>
            <h2 className="mt-3 text-3xl font-semibold text-slate-900">{t("featuredDestinations")}</h2>
          </div>
          <div className="flex items-center gap-3 lg:hidden">
            <button
              type="button"
              onClick={() => scrollCountries("left")}
              className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-slate-200 bg-white text-slate-700 transition hover:border-brand-300 hover:text-brand-700"
              aria-label={language === "ar" ? "??????? ??????" : "Scroll left"}
            >
              <ArrowLeft size={18} />
            </button>
            <button
              type="button"
              onClick={() => scrollCountries("right")}
              className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-slate-200 bg-white text-slate-700 transition hover:border-brand-300 hover:text-brand-700"
              aria-label={language === "ar" ? "??????? ??????" : "Scroll right"}
            >
              <ArrowRight size={18} />
            </button>
          </div>
        </div>

        <div className="relative mt-8 -mx-2 overflow-hidden sm:mx-0">
          <button
            type="button"
            onClick={() => scrollCountries("left")}
            className="absolute left-3 top-1/2 z-20 hidden h-11 w-11 -translate-y-1/2 items-center justify-center rounded-full border border-slate-200 bg-white/95 text-slate-700 shadow-soft transition hover:border-brand-300 hover:text-brand-700 lg:inline-flex"
            aria-label={language === "ar" ? "Ø§Ù„ØªÙ…Ø±ÙŠØ± ÙŠÙ…ÙŠÙ†Ù‹Ø§" : "Scroll left"}
          >
            <ArrowLeft size={18} />
          </button>
          <button
            type="button"
            onClick={() => scrollCountries("right")}
            className="absolute right-3 top-1/2 z-20 hidden h-11 w-11 -translate-y-1/2 items-center justify-center rounded-full border border-slate-200 bg-white/95 text-slate-700 shadow-soft transition hover:border-brand-300 hover:text-brand-700 lg:inline-flex"
            aria-label={language === "ar" ? "Ø§Ù„ØªÙ…Ø±ÙŠØ± ÙŠØ³Ø§Ø±Ù‹Ø§" : "Scroll right"}
          >
            <ArrowRight size={18} />
          </button>
          <div className="pointer-events-none absolute inset-y-0 left-0 z-10 w-6 bg-gradient-to-r from-white to-transparent sm:w-10" />
          <div className="pointer-events-none absolute inset-y-0 right-0 z-10 w-6 bg-gradient-to-l from-white to-transparent sm:w-10" />
          <div
            ref={countriesScrollerRef}
            className="flex gap-5 overflow-x-auto px-2 pb-2 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden sm:px-0"
          >
          {countries.map((country) => (
            <motion.div
              key={country._id}
              initial={{ opacity: 0, y: 18 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, amount: 0.2 }}
              transition={{ duration: 0.4 }}
              className="w-[calc(50%-0.625rem)] min-w-[calc(50%-0.625rem)] sm:w-[320px] sm:min-w-[320px]"
            >
              <DestinationCard country={country} />
            </motion.div>
          ))}
          </div>
        </div>
      </motion.section>

      <motion.section
        initial={{ opacity: 0, y: 28 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true, amount: 0.2 }}
        transition={sectionTransition}
        className="panel overflow-hidden p-8 sm:p-10"
      >
        <div className="flex items-end justify-between gap-4">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.3em] text-brand-700">{t("universities")}</p>
            <h2 className="mt-3 text-3xl font-semibold text-slate-900">{t("featuredUniversities")}</h2>
          </div>
        </div>

        <div className="relative mt-6 -mx-2 overflow-hidden sm:mx-0">
          <div className="pointer-events-none absolute inset-y-0 left-0 z-10 w-6 bg-gradient-to-r from-white to-transparent sm:hidden" />
          <div className="pointer-events-none absolute inset-y-0 right-0 z-10 w-6 bg-gradient-to-l from-white to-transparent sm:hidden" />
          <div className="flex snap-x gap-3 overflow-x-auto px-2 pb-2 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden sm:flex-wrap sm:overflow-visible sm:px-0 sm:pb-0">
          <button
            type="button"
            onClick={() => setSelectedUniversityCountry("all")}
            className={`shrink-0 snap-start whitespace-nowrap rounded-full px-5 py-2 text-sm font-semibold transition ${
              selectedUniversityCountry === "all"
                ? "bg-white text-brand-900 shadow-soft"
                : "border border-slate-200 bg-slate-50 text-slate-700 hover:border-brand-300 hover:text-brand-700"
            }`}
          >
            {t("allCountries")}
          </button>
          {universityCountries.map((country) => (
            <button
              key={country._id}
              type="button"
              onClick={() => setSelectedUniversityCountry(country._id)}
              className={`shrink-0 snap-start whitespace-nowrap rounded-full px-5 py-2 text-sm font-semibold transition ${
                selectedUniversityCountry === country._id
                  ? "bg-white text-brand-900 shadow-soft"
                  : "border border-slate-200 bg-slate-50 text-slate-700 hover:border-brand-300 hover:text-brand-700"
              }`}
            >
              {tv(country.name)}
            </button>
          ))}
          </div>
        </div>

        <div className="relative mt-8 -mx-2 overflow-hidden sm:mx-0">
          {visibleUniversities.length > 3 ? (
            <>
              <button
                type="button"
                onClick={() => scrollUniversities(language === "ar" ? "left" : "right")}
                className="absolute left-3 top-1/2 z-20 hidden h-11 w-11 -translate-y-1/2 items-center justify-center rounded-full border border-slate-200 bg-white/95 text-slate-700 shadow-soft transition hover:border-brand-300 hover:text-brand-700 lg:inline-flex"
                aria-label={language === "ar" ? "????? ???????? ??????" : "Scroll universities left"}
              >
                <ArrowLeft className="h-5 w-5" />
              </button>
              <button
                type="button"
                onClick={() => scrollUniversities(language === "ar" ? "right" : "left")}
                className="absolute right-3 top-1/2 z-20 hidden h-11 w-11 -translate-y-1/2 items-center justify-center rounded-full border border-slate-200 bg-white/95 text-slate-700 shadow-soft transition hover:border-brand-300 hover:text-brand-700 lg:inline-flex"
                aria-label={language === "ar" ? "????? ???????? ??????" : "Scroll universities right"}
              >
                <ArrowRight className="h-5 w-5" />
              </button>
            </>
          ) : null}
          <div className="pointer-events-none absolute inset-y-0 left-0 z-10 w-6 bg-gradient-to-r from-white to-transparent sm:w-10" />
          <div className="pointer-events-none absolute inset-y-0 right-0 z-10 w-6 bg-gradient-to-l from-white to-transparent sm:w-10" />
          <div ref={universitiesScrollerRef} className="flex gap-5 overflow-x-auto px-2 pb-2 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden sm:px-0">
          {visibleUniversities.map((university) => (
            <motion.div
              key={university._id}
              initial={{ opacity: 0, y: 18 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, amount: 0.2 }}
              transition={{ duration: 0.4 }}
              className="w-[calc(50%-0.625rem)] min-w-[calc(50%-0.625rem)] sm:w-[340px] sm:min-w-[340px]"
            >
              <UniversityCard university={university} />
            </motion.div>
          ))}
          </div>
        </div>
      </motion.section>

      {faqs.length ? (
        <motion.section
          id="faq"
          initial={{ opacity: 0, y: 28 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.2 }}
          transition={sectionTransition}
          className="panel overflow-hidden bg-white p-8 sm:p-10"
        >
          <div className="max-w-2xl">
            <p className="text-sm font-semibold uppercase tracking-[0.3em] text-brand-700">{t("faqEyebrow")}</p>
            <h2 className="mt-3 text-3xl font-semibold text-slate-900">{t("faqTitle")}</h2>
            <p className="mt-3 text-sm leading-7 text-slate-600">{t("faqBody")}</p>
          </div>

          <div className="mt-8 space-y-4">
            {displayedFaqs.map((faq) => {
              const isOpen = openFaqId === faq._id;

              return (
                <div key={faq._id} className="overflow-hidden rounded-[1.8rem] border border-slate-200 bg-slate-50/80">
                  <button
                    type="button"
                    onClick={() => setOpenFaqId((current) => (current === faq._id ? null : faq._id))}
                    className="flex w-full items-center justify-between gap-4 px-6 py-5 text-start"
                  >
                    <span className="text-base font-semibold text-slate-900 sm:text-lg">{faq.question}</span>
                    <span className={`inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-white text-slate-700 transition ${isOpen ? "rotate-180" : ""}`}>
                      <ChevronDown className="h-5 w-5" />
                    </span>
                  </button>
                  {isOpen ? <div className="border-t border-slate-200 px-6 py-5 text-sm leading-7 text-slate-600">{faq.answer}</div> : null}
                </div>
              );
            })}
          </div>

          {faqs.length > 4 ? (
            <div className="mt-8">
              <Link
                to="/faqs"
                className="inline-flex rounded-full bg-brand-900 px-6 py-3 text-sm font-semibold text-white transition hover:bg-brand-800"
              >
                {language === "ar" ? "المزيد" : "More"}
              </Link>
            </div>
          ) : null}
        </motion.section>
      ) : null}

      <motion.section
        initial={{ opacity: 0, y: 28 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true, amount: 0.2 }}
        transition={sectionTransition}
      >
        <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.3em] text-brand-700">{t("studentStories")}</p>
            <h2 className="mt-3 text-3xl font-semibold text-slate-900">{t("testimonialsTitle")}</h2>
          </div>
          <div className="flex items-center gap-2 self-start sm:self-auto">
            <button
              type="button"
              onClick={() => scrollTestimonials("left")}
              className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-slate-200 bg-white text-slate-700 transition hover:border-brand-300 hover:text-brand-700"
              aria-label={language === "ar" ? "ØªÙ…Ø±ÙŠØ± Ø§Ù„Ø¢Ø±Ø§Ø¡ Ù„Ù„ÙŠÙ…ÙŠÙ†" : "Scroll testimonials left"}
            >
              <ArrowLeft size={18} />
            </button>
            <button
              type="button"
              onClick={() => scrollTestimonials("right")}
              className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-slate-200 bg-white text-slate-700 transition hover:border-brand-300 hover:text-brand-700"
              aria-label={language === "ar" ? "ØªÙ…Ø±ÙŠØ± Ø§Ù„Ø¢Ø±Ø§Ø¡ Ù„Ù„ÙŠØ³Ø§Ø±" : "Scroll testimonials right"}
            >
              <ArrowRight size={18} />
            </button>
          </div>
        </div>

        <div ref={testimonialsScrollerRef} className="mt-8 flex gap-4 overflow-x-auto pb-4 [-ms-overflow-style:none] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
          {testimonials.map((testimonial) => (
            <motion.div
              key={testimonial._id}
              initial={{ opacity: 0, y: 18 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, amount: 0.2 }}
              transition={{ duration: 0.4 }}
              className="min-w-[320px] flex-none sm:min-w-[380px] lg:min-w-[420px]"
            >
              <TestimonialCard testimonial={testimonial} />
            </motion.div>
          ))}
        </div>
      </motion.section>

      <motion.section
        initial={{ opacity: 0, y: 28 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true, amount: 0.2 }}
        transition={sectionTransition}
        className="panel overflow-hidden bg-fusion p-8 text-white"
      >
        <h2 className="text-3xl font-semibold">{t("readyNextChapter")}</h2>
        <p className="mt-4 max-w-2xl text-brand-100">{t("ctaDescription")}</p>
        <div className="mt-6">
          <Link to={primaryHref} className="rounded-full bg-white px-6 py-3 font-semibold text-brand-900">
            {primaryLabel}
          </Link>
        </div>
      </motion.section>
    </div>
  );
};


