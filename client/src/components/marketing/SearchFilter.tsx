import { useEffect, useMemo, useState } from "react";
import { Search, X } from "lucide-react";
import type { Country, StudyField, University } from "../../types";
import { useLanguage } from "../../hooks/useLanguage";
import {
  PROGRAM_DEGREE_LEVELS,
  LEGACY_PROGRAM_DEGREE_LEVELS,
} from "../../constants/programOptions";

interface SearchFilterProps {
  keyword: string;
  filters: Record<string, string>;
  countries: Country[];
  universities: University[];
  studyFields: StudyField[];
  selectedUniversityName: string;
  onKeywordChange: (value: string) => void;
  onFilterChange: (key: string, value: string) => void;
  onUniversitySelect: (universityId: string) => void;
}

export const SearchFilter = ({
  keyword,
  filters,
  countries,
  universities,
  studyFields,
  selectedUniversityName,
  onKeywordChange,
  onFilterChange,
  onUniversitySelect,
}: SearchFilterProps) => {
  const { t, tv, language } = useLanguage();
  const [universityQuery, setUniversityQuery] = useState(selectedUniversityName);
  const [isUniversityMenuOpen, setIsUniversityMenuOpen] = useState(false);

  useEffect(() => {
    setUniversityQuery(selectedUniversityName);
  }, [selectedUniversityName]);

  const visibleUniversities = useMemo(() => {
    const normalizedQuery = universityQuery.trim().toLowerCase();

    return universities.filter((university) => {
      const matchesCountry = !filters.country || university.country?._id === filters.country;
      const matchesQuery = !normalizedQuery || university.name.toLowerCase().includes(normalizedQuery);
      return matchesCountry && matchesQuery;
    });
  }, [filters.country, universities, universityQuery]);

  return (
    <div className="panel grid gap-4 p-5 lg:grid-cols-4">
      <input
        value={keyword}
        onChange={(event) => onKeywordChange(event.target.value)}
        placeholder={t("searchKeyword")}
        className="rounded-2xl border border-slate-200 px-4 py-3 outline-none ring-brand-300 focus:ring"
      />
      <select
        value={filters.country}
        onChange={(event) => onFilterChange("country", event.target.value)}
        className="rounded-2xl border border-slate-200 px-4 py-3"
      >
        <option value="">{t("allCountries")}</option>
        {countries.map((country) => (
          <option key={country._id} value={country._id}>
            {tv(country.name)}
          </option>
        ))}
      </select>
      <div className="relative">
        <Search className="pointer-events-none absolute inset-y-0 left-4 my-auto h-4 w-4 text-slate-400" />
        <input
          value={universityQuery}
          onChange={(event) => {
            const value = event.target.value;
            setUniversityQuery(value);
            setIsUniversityMenuOpen(true);

            if (!value.trim()) {
              onUniversitySelect("");
            }
          }}
          onFocus={() => setIsUniversityMenuOpen(true)}
          onBlur={() => {
            window.setTimeout(() => {
              setIsUniversityMenuOpen(false);
              if (!filters.university) {
                setUniversityQuery("");
              }
            }, 150);
          }}
          placeholder={t("allUniversities")}
          className="w-full rounded-2xl border border-slate-200 py-3 pl-11 pr-12 outline-none ring-brand-300 focus:ring"
        />
        {universityQuery ? (
          <button
            type="button"
            onMouseDown={(event) => {
              event.preventDefault();
              setUniversityQuery("");
              setIsUniversityMenuOpen(false);
              onUniversitySelect("");
            }}
            className="absolute inset-y-0 right-4 my-auto inline-flex h-6 w-6 items-center justify-center rounded-full text-slate-400 transition hover:bg-slate-100 hover:text-slate-600"
            aria-label={language === "ar" ? "مسح البحث" : "Clear search"}
          >
            <X className="h-4 w-4" />
          </button>
        ) : null}
        {isUniversityMenuOpen ? (
          <div className="absolute z-20 mt-2 max-h-72 w-full overflow-y-auto rounded-3xl border border-slate-200 bg-white p-2 shadow-xl">
            <button
              type="button"
              onMouseDown={(event) => {
                event.preventDefault();
                setUniversityQuery("");
                setIsUniversityMenuOpen(false);
                onUniversitySelect("");
              }}
              className="flex w-full items-center rounded-2xl px-4 py-3 text-right text-sm font-medium text-slate-600 transition hover:bg-slate-100"
            >
              {t("allUniversities")}
            </button>
            {visibleUniversities.length ? (
              visibleUniversities.map((university) => (
                <button
                  key={university._id}
                  type="button"
                  onMouseDown={(event) => {
                    event.preventDefault();
                    setUniversityQuery(university.name);
                    setIsUniversityMenuOpen(false);
                    onUniversitySelect(university._id);
                  }}
                  className="flex w-full items-center justify-between gap-3 rounded-2xl px-4 py-3 text-right text-sm text-slate-700 transition hover:bg-slate-100"
                >
                  <span className="truncate font-medium">{university.name}</span>
                  {university.country?.name ? (
                    <span className="shrink-0 text-xs text-slate-400">{tv(university.country.name)}</span>
                  ) : null}
                </button>
              ))
            ) : (
              <div className="px-4 py-3 text-sm text-slate-400">{language === "ar" ? "لا توجد جامعات مطابقة" : "No matching universities"}</div>
            )}
          </div>
        ) : null}
      </div>
      <select
        value={filters.degreeLevel}
        onChange={(event) => onFilterChange("degreeLevel", event.target.value)}
        className="rounded-2xl border border-slate-200 px-4 py-3"
      >
        <option value="">{t("allDegreeLevels")}</option>
        {[...PROGRAM_DEGREE_LEVELS, ...LEGACY_PROGRAM_DEGREE_LEVELS].map((option) => (
          <option key={option.value} value={option.value}>
            {t(option.translationKey)}
          </option>
        ))}
      </select>
      <select
        value={filters.fieldOfStudy}
        onChange={(event) => onFilterChange("fieldOfStudy", event.target.value)}
        className="rounded-2xl border border-slate-200 px-4 py-3"
      >
        <option value="">{t("allFields")}</option>
        {studyFields.map((studyField) => (
          <option key={studyField._id} value={studyField.name}>
            {tv(studyField.name)}
          </option>
        ))}
      </select>
      <input
        value={filters.tuitionMin}
        onChange={(event) => onFilterChange("tuitionMin", event.target.value)}
        placeholder={t("minTuition")}
        className="rounded-2xl border border-slate-200 px-4 py-3"
      />
      <input
        value={filters.tuitionMax}
        onChange={(event) => onFilterChange("tuitionMax", event.target.value)}
        placeholder={t("maxTuition")}
        className="rounded-2xl border border-slate-200 px-4 py-3"
      />
      <select
        value={filters.sortBy}
        onChange={(event) => onFilterChange("sortBy", event.target.value)}
        className="rounded-2xl border border-slate-200 px-4 py-3 lg:col-span-4"
      >
        <option value="">{t("sortByFeatured")}</option>
        <option value="tuition">{t("tuition")}</option>
        <option value="popularity">{t("popularity")}</option>
      </select>
    </div>
  );
};
