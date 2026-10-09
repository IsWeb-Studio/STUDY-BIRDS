import { useEffect, useId, useState } from "react";
import { useLanguage } from "../../hooks/useLanguage";
import { formatCurrency } from "../../utils/format";

const DEFAULT_CEILING = 60000;
const parsePrice = (value: string, fallback: number) => {
  if (!value.trim()) return fallback;
  const price = Number(value);
  return Number.isFinite(price) && price >= 0 ? price : fallback;
};

export const PriceRangeFilter = ({ minimum, maximum, onChange }: {
  minimum: string;
  maximum: string;
  onChange: (minimum: string, maximum: string) => void;
}) => {
  const { language } = useLanguage();
  const id = useId();
  const ceiling = Math.max(DEFAULT_CEILING, Math.ceil((Math.max(parsePrice(minimum, 0), parsePrice(maximum, 0)) + 1) / 10000) * 10000);
  const resolveRange = () => {
    const upper = parsePrice(maximum, ceiling);
    return [Math.min(parsePrice(minimum, 0), upper), upper] as [number, number];
  };
  const [range, setRange] = useState<[number, number]>(resolveRange);

  useEffect(() => {
    setRange(resolveRange());
  }, [minimum, maximum, ceiling]);

  const commitRange = () => {
    const nextMinimum = range[0] === 0 ? "" : String(range[0]);
    const nextMaximum = range[1] === ceiling ? "" : String(range[1]);
    if (nextMinimum !== minimum || nextMaximum !== maximum) onChange(nextMinimum, nextMaximum);
  };
  const resetRange = () => {
    setRange([0, ceiling]);
    onChange("", "");
  };
  const unlimited = language === "ar" ? "بدون حد أعلى" : "No upper limit";
  const hasFilter = Boolean(minimum || maximum);

  return (
    <fieldset className="min-w-0 rounded-2xl border border-slate-200 bg-slate-50/60 px-4 pb-4 pt-3 lg:col-span-3">
      <legend className="px-2 text-sm font-semibold text-slate-800">{language === "ar" ? "نطاق السعر" : "Price range"}</legend>
      <div className="flex items-center justify-between gap-3 text-xs text-slate-500">
        <span>{language === "ar" ? "الرسوم الدراسية بالدولار" : "Tuition in USD"}</span>
        {hasFilter && <button type="button" onClick={resetRange} className="font-semibold text-brand-700 hover:underline">{language === "ar" ? "إعادة ضبط" : "Reset"}</button>}
      </div>
      <div className="price-range-control relative mx-2 mt-4 h-8" dir="ltr">
        <div className="pointer-events-none absolute inset-x-0 top-1/2 h-1.5 -translate-y-1/2 rounded-full bg-slate-200" />
        <div className="pointer-events-none absolute top-1/2 h-1.5 -translate-y-1/2 rounded-full bg-brand-500" style={{ left: `${range[0] / ceiling * 100}%`, right: `${100 - range[1] / ceiling * 100}%` }} />
        <input
          id={`${id}-minimum`}
          type="range" min={0} max={ceiling} step={1} value={range[0]}
          aria-label={language === "ar" ? "أقل سعر" : "Minimum price"}
          aria-valuetext={formatCurrency(range[0])}
          aria-valuemax={range[1]}
          onChange={(event) => setRange(([, upper]) => [Math.min(Number(event.target.value), upper), upper])}
          onPointerUp={commitRange} onKeyUp={commitRange} onBlur={commitRange}
          className="price-range-input" style={{ zIndex: range[0] > ceiling / 2 ? 3 : 2 }}
        />
        <input
          id={`${id}-maximum`}
          type="range" min={0} max={ceiling} step={1} value={range[1]}
          aria-label={language === "ar" ? "أقصى سعر" : "Maximum price"}
          aria-valuetext={range[1] === ceiling ? unlimited : formatCurrency(range[1])}
          aria-valuemin={range[0]}
          onChange={(event) => setRange(([lower]) => [lower, Math.max(Number(event.target.value), lower)])}
          onPointerUp={commitRange} onKeyUp={commitRange} onBlur={commitRange}
          className="price-range-input" style={{ zIndex: range[0] > ceiling / 2 ? 2 : 3 }}
        />
      </div>
      <div className="flex items-start justify-between gap-3" dir="ltr">
        <div className="text-left"><label htmlFor={`${id}-minimum`} className="block text-[11px] text-slate-500">{language === "ar" ? "من" : "From"}</label><output htmlFor={`${id}-minimum`} className="mt-1 block text-sm font-semibold tabular-nums text-brand-700">{formatCurrency(range[0])}</output></div>
        <div className="text-right"><label htmlFor={`${id}-maximum`} className="block text-[11px] text-slate-500">{language === "ar" ? "إلى" : "To"}</label><output htmlFor={`${id}-maximum`} className="mt-1 block text-sm font-semibold tabular-nums text-brand-700">{range[1] === ceiling ? unlimited : formatCurrency(range[1])}</output></div>
      </div>
    </fieldset>
  );
};
