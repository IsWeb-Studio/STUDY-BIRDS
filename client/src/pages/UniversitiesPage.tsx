import { useEffect, useMemo, useRef, useState } from "react";
import { ContentLoading } from '../components/ContentLoading';
import { ChevronLeft, ChevronRight, MapPinned, ScrollText } from "lucide-react";
import { useSearchParams } from "react-router-dom";
import { ArticleContentSection } from "../components/content/ArticleContentSection";
import { UniversityCard } from "../components/marketing/UniversityCard";
import { Seo } from "../components/seo/Seo";
import { universityService } from "../services/universityService";
import { contentService } from "../services/contentService";
import type { Country, PaginationMeta, University } from "../types";
import { useLanguage } from "../hooks/useLanguage";
import { seoText } from "../seo/site";
import { getDestinationImage } from "../utils/marketingVisuals";
import { getPaginatedItems, getPaginationMeta } from "../utils/pagination";

export const UniversitiesPage = () => {
  const { t, language, tv } = useLanguage();
  const [searchParams, setSearchParams] = useSearchParams();
  const universitiesSectionRef = useRef<HTMLDivElement | null>(null);
  const [universities, setUniversities] = useState<University[]>([]);
  const [pagination, setPagination] = useState<PaginationMeta | null>(null);
  const [countries, setCountries] = useState<Country[]>([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(() => Number(searchParams.get("page") || 1));
  const selectedCountryId = searchParams.get("country") || "";
  const selectedCountry = useMemo(
    () => countries.find((country) => country._id === selectedCountryId),
    [countries, selectedCountryId]
  );
  const filterCountries = useMemo(
    () => countries.filter((country) => country._id),
    [countries]
  );

  const handleCountryFilter = (countryId: string) => {
    const nextParams = new URLSearchParams(searchParams);

    if (countryId) {
      nextParams.set("country", countryId);
    } else {
      nextParams.delete("country");
    }

    nextParams.delete("page");
    setSearchParams(nextParams);
  };

  const scrollToUniversitiesSection = () => {
    universitiesSectionRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
  };

  useEffect(() => {
    let active = true;
    setLoading(true);

    Promise.all([
      universityService.getAll(
        selectedCountryId
          ? { country: selectedCountryId, page, limit: 12, paginate: true }
          : { page, limit: 12, paginate: true }
      ),
      contentService.getCountries(),
    ])
      .then(([universitiesData, countriesData]) => {
        if (!active) return;
        setUniversities(getPaginatedItems(universitiesData));
        setPagination(getPaginationMeta(universitiesData));
        setCountries(getPaginatedItems(countriesData));
      })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [page, selectedCountryId]);

  useEffect(() => {
    setPage(1);
  }, [selectedCountryId]);

  return (
    <div>
      <Seo
        title={seoText(language, "International Universities", "جامعات دولية")}
        description={seoText(
          language,
          "Explore international universities, partner institutions, rankings, and tuition options for studying abroad.",
          "استكشف الجامعات الدولية والجامعات الشريكة والتصنيفات وخيارات الرسوم للدراسة بالخارج."
        )}
        keywords={[
          "international universities",
          "partner universities",
          "study abroad universities",
          "جامعات دولية",
          "جامعات شريكة",
        ]}
      />
      <p className="text-sm font-semibold uppercase tracking-[0.3em] text-brand-700">{t("universities")}</p>
      <h1 className="mt-3 text-4xl font-semibold text-slate-900">
        {selectedCountry ? tv(selectedCountry.name) : t("universitiesTitle")}
      </h1>
      <div className="mt-6 flex flex-wrap gap-3">
        <button
          type="button"
          onClick={() => handleCountryFilter("")}
          className={`rounded-full px-5 py-2.5 text-sm font-semibold transition ${
            !selectedCountryId
              ? "bg-brand-900 text-white shadow-soft"
              : "border border-slate-200 bg-white text-slate-700 hover:border-brand-300 hover:text-brand-700"
          }`}
        >
          {t("allCountries")}
        </button>
        {filterCountries.map((country) => {
          const isActive = selectedCountryId === country._id;

          return (
            <button
              key={country._id}
              type="button"
              onClick={() => handleCountryFilter(country._id)}
              className={`rounded-full px-5 py-2.5 text-sm font-semibold transition ${
                isActive
                  ? "bg-brand-900 text-white shadow-soft"
                  : "border border-slate-200 bg-white text-slate-700 hover:border-brand-300 hover:text-brand-700"
              }`}
            >
              {tv(country.name)}
            </button>
          );
        })}
      </div>
      {selectedCountry ? (
        <div className="mt-6 overflow-hidden rounded-[2rem] border border-slate-200 bg-white shadow-sm">
          <div className="grid gap-0 lg:grid-cols-[320px_minmax(0,1fr)]">
            <div className="relative h-72 bg-slate-950 lg:h-full">
              <img
                src={getDestinationImage(selectedCountry.name, selectedCountry.heroImage)}
                alt={tv(selectedCountry.name)}
                loading="lazy"
                className="h-full w-full object-cover"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-slate-950/70 via-slate-950/20 to-transparent" />
            </div>
            <div className="p-6 lg:p-8">
              <div className="inline-flex items-center gap-2 rounded-full bg-brand-50 px-3 py-1 text-xs font-semibold text-brand-700">
                <MapPinned className="h-3.5 w-3.5" />
                <span>{t("destinationBadge")}</span>
              </div>
              <p className="mt-4 text-sm font-semibold uppercase tracking-[0.25em] text-slate-500">{selectedCountry.code}</p>
              {selectedCountry.description ? (
                <p className="mt-4 max-w-3xl text-base leading-8 text-slate-600">{selectedCountry.description}</p>
              ) : (
                <p className="mt-4 max-w-3xl text-base leading-8 text-slate-600">
                  {language === "ar"
                    ? `استعرض الجامعات المتاحة في ${tv(selectedCountry.name)} واختر الوجهة الأنسب لخطتك الدراسية.`
                    : `Browse the universities available in ${tv(selectedCountry.name)} and choose the best fit for your study plan.`}
                </p>
              )}
              {selectedCountry.visaNotes ? (
                <div className="mt-6 rounded-3xl bg-slate-50 p-5 text-sm leading-7 text-slate-600">
                  <div className="inline-flex items-center gap-2 font-semibold text-slate-900">
                    <ScrollText className="h-4 w-4 text-brand-700" />
                    <span>{language === "ar" ? "ملاحظات مهمة" : "Important notes"}</span>
                  </div>
                  <p className="mt-3">{selectedCountry.visaNotes}</p>
                </div>
              ) : null}
              <div className="mt-6 flex flex-wrap items-center gap-3 text-sm text-slate-900">
                <span className="font-semibold">
                  {language === "ar" ? `عرض جامعات ${tv(selectedCountry.name)}` : `Showing universities in ${tv(selectedCountry.name)}`}
                </span>
                <button
                  type="button"
                  onClick={scrollToUniversitiesSection}
                  className="rounded-full bg-slate-100 px-4 py-2 font-semibold text-accent-700 transition hover:bg-slate-200"
                >
                  {language === "ar" ? "عرض كل الجامعات" : "View all universities"}
                </button>
              </div>
            </div>
          </div>
        </div>
      ) : null}
      {selectedCountry ? <ArticleContentSection article={selectedCountry} language={language} /> : null}
      {loading && <ContentLoading layout="cards" compact={universities.length > 0} />}
      <div ref={universitiesSectionRef} aria-busy={loading} className="mt-8 grid gap-5 lg:grid-cols-3">
        {universities.map((university) => (
          <UniversityCard key={university._id} university={university} />
        ))}
      </div>
      {!loading && !universities.length ? (
        <div className="panel mt-8 p-8 text-sm text-slate-500">
          {language === "ar" ? "لا توجد جامعات مضافة لهذه الدولة حاليًا." : "No universities are available for this country yet."}
        </div>
      ) : null}
      {pagination ? (
        <div className="mt-6 flex items-center justify-between gap-4 rounded-2xl border border-slate-200 px-4 py-3">
          <p className="text-sm text-slate-600">
            {language === "ar" ? `صفحة ${pagination.page} من ${pagination.totalPages}` : `Page ${pagination.page} of ${pagination.totalPages}`}
          </p>
          <div className="flex items-center gap-2">
            <button
              type="button"
              disabled={loading || !pagination.hasPreviousPage}
              onClick={() => setPage((current) => Math.max(1, current - 1))}
              className="inline-flex items-center gap-2 rounded-full border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700 disabled:opacity-50"
            >
              <ChevronLeft className="h-4 w-4" />
              {language === "ar" ? "السابق" : "Previous"}
            </button>
            <button
              type="button"
              disabled={loading || !pagination.hasNextPage}
              onClick={() => setPage((current) => current + 1)}
              className="inline-flex items-center gap-2 rounded-full border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700 disabled:opacity-50"
            >
              {language === "ar" ? "التالي" : "Next"}
              <ChevronRight className="h-4 w-4" />
            </button>
          </div>
        </div>
      ) : null}
    </div>
  );
};
