import { useMemo } from "react";

const COMMON = /^(password|qwerty|welcome|letmein|admin|studybirds|abcdefgh|12345678|87654321)\d*$/i;

function kinds(v: string) {
  let k = 0;
  if (/[A-Z]/.test(v)) k++;
  if (/[a-z؀-ۿ]/.test(v)) k++;
  if (/[0-9]/.test(v)) k++;
  if (/[^a-zA-Z0-9؀-ۿ\s]/.test(v)) k++;
  return k;
}

export function passwordError(v: string): string | null {
  if (!v) return null;
  if (v.length < 8) return null;
  if (COMMON.test(v.replace(/[^a-zA-Z0-9]/g, ""))) return "هذه الكلمة سهلة التخمين.";
  if (new Set(v).size < 4) return "اختر كلمة أقل تكراراً.";
  if (kinds(v) < 3) return "اخلط 3 أنواع: أحرف كبيرة، صغيرة أو عربية، أرقام، رموز.";
  return null;
}

export function validatePassword(v: string): string | null {
  if (!v) return "أدخل كلمة المرور";
  if (v.length < 8) return "استخدم 8 أحرف على الأقل";
  if (new TextEncoder().encode(v).length > 72) return "كلمة المرور طويلة جدًا.";
  return passwordError(v);
}

type Strength = "weak" | "medium" | "strong";

function getStrength(v: string): Strength {
  if (!v || v.length < 8) return "weak";
  if (COMMON.test(v.replace(/[^a-zA-Z0-9]/g, "")) || new Set(v).size < 4) return "weak";
  const k = kinds(v);
  if (k >= 3 && v.length >= 10) return "strong";
  if (k >= 2) return "medium";
  return "weak";
}

export const PasswordStrengthBar = ({ value, language = "ar" }: { value: string; language?: string }) => {
  const ar = language === "ar";
  const strength = useMemo(() => getStrength(value), [value]);
  if (!value) return null;
  const segments: ("active" | "inactive")[] = [
    "active",
    strength === "medium" || strength === "strong" ? "active" : "inactive",
    strength === "strong" ? "active" : "inactive",
  ];
  const color = strength === "strong" ? "bg-emerald-500" : strength === "medium" ? "bg-amber-400" : "bg-rose-500";
  const label = strength === "strong"
    ? (ar ? "قوية" : "Strong")
    : strength === "medium"
    ? (ar ? "متوسطة" : "Medium")
    : (ar ? "ضعيفة" : "Weak");
  const hint = passwordError(value);
  return (
    <div className="mt-2 space-y-1.5">
      <div className="flex gap-1">
        {segments.map((s, i) => (
          <div key={i} className={`h-1.5 flex-1 rounded-full transition-colors ${s === "active" ? color : "bg-slate-200"}`} />
        ))}
      </div>
      <p className={`text-xs font-medium ${strength === "strong" ? "text-emerald-600" : strength === "medium" ? "text-amber-600" : "text-rose-600"}`}>
        {label}{hint ? ` — ${hint}` : ""}
      </p>
    </div>
  );
};
