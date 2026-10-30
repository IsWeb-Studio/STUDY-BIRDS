import { useEffect, useMemo, useRef, useState } from "react";
import type { Language } from "../../context/LanguageContext";
import { daysInMonth, isValidPastDateOnly } from "../../utils/formValidation";

type DateOfBirthFieldProps = {
  label: string;
  language: Language;
  value?: string;
  onChange: (value: string) => void;
};

const parseDateValue = (value?: string) => {
  const [year = "", month = "", day = ""] = (value || "").split("-");
  return { year, month, day };
};

export const DateOfBirthField = ({
  label,
  language,
  value,
  onChange,
}: DateOfBirthFieldProps) => {
  const [draft, setDraft] = useState(() => parseDateValue(value));
  const lastReportedValue = useRef(value || "");
  useEffect(() => {
    const incoming = value || "";
    if (incoming !== lastReportedValue.current) {
      setDraft(parseDateValue(incoming));
      lastReportedValue.current = incoming;
    }
  }, [value]);
  const { year, month, day } = draft;
  const now = new Date();
  const currentYear = new Date().getFullYear();

  const monthFormatter = useMemo(
    () => new Intl.DateTimeFormat(language === "ar" ? "ar" : "en-US", { month: "long" }),
    [language]
  );

  const months = useMemo(
    () =>
      Array.from({ length: 12 }, (_, index) => ({
        value: String(index + 1).padStart(2, "0"),
        label: monthFormatter.format(new Date(2024, index, 1)),
      })),
    [monthFormatter]
  );

  const years = useMemo(
    () => Array.from({ length: currentYear - 1900 + 1 }, (_, index) => String(currentYear - index)),
    [currentYear]
  );

  const monthOptions = useMemo(
    () => months.map((item) => ({
      ...item,
      disabled: Number(year) === now.getFullYear() && Number(item.value) > now.getMonth() + 1,
    })),
    [months, year, now]
  );

  const maxDay = year && month
    ? Math.min(
        daysInMonth(Number(year), Number(month)),
        Number(year) === now.getFullYear() && Number(month) === now.getMonth() + 1 ? now.getDate() : 31,
      )
    : 31;

  const placeholders =
    language === "ar"
      ? { day: "اليوم", month: "الشهر", year: "السنة" }
      : { day: "Day", month: "Month", year: "Year" };

  const updateValue = (next: { year?: string; month?: string; day?: string }) => {
    const nextYear = next.year ?? year;
    const nextMonth = next.month ?? month;
    let nextDay = next.day ?? day;
    if (nextYear && nextMonth && nextDay && Number(nextDay) > daysInMonth(Number(nextYear), Number(nextMonth))) {
      nextDay = "";
    }
    const updated = { year: nextYear, month: nextMonth, day: nextDay };
    setDraft(updated);
    const candidate = nextYear && nextMonth && nextDay
      ? `${nextYear}-${nextMonth}-${nextDay}`
      : "";
    const nextValue = candidate && isValidPastDateOnly(candidate) ? candidate : "";
    lastReportedValue.current = nextValue;
    onChange(nextValue);
  };

  return (
    <label className="block">
      <span className="mb-2 block text-sm font-medium text-slate-700">{label}</span>
      <div className="grid gap-3 sm:grid-cols-3">
        <select
          value={day}
          aria-label={placeholders.day}
          onChange={(event) => updateValue({ day: event.target.value })}
          className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none ring-brand-300 focus:ring"
        >
          <option value="">{placeholders.day}</option>
          {Array.from({ length: maxDay }, (_, index) => {
            const optionValue = String(index + 1).padStart(2, "0");
            return (
              <option key={optionValue} value={optionValue}>
                {index + 1}
              </option>
            );
          })}
        </select>

        <select
          value={month}
          aria-label={placeholders.month}
          onChange={(event) => updateValue({ month: event.target.value })}
          className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none ring-brand-300 focus:ring"
        >
          <option value="">{placeholders.month}</option>
          {monthOptions.map((item) => (
            <option key={item.value} value={item.value} disabled={item.disabled}>
              {item.label}
            </option>
          ))}
        </select>

        <select
          value={year}
          aria-label={placeholders.year}
          onChange={(event) => updateValue({ year: event.target.value })}
          className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none ring-brand-300 focus:ring"
        >
          <option value="">{placeholders.year}</option>
          {years.map((item) => (
            <option key={item} value={item}>
              {item}
            </option>
          ))}
        </select>
      </div>
    </label>
  );
};
