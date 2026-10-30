import { act, useState } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, expect, it } from "vitest";
import { DateOfBirthField } from "./DateOfBirthField";

let host: HTMLDivElement;
let root: Root;
beforeEach(() => {
  (globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
  host = document.createElement("div");
  document.body.append(host);
  root = createRoot(host);
});
afterEach(() => { act(() => root.unmount()); host.remove(); });

function Harness({ initial = "" }: { initial?: string }) {
  const [value, setValue] = useState(initial);
  return <>
    <DateOfBirthField label="Date of birth" language="en" value={value} onChange={setValue} />
    <output>{value}</output>
  </>;
}

function select(label: string, value: string) {
  const field = host.querySelector<HTMLSelectElement>(`select[aria-label="${label}"]`)!;
  act(() => {
    field.value = value;
    field.dispatchEvent(new Event("change", { bubbles: true }));
  });
}

it("keeps partial selections while choosing year, month, and day", () => {
  act(() => root.render(<Harness />));
  select("Year", "2024");
  select("Month", "02");
  select("Day", "29");
  expect(host.querySelector("output")?.textContent).toBe("2024-02-29");
});

it("does not offer impossible leap days or future calendar dates", () => {
  act(() => root.render(<Harness />));
  select("Year", "2025");
  select("Month", "02");
  expect([...host.querySelector<HTMLSelectElement>('select[aria-label="Day"]')!.options].map(option => option.value)).not.toContain("29");

  const currentYear = new Date().getFullYear();
  act(() => root.unmount());
  root = createRoot(host);
  act(() => root.render(<Harness />));
  select("Year", String(currentYear));
  const monthSelect = host.querySelector<HTMLSelectElement>('select[aria-label="Month"]')!;
  const futureMonth = String(new Date().getMonth() + 2).padStart(2, "0");
  expect([...monthSelect.options].find(option => option.value === futureMonth)?.disabled).toBe(true);
});

it("clears an incompatible day when the selected month has fewer days", () => {
  act(() => root.render(<Harness initial="2024-01-31" />));
  select("Month", "02");
  expect(host.querySelector("output")?.textContent).toBe("");
  select("Day", "29");
  expect(host.querySelector("output")?.textContent).toBe("2024-02-29");
});
