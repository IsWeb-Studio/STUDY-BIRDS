import { useEffect, useMemo, useState } from "react";
import { ChevronLeft, ChevronRight, ScrollText, Sparkles } from "lucide-react";
import { useSearchParams } from "react-router-dom";
import { ProgramCard } from "../components/marketing/ProgramCard";
import { SearchFilter } from "../components/marketing/SearchFilter";
import { EmptyState } from "../components/EmptyState";
import { Seo } from "../components/seo/Seo";
import { programService } from "../services/programService";
import { universityService } from "../services/universityService";
import { contentService } from "../services/contentService";
import type { Country, Program, StudyField, University } from "../types";
import { useLanguage } from "../hooks/useLanguage";
import { seoText } from "../seo/site";
import { getApiAssetUrl } from "../lib/api";
import { getPaginatedItems, getPaginationMeta } from "../utils/pagination";
import type { PaginationMeta } from "../types";

export const ProgramsPage = () => {
  const { t, language, tv } = useLanguage();
  const [searchParams] = useSearchParams();
  const [programs, setPrograms] = useState<Program[]>([]);
  const [programPagination, setProgramPagination] = useState<PaginationMeta | null>(null);
  const [countries, setCountries] = useState<Country[]>([]);
  const [universities, setUniversities] = useState<University[]>([]);
  const [studyFields, setStudyFields] = useState<StudyField[]>([]);
  const [loading, setLoading] = useState(true);
  const [keyword, setKeyword] = useState(() => searchParams.get("keyword") || "");
  const [page, setPage] = useState(() => Number(searchParams.get("page") || 1));
  const [filters, setFilters] = useState<Record<string, string>>(() => ({
    country: searchParams.get("country") || "",
    university: searchParams.get("university") || "",
    degreeLevel: searchParams.get("degreeLevel") || "",
    fieldOfStudy: searchParams.get("fieldOfStudy") || "",
    tuitionMin: searchParams.get("tuitionMin") || "",
    tuitionMax: searchParams.get("tuitionMax") || "",
    sortBy: searchParams.get("sortBy") || "",
  }));
  const selectedStudyField = useMemo(
    () => studyFields.find((studyField) => studyField.name === filters.fieldOfStudy),
    [filters.fieldOfStudy, studyFields]
  );
  const selectedUniversityName = useMemo(
    () => universities.find((university) => university._id === filters.university)?.name || "",
    [filters.university, universities]
  );

  useEffect(() => {
    Promise.all([
      contentService.getCountries(),
      universityService.getAll(),
      contentService.getStudyFields(),
    ]).then(([countryData, universityData, studyFieldData]) => {
      setCountries(getPaginatedItems(countryData));
      setUniversities(getPaginatedItems(universityData));
      setStudyFields(getPaginatedItems(studyFieldData));
    });
  }, []);

  useEffect(() => {
    setLoading(true);
    const params = { keyword, ...filters, page, limit: 12, paginate: true };
    programService.getAll(params).then((response) => {
      setPrograms(getPaginatedItems(response));
      setProgramPagination(getPaginationMeta(response));
    }).finally(() => setLoading(false));
  }, [keyword, filters, page]);

  useEffect(() => {
    setPage(1);
  }, [keyword, filters]);

  useEffect(() => {
    if (!filters.university) {
      return;
    }

    const selectedUniversity = universities.find((university) => university._id === filters.university);
    if (filters.country && selectedUniversity?.country?._id !== filters.country) {
      setFilters((current) => ({ ...current, university: "" }));
    }
  }, [filters.country, filters.university, universities]);

  return (
    <div className="space-y-8">
      <Seo
        title={seoText(language, "Study Abroad Programs", "برامج الدراسة بالخارج")}
        description={seoText(
          language,
          "Browse study abroad programs, compare tuition, degree levels, and admission requirements in English and Arabic.",
          "تصفح برامج الدراسة بالخارج وقارن الرسوم والدرجات العلمية ومتطلبات القبول بالعربية والإنجليزية."
        )}
        keywords={[
          "study abroad programs",
          "international degree programs",
          "university admissions",
          "برامج دولية",
          "برامج جامعية",
        ]}
      />
      <div>
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-brand-700">{t("programs")}</p>
        <h1 className="mt-3 text-4xl font-semibold text-slate-900">
          {selectedStudyField ? tv(selectedStudyField.name) : t("searchProgramsTitle")}
        </h1>
      </div>
      {selectedStudyField ? (
        <div className="overflow-hidden rounded-[2rem] border border-slate-200 bg-white shadow-sm">
          <div className="grid gap-0 lg:grid-cols-[320px_minmax(0,1fr)]">
            <div className="relative h-72 bg-slate-950 lg:h-full">
              {selectedStudyField.image ? (
                <img src={getApiAssetUrl(selectedStudyField.image)} alt={tv(selectedStudyField.name)} className="h-full w-full object-cover" />
              ) : (
                <div className="h-full w-full bg-fusion" />
              )}
              <div className="absolute inset-0 bg-gradient-to-t from-slate-950/70 via-slate-950/20 to-transparent" />
            </div>
            <div className="p-6 lg:p-8">
              <div className="inline-flex items-center gap-2 rounded-full bg-brand-50 px-3 py-1 text-xs font-semibold text-brand-700">
                <Sparkles className="h-3.5 w-3.5" />
                <span>{t("studyFieldBadge")}</span>
              </div>
              {selectedStudyField.description ? (
                <p className="mt-4 max-w-3xl text-base leading-8 text-slate-600">{selectedStudyField.description}</p>
              ) : (
                <p className="mt-4 max-w-3xl text-base leading-8 text-slate-600">
                  {language === "ar"
                    ? `استعرض البرامج المتاحة في تخصص ${tv(selectedStudyField.name)} وقارن بين الجامعات والرسوم قبل اختيار البرنامج المناسب.`
                    : `Browse the programs available in ${tv(selectedStudyField.name)} and compare universities and tuition before choosing the best fit.`}
                </p>
              )}
              <div className="mt-6 rounded-3xl bg-slate-50 p-5 text-sm leading-7 text-slate-600">
                <div className="inline-flex items-center gap-2 font-semibold text-slate-900">
                  <ScrollText className="h-4 w-4 text-brand-700" />
                  <span>{language === "ar" ? "عرض البرامج" : "Program view"}</span>
                </div>
                <p className="mt-3">
                  {language === "ar"
                    ? `يتم الآن عرض البرامج المرتبطة بتخصص ${tv(selectedStudyField.name)} فقط.`
                    : `You are now viewing programs related to ${tv(selectedStudyField.name)} only.`}
                </p>
              </div>
            </div>
          </div>
        </div>
      ) : null}
      <SearchFilter
        keyword={keyword}
        filters={filters}
        countries={countries}
        universities={universities}
        studyFields={studyFields}
        selectedUniversityName={selectedUniversityName}
        onKeywordChange={setKeyword}
        onFilterChange={(key, value) => setFilters((current) => ({ ...current, [key]: value }))}
        onUniversitySelect={(universityId) => setFilters((current) => ({ ...current, university: universityId }))}
      />
      {loading ? (
        <div className="panel p-8 text-sm text-slate-500">{language === "ar" ? "جاري تحميل البرامج..." : "Loading programs..."}</div>
      ) : programs.length ? (
        <div className="space-y-3">
          {programs.map((program) => (
            <ProgramCard key={program._id} program={program} />
          ))}
        </div>
      ) : (
        <EmptyState title={t("noPrograms")} description={t("noProgramsDescription")} />
      )}
      {programPagination ? (
        <div className="flex items-center justify-between gap-4 rounded-2xl border border-slate-200 px-4 py-3">
          <p className="text-sm text-slate-600">
            {language === "ar"
              ? `صفحة ${programPagination.page} من ${programPagination.totalPages}`
              : `Page ${programPagination.page} of ${programPagination.totalPages}`}
          </p>
          <div className="flex items-center gap-2">
            <button
              type="button"
              disabled={!programPagination.hasPreviousPage}
              onClick={() => setPage((current) => Math.max(1, current - 1))}
              className="inline-flex items-center gap-2 rounded-full border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700 disabled:opacity-50"
            >
              <ChevronLeft className="h-4 w-4" />
              {language === "ar" ? "السابق" : "Previous"}
            </button>
            <button
              type="button"
              disabled={!programPagination.hasNextPage}
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
