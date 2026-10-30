import { forwardRef, useId, type InputHTMLAttributes } from "react";

interface FormInputProps extends InputHTMLAttributes<HTMLInputElement> {
  label: string;
  error?: string;
}

export const FormInput = forwardRef<HTMLInputElement, FormInputProps>(function FormInput(
  { label, error, className, required, ...props },
  ref,
) {
  const generatedId = useId();
  const inputId = props.id ?? generatedId;
  const errorId = `${inputId}-error`;
  return (
    <label className="block" htmlFor={inputId}>
      <span className="mb-2 block text-sm font-medium text-slate-700">
        {label}{required ? <span aria-hidden="true"> *</span> : null}
      </span>
      <input
        ref={ref}
        {...props}
        id={inputId}
        required={required}
        aria-required={required || undefined}
        aria-invalid={error ? "true" : "false"}
        aria-describedby={error ? errorId : props["aria-describedby"]}
        className={[
          "w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none ring-brand-300 focus:ring",
          error ? "border-rose-300 ring-rose-200" : "",
          className ?? "",
        ]
          .filter(Boolean)
          .join(" ")}
      />
      {error ? <span id={errorId} role="alert" className="mt-2 block text-sm text-rose-600">{error}</span> : null}
    </label>
  );
});

FormInput.displayName = "FormInput";
