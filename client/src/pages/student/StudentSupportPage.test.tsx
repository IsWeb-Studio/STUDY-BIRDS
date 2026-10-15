import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { StudentSupportPage } from "./StudentSupportPage";
import { studentService } from "../../services/studentService";

vi.mock("../../hooks/useLanguage", () => ({ useLanguage: () => ({ language: "en" }) }));
vi.mock("../../components/DocumentFileLink", () => ({ DocumentFileLink: () => null }));
vi.mock("../../services/studentService", () => ({ studentService: { getSupportTickets: vi.fn(), replySupportTicket: vi.fn(), createSupportTicket: vi.fn() } }));
let root: Root, host: HTMLDivElement;
const ticket = { _id: "ticket", subject: "Help with documents", message: "Original question", status: "answered" as const, category: "documents" as const, replies: [{ fromRole: "student" as const, message: "Original question" }, { fromRole: "admin" as const, message: "Please upload a document", displayName: "Advisor" }] };
beforeEach(() => {
  vi.useFakeTimers();
  Object.defineProperty(document, "hidden", { configurable: true, value: false });
  (globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
  vi.mocked(studentService.getSupportTickets).mockResolvedValue([ticket]);
  vi.mocked(studentService.replySupportTicket).mockResolvedValue(ticket);
  host = document.createElement("div"); document.body.append(host); root = createRoot(host);
});
afterEach(() => { act(() => root.unmount()); host.remove(); vi.useRealTimers(); vi.clearAllMocks(); });
const render = async () => { await act(async () => { root.render(<StudentSupportPage />); }); };
const draft = (value: string) => {
  const textarea = host.querySelector("article textarea") as HTMLTextAreaElement;
  act(() => { Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, "value")!.set!.call(textarea, value); textarea.dispatchEvent(new Event("input", { bubbles: true })); });
  return textarea;
};

it("shows the opening message once and lets the student reply in the same ticket", async () => {
  await render();
  expect(host.textContent!.split("Original question").length - 1).toBe(1);
  expect(host.textContent).toContain("Advisor");
  const textarea = draft("Thanks, here is my question");
  await act(async () => { textarea.closest("form")!.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true })); });
  expect(studentService.replySupportTicket).toHaveBeenCalledWith("ticket", "Thanks, here is my question");
  expect(textarea.value).toBe("");
});
it("refreshes incoming replies without deleting the student's unsent draft", async () => {
  await render(); const textarea = draft("Unsent question");
  vi.mocked(studentService.getSupportTickets).mockResolvedValue([{ ...ticket, replies: [...ticket.replies, { fromRole: "admin", message: "New answer" }] }]);
  await act(async () => { await vi.advanceTimersByTimeAsync(15000); });
  expect(host.textContent).toContain("New answer"); expect(textarea.value).toBe("Unsent question");
});
it("retains the reply text on failure and hides reply controls for a closed ticket", async () => {
  await render(); const textarea = draft("Keep this draft");
  vi.mocked(studentService.replySupportTicket).mockRejectedValueOnce(new Error("Connection lost"));
  await act(async () => { textarea.closest("form")!.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true })); });
  expect(textarea.value).toBe("Keep this draft"); expect(host.textContent).toContain("Connection lost");
  vi.mocked(studentService.getSupportTickets).mockResolvedValue([{ ...ticket, status: "closed" }]);
  await act(async () => { await vi.advanceTimersByTimeAsync(15000); });
  expect(host.querySelector("article form")).toBeNull();
});
