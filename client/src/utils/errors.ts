import axios from "axios";

type Copy = { ar: string; en: string };

export const ERROR_COPY = {
  offline: {
    ar: "لا يوجد اتصال بالإنترنت. تحقق من اتصالك وحاول مرة أخرى.",
    en: "No internet connection. Please check your connection and try again.",
  },
  timeout: {
    ar: "استغرق الطلب وقتًا أطول من المعتاد. حاول مرة أخرى بعد قليل.",
    en: "Your request timed out. Please try again in a moment.",
  },
  unavailable: {
    ar: "الخدمة غير متاحة مؤقتًا. حاول مرة أخرى بعد قليل.",
    en: "The server is temporarily unavailable. Please try again shortly.",
  },
  rateLimited: {
    ar: "محاولات كثيرة خلال وقت قصير. انتظر قليلًا ثم حاول مجددًا.",
    en: "Too many attempts. Please wait a moment and try again.",
  },
} satisfies Record<string, Copy>;

const currentLanguage = (): "ar" | "en" => {
  try {
    return localStorage.getItem("studyBirdsLanguage") === "ar" ? "ar" : "en";
  } catch {
    return "en";
  }
};

export const pickCopy = (copy: Copy) => copy[currentLanguage()];

/** The request never got an answer: offline, DNS failure, reset or timeout. */
export const isNetworkError = (error: unknown) =>
  axios.isAxiosError(error) && !error.response && error.code !== "ERR_CANCELED";

export const isTimeoutError = (error: unknown) =>
  axios.isAxiosError(error) && !error.response && (error.code === "ECONNABORTED" || error.code === "ETIMEDOUT");

/** True when the failure means "could not reach the server" (not a server answer). */
export const isConnectivityError = (error: unknown) =>
  isNetworkError(error) || (error instanceof TypeError && /failed to fetch|network/i.test(error.message));

export const getErrorMessage = (error: unknown, fallback: string) => {
  if (axios.isAxiosError<{ message?: string }>(error)) {
    if (isTimeoutError(error)) return pickCopy(ERROR_COPY.timeout);
    if (isNetworkError(error)) return pickCopy(ERROR_COPY.offline);
    const status = error.response?.status ?? 0;
    // Never surface server internals for server-side failures.
    if (status >= 500) return pickCopy(ERROR_COPY.unavailable);
    if (status === 429) return pickCopy(ERROR_COPY.rateLimited);
    return error.response?.data?.message || fallback;
  }

  if (isConnectivityError(error)) return pickCopy(ERROR_COPY.offline);

  if (error instanceof Error) {
    return error.message;
  }

  return fallback;
};
