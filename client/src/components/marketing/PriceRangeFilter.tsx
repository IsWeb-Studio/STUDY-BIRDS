import { useEffect, useId, useState } from "react";
import { RotateCcw } from "lucide-react";
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
    <fieldset className="price-range-compact h-[50px] min-w-0 rounded-2xl border border-slate-200 bg-white px-4 py-1.5">
      <legend className="sr-only">{language === "ar" ? "نطاق السعر" : "Price range"}</legend>
      <div className="flex h-4 items-center justify-between gap-2">
        <span className="shrink-0 text-xs font-medium text-slate-600">{language === "ar" ? "نطاق السعر" : "Price range"}</span>
        <div className="flex min-w-0 items-center gap-2">
          <output htmlFor={`${id}-minimum ${id}-maximum`} dir="ltr" title={`${formatCurrency(range[0])} – ${range[1] === ceiling ? unlimited : formatCurrency(range[1])}`} aria-label={`${formatCurrency(range[0])} – ${range[1] === ceiling ? unlimited : formatCurrency(range[1])}`} className="truncate text-[11px] font-semibold tabular-nums text-brand-700">{formatCurrency(range[0])} – {range[1] === ceiling ? "∞" : formatCurrency(range[1])}</output>
          {hasFilter && <button type="button" onClick={resetRange} aria-label={language === "ar" ? "إعادة ضبط السعر" : "Reset price"} title={language === "ar" ? "إعادة ضبط السعر" : "Reset price"} className="shrink-0 rounded text-slate-400 hover:text-brand-700"><RotateCcw className="h-3 w-3" /></button>}
        </div>
      </div>
      <div className="price-range-control relative mx-1 h-5" dir="ltr">
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
    </fieldset>
  );
};
