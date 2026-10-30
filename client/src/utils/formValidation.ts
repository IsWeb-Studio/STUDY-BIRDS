const normalizeDigits = (value: string) => value.replace(/[٠-٩۰-۹]/g, (digit) => {
  const code = digit.charCodeAt(0);
  return String.fromCharCode(code >= 0x06f0 ? code - 0x06f0 + 0x30 : code - 0x0660 + 0x30);
});

export const isValidEmail = (value: string) => {
  const email = value.trim();
  if (!email || /\s/u.test(email)) return false;
  const at = email.indexOf("@");
  if (at <= 0 || at !== email.lastIndexOf("@") || at === email.length - 1) return false;
  const local = email.slice(0, at);
  const labels = email.slice(at + 1).split(".");
  return !local.startsWith(".") && !local.endsWith(".") && !local.includes("..") &&
    labels.length >= 2 && labels.every((label) => label && !label.startsWith("-") && !label.endsWith("-"));
};

export const isValidPhoneNumber = (dialCode: string, phoneNumber: string) => {
  const local = normalizeDigits(phoneNumber.trim()).replace(/[\s().-]/gu, "");
  if (!local) return false;
  if (!/^\+?[0-9]+$/u.test(local)) return false;
  const prefix = normalizeDigits(dialCode).replace(/\D/gu, "");
  const digits = local.startsWith("+") ? local.slice(1) : `${prefix}${local}`;
  return digits.length >= 7 && digits.length <= 15;
};

export const isValidNonNegativeDecimal = (value: string) => {
  const normalized = normalizeDigits(value).replace(/\u066b/gu, ".").trim();
  return /^\d+(?:\.\d+)?$/u.test(normalized) && Number.isFinite(Number(normalized)) && Number(normalized) >= 0;
};

export const daysInMonth = (year: number, month: number) =>
  new Date(year, month, 0).getDate();

/** Strict date-only validation using local calendar fields, without timezone conversion. */
export const isValidPastDateOnly = (value: string, today = new Date()) => {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/u.exec(value);
  if (!match) return false;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const date = new Date(year, month - 1, day);
  if (date.getFullYear() !== year || date.getMonth() + 1 !== month || date.getDate() !== day) return false;
  const currentDate = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  return date <= currentDate;
};
