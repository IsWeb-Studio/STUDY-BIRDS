import { ArrowRight, Compass, Globe2, Sparkles, Target, Users } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { Seo } from "../components/seo/Seo";
import { useLanguage } from "../hooks/useLanguage";
import { getApiAssetUrl } from "../lib/api";
import { SITE_NAME, seoText } from "../seo/site";
import { contentService } from "../services/contentService";
import type { OurStory } from "../types";
import { getErrorMessage } from "../utils/errors";

const emptyStory: OurStory = {
  heroEyebrow: "",
  heroTitle: "",
  heroBody: "",
  heroImage: "",
  heroCtaText: "",
  heroCtaLink: "",
  storyEyebrow: "",
  storyTitle: "",
  storyBody: "",
  storyImage: "",
  missionTitle: "",
  missionBody: "",
  visionTitle: "",
  visionBody: "",
  foundersTitle: "",
  foundersBody: "",
  founders: [],
  timelineTitle: "",
  timelineBody: "",
  timelineItems: [],
  impactTitle: "",
  impactBody: "",
  impactStats: [],
  isPublished: true,
};

export const OurStoryPage = () => {
  const { language } = useLanguage();
  const [story, setStory] = useState<OurStory>(emptyStory);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const loadStory = async () => {
      setLoading(true);
      setError("");
      try {
        const storyData = await contentService.getOurStory();
        setStory(storyData);
      } catch (loadError) {
        setError(getErrorMessage(loadError, language === "ar" ? "تعذر تحميل صفحة قصتنا حاليًا." : "Unable to load the story page right now."));
      } finally {
        setLoading(false);
      }
    };

    loadStory();
  }, [language]);

  const timelineItems = useMemo(
    () => [...(story.timelineItems || [])].sort((a, b) => (a.sortOrder || 0) - (b.sortOrder || 0)),
    [story.timelineItems]
  );

  const heroImage = getApiAssetUrl(story.heroImage);
  const storyImage = getApiAssetUrl(story.storyImage);

  return (
    <div className="space-y-8">
      <Seo
        title={seoText(language, `Our Story | ${SITE_NAME}`, `قصتنا | ${SITE_NAME}`)}
        description={seoText(
          language,
          `Read the story behind ${SITE_NAME}, meet the people behind the mission, and explore the milestones that shaped the journey.`,
          `اكتشف القصة وراء ${SITE_NAME}، وتعرّف على الأشخاص خلف الرسالة، واستعرض المحطات التي شكّلت الرحلة.`
        )}
      />

      {error ? <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div> : null}

      <section className="relative overflow-hidden rounded-[2.8rem] bg-[linear-gradient(135deg,#071225_0%,#0d2d55_58%,#f97316_170%)] px-8 py-12 text-white sm:px-10 sm:py-14">
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_top_right,rgba(249,115,22,0.24),transparent_28%)]" />
        <div className="relative grid gap-8 xl:grid-cols-[1.05fr_0.95fr] xl:items-center">
          <div>
            <div className="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-4 py-2 text-xs font-semibold uppercase tracking-[0.3em] text-orange-200">
              <Sparkles className="h-4 w-4" />
              {story.heroEyebrow || (language === "ar" ? "قصتنا" : "Our Story")}
            </div>
            <h1 className="mt-5 max-w-4xl text-4xl font-semibold leading-tight sm:text-5xl">
              {story.heroTitle || (language === "ar" ? "رحلة بُنيت حول الطالب، لا حول الإجراءات" : "A journey built around the student, not the paperwork")}
            </h1>
            <p className="mt-5 max-w-3xl text-base leading-8 text-slate-200 sm:text-lg">
              {story.heroBody ||
                (language === "ar"
                  ? "نؤمن أن الدراسة بالخارج رحلة تحتاج إلى وضوح ودعم حقيقي، لذلك بنينا Study Birds لتكون نقطة انطلاق موثوقة للطالب العربي."
                  : "We believe studying abroad needs clarity and real support, so we built Study Birds to be a trusted launch point for students.")}
            </p>
            {story.heroCtaText ? (
              story.heroCtaLink ? (
                <a href={story.heroCtaLink} className="mt-8 inline-flex items-center gap-2 rounded-full bg-orange-500 px-6 py-3 text-sm font-semibold text-white transition hover:bg-orange-400">
                  {story.heroCtaText}
                  <ArrowRight className="h-4 w-4" />
                </a>
              ) : (
                <span className="mt-8 inline-flex items-center gap-2 rounded-full bg-orange-500 px-6 py-3 text-sm font-semibold text-white">
                  {story.heroCtaText}
                </span>
              )
            ) : null}
          </div>

          <div className="overflow-hidden rounded-[2.2rem] border border-white/10 bg-white/5 p-3 backdrop-blur-sm">
            {heroImage ? (
              <img src={heroImage} alt={story.heroTitle || "Our Story"} className="h-[22rem] w-full rounded-[1.7rem] object-cover sm:h-[28rem]" />
            ) : (
              <div className="flex h-[22rem] w-full items-center justify-center rounded-[1.7rem] bg-[linear-gradient(135deg,#102b52_0%,#1e40af_100%)] text-slate-200 sm:h-[28rem]">
                <Globe2 className="h-12 w-12" />
              </div>
            )}
          </div>
        </div>
      </section>

      <section className="grid gap-6 xl:grid-cols-[1.05fr_0.95fr]">
        <article className="panel rounded-[2rem] p-7">
          <p className="text-sm font-semibold uppercase tracking-[0.3em] text-brand-700">{story.storyEyebrow || (language === "ar" ? "كيف بدأت" : "How It Started")}</p>
          <h2 className="mt-4 text-3xl font-semibold text-slate-900">{story.storyTitle || (language === "ar" ? "قصة بدأت من احتياج حقيقي" : "A story born from a real need")}</h2>
          <p className="mt-5 text-sm leading-8 text-slate-600">
            {story.storyBody ||
              (language === "ar"
                ? "بدأت الفكرة من رغبة في جعل الطريق الدراسي أوضح وأسهل، بحيث يجد الطالب مكانًا يجمع له الإرشاد، الفرص، والمتابعة في تجربة واحدة متماسكة."
                : "The idea started from a desire to make the student journey clearer and easier with guidance, opportunities, and follow-up in one place.")}
          </p>
          {story.heroCtaText && story.heroCtaLink ? (
            <Link to="/our-event" className="mt-6 inline-flex items-center gap-2 text-sm font-semibold text-brand-700">
              {language === "ar" ? "شاهد فعاليتنا أيضًا" : "See our event too"}
              <ArrowRight className="h-4 w-4" />
            </Link>
          ) : null}
        </article>

        <div className="space-y-6">
          <div className="overflow-hidden rounded-[2rem] border border-slate-200 bg-white p-3 shadow-sm">
            {storyImage ? (
              <img src={storyImage} alt={story.storyTitle || "Story"} className="h-64 w-full rounded-[1.5rem] object-cover" />
            ) : (
              <div className="flex h-64 items-center justify-center rounded-[1.5rem] bg-[linear-gradient(135deg,#dbeafe_0%,#eff6ff_100%)] text-brand-700">
                <Compass className="h-10 w-10" />
              </div>
            )}
          </div>
          <div className="grid gap-4 md:grid-cols-2">
            <article className="panel rounded-[2rem] p-6">
              <span className="inline-flex h-12 w-12 items-center justify-center rounded-2xl bg-orange-100 text-orange-600">
                <Target className="h-5 w-5" />
              </span>
              <h3 className="mt-4 text-2xl font-semibold text-slate-900">{story.missionTitle || (language === "ar" ? "رسالتنا" : "Our Mission")}</h3>
              <p className="mt-3 text-sm leading-7 text-slate-600">{story.missionBody || (language === "ar" ? "أن نمنح الطالب طريقًا أكثر وضوحًا نحو التعليم الدولي." : "To give students a clearer path toward global education.")}</p>
            </article>
            <article className="panel rounded-[2rem] p-6">
              <span className="inline-flex h-12 w-12 items-center justify-center rounded-2xl bg-sky-100 text-sky-700">
                <Globe2 className="h-5 w-5" />
              </span>
              <h3 className="mt-4 text-2xl font-semibold text-slate-900">{story.visionTitle || (language === "ar" ? "رؤيتنا" : "Our Vision")}</h3>
              <p className="mt-3 text-sm leading-7 text-slate-600">{story.visionBody || (language === "ar" ? "أن تكون الفرص الأكاديمية العالمية أقرب، أوضح، وأكثر إنصافًا." : "To make global academic opportunities closer, clearer, and more accessible.")}</p>
            </article>
          </div>
        </div>
      </section>

      {(story.founders?.length || 0) > 0 ? (
        <section className="panel p-8">
          <div className="max-w-3xl">
            <p className="text-sm font-semibold uppercase tracking-[0.3em] text-brand-700">{language === "ar" ? "من يقف خلف الرحلة" : "Who leads the journey"}</p>
            <h2 className="mt-3 text-3xl font-semibold text-slate-900">{story.foundersTitle || (language === "ar" ? "المؤسسون وقادة الفريق" : "Founders and leadership")}</h2>
            {story.foundersBody ? <p className="mt-3 text-sm leading-7 text-slate-600">{story.foundersBody}</p> : null}
          </div>
          <div className="mt-8 grid gap-6 md:grid-cols-2 xl:grid-cols-3">
            {story.founders?.map((founder, index) => (
              <article key={founder._id || index} className="overflow-hidden rounded-[2rem] border border-slate-200 bg-white shadow-sm">
                {founder.image ? (
                  <img src={getApiAssetUrl(founder.image)} alt={founder.name} className="h-72 w-full object-cover" />
                ) : (
                  <div className="flex h-72 items-center justify-center bg-[linear-gradient(135deg,#dbeafe_0%,#eff6ff_100%)] text-brand-700">
                    <Users className="h-10 w-10" />
                  </div>
                )}
                <div className="p-6">
                  <h3 className="text-2xl font-semibold text-slate-900">{founder.name}</h3>
                  {founder.role ? <p className="mt-2 text-sm font-semibold text-orange-600">{founder.role}</p> : null}
                  {founder.bio ? <p className="mt-4 text-sm leading-7 text-slate-600">{founder.bio}</p> : null}
                </div>
              </article>
            ))}
          </div>
        </section>
      ) : null}

      {(timelineItems.length || loading) ? (
        <section className="panel p-8">
          <div className="max-w-3xl">
            <p className="text-sm font-semibold uppercase tracking-[0.3em] text-brand-700">{language === "ar" ? "رحلتنا" : "Our Journey"}</p>
            <h2 className="mt-3 text-3xl font-semibold text-slate-900">{story.timelineTitle || (language === "ar" ? "محطات شكلت قصتنا" : "Milestones that shaped our story")}</h2>
            <p className="mt-3 text-sm leading-7 text-slate-600">{story.timelineBody || (language === "ar" ? "محطات زمنية مختارة توضح كيف تطورت الفكرة والخدمة والأثر." : "A timeline of moments that shaped the service and its impact.")}</p>
          </div>
          <div className="mt-8 space-y-6">
            {timelineItems.map((item, index) => (
              <article key={item._id || index} className="grid gap-5 rounded-[2rem] border border-slate-200 p-5 lg:grid-cols-[160px_1fr_260px] lg:items-start">
                <div>
                  {item.year ? <div className="inline-flex rounded-full bg-brand-50 px-4 py-2 text-sm font-semibold text-brand-700">{item.year}</div> : null}
                  {item.dateLabel ? <p className="mt-3 text-sm font-medium text-orange-600">{item.dateLabel}</p> : null}
                </div>
                <div>
                  <h3 className="text-2xl font-semibold text-slate-900">{item.title}</h3>
                  {item.body ? <p className="mt-4 text-sm leading-8 text-slate-600">{item.body}</p> : null}
                </div>
                <div className="overflow-hidden rounded-[1.6rem] border border-slate-200 bg-slate-50">
                  {item.image ? (
                    <img src={getApiAssetUrl(item.image)} alt={item.title || "Milestone"} className="h-44 w-full object-cover" />
                  ) : (
                    <div className="flex h-44 items-center justify-center text-slate-400">
                      <Sparkles className="h-8 w-8" />
                    </div>
                  )}
                </div>
              </article>
            ))}
          </div>
        </section>
      ) : null}

      {(story.impactStats?.length || 0) > 0 ? (
        <section className="overflow-hidden rounded-[2.5rem] bg-[linear-gradient(135deg,#0b1730_0%,#102f56_60%,#1e40af_100%)] px-8 py-10 text-white sm:px-10">
          <div className="max-w-3xl">
            <p className="text-sm font-semibold uppercase tracking-[0.3em] text-orange-200">{language === "ar" ? "أثرنا" : "Our Impact"}</p>
            <h2 className="mt-3 text-3xl font-semibold">{story.impactTitle || (language === "ar" ? "أثر يتوسع مع كل طالب" : "Impact that grows with every student")}</h2>
            <p className="mt-3 text-sm leading-8 text-slate-200">{story.impactBody}</p>
          </div>
          <div className="mt-8 grid gap-4 md:grid-cols-3">
            {story.impactStats?.map((stat, index) => (
              <article key={stat._id || index} className="rounded-[1.8rem] border border-white/10 bg-white/10 p-6 backdrop-blur-sm">
                <div className="text-4xl font-semibold tracking-tight text-white">{stat.value}</div>
                <p className="mt-3 text-sm leading-7 text-slate-200">{stat.label}</p>
              </article>
            ))}
          </div>
        </section>
      ) : null}
    </div>
  );
};
