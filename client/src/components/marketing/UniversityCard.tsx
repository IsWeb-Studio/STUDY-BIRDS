import { ArrowUpLeft, BadgeCheck, CircleDollarSign, MapPinned, Sparkles } from "lucide-react";
import { Link } from "react-router-dom";
import { getApiAssetUrl } from "../../lib/api";
import type { University } from "../../types";
import { formatCurrency } from "../../utils/format";
import { useLanguage } from "../../hooks/useLanguage";
import { useContentTranslation } from "../../hooks/useContentTranslation";
import { campusFallbackImage } from "../../utils/marketingVisuals";
import { universityName } from "../../utils/localizedContent";

export const UniversityCard = ({ university }: { university: University }) => {
  const { t, tv, language } = useLanguage();
  const tr = useContentTranslation(language);
  const coverImage = university.logo || university.campusImages?.[0];
  const coverImageUrl = coverImage ? getApiAssetUrl(coverImage) : campusFallbackImage;
  const locationLabel = [tv(university.country?.name), tr(university.city)].filter(Boolean).join(" - ");

  return (
    <Link
      to={`/universities/${university._id}`}
      className="group block overflow-hidden rounded-[2rem] bg-white shadow-[0_24px_80px_rgba(15,23,42,0.12)] transition hover:-translate-y-1"
    >
      <div className="relative h-40 overflow-hidden bg-slate-950 sm:h-52 lg:h-64">
        <div className="flex h-full w-full items-center justify-center bg-[radial-gradient(circle_at_top,rgba(255,255,255,0.16),transparent_55%),linear-gradient(180deg,rgba(15,23,42,0.92)_0%,rgba(15,23,42,0.74)_100%)] p-4">
          <img src={coverImageUrl} alt={universityName(language, university, tr)} loading="lazy" className="h-full w-full object-contain transition duration-500 group-hover:scale-105" />
        </div>
        <div className="absolute inset-0 bg-gradient-to-t from-slate-950/50 via-slate-950/10 to-transparent" />
        <div className="absolute start-5 top-5 flex items-center gap-3">
          <div className="inline-flex items-center gap-2 rounded-full bg-white/90 px-3 py-1 text-xs font-semibold text-slate-900 shadow-sm">
            <Sparkles className="h-3.5 w-3.5" />
            {t("universityBadge")}
          </div>
          {university.featured ? (
            <span className="inline-flex items-center gap-1 rounded-full bg-amber-100 px-3 py-1 text-xs font-semibold text-amber-800 shadow-sm">
              <BadgeCheck size={14} />
              {t("featured")}
            </span>
          ) : null}
        </div>
      </div>

      <div className="p-4 text-slate-900 sm:p-5 lg:p-6">
        <div className="inline-flex items-center gap-1.5 text-[11px] text-slate-500 sm:text-xs">
          <MapPinned className="h-4 w-4 text-brand-700" />
          <span>{locationLabel || t("universityBadge")}</span>
        </div>

        <div className="mt-4 grid gap-3">
          <div className="flex items-start justify-between gap-3">
            <h3 className="text-base font-semibold sm:text-lg lg:text-xl">{universityName(language, university, tr)}</h3>
            <span className="inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-full border border-slate-200 bg-slate-50 text-slate-900 transition group-hover:-translate-y-1 group-hover:border-brand-200 group-hover:bg-brand-50 sm:h-11 sm:w-11 lg:h-12 lg:w-12">
              <ArrowUpLeft className="h-4 w-4 sm:h-5 sm:w-5" />
            </span>
          </div>

          <div className="grid grid-cols-2 gap-1.5 text-[10px] font-semibold text-slate-600 sm:text-[11px]">
            {university.city ? <div className="rounded-2xl bg-slate-100 px-2 py-1.5 sm:px-2.5 sm:py-2">{tr(university.city)}</div> : null}
            {university.language ? <div className="rounded-2xl bg-slate-100 px-2 py-1.5 sm:px-2.5 sm:py-2">{language === "ar" ? `اللغة ${university.language}` : `Language ${university.language}`}</div> : null}
            <div className="rounded-2xl bg-slate-100 px-2 py-1.5 sm:px-2.5 sm:py-2">{language === "ar" ? `الطلاب ${university.studentCount || 0}` : `${university.studentCount || 0} Students`}</div>
            <div className="rounded-2xl bg-slate-100 px-2 py-1.5 sm:px-2.5 sm:py-2">{language === "ar" ? `التخصصات ${university.specialtyCount || 0}` : `${university.specialtyCount || 0} Specialties`}</div>
            <div className="rounded-2xl bg-slate-100 px-2 py-1.5 sm:px-2.5 sm:py-2">
              {t("ranking")}: {university.ranking || "-"}
            </div>
            <div className="inline-flex items-center gap-1 rounded-2xl bg-slate-100 px-2 py-1.5 sm:px-2.5 sm:py-2">
              <CircleDollarSign className="h-3.5 w-3.5 shrink-0" />
              <span className="truncate">
                {formatCurrency(university.tuitionRange?.min)} - {formatCurrency(university.tuitionRange?.max)}
              </span>
            </div>
          </div>

          <p className="text-[11px] font-medium text-brand-700 sm:text-xs">{t("viewUniversity")}</p>
        </div>
      </div>
    </Link>
  );
};
