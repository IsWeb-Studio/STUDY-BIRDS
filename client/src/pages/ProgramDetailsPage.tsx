import { useEffect, useState, type FormEvent } from "react";
import { Link, useLocation, useParams } from "react-router-dom";
import { FormInput } from "../components/forms/FormInput";
import { PhoneNumberField } from "../components/forms/PhoneNumberField";
import { LoadingSpinner } from "../components/LoadingSpinner";
import { Seo } from "../components/seo/Seo";
import { DOCUMENT_UPLOAD_ACCEPT } from "../constants/upload";
import { useAuth } from "../hooks/useAuth";
import { useLanguage } from "../hooks/useLanguage";
import { SITE_NAME, seoText } from "../seo/site";
import { applicationService } from "../services/applicationService";
import { programService } from "../services/programService";
import { studentService } from "../services/studentService";
import type { Program } from "../types";
import { dt } from "../utils/dashboardTranslations";
import { getErrorMessage } from "../utils/errors";
import { formatCurrency } from "../utils/format";
import { buildPhoneNumber, DEFAULT_PHONE_DIAL_CODE, splitPhoneNumber } from "../utils/phoneCountryOptions";

type ApplicationFormState = {
  name: string;
  email: string;
  nationality: string;
  currentEducation: string;
  gpa: string;
  intake: string;
  englishExam: string;
  englishScore: string;
  address: string;
  notes: string;
};

const emptyForm: ApplicationFormState = {
  name: "",
  email: "",
  nationality: "",
  currentEducation: "",
  gpa: "",
  intake: "",
  englishExam: "",
  englishScore: "",
  address: "",
  notes: "",
};

export const ProgramDetailsPage = () => {
  const { t, tv, language } = useLanguage();
  const { id = "" } = useParams();
  const { hash } = useLocation();
  const { profile, refreshSession, user } = useAuth();
  const [program, setProgram] = useState<Program | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [message, setMessage] = useState("");
  const [errorMessage, setErrorMessage] = useState("");
  const [applicationForm, setApplicationForm] = useState<ApplicationFormState>(emptyForm);
  const [phoneDialCode, setPhoneDialCode] = useState(DEFAULT_PHONE_DIAL_CODE);
  const [phoneNumber, setPhoneNumber] = useState("");
  const [documentFiles, setDocumentFiles] = useState<Record<string, File>>({});
  const [uploadKey, setUploadKey] = useState(0);
  const [favoriteLoading, setFavoriteLoading] = useState(false);
  const [favoriteMessage, setFavoriteMessage] = useState("");
  const requiredTypes = program?.requiredDocumentTypes ?? ['passport', 'biometric-photo', 'latest-qualification'];
  const documentLabels: Record<string, string[]> = { passport: ['جواز السفر', 'Passport'], 'biometric-photo': ['صورة شخصية', 'Photo'], 'latest-qualification': ['آخر مؤهل دراسي', 'Latest qualification'], transcript: ['كشف الدرجات', 'Transcript'], 'language-certificate': ['شهادة اللغة', 'Language certificate'], other: ['مستند إضافي', 'Additional document'] };

  useEffect(() => {
    if (!loading && program?._id === id && hash === "#program-application") {
      document.getElementById("program-application")?.scrollIntoView({ block: "start" });
    }
  }, [loading, program?._id, id, hash]);

  useEffect(() => {
    const loadProgram = async () => {
      setLoading(true);
      setLoadError("");

      try {
        const data = await programService.getById(id);
        setProgram(data);
      } catch (error) {
        setLoadError(getErrorMessage(error, dt(language, "loadProgramFailed")));
      } finally {
        setLoading(false);
      }
    };

    loadProgram();
  }, [id, language]);

  useEffect(() => {
    setApplicationForm((current) => ({
      ...current,
      name: current.name || user?.name || profile?.user?.name || "",
      email: current.email || user?.email || profile?.user?.email || "",
      nationality: current.nationality || profile?.nationality || "",
      currentEducation: current.currentEducation || profile?.currentEducation || "",
      gpa: current.gpa || profile?.gpa || "",
      intake: current.intake || profile?.intake || "",
      englishExam: current.englishExam || profile?.englishTest?.exam || "",
      englishScore: current.englishScore || profile?.englishTest?.score || "",
      address: current.address || profile?.address || "",
    }));
  }, [profile, user]);

  useEffect(() => {
    const { dialCode, phoneNumber: savedPhoneNumber } = splitPhoneNumber(profile?.phone);
    setPhoneDialCode(savedPhoneNumber ? dialCode : DEFAULT_PHONE_DIAL_CODE);
    setPhoneNumber((current) => current || savedPhoneNumber);
  }, [profile?.phone]);

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setMessage("");
    setErrorMessage("");

    if (!user) {
      setErrorMessage(t("submitApplicationLoginRequired"));
      return;
    }

    if (user.role !== "student") {
      setErrorMessage(dt(language, "studentOnlyApplication"));
      return;
    }

    if (!program) {
      setErrorMessage(dt(language, "loadProgramFailed"));
      return;
    }

    const formattedPhoneNumber = buildPhoneNumber(phoneDialCode, phoneNumber);

    if (!formattedPhoneNumber) {
      setErrorMessage(t("phone"));
      return;
    }

    if (requiredTypes.some(type => !documentFiles[type])) {
      setErrorMessage(dt(language, "fillRequiredDocuments"));
      return;
    }

    setSubmitting(true);

    try {
      await studentService.updateProfile({
        name: applicationForm.name,
        email: applicationForm.email,
        phone: formattedPhoneNumber,
        nationality: applicationForm.nationality,
        currentEducation: applicationForm.currentEducation,
        gpa: applicationForm.gpa,
        intake: applicationForm.intake,
        englishTest: {
          exam: applicationForm.englishExam,
          score: applicationForm.englishScore,
        },
        address: applicationForm.address,
      });

      const uploadedDocuments = await Promise.all(requiredTypes.map(type => studentService.uploadDocument(documentFiles[type], type)));

      await applicationService.create({
        programId: program._id,
        notes: applicationForm.notes,
        documentIds: uploadedDocuments.map(document => document._id),
        applicantProfile: {
          name: applicationForm.name,
          email: applicationForm.email,
          phone: formattedPhoneNumber,
          dateOfBirth: profile?.dateOfBirth,
          nationality: applicationForm.nationality,
          currentEducation: applicationForm.currentEducation,
          gpa: applicationForm.gpa,
          intake: applicationForm.intake,
          address: applicationForm.address,
          englishTest: {
            exam: applicationForm.englishExam,
            score: applicationForm.englishScore,
          },
        },
      });

      await refreshSession();
      setMessage(t("submitApplicationSuccess"));
      setApplicationForm((current) => ({ ...current, notes: "" }));
      setDocumentFiles({});
      setUploadKey(current => current + 1);
    } catch (error) {
      setErrorMessage(getErrorMessage(error, dt(language, "applicationFailed")));
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) {
    return (
      <>
        <Seo
          title={seoText(language, "Program Details", "تفاصيل البرنامج")}
          description={seoText(
            language,
            "Discover detailed information about this international program and start your study abroad application.",
            "اكتشف التفاصيل الكاملة لهذا البرنامج الدولي وابدأ التقديم للدراسة بالخارج."
          )}
        />
        <LoadingSpinner />
      </>
    );
  }

  if (!program || loadError) {
    return (
      <>
        <Seo
          title={seoText(language, "Program Not Found", "البرنامج غير موجود")}
          description={seoText(
            language,
            "The requested program could not be loaded.",
            "تعذر تحميل البرنامج المطلوب."
          )}
          noIndex
        />
        <div className="panel p-8">
          <p className="text-sm font-semibold uppercase tracking-[0.3em] text-brand-700">{t("programs")}</p>
          <h1 className="mt-3 text-3xl font-semibold text-slate-900">{loadError || dt(language, "loadProgramFailed")}</h1>
          <Link to="/programs" className="mt-6 inline-flex rounded-full bg-brand-900 px-5 py-3 text-sm font-semibold text-white">
            {t("explorePrograms")}
          </Link>
        </div>
      </>
    );
  }

  const isPartnerUser = user?.role === "partner";
  const visibleTuition = isPartnerUser ? program.partnerTuition ?? program.tuition : program.tuition;
  const seoDescription =
    program.summary ||
    seoText(
      language,
      `Explore ${program.title} at ${program.university?.name || SITE_NAME} and review tuition and admission requirements.`,
      `استكشف برنامج ${program.title} في ${program.university?.name || SITE_NAME} وتعرّف على الرسوم ومتطلبات القبول.`
    );
  const structuredData = {
    "@context": "https://schema.org",
    "@type": "Course",
    name: program.title,
    description: seoDescription,
    provider: {
      "@type": "CollegeOrUniversity",
      name: program.university?.name || SITE_NAME,
    },
  };

  const handleFavorite = async () => {
    if (user?.role !== "student" || !program) return;
    setFavoriteLoading(true);
    setFavoriteMessage("");
    try {
      const result = await studentService.toggleFavorite({ itemType: "program", programId: program._id });
      setFavoriteMessage("removed" in result ? (language === "ar" ? "تم حذف البرنامج من المفضلة." : "Program removed from favorites.") : language === "ar" ? "تمت إضافة البرنامج إلى المفضلة." : "Program added to favorites.");
    } catch (error) {
      setFavoriteMessage(getErrorMessage(error, language === "ar" ? "تعذر تحديث المفضلة." : "Unable to update favorites."));
    } finally {
      setFavoriteLoading(false);
    }
  };

  return (
    <div className="grid gap-6 xl:grid-cols-[1.08fr_0.92fr]">
      <Seo
        title={program.title}
        description={seoDescription}
        keywords={[
          program.title,
          program.university?.name || "",
          program.fieldOfStudy,
          program.degreeLevel,
        ]}
        structuredData={structuredData}
      />
      <section className="panel overflow-hidden p-0">
        <div className="p-8">
          <p className="text-sm font-semibold uppercase tracking-[0.3em] text-brand-700">{tv(program.degreeLevel)}</p>
          <h1 className="mt-3 text-4xl font-semibold text-slate-900">{program.title}</h1>
          <p className="mt-4 text-slate-600">{program.summary}</p>

          <div className="mt-8 grid gap-4 md:grid-cols-2">
            <div className="rounded-3xl bg-slate-50 p-5">
              <div className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-500">{t("university")}</div>
              {program.university ? (
                <Link to={`/universities/${program.university._id}`} className="mt-2 inline-flex font-semibold text-brand-700">
                  {program.university.name}
                </Link>
              ) : (
                <p className="mt-2 font-semibold text-slate-900">{dt(language, "unknownUniversity")}</p>
              )}
            </div>
            <div className="rounded-3xl bg-slate-50 p-5">
              <div className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-500">{t("country")}</div>
              <p className="mt-2 font-semibold text-slate-900">{tv(program.university?.country?.name)}</p>
            </div>
            <div className="rounded-3xl bg-slate-50 p-5">
              <div className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-500">{language === "ar" ? "لغة البرنامج" : "Program language"}</div>
              <p className="mt-2 font-semibold text-slate-900">{program.language || dt(language, "notAvailable")}</p>
            </div>
            <div className="rounded-3xl bg-slate-50 p-5">
              <div className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-500">{language === "ar" ? "مجالات الدراسة" : "Study fields"}</div>
              <p className="mt-2 font-semibold text-slate-900">
                {program.fieldsOfStudy?.length ? program.fieldsOfStudy.join(language === "ar" ? "، " : ", ") : program.fieldOfStudy}
              </p>
            </div>
            <div className="rounded-3xl bg-slate-50 p-5">
              <div className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-500">{isPartnerUser ? t("partnerPrice") : t("tuition")}</div>
              <p className="mt-2 font-semibold text-slate-900">{formatCurrency(visibleTuition)}</p>
              {isPartnerUser && typeof program.partnerTuition === "number" && typeof program.tuition === "number" ? (
                <p className="mt-2 text-sm text-slate-500">{t("tuition")}: {formatCurrency(program.tuition)}</p>
              ) : null}
            </div>
          </div>

          <div className="mt-8">
            {user?.role === "student" ? (
              <div className="mb-6">
                <button type="button" onClick={handleFavorite} disabled={favoriteLoading} className="rounded-full border border-slate-200 px-5 py-3 text-sm font-semibold text-slate-700">
                  {favoriteLoading ? (language === "ar" ? "جارٍ الحفظ..." : "Saving...") : language === "ar" ? "أضف إلى المفضلة" : "Add to Favorites"}
                </button>
                {favoriteMessage ? <p className="mt-3 text-sm text-slate-500">{favoriteMessage}</p> : null}
              </div>
            ) : null}
            <h2 className="text-xl font-semibold text-slate-900">{t("requirements")}</h2>
            {program.requirements?.length ? (
              <ul className="mt-4 list-disc space-y-2 pl-5 text-slate-600">
                {program.requirements.map((item) => (
                  <li key={item}>{tv(item)}</li>
                ))}
              </ul>
            ) : (
              <p className="mt-4 text-slate-500">{dt(language, "notAvailable")}</p>
            )}
          </div>
        </div>
      </section>

      {/* PRD 21: careers, where else the program is taught, and related programs. */}
      {program.careerOpportunities?.length || program.offeredAt?.length || program.relatedPrograms?.length ? (
        <section className="grid gap-4 lg:grid-cols-3">
          {program.careerOpportunities?.length ? (
            <div className="panel p-6">
              <h2 className="text-xl font-semibold text-slate-900">{language === "ar" ? "مجالات العمل بعد التخرج" : "Career opportunities"}</h2>
              <ul className="mt-4 list-disc space-y-2 ps-5 text-slate-600">
                {program.careerOpportunities.map((item) => <li key={item}>{item}</li>)}
              </ul>
            </div>
          ) : null}
          {program.offeredAt?.length ? (
            <div className="panel p-6">
              <h2 className="text-xl font-semibold text-slate-900">{language === "ar" ? "جامعات أخرى تقدّم البرنامج" : "Also offered at"}</h2>
              <ul className="mt-4 space-y-2 text-slate-600">
                {program.offeredAt.map((item) => (
                  <li key={item._id}>
                    <Link className="font-semibold text-brand-700" to={`/programs/${item._id}`}>{item.university?.name}</Link>
                    {[item.university?.city, item.university?.country?.name].filter(Boolean).length ? ` — ${[item.university?.city, item.university?.country?.name].filter(Boolean).join("، ")}` : ""}
                  </li>
                ))}
              </ul>
            </div>
          ) : null}
          {program.relatedPrograms?.length ? (
            <div className="panel p-6">
              <h2 className="text-xl font-semibold text-slate-900">{language === "ar" ? "برامج ذات صلة" : "Related programs"}</h2>
              <ul className="mt-4 space-y-2 text-slate-600">
                {program.relatedPrograms.map((item) => (
                  <li key={item._id}>
                    <Link className="font-semibold text-brand-700" to={`/programs/${item._id}`}>{item.title}</Link>
                    {item.university?.name ? ` — ${item.university.name}` : ""}
                  </li>
                ))}
              </ul>
            </div>
          ) : null}
        </section>
      ) : null}


      <section id="program-application" className="panel scroll-mt-32 p-8">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-brand-700">{dt(language, "submitUniversityApplication")}</p>
        <h2 className="mt-3 text-3xl font-semibold text-slate-900">{dt(language, "applicationFormTitle")}</h2>
        <p className="mt-3 text-sm leading-6 text-slate-500">{dt(language, "applicationFormSubtitle")}</p>

        {message ? <div className="mt-6 rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{message}</div> : null}
        {errorMessage ? <div className="mt-6 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{errorMessage}</div> : null}

        <form onSubmit={handleSubmit} className="mt-6 space-y-6">
          <div className="grid gap-4 md:grid-cols-2">
            <FormInput
              label={t("name")}
              value={applicationForm.name}
              onChange={(event) => setApplicationForm((current) => ({ ...current, name: event.target.value }))}
              required
            />
            <FormInput
              label={t("email")}
              type="email"
              value={applicationForm.email}
              onChange={(event) => setApplicationForm((current) => ({ ...current, email: event.target.value }))}
              required
            />
            <PhoneNumberField
              label={t("phone")}
              dialCode={phoneDialCode}
              phoneNumber={phoneNumber}
              onDialCodeChange={setPhoneDialCode}
              onPhoneNumberChange={setPhoneNumber}
              required
            />
            <FormInput
              label={t("nationality")}
              value={applicationForm.nationality}
              onChange={(event) => setApplicationForm((current) => ({ ...current, nationality: event.target.value }))}
              required
            />
            <FormInput
              label={t("currentEducation")}
              value={applicationForm.currentEducation}
              onChange={(event) => setApplicationForm((current) => ({ ...current, currentEducation: event.target.value }))}
              required
            />
            <FormInput
              label={t("gpa")}
              value={applicationForm.gpa}
              onChange={(event) => setApplicationForm((current) => ({ ...current, gpa: event.target.value }))}
            />
            <FormInput
              label={t("preferredIntake")}
              value={applicationForm.intake}
              onChange={(event) => setApplicationForm((current) => ({ ...current, intake: event.target.value }))}
            />
            <FormInput
              label={dt(language, "englishExam")}
              value={applicationForm.englishExam}
              onChange={(event) => setApplicationForm((current) => ({ ...current, englishExam: event.target.value }))}
            />
            <FormInput
              label={dt(language, "englishScore")}
              value={applicationForm.englishScore}
              onChange={(event) => setApplicationForm((current) => ({ ...current, englishScore: event.target.value }))}
            />
            <FormInput
              label={t("address")}
              value={applicationForm.address}
              onChange={(event) => setApplicationForm((current) => ({ ...current, address: event.target.value }))}
            />
          </div>

          <label className="block">
            <span className="mb-2 block text-sm font-medium text-slate-700">{dt(language, "applicationNotes")}</span>
            <textarea
              value={applicationForm.notes}
              onChange={(event) => setApplicationForm((current) => ({ ...current, notes: event.target.value }))}
              rows={4}
              placeholder={dt(language, "applicationNotesPlaceholder")}
              className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none ring-brand-300 focus:ring"
            />
          </label>

          <div key={uploadKey} className="grid gap-4 md:grid-cols-2">
            {requiredTypes.map(type => <label className="block" key={type}>
              <span className="mb-2 block text-sm font-medium text-slate-700">{documentLabels[type]?.[language === 'ar' ? 0 : 1] || type}</span>
              <input type="file" required accept={type === 'biometric-photo' ? 'image/jpeg,image/png,image/webp' : DOCUMENT_UPLOAD_ACCEPT} onChange={event => {
                const file = event.target.files?.[0];
                setDocumentFiles(current => { const next = {...current}; if (file) next[type] = file; else delete next[type]; return next; });
              }} className="w-full rounded-2xl border border-dashed border-slate-300 bg-slate-50 px-4 py-4 text-sm" />
            </label>)}
          </div>

          <button
            type="submit"
            disabled={submitting || user?.role !== "student"}
            className="rounded-full bg-brand-900 px-6 py-3 font-semibold text-white disabled:cursor-not-allowed disabled:bg-slate-300"
          >
            {submitting ? dt(language, "applyingNow") : dt(language, "saveAndApply")}
          </button>

          <p className="text-sm text-slate-500">
            {user ? (user.role === "student" ? dt(language, "fillRequiredDocuments") : dt(language, "studentOnlyApplication")) : t("submitApplicationLoginRequired")}
          </p>
        </form>
      </section>
    </div>
  );
};
