import { ArrowRight, Award, Sparkles } from "lucide-react";
import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { Seo } from "../components/seo/Seo";
import { useLanguage } from "../hooks/useLanguage";
import { getApiAssetUrl } from "../lib/api";
import { SITE_NAME, seoText } from "../seo/site";
import { contentService } from "../services/contentService";
import type { Recognition } from "../types";
import { getErrorMessage } from "../utils/errors";
import { getPaginatedItems } from "../utils/pagination";
import { repairMojibake } from "../utils/textCodec";

export const AboutPage = () => {
  const { t, language } = useLanguage();
  const [recognitions, setRecognitions] = useState<Recognition[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const loadRecognitions = async () => {
      setLoading(true);
      setError("");

      try {
        const recognitionsData = await contentService.getRecognitions({ page: 1, limit: 12, paginate: true, featuredOnly: true });
        setRecognitions(getPaginatedItems(recognitionsData).filter((recognition) => recognition.featured !== false));
      } catch (loadError) {
        setError(getErrorMessage(loadError, language === "ar" ? "تعذر تحميل محتوى صفحة من نحن حاليًا." : "Unable to load the About page content right now."));
      } finally {
        setLoading(false);
      }
    };

    loadRecognitions();
  }, [language]);

  const quickLinks = [
    {
      href: "/about",
      title: language === "ar" ? "من نحن" : "About Us",
      body:
        language === "ar"
          ? "تعرّف على رؤية Study Birds وطريقتنا في مرافقة الطالب من أول استشارة حتى بداية الرحلة الجامعية."
          : "Get to know the Study Birds vision and the way we guide students from first consultation to university arrival.",
    },
    {
      href: "/our-event",
      title: language === "ar" ? "فعاليتنا" : "Our Event",
      body:
        language === "ar"
          ? "تابع الفعالية القادمة، واحجز مقعدك بسرعة، واستعرض أهم معارضنا وندواتنا السابقة."
          : "Follow the next event, reserve your seat quickly, and explore our fairs and webinars.",
    },
    {
      href: "/our-story",
      title: language === "ar" ? "قصتنا" : "Our Story",
      body:
        language === "ar"
          ? "اقرأ كيف بدأت الفكرة، وكيف تطورت خدماتنا وشراكاتنا لخدمة الطلاب العرب في الخارج."
          : "Read how the idea started and how our services and partnerships evolved to support Arab students abroad.",
    },
  ];

  return (
    <div className="space-y-8">
      <Seo
        title={seoText(language, `About ${SITE_NAME}`, `عن ${SITE_NAME}`)}
        description={seoText(
          language,
          `Learn how ${SITE_NAME} helps students compare universities, apply to international programs, and stay connected through events and student communities.`,
          `تعرّف على كيفية مساعدة ${SITE_NAME} للطلاب في مقارنة الجامعات، واختيار البرامج، والبقاء على تواصل من خلال الفعاليات والمجتمع الطلابي.`
        )}
      />

      {error ? <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div> : null}

      <section className="relative overflow-hidden rounded-[2.5rem] bg-[linear-gradient(135deg,#0b1730_0%,#0f3b72_60%,#1d4ed8_100%)] px-8 py-10 text-white sm:px-10 sm:py-12">
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_top_right,rgba(249,115,22,0.24),transparent_28%)]" />
        <div className="relative grid gap-8 xl:grid-cols-[1.1fr_0.9fr] xl:items-center">
          <div>
            <div className="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-4 py-2 text-xs font-semibold uppercase tracking-[0.3em] text-orange-200">
              <Sparkles className="h-4 w-4" />
              {language === "ar" ? "من نحن" : "About Us"}
            </div>
            <h1 className="mt-5 max-w-3xl text-4xl font-semibold leading-tight sm:text-5xl">{t("aboutTitle")}</h1>
            <p className="mt-5 max-w-3xl text-base leading-8 text-slate-200 sm:text-lg">{t("aboutBody")}</p>
          </div>

          <div className="grid gap-4">
            {quickLinks.map((item) => (
              <Link
                key={item.href}
                to={item.href}
                className="group rounded-[1.8rem] border border-white/10 bg-white/10 p-5 backdrop-blur-sm transition hover:-translate-y-1 hover:bg-white/15"
              >
                <div className="flex items-center justify-between gap-4">
                  <h2 className="text-xl font-semibold text-white">{item.title}</h2>
                  <ArrowRight className="h-5 w-5 text-orange-300 transition group-hover:translate-x-1" />
                </div>
                <p className="mt-3 text-sm leading-7 text-slate-200">{item.body}</p>
              </Link>
            ))}
          </div>
        </div>
      </section>

      <section className="overflow-hidden rounded-[2.5rem] bg-fusion px-8 py-10 text-white sm:px-10">
        <h2 className="text-3xl font-semibold">{t("recognitionsTitle")}</h2>
        <p className="mt-3 max-w-2xl text-sm leading-7 text-brand-100/85">{t("recognitionsBody")}</p>

        {loading ? <div className="mt-6 text-sm text-brand-100/80">{language === "ar" ? "جارٍ تحميل الشهادات..." : "Loading recognitions..."}</div> : null}

        {!loading && recognitions.length ? (
          <div className="mt-6 grid grid-cols-2 gap-4 sm:grid-cols-3">
            {recognitions.map((recognition) => {
              const imageUrl = recognition.image ? getApiAssetUrl(recognition.image) : "";
              const title = repairMojibake(recognition.title);

              return (
                <div
                  key={recognition._id}
                  className="overflow-hidden rounded-[1.6rem] border border-white/10 bg-white/5 p-2 backdrop-blur-sm"
                >
                  <Link to={`/recognitions/${recognition.slug || recognition._id}`} className="block">
                    {imageUrl ? (
                      <div className="flex h-32 w-full items-center justify-center rounded-[1.2rem] bg-[linear-gradient(180deg,rgba(255,255,255,0.16)_0%,rgba(255,255,255,0.06)_100%)] p-3 sm:h-40 lg:h-48">
                        <img src={imageUrl} alt={title} loading="lazy" className="h-full w-full rounded-[1rem] object-contain" />
                      </div>
                    ) : (
                      <div className="flex h-32 w-full flex-col justify-between rounded-[1.2rem] bg-[linear-gradient(180deg,rgba(255,255,255,0.18)_0%,rgba(255,255,255,0.08)_100%)] p-4 sm:h-40 sm:p-5 lg:h-48">
                        <span className="inline-flex h-12 w-12 items-center justify-center rounded-2xl border border-white/15 bg-white/10 text-brand-100">
                          <Award size={22} />
                        </span>
                        <p className="text-lg font-semibold text-white">{title}</p>
                      </div>
                    )}
                    <div className="px-1 pb-1 pt-3">
                      <p className="text-sm font-semibold text-white">{title}</p>
                      <p className="mt-2 text-xs font-medium text-brand-100">{t("viewRecognition")}</p>
                    </div>
                  </Link>
                </div>
              );
            })}
          </div>
        ) : null}
      </section>
    </div>
  );
};
