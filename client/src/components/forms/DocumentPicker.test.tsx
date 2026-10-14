import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { DocumentPicker } from "./DocumentPicker";

vi.mock("../../hooks/useLanguage", () => ({ useLanguage: () => ({ language: "en" }) }));
let host: HTMLDivElement;
let root: Root;
let stop: ReturnType<typeof vi.fn>;
let getUserMedia: ReturnType<typeof vi.fn>;
beforeEach(() => {
  stop = vi.fn();
  getUserMedia = vi.fn().mockResolvedValue({ getTracks: () => [{ stop }] });
  Object.defineProperty(navigator, "mediaDevices", { configurable: true, value: { getUserMedia } });
  vi.spyOn(HTMLMediaElement.prototype, "play").mockResolvedValue(undefined);
  (globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
  host = document.createElement("div");
  document.body.append(host);
  root = createRoot(host);
});
afterEach(() => { act(() => root.unmount()); host.remove(); vi.restoreAllMocks(); vi.unstubAllGlobals(); });

it("offers separate live camera, photo library and file selection without submitting the form", () => {
  act(() => root.render(<DocumentPicker onSelect={vi.fn()} />));
  const inputs = [...host.querySelectorAll("input")];
  const buttons = [...host.querySelectorAll("button")];
  expect(buttons.map(button => button.textContent)).toEqual(["Take a photo", "Choose photos", "Choose a file"]);
  expect(inputs[0].getAttribute("capture")).toBe("environment");
  expect(inputs[1].hasAttribute("capture")).toBe(false);
  expect(inputs[2].accept).toContain(".pdf");
  buttons.slice(1).forEach((button, offset) => {
    const index = offset + 1;
    const click = vi.spyOn(inputs[index], "click").mockImplementation(() => {});
    act(() => button.click());
    expect(click).toHaveBeenCalledOnce();
    expect(button.type).toBe("button");
  });
});

it("opens a live preview instead of the file chooser and releases the camera on cancel", async () => {
  act(() => root.render(<DocumentPicker onSelect={vi.fn()} />));
  const nativeClick = vi.spyOn(host.querySelector("input")!, "click");
  await act(async () => host.querySelector("button")!.click());
  expect(getUserMedia).toHaveBeenCalledWith(expect.objectContaining({ audio: false, video: expect.objectContaining({ facingMode: { ideal: "environment" } }) }));
  expect(nativeClick).not.toHaveBeenCalled();
  expect(document.querySelector('[role="dialog"] video')).not.toBeNull();
  expect(HTMLMediaElement.prototype.play).toHaveBeenCalled();
  const cancel = [...document.querySelectorAll('button')].find(button => button.textContent === "Cancel")!;
  act(() => cancel.click());
  expect(stop).toHaveBeenCalledOnce();
  expect(document.querySelector('[role="dialog"]')).toBeNull();
});

it("reports denied permission without silently opening files", async () => {
  getUserMedia.mockRejectedValue(new DOMException("Denied", "NotAllowedError"));
  act(() => root.render(<DocumentPicker onSelect={vi.fn()} />));
  const click = vi.spyOn(host.querySelector("input")!, "click");
  await act(async () => host.querySelector("button")!.click());
  expect(document.querySelector('[role="alert"]')?.textContent).toContain("Allow camera access");
  expect(click).not.toHaveBeenCalled();
});

it("stops a camera request that resolves after cancellation", async () => {
  let resolve!: (stream: MediaStream) => void;
  getUserMedia.mockReturnValue(new Promise<MediaStream>(done => { resolve = done; }));
  act(() => root.render(<DocumentPicker onSelect={vi.fn()} />));
  await act(async () => host.querySelector("button")!.click());
  act(() => [...document.querySelectorAll('button')].find(button => button.textContent === "Cancel")!.click());
  await act(async () => resolve({ getTracks: () => [{ stop }] } as unknown as MediaStream));
  expect(stop).toHaveBeenCalledOnce();
  expect(document.querySelector('[role="dialog"]')).toBeNull();
});

it("requires confirmation before returning a photographed JPEG", async () => {
  const selected = vi.fn();
  vi.spyOn(HTMLCanvasElement.prototype, "getContext").mockReturnValue({ drawImage: vi.fn() } as unknown as CanvasRenderingContext2D);
  vi.spyOn(HTMLCanvasElement.prototype, "toBlob").mockImplementation(callback => callback(new Blob(["photo"], { type: "image/jpeg" })));
  const revoke = vi.fn();
  vi.stubGlobal("URL", { createObjectURL: vi.fn().mockReturnValue("blob:photo"), revokeObjectURL: revoke });
  act(() => root.render(<DocumentPicker onSelect={selected} />));
  await act(async () => host.querySelector("button")!.click());
  const live = document.querySelector("video")!;
  Object.defineProperty(live, "videoWidth", { value: 1920 });
  Object.defineProperty(live, "videoHeight", { value: 1080 });
  act(() => live.dispatchEvent(new Event("loadeddata")));
  const capture = [...document.querySelectorAll('button')].find(button => button.textContent === "Capture photo")!;
  await act(async () => capture.click());
  expect(selected).not.toHaveBeenCalled();
  expect(stop).toHaveBeenCalledOnce();
  act(() => [...document.querySelectorAll('button')].find(button => button.textContent === "Use this photo")!.click());
  expect(selected).toHaveBeenCalledOnce();
  const file = selected.mock.calls[0][0] as File;
  expect(file.type).toBe("image/jpeg");
  expect(file.name).toMatch(/\.jpg$/);
  expect(revoke).toHaveBeenCalledWith("blob:photo");
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
