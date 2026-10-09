import { useEffect, useState, type FormEvent } from "react";
import { useForm } from "react-hook-form";
import { DateOfBirthField } from "../../components/forms/DateOfBirthField";
import { FormInput } from "../../components/forms/FormInput";
import { PhoneNumberField } from "../../components/forms/PhoneNumberField";
import { useAuth } from "../../hooks/useAuth";
import { useLanguage } from "../../hooks/useLanguage";
import { authService } from "../../services/authService";
import { partnerService } from "../../services/partnerService";
import { studentService } from "../../services/studentService";
import type { StudentProfile } from "../../types";
import { dt } from "../../utils/dashboardTranslations";
import { getErrorMessage } from "../../utils/errors";
import { buildPhoneNumber, DEFAULT_PHONE_DIAL_CODE, splitPhoneNumber } from "../../utils/phoneCountryOptions";

type ProfileFormValues = StudentProfile & {
  name: string;
  email: string;
  englishExam?: string;
  englishScore?: string;
  targetCountriesText?: string;
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
    formState: { isSubmitting },
  } = useForm<ProfileFormValues>();
  const dateOfBirthValue = watch("dateOfBirth");

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

      reset({
        ...data,
        name: data.user?.name || "",
        email: data.user?.email || "",
        englishExam: data.englishTest?.exam || "",
        englishScore: data.englishTest?.score || "",
        targetCountriesText: data.targetCountries?.join(", ") || "",
        otherLanguagesText: data.otherLanguages?.join(", ") || "",
        dateOfBirth: data.dateOfBirth ? new Date(data.dateOfBirth).toISOString().slice(0, 10) : "",
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

    try {
      const updateProfile = isPartner ? partnerService.updateProfile : studentService.updateProfile;

      await updateProfile({
        name: values.name,
        email: values.email,
        phone: buildPhoneNumber(phoneDialCode, phoneNumber),
        dateOfBirth: values.dateOfBirth,
        nationality: values.nationality,
        address: values.address,
        bio: values.bio,
        ...(isPartner
          ? {}
          : {
              currentEducation: values.currentEducation,
              gpa: values.gpa,
              intake: values.intake,
              targetCountries: values.targetCountriesText
                ?.split(",")
                .map((item) => item.trim())
                .filter(Boolean),
              englishTest: {
                exam: values.englishExam,
                score: values.englishScore,
              },
              englishFullName: values.englishFullName,
              passportNumber: values.passportNumber,
              currentEducationLevel: values.currentEducationLevel,
              currentResidenceCountry: values.currentResidenceCountry,
              currentResidenceRegion: values.currentResidenceRegion,
              nativeLanguage: values.nativeLanguage,
              otherLanguages: values.otherLanguagesText
                ?.split(",")
                .map((item) => item.trim())
                .filter(Boolean),
              parentInfo: {
                name: values.parentName,
                phone: buildPhoneNumber(parentPhoneDialCode, parentPhoneNumber),
                relationship: values.parentRelationship,
              },
              emergencyContact: {
                name: values.emergencyName,
                phone: buildPhoneNumber(emergencyPhoneDialCode, emergencyPhoneNumber),
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
                ? "مرحباً بك في لوحة تحكم Study Birds، تتبع حالة قبولك الجامعي، أدر مستنداتك، وابدأ رحلتك التعليمية معنا."
                : "Welcome to the Study Birds dashboard. Track your admission progress, manage your documents, and continue your study journey with us."}
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
                <FormInput label={dt(language, "fullName")} {...register("name")} />
                <FormInput label={t("email")} type="email" {...register("email")} />
                {!isPartner ? <FormInput label={ar ? "الاسم باللغة الإنجليزية كما في جواز السفر" : "English Full Name (as in passport)"} {...register("englishFullName", { required: !isPartner })} /> : null}
                {!isPartner ? <FormInput label={ar ? "رقم جواز السفر أو الهوية" : "Passport / ID Number"} {...register("passportNumber")} /> : null}
                <PhoneNumberField
                  label={t("phone")}
                  dialCode={phoneDialCode}
                  phoneNumber={phoneNumber}
                  onDialCodeChange={setPhoneDialCode}
                  onPhoneNumberChange={setPhoneNumber}
                />
                <input type="hidden" {...register("dateOfBirth")} />
                <DateOfBirthField
                  label={dt(language, "dateOfBirth")}
                  language={language}
                  value={dateOfBirthValue}
                  onChange={(value) => setValue("dateOfBirth", value, { shouldDirty: true })}
                />
                <FormInput label={t("nationality")} {...register("nationality")} />
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
                    <FormInput label={ar ? "البلد المقيم فيه حالياً" : "Current Country of Residence"} {...register("currentResidenceCountry")} />
                    <FormInput label={ar ? "المنطقة / المحافظة" : "Region / Province"} {...register("currentResidenceRegion")} />
                    <FormInput label={ar ? "اللغة الأم" : "Native Language"} {...register("nativeLanguage")} />
                    <FormInput
                      label={ar ? "لغات أخرى (مفصولة بفاصلة)" : "Other Languages (comma-separated)"}
                      {...register("otherLanguagesText")}
                      placeholder={ar ? "مثال: الإنجليزية، الفرنسية" : "e.g. English, French"}
                    />
                    <FormInput label={t("gpa")} type="number" inputMode="decimal" step="0.01" min="0" max="4" {...register("gpa")} />
                    <FormInput label={t("preferredIntake")} {...register("intake")} />
                    <FormInput label={dt(language, "targetCountries")} {...register("targetCountriesText")} placeholder="Turkey, Canada, Germany" />
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
                      onDialCodeChange={setParentPhoneDialCode}
                      onPhoneNumberChange={setParentPhoneNumber}
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
                      onDialCodeChange={setEmergencyPhoneDialCode}
                      onPhoneNumberChange={setEmergencyPhoneNumber}
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
