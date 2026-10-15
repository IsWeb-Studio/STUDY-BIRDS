import { useState, type FormEvent } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../hooks/useAuth";
import { SocialLinks } from "../components/SocialLinks";
import { useSiteSettings } from "../hooks/useSiteSettings";
import { Seo } from "../components/seo/Seo";
import { useLanguage } from "../hooks/useLanguage";
import { SITE_NAME, seoText } from "../seo/site";
import { contactService } from "../services/contactService";
import { getErrorMessage } from "../utils/errors";

type ContactFormState = {
  name: string;
  email: string;
  phone: string;
  subject: string;
  message: string;
};

const emptyForm: ContactFormState = {
  name: "",
  email: "",
  phone: "",
  subject: "",
  message: "",
};

export const ContactPage = () => {
  const { user } = useAuth();
  const { t, language } = useLanguage();
  const siteSettings = useSiteSettings();
  const supportHoursText = siteSettings.supportHours?.trim() || t("supportHours");
  const officeLocationsText = siteSettings.officeLocations?.trim() || t("offices");
  const [form, setForm] = useState<ContactFormState>(emptyForm);
  const [submitting, setSubmitting] = useState(false);
  const [successMessage, setSuccessMessage] = useState("");
  const [errorMessage, setErrorMessage] = useState("");

  const isArabic = language === "ar";

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setSuccessMessage("");
    setErrorMessage("");

    if (!form.name.trim() || !form.email.trim() || !form.subject.trim() || !form.message.trim()) {
      setErrorMessage(isArabic ? "\u064a\u0631\u062c\u0649 \u062a\u0639\u0628\u0626\u0629 \u0627\u0644\u0627\u0633\u0645 \u0648\u0627\u0644\u0628\u0631\u064a\u062f \u0627\u0644\u0625\u0644\u0643\u062a\u0631\u0648\u0646\u064a \u0648\u0627\u0644\u0645\u0648\u0636\u0648\u0639 \u0648\u0627\u0644\u0631\u0633\u0627\u0644\u0629." : "Please fill in name, email, subject, and message.");
      return;
    }

    try {
      setSubmitting(true);
      await contactService.sendMessage({
        name: form.name.trim(),
        email: form.email.trim(),
        phone: form.phone.trim(),
        subject: form.subject.trim(),
        message: form.message.trim(),
      });
      setForm(emptyForm);
      setSuccessMessage(isArabic ? "\u062a\u0645 \u0625\u0631\u0633\u0627\u0644 \u0631\u0633\u0627\u0644\u062a\u0643 \u0628\u0646\u062c\u0627\u062d. \u0633\u0646\u0639\u0648\u062f \u0625\u0644\u064a\u0643 \u0639\u0628\u0631 \u0627\u0644\u0628\u0631\u064a\u062f \u0627\u0644\u0625\u0644\u0643\u062a\u0631\u0648\u0646\u064a \u0642\u0631\u064a\u0628\u064b\u0627." : "Your message was sent successfully. We will reply by email soon.");
    } catch (error) {
      setErrorMessage(
        getErrorMessage(
          error,
          isArabic ? "\u062a\u0639\u0630\u0631 \u0625\u0631\u0633\u0627\u0644 \u0627\u0644\u0631\u0633\u0627\u0644\u0629 \u0627\u0644\u0622\u0646. \u062d\u0627\u0648\u0644 \u0645\u0631\u0629 \u0623\u062e\u0631\u0649 \u0628\u0639\u062f \u0642\u0644\u064a\u0644." : "Unable to send your message right now. Please try again shortly."
        )
      );
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="grid gap-8 lg:grid-cols-2">
      <Seo
        title={seoText(language, `Contact ${SITE_NAME}`, `\u062a\u0648\u0627\u0635\u0644 \u0645\u0639 ${SITE_NAME}`)}
        description={seoText(
          language,
          `Contact ${SITE_NAME} for support with university applications, international programs, and study abroad planning.`,
          `\u062a\u0648\u0627\u0635\u0644 \u0645\u0639 ${SITE_NAME} \u0644\u0644\u062d\u0635\u0648\u0644 \u0639\u0644\u0649 \u062f\u0639\u0645 \u0641\u064a \u0627\u0644\u062a\u0642\u062f\u064a\u0645 \u0627\u0644\u062c\u0627\u0645\u0639\u064a\u060c \u0648\u0627\u062e\u062a\u064a\u0627\u0631 \u0627\u0644\u0628\u0631\u0627\u0645\u062c\u060c \u0648\u0627\u0644\u062a\u062e\u0637\u064a\u0637 \u0644\u0644\u062f\u0631\u0627\u0633\u0629 \u0628\u0627\u0644\u062e\u0627\u0631\u062c.`
        )}
      />

      <div className="panel border-t-4 border-t-accent-300 bg-white p-8">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-brand-700">{t("contact")}</p>
        <h1 className="mt-3 text-4xl font-semibold text-slate-900">{t("contactTitle")}</h1>
        {user?.role === "student" && <p className="mt-4 text-sm text-slate-600">{isArabic ? "لمتابعة طلبك والحفاظ على سجل الردود، استخدم " : "To follow your application and keep the conversation history, use "}<Link to="/student/support" className="font-semibold text-brand-700 underline">{isArabic ? "تذاكر الدعم داخل حسابك" : "support tickets in your account"}</Link>.</p>}
        <p className="mt-4 text-slate-600">{t("contactBody")}</p>
      </div>

      <div className="panel bg-white p-8">
        <h2 className="text-2xl font-semibold text-slate-900">
          {isArabic ? "\u0623\u0631\u0633\u0644 \u0631\u0633\u0627\u0644\u0629 \u0625\u0644\u0649 \u0641\u0631\u064a\u0642\u0646\u0627" : "Send a message to our team"}
        </h2>
        <p className="mt-2 text-sm leading-7 text-slate-600">
          {isArabic ? "\u0627\u0645\u0644\u0623 \u0627\u0644\u0646\u0645\u0648\u0630\u062c \u0648\u0633\u0646\u062a\u0648\u0627\u0635\u0644 \u0645\u0639\u0643 \u0639\u0628\u0631 \u0627\u0644\u0628\u0631\u064a\u062f \u0627\u0644\u0625\u0644\u0643\u062a\u0631\u0648\u0646\u064a \u0641\u064a \u0623\u0642\u0631\u0628 \u0648\u0642\u062a \u0645\u0645\u0643\u0646." : "Fill out the form and we will contact you by email as soon as possible."}
        </p>

        <form className="mt-6 space-y-4" onSubmit={handleSubmit}>
          <div className="grid gap-4 sm:grid-cols-2">
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "\u0627\u0644\u0627\u0633\u0645" : "Name"}</span>
              <input
                type="text"
                value={form.name}
                onChange={(event) => setForm((current) => ({ ...current, name: event.target.value }))}
                className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none transition focus:border-brand-400 focus:ring"
                placeholder={isArabic ? "\u0627\u0643\u062a\u0628 \u0627\u0633\u0645\u0643 \u0627\u0644\u0643\u0627\u0645\u0644" : "Enter your full name"}
              />
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{t("email")}</span>
              <input
                type="email"
                value={form.email}
                onChange={(event) => setForm((current) => ({ ...current, email: event.target.value }))}
                className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none transition focus:border-brand-400 focus:ring"
                placeholder="name@example.com"
              />
            </label>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{t("phone")}</span>
              <input
                type="text"
                value={form.phone}
                onChange={(event) => setForm((current) => ({ ...current, phone: event.target.value }))}
                className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none transition focus:border-brand-400 focus:ring"
                placeholder={isArabic ? "\u0627\u062e\u062a\u064a\u0627\u0631\u064a" : "Optional"}
              />
            </label>
            <label className="block">
              <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "\u0627\u0644\u0645\u0648\u0636\u0648\u0639" : "Subject"}</span>
              <input
                type="text"
                value={form.subject}
                onChange={(event) => setForm((current) => ({ ...current, subject: event.target.value }))}
                className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none transition focus:border-brand-400 focus:ring"
                placeholder={isArabic ? "\u0639\u0646\u0648\u0627\u0646 \u0627\u0644\u0631\u0633\u0627\u0644\u0629" : "Message subject"}
              />
            </label>
          </div>

          <label className="block">
            <span className="mb-2 block text-sm font-medium text-slate-700">{isArabic ? "\u0627\u0644\u0631\u0633\u0627\u0644\u0629" : "Message"}</span>
            <textarea
              rows={6}
              value={form.message}
              onChange={(event) => setForm((current) => ({ ...current, message: event.target.value }))}
              className="w-full rounded-3xl border border-slate-200 px-4 py-3 outline-none transition focus:border-brand-400 focus:ring"
              placeholder={isArabic ? "\u0627\u0643\u062a\u0628 \u062a\u0641\u0627\u0635\u064a\u0644 \u0637\u0644\u0628\u0643 \u0623\u0648 \u0627\u0633\u062a\u0641\u0633\u0627\u0631\u0643 \u0647\u0646\u0627" : "Write your request or question here"}
            />
          </label>

          {successMessage ? (
            <div className="rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{successMessage}</div>
          ) : null}
          {errorMessage ? (
            <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{errorMessage}</div>
          ) : null}

          <button
            type="submit"
            disabled={submitting}
            className="inline-flex rounded-full bg-brand-900 px-6 py-3 text-sm font-semibold text-white transition hover:bg-brand-800 disabled:cursor-not-allowed disabled:opacity-70"
          >
            {submitting
              ? isArabic
                ? "\u062c\u0627\u0631\u064d \u0627\u0644\u0625\u0631\u0633\u0627\u0644..."
                : "Sending..."
              : isArabic
                ? "\u0625\u0631\u0633\u0627\u0644 \u0627\u0644\u0631\u0633\u0627\u0644\u0629"
                : "Send message"}
          </button>
        </form>

        <div className="mt-8 space-y-4 border-t border-slate-200 pt-8 text-slate-700">
          <p>
            {t("email")}: {siteSettings.contactEmail}
          </p>
          <div>
            <p className="font-semibold text-slate-900">{t("supportHoursLabel")}</p>
            <p className="mt-1 whitespace-pre-line">{supportHoursText}</p>
          </div>
          <div>
            <p className="font-semibold text-slate-900">{t("officeLocationsLabel")}</p>
            <p className="mt-1 whitespace-pre-line">{officeLocationsText}</p>
          </div>
          <div className="pt-2">
            <SocialLinks
              settings={siteSettings}
              className="grid gap-3 sm:grid-cols-2"
              itemClassName="group inline-flex items-center gap-3 rounded-3xl border border-slate-200 bg-white px-4 py-4 text-slate-700 transition hover:-translate-y-0.5 hover:border-accent-300 hover:bg-accent-50 hover:text-accent-700"
              labelClassName="text-sm font-medium"
            />
          </div>
        </div>
      </div>
    </div>
  );
};
