import { ArrowUpRight, GraduationCap, Languages, School } from "lucide-react";
import { Link } from "react-router-dom";
import type { Program } from "../../types";
import { useAuth } from "../../hooks/useAuth";
import { formatCurrency } from "../../utils/format";
import { useLanguage } from "../../hooks/useLanguage";
import { findProgramLanguage, PROGRAM_DEGREE_LEVELS } from "../../constants/programOptions";

export const ProgramCard = ({ program }: { program: Program }) => {
  const { t, tv, language } = useLanguage();
  const { user } = useAuth();
  const isPartnerUser = user?.role === "partner";
  const visibleTuition = isPartnerUser ? program.partnerTuition ?? program.tuition : program.tuition;
  const hasPartnerDiscount = isPartnerUser && typeof program.partnerTuition === "number" && typeof program.tuition === "number" && program.partnerTuition < program.tuition;
  const degree = PROGRAM_DEGREE_LEVELS.find((option) => option.value === program.degreeLevel);
  const programLanguage = findProgramLanguage(program.language || "");

  return (
    <article className="program-list-card rounded-2xl border border-slate-200 bg-white shadow-sm transition hover:border-brand-300 hover:shadow-md">
      <div className="program-list-card-content p-5 sm:p-6">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <span className="inline-flex items-center gap-1.5 rounded-lg bg-brand-50 px-2.5 py-1 text-xs font-medium text-brand-700">
              <GraduationCap className="h-3.5 w-3.5" />{degree ? t(degree.translationKey) : tv(program.degreeLevel)}
            </span>
            {program.language && <span className="inline-flex items-center gap-1.5 rounded-lg bg-slate-100 px-2.5 py-1 text-xs font-medium text-slate-600">
              <Languages className="h-3.5 w-3.5" />{programLanguage ? (language === "ar" ? programLanguage.ar : programLanguage.en) : program.language}
            </span>}
            {program.featured && <span className="rounded-lg border border-brand-100 px-2.5 py-1 text-xs font-medium text-brand-700">{language === "ar" ? "مميز" : "Featured"}</span>}
          </div>
          <h3 className="mt-3 break-words text-lg font-bold leading-7 text-slate-900">
            <Link to={`/programs/${program._id}`} className="transition hover:text-brand-700 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-300">{program.title}</Link>
          </h3>
          <p className="mt-2 flex flex-wrap items-center gap-2 text-sm text-slate-500">
            <School className="h-4 w-4 shrink-0 text-brand-500" />
            <span>{program.university?.name}</span>
            {program.university?.country?.name && <><span aria-hidden="true" className="h-1 w-1 rounded-full bg-slate-300" /><span>{tv(program.university.country.name)}</span></>}
          </p>
          {program.fieldOfStudy && <p className="mt-2 text-xs text-slate-400">{tv(program.fieldOfStudy)}</p>}
        </div>
        <div className="program-list-card-pricing flex flex-wrap items-center justify-between gap-4">
          <div>
            <p className="text-xs font-medium text-slate-500">{isPartnerUser ? t("partnerPrice") : t("tuition")}</p>
            {hasPartnerDiscount && <p className="mt-1 text-xs text-slate-400 line-through">{formatCurrency(program.tuition)}</p>}
            <p className="mt-1 whitespace-nowrap text-xl font-bold tabular-nums text-brand-700">{formatCurrency(visibleTuition)}</p>
          </div>
          <Link to={`/programs/${program._id}#program-application`} className="inline-flex shrink-0 items-center justify-center gap-2 rounded-xl bg-brand-900 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-brand-700 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 focus-visible:ring-offset-2">
            {language === "ar" ? "التقديم الآن" : "Apply now"}<ArrowUpRight className="h-4 w-4 rtl:-scale-x-100" />
          </Link>
        </div>
      </div>
    </article>
  );
};
