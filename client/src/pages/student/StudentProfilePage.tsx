import { useEffect, useRef, useState, type FormEvent } from "react";
import { useForm } from "react-hook-form";
import { DateOfBirthField } from "../../components/forms/DateOfBirthField";
import { FormInput } from "../../components/forms/FormInput";
import { PhoneNumberField } from "../../components/forms/PhoneNumberField";
import { useAuth } from "../../hooks/useAuth";
import { useLanguage } from "../../hooks/useLanguage";
import { authService } from "../../services/authService";
import { contentService } from "../../services/contentService";
import { partnerService } from "../../services/partnerService";
import { studentService } from "../../services/studentService";
import { universityService } from "../../services/universityService";
import type { Country, StudentProfile } from "../../types";
import { dt } from "../../utils/dashboardTranslations";
import { getErrorMessage } from "../../utils/errors";
import { buildPhoneNumber, DEFAULT_PHONE_DIAL_CODE, splitPhoneNumber } from "../../utils/phoneCountryOptions";
import { isValidNonNegativeDecimal, isValidPastDateOnly, isValidPhoneNumber } from "../../utils/formValidation";

type ProfileFormValues = StudentProfile & {
  name: string;
  email: string;
  englishExam?: string;
  englishScore?: string;
  otherLanguagesText?: string;
  parentName?: string;
  parentRelationship?: string;
  emergencyName?: string;
  emergencyRelationship?: string;
  companyName?: string;
  website?: string;
  location?: string;
  taxId?: string;
};

type SavedTargetData = { codes: string[]; labels: string[] };

export const StudentProfilePage = () => {
  const { language, t } = useLanguage();
  const { profile, refreshSession, user } = useAuth();
  const isPartner = user?.role === "partner";
  const ar = language === "ar";
  const [formMessage, setFormMessage] = useState("");
  const [formError, setFormError] = useState("");
  const [passwordMessage, setPasswordMessage] = useState("");
  const [passwordError, setPasswordError] = useState("");

  const [phoneDialCode, setPhoneDialCode] = useState(DEFAULT_PHONE_DIAL_CODE);
  const [phoneNumber, setPhoneNumber] = useState("");
  const [parentPhoneDialCode, setParentPhoneDialCode] = useState(DEFAULT_PHONE_DIAL_CODE);
  const [parentPhoneNumber, setParentPhoneNumber] = useState("");
  const [emergencyPhoneDialCode, setEmergencyPhoneDialCode] = useState(DEFAULT_PHONE_DIAL_CODE);
  const [emergencyPhoneNumber, setEmergencyPhoneNumber] = useState("");
  const [phoneChanged, setPhoneChanged] = useState({ phone: false, parent: false, emergency: false });
  const [phoneErrors, setPhoneErrors] = useState({ phone: "", parent: "", emergency: "" });
  const [savedPhones, setSavedPhones] = useState({ phone: "", parent: "", emergency: "" });
  const [initialGrade, setInitialGrade] = useState("");
  const [initialDateOfBirth, setInitialDateOfBirth] = useState("");
  const [countries, setCountries] = useState<Country[]>([]);
  const [countriesError, setCountriesError] = useState("");
  const [targetCountriesError, setTargetCountriesError] = useState("");
  const [targetCountryOptions, setTargetCountryOptions] = useState<Country[]>([]);
  const [targetCountriesLoaded, setTargetCountriesLoaded] = useState(false);
  const [destinationSearch, setDestinationSearch] = useState("");
  const [nationalitySearch, setNationalitySearch] = useState("");
  const [residenceSearch, setResidenceSearch] = useState("");
  const [legacyTargetCountries, setLegacyTargetCountries] = useState<string[]>([]);
  const [savedTargetData, setSavedTargetData] = useState<SavedTargetData | null>(null);
  const targetCountriesInitialized = useRef(false);

  const [passwordForm, setPasswordForm] = useState({
    currentPassword: "",
    newPassword: "",
    confirmPassword: "",
  });
  const {
    register,
    handleSubmit,
    reset,
    setValue,
    watch,
    formState: { isSubmitting, errors },
  } = useForm<ProfileFormValues>({ mode: "onBlur" });
  const dateOfBirthValue = watch("dateOfBirth");
  const currentResidenceCountryCode = watch("currentResidenceCountryCode") || "";
  const currentResidenceRegion = watch("currentResidenceRegion") || "";
  const targetCountryCodes = watch("targetCountryCodes") || [];
  const targetCountryChoices = [...new Map(
    [...targetCountryOptions, ...countries.filter((country) => targetCountryCodes.includes(country.code))]
      .map((country) => [country.code, country] as const),
  ).values()];

  useEffect(() => {
    let active = true;
    contentService.getCountries({ paginate: false })
      .then((result) => {
        const items = Array.isArray(result) ? result : result.items;
        if (active) setCountries(items);
      })
      .catch(() => {
        if (active) setCountriesError(ar ? "تعذر تحميل قائمة الدول. أعد المحاولة لاحقًا." : "Countries could not be loaded. Try again later.");
      });
    return () => { active = false; };
  }, [ar]);

  useEffect(() => {
    let active = true;
    universityService.getAvailableCountries()
      .then((result) => {
        if (active) {
          setTargetCountryOptions(result);
          setTargetCountriesLoaded(true);
        }
      })
      .catch(() => {
        if (active) setTargetCountriesError(ar ? "تعذر تحميل الدول التي تتوفر فيها جامعات." : "Countries with listed universities could not be loaded.");
      });
    return () => { active = false; };
  }, [ar]);

  useEffect(() => {
    if (!countries.length || !savedTargetData || targetCountriesInitialized.current) return;
    const codes = savedTargetData.codes.length
      ? savedTargetData.codes.filter((code) => countries.some((country) => country.code === code))
      : savedTargetData.labels.flatMap((label) => {
          const country = countries.find((item) => item.name === label || item.nameAr === label);
          return country ? [country.code] : [];
        });
    const knownNames = new Set(countries.flatMap((country) => [country.name, country.nameAr].filter((value): value is string => Boolean(value))));
    setLegacyTargetCountries(savedTargetData.labels.filter((label) => !knownNames.has(label)));
    setValue("targetCountryCodes", [...new Set(codes)]);
    targetCountriesInitialized.current = true;
  }, [countries, savedTargetData, setValue]);

  useEffect(() => {
    const loadProfile = isPartner ? partnerService.getProfile : studentService.getProfile;

    loadProfile().then((data) => {
      const { dialCode, phoneNumber: savedPhone } = splitPhoneNumber(data.phone);
      setPhoneDialCode(savedPhone ? dialCode : DEFAULT_PHONE_DIAL_CODE);
      setPhoneNumber(savedPhone);

      const { dialCode: pDial, phoneNumber: pPhone } = splitPhoneNumber(data.parentInfo?.phone);
      setParentPhoneDialCode(pPhone ? pDial : DEFAULT_PHONE_DIAL_CODE);
      setParentPhoneNumber(pPhone);

      const { dialCode: eDial, phoneNumber: ePhone } = splitPhoneNumber(data.emergencyContact?.phone);
      setEmergencyPhoneDialCode(ePhone ? eDial : DEFAULT_PHONE_DIAL_CODE);
      setEmergencyPhoneNumber(ePhone);
      setSavedPhones({
        phone: data.phone || "",
        parent: data.parentInfo?.phone || "",
        emergency: data.emergencyContact?.phone || "",
      });
      setPhoneChanged({ phone: false, parent: false, emergency: false });
      setPhoneErrors({ phone: "", parent: "", emergency: "" });
      const dob = data.dateOfBirth ? new Date(data.dateOfBirth).toISOString().slice(0, 10) : "";
      setInitialDateOfBirth(dob);
      setInitialGrade(data.gpa || "");
      setSavedTargetData({
        codes: data.targetCountryCodes || [],
        labels: data.targetCountries || [],
      });
      targetCountriesInitialized.current = false;

      reset({
        ...data,
        name: data.user?.name || "",
        email: data.user?.email || "",
        englishExam: data.englishTest?.exam || "",
        englishScore: data.englishTest?.score || "",
        otherLanguagesText: data.otherLanguages?.join(", ") || "",
        dateOfBirth: dob,
        companyName: data.companyName || "",
        website: data.website || "",
        location: data.location || "",
        taxId: data.taxId || "",
        englishFullName: data.englishFullName || "",
        passportNumber: data.passportNumber || "",
        currentEducationLevel: data.currentEducationLevel || "",
        currentResidenceCountry: data.currentResidenceCountry || "",
        currentResidenceRegion: data.currentResidenceRegion || "",
        nativeLanguage: data.nativeLanguage || "",
        parentName: data.parentInfo?.name || "",
        parentRelationship: data.parentInfo?.relationship || "",
        emergencyName: data.emergencyContact?.name || "",
        emergencyRelationship: data.emergencyContact?.relationship || "",
      });
    });
  }, [isPartner, reset]);

  const onSubmit = async (values: ProfileFormValues) => {
    setFormError("");
    setFormMessage("");

    const localized = (arabic: string, english: string) => ar ? arabic : english;
    const nextPhoneErrors = {
      phone: phoneChanged.phone && phoneNumber.trim() && !isValidPhoneNumber(phoneDialCode, phoneNumber)
        ? localized("تحقق من رقم الهاتف ورمز الدولة", "Check the phone number and country code") : "",
      parent: phoneChanged.parent && parentPhoneNumber.trim() && !isValidPhoneNumber(parentPhoneDialCode, parentPhoneNumber)
        ? localized("تحقق من رقم هاتف ولي الأمر", "Check the guardian phone number") : "",
      emergency: phoneChanged.emergency && emergencyPhoneNumber.trim() && !isValidPhoneNumber(emergencyPhoneDialCode, emergencyPhoneNumber)
        ? localized("تحقق من رقم هاتف الطوارئ", "Check the emergency phone number") : "",
    };
    setPhoneErrors(nextPhoneErrors);
    if (Object.values(nextPhoneErrors).some(Boolean)) return;
    if (values.dateOfBirth && values.dateOfBirth !== initialDateOfBirth && !isValidPastDateOnly(values.dateOfBirth)) {
      setFormError(localized("أدخل تاريخ ميلاد صحيحًا وغير مستقبلي", "Enter a valid date of birth that is not in the future"));
      return;
    }
    if (values.gpa?.trim() && values.gpa.trim() !== initialGrade && !isValidNonNegativeDecimal(values.gpa)) {
      setFormError(localized("أدخل المعدل كرقم غير سالب", "Enter the grade as a non-negative number"));
      return;
    }

    try {
      const updateProfile = isPartner ? partnerService.updateProfile : studentService.updateProfile;
      const nextPhones = {
        phone: phoneChanged.phone ? buildPhoneNumber(phoneDialCode, phoneNumber) : savedPhones.phone,
        parent: phoneChanged.parent ? buildPhoneNumber(parentPhoneDialCode, parentPhoneNumber) : savedPhones.parent,
        emergency: phoneChanged.emergency ? buildPhoneNumber(emergencyPhoneDialCode, emergencyPhoneNumber) : savedPhones.emergency,
      };

      await updateProfile({
        name: values.name,
        email: values.email,
        phone: nextPhones.phone,
        dateOfBirth: values.dateOfBirth,
        nationality: values.nationality,
        ...(isPartner ? {} : { nationalityCountryCode: values.nationalityCountryCode || "" }),
        address: values.address,
        bio: values.bio,
        ...(isPartner
          ? {}
          : {
              currentEducation: values.currentEducation,
              gpa: values.gpa,
              intake: values.intake,
              ...(targetCountriesLoaded ? {
                targetCountryCodes,
                targetCountries: [
                  ...targetCountryCodes
                    .map((code) => targetCountryChoices.find((country) => country.code === code)?.name)
                    .filter((name): name is string => Boolean(name)),
                  ...legacyTargetCountries,
                ],
              } : {}),
              englishTest: {
                exam: values.englishExam,
                score: values.englishScore,
              },
              englishFullName: values.englishFullName,
              passportNumber: values.passportNumber,
              currentEducationLevel: values.currentEducationLevel,
              currentResidenceCountry: values.currentResidenceCountry,
              currentResidenceCountryCode: values.currentResidenceCountryCode || "",
              currentResidenceRegion: values.currentResidenceRegion,
              nativeLanguage: values.nativeLanguage,
              otherLanguages: values.otherLanguagesText
                ?.split(",")
                .map((item) => item.trim())
                .filter(Boolean),
              parentInfo: {
                name: values.parentName,
                phone: nextPhones.parent,
                relationship: values.parentRelationship,
              },
              emergencyContact: {
                name: values.emergencyName,
                phone: nextPhones.emergency,
                relationship: values.emergencyRelationship,
              },
            }),
        ...(isPartner
          ? {
              companyName: values.companyName,
              website: values.website,
              location: values.location,
              taxId: values.taxId,
            }
          : {}),
      } as Partial<StudentProfile> & { name: string; email: string });

      await refreshSession();
      setSavedPhones(nextPhones);
      setPhoneChanged({ phone: false, parent: false, emergency: false });
      setFormMessage(dt(language, "profileSaved"));
    } catch (error) {
      setFormError(getErrorMessage(error, dt(language, "profileSaveFailed")));
    }
  };

  const handlePasswordSubmit = async (event: FormEvent) => {
    event.preventDefault();
    setPasswordError("");
    setPasswordMessage("");

    if (passwordForm.newPassword !== passwordForm.confirmPassword) {
      setPasswordError(dt(language, "passwordMismatch"));
      return;
    }

    try {
      await authService.changePassword({
        currentPassword: passwordForm.currentPassword,
        newPassword: passwordForm.newPassword,
      });
      setPasswordMessage(dt(language, "passwordUpdated"));
      setPasswordForm({ currentPassword: "", newPassword: "", confirmPassword: "" });
    } catch (error) {
      setPasswordError(getErrorMessage(error, dt(language, "profileSaveFailed")));
    }
  };

  const initials = user?.name
    ?.split(" ")
    .map((part) => part[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();
  const accountTypeLabel =
    user?.role === "partner" ? t("partner") : user?.role === "admin" ? t("admin") : t("student");

  return (
    <div className="grid gap-6 xl:grid-cols-[340px_1fr]">
      <aside className="space-y-6">
        <section className="panel p-8">
          <div className="flex h-24 w-24 items-center justify-center rounded-full bg-brand-900 text-2xl font-semibold text-white">
            {initials || "SB"}
          </div>
          <h1 className="mt-5 text-3xl font-semibold text-slate-900">{dt(language, "profilePageTitle")}</h1>
          <p className="mt-3 text-sm leading-6 text-slate-500">
            {isPartner
              ? dt(language, "profilePageSubtitle")
              : ar
                ? "مرحباً بك في لوحة تحكم COVEY، تتبع حالة قبولك الجامعي، أدر مستنداتك، وابدأ رحلتك التعليمية معنا."
                : "Welcome to the COVEY dashboard. Track your admission progress, manage your documents, and continue your study journey with us."}
          </p>
          <div className="mt-6 space-y-3 rounded-3xl bg-slate-50 p-5">
            <p className="text-sm text-slate-500">{dt(language, "profileNote")}</p>
            <div className="rounded-2xl bg-white px-4 py-3 text-sm text-slate-700">
              <span className="font-semibold">{t("email")}:</span> {user?.email || profile?.user?.email}
            </div>
            <div className="rounded-2xl bg-white px-4 py-3 text-sm text-slate-700">
              <span className="font-semibold">{t("role")}:</span> {accountTypeLabel}
            </div>
            {isPartner ? (
              <div className="rounded-2xl bg-white px-4 py-3 text-sm text-slate-700">
                <span className="font-semibold">{ar ? "حالة التوثيق" : "Verification status"}:</span>{" "}
                {profile?.verificationStatus || "pending"}
              </div>
            ) : null}
            {!isPartner ? (
              <div className="rounded-2xl bg-white px-4 py-3 text-sm text-slate-700">
                <span className="font-semibold">{t("studentProfile")}:</span> {profile?.currentEducation || dt(language, "notAvailable")}
              </div>
            ) : null}
          </div>
        </section>
      </aside>

      <div className="space-y-6">
        <section className="panel p-8">
          {formMessage ? <div className="mb-5 rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{formMessage}</div> : null}
          {formError ? <div className="mb-5 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{formError}</div> : null}

          <form onSubmit={handleSubmit(onSubmit)} className="grid gap-8">
            {/* Personal Details */}
            <div>
              <h2 className="text-2xl font-semibold text-slate-900">{dt(language, "personalDetails")}</h2>
              <div className="mt-5 grid gap-5 md:grid-cols-2">
                <FormInput
                  label={dt(language, "fullName")}
                  required
                  error={errors.name?.message}
                  {...register("name", { validate: value => !!value?.trim() || (ar ? "أدخل الاسم" : "Enter a name") })}
                />
                <FormInput label={t("email")} type="email" readOnly {...register("email")} />
                {!isPartner ? <FormInput label={ar ? "الاسم باللغة الإنجليزية كما في جواز السفر" : "English Full Name (as in passport)"} {...register("englishFullName", { required: !isPartner })} /> : null}
                {!isPartner ? <FormInput label={ar ? "رقم جواز السفر أو الهوية" : "Passport / ID Number"} {...register("passportNumber")} /> : null}
                <PhoneNumberField
                  label={t("phone")}
                  dialCode={phoneDialCode}
                  phoneNumber={phoneNumber}
                  error={phoneErrors.phone}
                  onDialCodeChange={(value) => { setPhoneDialCode(value); setPhoneChanged(current => ({ ...current, phone: true })); setPhoneErrors(current => ({ ...current, phone: "" })); }}
                  onPhoneNumberChange={(value) => { setPhoneNumber(value); setPhoneChanged(current => ({ ...current, phone: true })); setPhoneErrors(current => ({ ...current, phone: "" })); }}
                />
                <input type="hidden" {...register("dateOfBirth")} />
                <DateOfBirthField
                  label={dt(language, "dateOfBirth")}
                  language={language}
                  value={dateOfBirthValue}
                  onChange={(value) => setValue("dateOfBirth", value, { shouldDirty: true })}
                />
                {!isPartner ? (
                  <label className="block">
                    <span className="mb-2 block text-sm font-medium text-slate-700">{t("nationality")}</span>
                    <input
                      type="search"
                      value={nationalitySearch}
                      onChange={(event) => setNationalitySearch(event.target.value)}
                      aria-label={ar ? "ابحث عن الجنسية" : "Search nationality"}
                      placeholder={ar ? "ابحث عن دولة" : "Search countries"}
                      className="mb-2 w-full rounded-xl border border-slate-200 px-3 py-2 outline-none focus:ring"
                    />
                    <select
                      {...register("nationalityCountryCode", {
                        onChange: (event) => {
                          const selected = countries.find((country) => country.code === event.target.value);
                          setValue("nationality", selected ? ar ? selected.nameAr || selected.name : selected.name : "", { shouldDirty: true });
                        },
                      })}
                      disabled={!countries.length}
                      className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none ring-brand-300 focus:ring"
                    >
                      <option value="">{countriesError || (watch("nationality")
                        ? `${ar ? "الجنسية المحفوظة" : "Saved nationality"}: ${watch("nationality")} (${ar ? "غير موجودة في القائمة" : "not in catalog"})`
                        : ar ? "اختر الجنسية من القائمة" : "Select a nationality")}</option>
                      {countries
                        .filter((country) => `${country.name} ${country.nameAr || ""}`.toLocaleLowerCase().includes(nationalitySearch.toLocaleLowerCase()) || country.code === watch("nationalityCountryCode"))
                        .map((country) => <option key={country._id} value={country.code}>{ar ? country.nameAr || country.name : country.name}</option>)}
                    </select>
                    {countriesError ? <span role="alert" className="mt-1 block text-sm text-rose-700">{countriesError}</span> : null}
                  </label>
                ) : <FormInput label={t("nationality")} {...register("nationality")} />}
                <FormInput label={t("address")} {...register("address")} />
                <label className="block md:col-span-2">
                  <span className="mb-2 block text-sm font-medium text-slate-700">{dt(language, "bio")}</span>
                  <textarea {...register("bio")} rows={4} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none ring-brand-300 focus:ring" />
                </label>
              </div>
            </div>

            {isPartner ? (
              <div>
                <h2 className="text-2xl font-semibold text-slate-900">{ar ? "بيانات الشركة أو المكتب" : "Company Details"}</h2>
                <div className="mt-5 grid gap-5 md:grid-cols-2">
                  <FormInput label={ar ? "اسم الشركة أو المكتب" : "Company Name"} {...register("companyName")} />
                  <FormInput label={ar ? "الموقع الإلكتروني" : "Website"} {...register("website")} />
                  <FormInput label={ar ? "المدينة أو مقر العمل" : "Location / City"} {...register("location")} />
                  <FormInput label={ar ? "الرقم الضريبي أو السجل التجاري" : "Tax / Commercial ID"} {...register("taxId")} />
                </div>
                {profile?.verificationReason ? (
                  <div className="mt-5 rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
                    {profile.verificationReason}
                  </div>
                ) : null}
              </div>
            ) : null}

            {!isPartner ? (
              <>
                {/* Academic Details */}
                <div>
                  <h2 className="text-2xl font-semibold text-slate-900">{dt(language, "academicDetails")}</h2>
                  <div className="mt-5 grid gap-5 md:grid-cols-2">
                    <FormInput label={t("currentEducation")} {...register("currentEducation")} />
                    <label>
                      <span className="mb-2 block text-sm font-medium text-slate-700">{ar ? "المرحلة الدراسية الحالية" : "Current Education Level"}</span>
                      <select {...register("currentEducationLevel")} className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none ring-brand-300 focus:ring">
                        <option value="">{ar ? "اختر المرحلة" : "Select level"}</option>
                        <option value="high-school">{ar ? "ثانوية عامة" : "High School"}</option>
                        <option value="bachelor">{ar ? "بكالوريوس" : "Bachelor"}</option>
                        <option value="master">{ar ? "ماستر" : "Master"}</option>
                        <option value="phd">{ar ? "دكتوراه" : "PhD"}</option>
                      </select>
                    </label>
                    <label className="block">
                      <span className="mb-2 block text-sm font-medium text-slate-700">{ar ? "البلد المقيم فيه حاليًا" : "Current Country of Residence"}</span>
                      <input
                        type="search"
                        value={residenceSearch}
                        onChange={(event) => setResidenceSearch(event.target.value)}
                        aria-label={ar ? "ابحث عن بلد الإقامة" : "Search residence countries"}
                        placeholder={ar ? "ابحث عن دولة" : "Search countries"}
                        className="mb-2 w-full rounded-xl border border-slate-200 px-3 py-2 outline-none focus:ring"
                      />
                      <select
                        {...register("currentResidenceCountryCode", {
                          onChange: (event) => {
                            const nextCode = event.target.value;
                            if (currentResidenceRegion.trim() && nextCode !== currentResidenceCountryCode) {
                              const confirmed = window.confirm(ar
                                ? "تغيير بلد الإقامة سيمسح المنطقة المرتبطة به. هل تريد المتابعة؟"
                                : "Changing the residence country will clear the associated region. Continue?");
                              if (!confirmed) {
                                setValue("currentResidenceCountryCode", currentResidenceCountryCode);
                                return;
                              }
                              setValue("currentResidenceRegion", "", { shouldDirty: true });
                            }
                            const selected = countries.find((country) => country.code === nextCode);
                            setValue("currentResidenceCountry", selected ? ar ? selected.nameAr || selected.name : selected.name : "", { shouldDirty: true });
                          },
                        })}
                        disabled={!countries.length}
                        className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none ring-brand-300 focus:ring"
                      >
                        <option value="">
                          {countriesError || (watch("currentResidenceCountry")
                            ? `${ar ? "الدولة المحفوظة" : "Saved country"}: ${watch("currentResidenceCountry")} (${ar ? "غير موجودة في القائمة" : "not in catalog"})`
                            : ar ? "اختر دولة الإقامة" : "Select a residence country")}
                        </option>
                        {countries
                          .filter((country) => `${country.name} ${country.nameAr || ""}`.toLocaleLowerCase().includes(residenceSearch.toLocaleLowerCase()) || country.code === currentResidenceCountryCode)
                          .map((country) => <option key={country._id} value={country.code}>{ar ? country.nameAr || country.name : country.name}</option>)}
                      </select>
                      {countriesError ? <span role="alert" className="mt-1 block text-sm text-rose-700">{countriesError}</span> : null}
                    </label>
                    <FormInput label={ar ? "المنطقة / المحافظة" : "Region / Province"} {...register("currentResidenceRegion")} />
                    <FormInput label={ar ? "اللغة الأم" : "Native Language"} {...register("nativeLanguage")} />
                    <FormInput
                      label={ar ? "لغات أخرى (مفصولة بفاصلة)" : "Other Languages (comma-separated)"}
                      {...register("otherLanguagesText")}
                      placeholder={ar ? "مثال: الإنجليزية، الفرنسية" : "e.g. English, French"}
                    />
                    <FormInput
                      label={t("gpa")}
                      type="text"
                      inputMode="decimal"
                      error={errors.gpa?.message}
                      {...register("gpa", { validate: value => !value?.trim() || value.trim() === initialGrade || isValidNonNegativeDecimal(value) || (ar ? "أدخل المعدل كرقم غير سالب" : "Enter the grade as a non-negative number") })}
                    />
                    <FormInput label={t("preferredIntake")} {...register("intake")} />
                    <fieldset className="rounded-2xl border border-slate-200 p-4">
                      <legend className="px-1 text-sm font-medium text-slate-700">{dt(language, "targetCountries")}</legend>
                      <input
                        type="search"
                        value={destinationSearch}
                        onChange={(event) => setDestinationSearch(event.target.value)}
                        disabled={!countries.length}
                        aria-label={ar ? "ابحث في الدول المتاحة" : "Search available countries"}
                        placeholder={ar ? "ابحث عن دولة" : "Search countries"}
                        className="mb-3 w-full rounded-xl border border-slate-200 px-3 py-2 outline-none focus:ring"
                      />
                      <div className="max-h-64 space-y-2 overflow-y-auto">
                        {targetCountryChoices
                          .filter((country) => `${country.name} ${country.nameAr || ""}`.toLocaleLowerCase().includes(destinationSearch.toLocaleLowerCase()))
                          .map((country) => (
                            <label key={country._id} className="flex items-center gap-3 text-sm text-slate-700">
                              <input
                                type="checkbox"
                                checked={targetCountryCodes.includes(country.code)}
                                disabled={!countries.length}
                                onChange={(event) => {
                                  const nextCodes = event.target.checked
                                    ? [...new Set([...targetCountryCodes, country.code])]
                                    : targetCountryCodes.filter((code) => code !== country.code);
                                  setValue("targetCountryCodes", nextCodes, { shouldDirty: true });
                                }}
                              />
                              <span>{ar ? country.nameAr || country.name : country.name}{!targetCountryOptions.some((option) => option.code === country.code) ? ` (${ar ? "غير متاحة حاليًا" : "currently unavailable"})` : ""}</span>
                            </label>
                          ))}
                        {!targetCountryOptions.length ? <p role="status" className="text-sm text-slate-500">{targetCountriesError || (targetCountriesLoaded
                          ? ar ? "لا توجد دول فيها جامعات مدرجة حاليًا." : "No countries with listed universities are available."
                          : ar ? "جارٍ تحميل الدول المتاحة..." : "Loading available countries...")}</p> : null}
                      </div>
                      {legacyTargetCountries.map((country) => <p key={country} className="mt-3 text-xs text-amber-700">{ar ? `قيمة محفوظة غير موجودة في القائمة: ${country}` : `Saved value outside the current catalog: ${country}`}</p>)}
                      {targetCountriesError ? <p role="alert" className="mt-2 text-sm text-rose-700">{targetCountriesError}</p> : null}
                      {countriesError ? <p role="alert" className="mt-2 text-sm text-rose-700">{countriesError}</p> : null}
                    </fieldset>
                    <FormInput label={dt(language, "englishExam")} {...register("englishExam")} />
                    <FormInput label={dt(language, "englishScore")} {...register("englishScore")} />
                  </div>
                </div>

                {/* Parent Info */}
                <div>
                  <h2 className="text-2xl font-semibold text-slate-900">{ar ? "معلومات ولي الأمر" : "Parent / Guardian Info"}</h2>
                  <div className="mt-5 grid gap-5 md:grid-cols-2">
                    <FormInput label={ar ? "الاسم الكامل" : "Full Name"} {...register("parentName")} />
                    <FormInput label={ar ? "صلة القرابة" : "Relationship"} {...register("parentRelationship")} placeholder={ar ? "مثال: أب، أم، أخ" : "e.g. Father, Mother"} />
                    <PhoneNumberField
                      label={ar ? "رقم الهاتف" : "Phone Number"}
                      dialCode={parentPhoneDialCode}
                      phoneNumber={parentPhoneNumber}
                      error={phoneErrors.parent}
                      onDialCodeChange={(value) => { setParentPhoneDialCode(value); setPhoneChanged(current => ({ ...current, parent: true })); setPhoneErrors(current => ({ ...current, parent: "" })); }}
                      onPhoneNumberChange={(value) => { setParentPhoneNumber(value); setPhoneChanged(current => ({ ...current, parent: true })); setPhoneErrors(current => ({ ...current, parent: "" })); }}
                    />
                  </div>
                </div>

                {/* Emergency Contact */}
                <div>
                  <h2 className="text-2xl font-semibold text-slate-900">{ar ? "جهة الاتصال في حالات الطوارئ" : "Emergency Contact"}</h2>
                  <div className="mt-5 grid gap-5 md:grid-cols-2">
                    <FormInput label={ar ? "الاسم الكامل" : "Full Name"} {...register("emergencyName")} />
                    <FormInput label={ar ? "صلة القرابة" : "Relationship"} {...register("emergencyRelationship")} placeholder={ar ? "مثال: أخ، عم، صديق" : "e.g. Brother, Uncle, Friend"} />
                    <PhoneNumberField
                      label={ar ? "رقم الهاتف" : "Phone Number"}
                      dialCode={emergencyPhoneDialCode}
                      phoneNumber={emergencyPhoneNumber}
                      error={phoneErrors.emergency}
                      onDialCodeChange={(value) => { setEmergencyPhoneDialCode(value); setPhoneChanged(current => ({ ...current, emergency: true })); setPhoneErrors(current => ({ ...current, emergency: "" })); }}
                      onPhoneNumberChange={(value) => { setEmergencyPhoneNumber(value); setPhoneChanged(current => ({ ...current, emergency: true })); setPhoneErrors(current => ({ ...current, emergency: "" })); }}
                    />
                  </div>
                </div>
              </>
            ) : null}

            <button type="submit" disabled={isSubmitting} className="w-fit rounded-full bg-brand-900 px-6 py-3 font-semibold text-white">
              {isSubmitting ? dt(language, "saving") : dt(language, "saveChanges")}
            </button>
          </form>
        </section>

        <section className="panel p-8">
          <h2 className="text-2xl font-semibold text-slate-900">{dt(language, "accountActions")}</h2>
          <p className="mt-2 text-sm text-slate-500">{dt(language, "passwordHelp")}</p>
          {passwordMessage ? <div className="mt-5 rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{passwordMessage}</div> : null}
          {passwordError ? <div className="mt-5 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{passwordError}</div> : null}
          <form onSubmit={handlePasswordSubmit} className="mt-5 grid gap-5 md:grid-cols-3">
            <FormInput
              label={dt(language, "currentPassword")}
              type="password"
              value={passwordForm.currentPassword}
              onChange={(event) => setPasswordForm((current) => ({ ...current, currentPassword: event.target.value }))}
            />
            <FormInput
              label={dt(language, "newPassword")}
              type="password"
              value={passwordForm.newPassword}
              onChange={(event) => setPasswordForm((current) => ({ ...current, newPassword: event.target.value }))}
            />
            <FormInput
              label={dt(language, "confirmNewPassword")}
              type="password"
              value={passwordForm.confirmPassword}
              onChange={(event) => setPasswordForm((current) => ({ ...current, confirmPassword: event.target.value }))}
            />
            <button type="submit" className="w-fit rounded-full bg-slate-950 px-6 py-3 font-semibold text-white md:col-span-3">
              {dt(language, "updatePassword")}
            </button>
          </form>
        </section>
      </div>
    </div>
  );
};
