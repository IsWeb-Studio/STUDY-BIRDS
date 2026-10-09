import { phoneCountryOptions } from "../../utils/phoneCountryOptions";

type PhoneNumberFieldProps = {
  label: string;
  dialCode: string;
  phoneNumber: string;
  onDialCodeChange: (value: string) => void;
  onPhoneNumberChange: (value: string) => void;
  required?: boolean;
};

export const PhoneNumberField = ({
  label,
  dialCode,
  phoneNumber,
  onDialCodeChange,
  onPhoneNumberChange,
  required,
}: PhoneNumberFieldProps) => (
  <label className="block">
    <span className="mb-2 block text-sm font-medium text-slate-700">{label}</span>
    <div className="grid gap-3 sm:grid-cols-[120px_1fr]">
      <select
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
        value={phoneNumber}
        required={required}
        onChange={(event) => onPhoneNumberChange(event.target.value)}
        className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none ring-brand-300 focus:ring"
      />
    </div>
  </label>
);
