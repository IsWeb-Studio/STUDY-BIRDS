import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { DocumentPicker } from "./DocumentPicker";

vi.mock("../../hooks/useLanguage", () => ({ useLanguage: () => ({ language: "en" }) }));
let host: HTMLDivElement;
let root: Root;
beforeEach(() => {
  (globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
  host = document.createElement("div");
  document.body.append(host);
  root = createRoot(host);
});
afterEach(() => { act(() => root.unmount()); host.remove(); });

it("offers separate live camera, photo library and file selection without submitting the form", () => {
  act(() => root.render(<DocumentPicker onSelect={vi.fn()} />));
  const inputs = [...host.querySelectorAll("input")];
  const buttons = [...host.querySelectorAll("button")];
  expect(buttons.map(button => button.textContent)).toEqual(["Take a photo", "Choose photos", "Choose a file"]);
  expect(inputs[0].getAttribute("capture")).toBe("environment");
  expect(inputs[1].hasAttribute("capture")).toBe(false);
  expect(inputs[2].accept).toContain(".pdf");
  buttons.forEach((button, index) => {
    const click = vi.spyOn(inputs[index], "click").mockImplementation(() => {});
    act(() => button.click());
    expect(click).toHaveBeenCalledOnce();
    expect(button.type).toBe("button");
  });
});

it("keeps the selected file when the next picker is cancelled and accepts selecting it again", () => {
  const selected = vi.fn();
  act(() => root.render(<DocumentPicker onSelect={selected} />));
  const input = host.querySelectorAll("input")[2];
  const file = new File(["passport"], "passport.pdf", { type: "application/pdf" });
  function choose(files: File[]) {
    Object.defineProperty(input, "files", { configurable: true, value: files });
    act(() => input.dispatchEvent(new Event("change", { bubbles: true })));
  }
  choose([file]);
  choose([]);
  expect(selected).toHaveBeenCalledTimes(1);
  expect(host.textContent).toContain("passport.pdf");
  choose([file]);
  expect(selected).toHaveBeenCalledTimes(2);
  expect(selected).toHaveBeenLastCalledWith(file);
});

it("disables all sources while uploading", () => {
  act(() => root.render(<DocumentPicker disabled onSelect={vi.fn()} />));
  host.querySelectorAll("button,input").forEach(element => expect((element as HTMLInputElement).disabled).toBe(true));
});