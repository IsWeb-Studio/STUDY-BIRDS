import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { SocialLinks } from "./SocialLinks";
import { useSiteSettings } from "../hooks/useSiteSettings";
import { useLanguage } from "../hooks/useLanguage";
import { useAuth } from "../hooks/useAuth";
import { contentService } from "../services/contentService";
import { BRAND_LOGO_PATH, SITE_NAME } from "../seo/site";
import type { Country } from "../types";
import { getPaginatedItems } from "../utils/pagination";

export const Footer = () => {
  const { t, tv, language } = useLanguage();
  const { user } = useAuth();
  const siteSettings = useSiteSettings();
  const [countries, setCountries] = useState<Country[]>([]);

  useEffect(() => {
    let active = true;

    contentService
      .getCountries({ paginate: false })
      .then((data) => {
        if (active) {
          setCountries(getPaginatedItems(data).slice(0, 6));
        }
      })
      .catch(() => {
        if (active) {
          setCountries([]);
        }
      });

    return () => {
      active = false;
    };
  }, []);

  return (
    <footer className="mt-20 bg-fusion text-white">
      <div className="container-shell grid gap-10 py-14 md:grid-cols-2 xl:grid-cols-4">
        <div>
          <div className="flex items-center gap-3">
            <img src={BRAND_LOGO_PATH} alt={SITE_NAME} className="h-12 w-12 rounded-2xl bg-white object-cover p-1" />
            <h3 className="text-2xl font-semibold">{SITE_NAME}</h3>
          </div>
          <p className="mt-4 max-w-sm text-sm text-brand-100">{t("footerBody")}</p>
          {!user ? (
            <div className="mt-6 flex flex-wrap gap-3">
              <Link to="/login" className="rounded-full border border-white/20 px-4 py-2 text-sm font-medium text-white transition hover:bg-white hover:text-brand-900">
                {t("login")}
              </Link>
              <Link to="/register" className="rounded-full bg-white px-4 py-2 text-sm font-semibold text-brand-900 transition hover:bg-brand-50">
                {t("startJourney")}
              </Link>
            </div>
          ) : null}
        </div>

        <div>
          <h4 className="font-semibold">{t("explore")}</h4>
          <div className="mt-4 flex flex-col gap-3 text-sm text-brand-100">
            <Link to="/programs">{t("programs")}</Link>
            <Link to="/universities">{t("universities")}</Link>
            <Link to="/destinations">{t("destinations")}</Link>
            <Link to="/services">{t("servicesEyebrow")}</Link>
            <Link to="/blog">{t("exhibitions")}</Link>
            <Link to="/partner">{t("partner")}</Link>
          </div>
        </div>

        <div>
          <h4 className="font-semibold">{language === "ar" ? "\u0631\u0648\u0627\u0628\u0637 \u0633\u0631\u064a\u0639\u0629" : "Quick Links"}</h4>
          <div className="mt-4 flex flex-col gap-3 text-sm text-brand-100">
            <Link to="/about">{language === "ar" ? "\u0645\u0646 \u0646\u062d\u0646" : "About Us"}</Link>
            <Link to="/contact">{t("contact")}</Link>
            <Link to="/privacy-policy">{language === "ar" ? "سياسة الخصوصية" : "Privacy Policy"}</Link>
            <Link to="/delete-account">{language === 'ar' ? 'حذف الحساب' : 'Delete account'}</Link>
          </div>
          {countries.length ? (
            <div className="mt-6">
              <h5 className="font-semibold text-white">{language === "ar" ? "\u0627\u0644\u062f\u0648\u0644 \u0627\u0644\u0645\u0633\u062a\u0647\u062f\u0641\u0629 \u0644\u0644\u062f\u0631\u0627\u0633\u0629" : "Target Study Countries"}</h5>
              <div className="mt-4 flex flex-col gap-3 text-sm text-brand-100">
                {countries.map((country) => (
                  <Link key={country._id} to={`/universities?country=${country._id}`}>
                    {tv(country.name)}
                  </Link>
                ))}
              </div>
            </div>
          ) : null}
        </div>

        <div>
          <div className="mb-6">
            <h4 className="font-semibold">{language === "ar" ? "\u0639\u0636\u0648 \u0641\u064a" : "Member of"}</h4>
            {siteSettings.britishMembershipUrl ? (
              <a
                href={siteSettings.britishMembershipUrl}
                target="_blank"
                rel="noreferrer"
                className="mt-4 inline-flex items-center justify-center rounded-2xl border border-white/15 bg-white/10 p-3 transition hover:-translate-y-0.5 hover:bg-white"
                aria-label={language === "ar" ? "\u0627\u0644\u0639\u0636\u0648\u064a\u0629 \u0627\u0644\u0628\u0631\u064a\u0637\u0627\u0646\u064a\u0629" : "British membership"}
              >
                <img src="/british.svg" alt={language === "ar" ? "\u0627\u0644\u0639\u0636\u0648\u064a\u0629 \u0627\u0644\u0628\u0631\u064a\u0637\u0627\u0646\u064a\u0629" : "British membership"} className="h-12 w-auto" />
              </a>
            ) : (
              <div className="mt-4 inline-flex items-center justify-center rounded-2xl border border-white/15 bg-white/10 p-3 opacity-80">
                <img src="/british.svg" alt={language === "ar" ? "\u0627\u0644\u0639\u0636\u0648\u064a\u0629 \u0627\u0644\u0628\u0631\u064a\u0637\u0627\u0646\u064a\u0629" : "British membership"} className="h-12 w-auto" />
              </div>
            )}
          </div>
          <h4 className="font-semibold">{t("contact")}</h4>
          <div className="mt-4 space-y-4 text-sm text-brand-100">
            <p>{siteSettings.contactEmail}</p>
            <p>{t("contactBody")}</p>
            <SocialLinks
              settings={siteSettings}
              className="flex flex-wrap gap-3"
              itemClassName="inline-flex items-center justify-center rounded-2xl border border-white/15 bg-white/10 p-3 text-white transition hover:-translate-y-0.5 hover:bg-white hover:text-brand-900"
              labelClassName="sr-only"
            />
          </div>
        </div>
      </div>
    </footer>
  );
};
