import { describe, expect, it } from "vitest";
import { daysInMonth, isValidEmail, isValidNonNegativeDecimal, isValidPastDateOnly, isValidPhoneNumber } from "./formValidation";

describe("form input validation", () => {
  it("accepts international email text and rejects malformed addresses", () => {
    expect(isValidEmail(" learner@example.test ")).toBe(true);
    expect(isValidEmail("élève@例え.テスト")).toBe(true);
    expect(isValidEmail("person@" )).toBe(false);
    expect(isValidEmail("person @example.test")).toBe(false);
  });

  it("validates phone numbers using a global digit range without a national fixed length", () => {
    expect(isValidPhoneNumber("+90", "٥٥٥١٢٣٤٥٦٧")).toBe(true);
    expect(isValidPhoneNumber("+1", "202-555-0100")).toBe(true);
    expect(isValidPhoneNumber("+90", "123")).toBe(false);
    expect(isValidPhoneNumber("+90", "555CALL")).toBe(false);
  });

  it("checks non-negative decimal values without imposing a GPA maximum", () => {
    expect(isValidNonNegativeDecimal("3.7")).toBe(true);
    expect(isValidNonNegativeDecimal("85")).toBe(true);
    expect(isValidNonNegativeDecimal("١٢٫٥")).toBe(true);
    expect(isValidNonNegativeDecimal("-1")).toBe(false);
    expect(isValidNonNegativeDecimal("3.2.1")).toBe(false);
  });

  it("validates actual calendar days and rejects future dates", () => {
    expect(daysInMonth(2024, 2)).toBe(29);
    expect(daysInMonth(2025, 2)).toBe(28);
    const today = new Date(2026, 9, 23);
    expect(isValidPastDateOnly("2024-02-29", today)).toBe(true);
    expect(isValidPastDateOnly("2025-02-29", today)).toBe(false);
    expect(isValidPastDateOnly("2026-10-24", today)).toBe(false);
  });
});
