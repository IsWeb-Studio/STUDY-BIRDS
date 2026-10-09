export type PhoneCountryOption = {
  country: string;
  dialCode: string;
  flag: string;
};

export const DEFAULT_PHONE_DIAL_CODE = "+90";

export const phoneCountryOptions: PhoneCountryOption[] = [
  { flag: "🇹🇷", country: "Turkey", dialCode: "+90" },
  { flag: "🇪🇬", country: "Egypt", dialCode: "+20" },
  { flag: "🇸🇦", country: "Saudi Arabia", dialCode: "+966" },
  { flag: "🇦🇪", country: "United Arab Emirates", dialCode: "+971" },
  { flag: "🇶🇦", country: "Qatar", dialCode: "+974" },
  { flag: "🇯🇴", country: "Jordan", dialCode: "+962" },
  { flag: "🇰🇼", country: "Kuwait", dialCode: "+965" },
  { flag: "🇴🇲", country: "Oman", dialCode: "+968" },
  { flag: "🇧🇭", country: "Bahrain", dialCode: "+973" },
  { flag: "🇮🇶", country: "Iraq", dialCode: "+964" },
  { flag: "🇱🇧", country: "Lebanon", dialCode: "+961" },
  { flag: "🇸🇾", country: "Syria", dialCode: "+963" },
  { flag: "🇾🇪", country: "Yemen", dialCode: "+967" },
  { flag: "🇱🇾", country: "Libya", dialCode: "+218" },
  { flag: "🇲🇦", country: "Morocco", dialCode: "+212" },
  { flag: "🇩🇿", country: "Algeria", dialCode: "+213" },
  { flag: "🇹🇳", country: "Tunisia", dialCode: "+216" },
  { flag: "🇸🇩", country: "Sudan", dialCode: "+249" },
  { flag: "🇸🇴", country: "Somalia", dialCode: "+252" },
  { flag: "🇵🇸", country: "Palestine", dialCode: "+970" },
  { flag: "🇩🇪", country: "Germany", dialCode: "+49" },
  { flag: "🇬🇧", country: "United Kingdom", dialCode: "+44" },
  { flag: "🇺🇸", country: "United States", dialCode: "+1" },
  { flag: "🇨🇦", country: "Canada", dialCode: "+1" },
  { flag: "🇫🇷", country: "France", dialCode: "+33" },
  { flag: "🇮🇹", country: "Italy", dialCode: "+39" },
  { flag: "🇪🇸", country: "Spain", dialCode: "+34" },
  { flag: "🇳🇱", country: "Netherlands", dialCode: "+31" },
  { flag: "🇧🇪", country: "Belgium", dialCode: "+32" },
  { flag: "🇸🇪", country: "Sweden", dialCode: "+46" },
  { flag: "🇳🇴", country: "Norway", dialCode: "+47" },
  { flag: "🇩🇰", country: "Denmark", dialCode: "+45" },
  { flag: "🇫🇮", country: "Finland", dialCode: "+358" },
  { flag: "🇨🇭", country: "Switzerland", dialCode: "+41" },
  { flag: "🇦🇹", country: "Austria", dialCode: "+43" },
  { flag: "🇵🇱", country: "Poland", dialCode: "+48" },
  { flag: "🇵🇹", country: "Portugal", dialCode: "+351" },
  { flag: "🇨🇿", country: "Czech Republic", dialCode: "+420" },
  { flag: "🇭🇺", country: "Hungary", dialCode: "+36" },
  { flag: "🇷🇴", country: "Romania", dialCode: "+40" },
  { flag: "🇬🇷", country: "Greece", dialCode: "+30" },
  { flag: "🇷🇺", country: "Russia", dialCode: "+7" },
  { flag: "🇺🇦", country: "Ukraine", dialCode: "+380" },
  { flag: "🇦🇿", country: "Azerbaijan", dialCode: "+994" },
  { flag: "🇰🇿", country: "Kazakhstan", dialCode: "+7" },
  { flag: "🇺🇿", country: "Uzbekistan", dialCode: "+998" },
  { flag: "🇵🇰", country: "Pakistan", dialCode: "+92" },
  { flag: "🇮🇳", country: "India", dialCode: "+91" },
  { flag: "🇧🇩", country: "Bangladesh", dialCode: "+880" },
  { flag: "🇳🇬", country: "Nigeria", dialCode: "+234" },
  { flag: "🇿🇦", country: "South Africa", dialCode: "+27" },
  { flag: "🇰🇪", country: "Kenya", dialCode: "+254" },
  { flag: "🇪🇹", country: "Ethiopia", dialCode: "+251" },
  { flag: "🇨🇳", country: "China", dialCode: "+86" },
  { flag: "🇯🇵", country: "Japan", dialCode: "+81" },
  { flag: "🇰🇷", country: "South Korea", dialCode: "+82" },
  { flag: "🇲🇾", country: "Malaysia", dialCode: "+60" },
  { flag: "🇮🇩", country: "Indonesia", dialCode: "+62" },
  { flag: "🇦🇺", country: "Australia", dialCode: "+61" },
  { flag: "🇳🇿", country: "New Zealand", dialCode: "+64" },
  { flag: "🇧🇷", country: "Brazil", dialCode: "+55" },
  { flag: "🇦🇷", country: "Argentina", dialCode: "+54" },
  { flag: "🇲🇽", country: "Mexico", dialCode: "+52" },
];

export const splitPhoneNumber = (value?: string) => {
  const normalizedValue = value?.trim() || "";
  const matchedOption = phoneCountryOptions.find((option) => normalizedValue.startsWith(option.dialCode));

  if (!matchedOption) {
    return {
      dialCode: DEFAULT_PHONE_DIAL_CODE,
      phoneNumber: normalizedValue,
    };
  }

  return {
    dialCode: matchedOption.dialCode,
    phoneNumber: normalizedValue.slice(matchedOption.dialCode.length).trim(),
  };
};

export const buildPhoneNumber = (dialCode: string, phoneNumber: string) => {
  const trimmedPhoneNumber = phoneNumber.trim();
  return trimmedPhoneNumber ? `${dialCode} ${trimmedPhoneNumber}` : "";
};
