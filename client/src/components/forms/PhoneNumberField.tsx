import { useId } from "react";
import { phoneCountryOptions } from "../../utils/phoneCountryOptions";

type PhoneNumberFieldProps = {
  label: string;
  dialCode: string;
  phoneNumber: string;
  onDialCodeChange: (value: string) => void;
  onPhoneNumberChange: (value: string) => void;
  required?: boolean;
  error?: string;
};

export const PhoneNumberField = ({
  label,
  dialCode,
  phoneNumber,
  onDialCodeChange,
  onPhoneNumberChange,
  required,
  error,
}: PhoneNumberFieldProps) => {
  const errorId = useId();
  return (
    <div className="block">
      <span className="mb-2 block text-sm font-medium text-slate-700">{label}</span>
      <div className="grid gap-3 sm:grid-cols-[120px_1fr]">
        <select
          aria-label={`${label} country code`}
          value={dialCode}
          onChange={(event) => onDialCodeChange(event.target.value)}
          className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none ring-brand-300 focus:ring"
        >
          {phoneCountryOptions.map((option) => (
            <option key={`${option.country}-${option.dialCode}`} value={option.dialCode}>
              {option.flag} {option.dialCode} {option.country}
            </option>
          ))}
        </select>
        <input
          type="tel"
          inputMode="tel"
          aria-label={label}
          value={phoneNumber}
          required={required}
          aria-invalid={error ? "true" : "false"}
          aria-describedby={error ? errorId : undefined}
          onChange={(event) => onPhoneNumberChange(event.target.value)}
          className={`w-full rounded-2xl border px-4 py-3 outline-none ring-brand-300 focus:ring ${error ? "border-rose-400" : "border-slate-200"}`}
        />
      </div>
      {error ? <p id={errorId} role="alert" className="mt-2 text-sm text-rose-700">{error}</p> : null}
    </div>
  );
};
