export const PROGRAM_DEGREE_LEVELS = [
  { value: "Technical Institute", translationKey: "degreeTechnicalInstitute" },
  { value: "Bachelor", translationKey: "degreeBachelor" },
  { value: "Postgraduate Diploma", translationKey: "degreePostgraduateDiploma" },
  { value: "Non-Thesis Master", translationKey: "degreeNonThesisMaster" },
  { value: "Thesis Master", translationKey: "degreeThesisMaster" },
  { value: "Professional Doctorate", translationKey: "degreeProfessionalDoctorate" },
  { value: "PhD", translationKey: "degreePhD" },
  { value: "Postdoctoral", translationKey: "degreePostdoctoral" },
] as const;

// Keep existing programs searchable without offering these generic values for new programs.
export const LEGACY_PROGRAM_DEGREE_LEVELS = [
  { value: "Master", translationKey: "degreeMaster" },
  { value: "Diploma", translationKey: "degreeDiploma" },
] as const;

export const PROGRAM_LANGUAGES = [
  { value: "Arabic", ar: "العربية", en: "Arabic" },
  { value: "Turkish", ar: "التركية", en: "Turkish" },
  { value: "30% English + 70% Turkish", ar: "30% إنجليزي + 70% تركي", en: "30% English + 70% Turkish" },
  { value: "30% Turkish + 70% English", ar: "30% تركي + 70% إنجليزي", en: "30% Turkish + 70% English" },
  { value: "Russian", ar: "الروسية", en: "Russian" },
  { value: "Uzbek", ar: "الأوزبكية", en: "Uzbek" },
  { value: "English", ar: "الإنجليزية", en: "English" },
  { value: "German", ar: "الألمانية", en: "German" },
  { value: "Italian", ar: "الإيطالية", en: "Italian" },
  { value: "Polish", ar: "البولندية", en: "Polish" },
  { value: "Dutch", ar: "الهولندية", en: "Dutch" },
  { value: "French", ar: "الفرنسية", en: "French" },
  { value: "Spanish", ar: "الإسبانية", en: "Spanish" },
  { value: "Portuguese", ar: "البرتغالية", en: "Portuguese" },
  { value: "Hungarian", ar: "المجرية", en: "Hungarian" },
  { value: "Czech", ar: "التشيكية", en: "Czech" },
  { value: "Romanian", ar: "الرومانية", en: "Romanian" },
  { value: "Chinese", ar: "الصينية", en: "Chinese" },
  { value: "Korean", ar: "الكورية", en: "Korean" },
  { value: "Japanese", ar: "اليابانية", en: "Japanese" },
] as const;

export const findProgramLanguage = (value: string) => PROGRAM_LANGUAGES.find(
  (option) => option.value.toLowerCase() === value.trim().toLowerCase() || option.ar === value.trim(),
);

export const PROGRAM_FIELDS_OF_STUDY = [
  { value: "Technology", translationKey: "fieldTechnology" },
  { value: "Business", translationKey: "fieldBusiness" },
  { value: "Engineering", translationKey: "fieldEngineering" },
  { value: "Social Sciences", translationKey: "fieldSocialSciences" },
] as const;

export const PROGRAM_INTAKES = [
  { value: "Fall 2026", translationKey: "intakeFall2026" },
  { value: "Spring 2027", translationKey: "intakeSpring2027" },
] as const;
