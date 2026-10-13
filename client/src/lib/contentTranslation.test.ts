import { beforeEach, describe, expect, it, vi } from "vitest";

const post = vi.fn();
vi.mock("./api", () => ({ api: { post: (...args: unknown[]) => post(...args) } }));

import {
  getTranslationVersion,
  needsTranslation,
  resetTranslationsForTest,
  translateToArabic,
  translateToEnglish,
} from "./contentTranslation";
import { pickLocalized, localizedArticle } from "../utils/localizedContent";

const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

// Fake server: reverses direction by `target`.
const fakeServer = (_url: string, body: { texts: string[]; target: "en" | "ar" }) =>
  Promise.resolve({
    data: { translations: body.texts.map((text) => (body.target === "ar" ? `AR(${text})` : `EN(${text})`)) },
  });

beforeEach(() => {
  resetTranslationsForTest();
  post.mockReset();
  post.mockImplementation(fakeServer);
});

describe("content translation works in both directions", () => {
  it("decides by script, per direction", () => {
    expect(needsTranslation("جامعة إسطنبول", "en")).toBe(true);
    expect(needsTranslation("Istanbul University", "en")).toBe(false);
    expect(needsTranslation("Istanbul University", "ar")).toBe(true);
    expect(needsTranslation("جامعة إسطنبول", "ar")).toBe(false);
    expect(needsTranslation("1234", "ar")).toBe(false);
  });

  it("English mode: Arabic text -> English, delivered after the fetch", async () => {
    expect(translateToEnglish("جامعة إسطنبول")).toBe("جامعة إسطنبول"); // original first
    await wait(400);
    expect(translateToEnglish("جامعة إسطنبول")).toBe("EN(جامعة إسطنبول)");
    expect(post).toHaveBeenCalledWith("/translate", { texts: ["جامعة إسطنبول"], target: "en" });
  });

  it("Arabic mode: English-only text -> Arabic", async () => {
    expect(translateToArabic("Istanbul University")).toBe("Istanbul University");
    await wait(400);
    expect(translateToArabic("Istanbul University")).toBe("AR(Istanbul University)");
    expect(post).toHaveBeenCalledWith("/translate", { texts: ["Istanbul University"], target: "ar" });
  });

  it("text already in the wanted language is never sent anywhere", async () => {
    expect(translateToArabic("جامعة إسطنبول")).toBe("جامعة إسطنبول");
    expect(translateToEnglish("Istanbul University")).toBe("Istanbul University");
    await wait(300);
    expect(post).not.toHaveBeenCalled();
  });

  it("both directions can be pending together and do not mix up results", async () => {
    translateToEnglish("كلية الطب");
    translateToArabic("Medicine");
    await wait(450);
    expect(translateToEnglish("كلية الطب")).toBe("EN(كلية الطب)");
    expect(translateToArabic("Medicine")).toBe("AR(Medicine)");
    expect(getTranslationVersion()).toBeGreaterThan(0);
  });

  it("when the server fails, the original text stays (never blank)", async () => {
    post.mockRejectedValue(new Error("down"));
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false }));
    translateToArabic("Medicine");
    await wait(450);
    expect(translateToArabic("Medicine")).toBe("Medicine");
    vi.unstubAllGlobals();
  });
});

describe("localized catalog content", () => {
  const tr = (text?: string | null) => (text ? `T(${text})` : "");

  it("Arabic mode shows Arabic text as is and translates English-only content", () => {
    expect(pickLocalized("ar", "جامعة", "University", (t) => t || "")).toBe("جامعة");
    expect(pickLocalized("ar", "", "University", tr)).toBe("T(University)");
    expect(pickLocalized("ar", "Istanbul University", "", tr)).toBe("T(Istanbul University)");
  });

  it("English mode prefers the hand-written English, else translates the Arabic", () => {
    expect(pickLocalized("en", "جامعة", "University", tr)).toBe("University");
    expect(pickLocalized("en", "جامعة", "", tr)).toBe("T(جامعة)");
  });

  it("articles: Arabic mode falls back to translated English sections", () => {
    const article = {
      articleTitle: "",
      articleTitleEn: "Study plan",
      articleHeadings: [],
      articleHeadingsEn: ["Careers"],
      articleBodies: [],
      articleBodiesEn: ["Many jobs"],
    } as never;
    const result = localizedArticle("ar", article, tr);
    expect(result.articleTitle).toBe("T(Study plan)");
    expect(result.articleHeadings).toEqual(["T(Careers)"]);
    expect(result.articleBodies).toEqual(["T(Many jobs)"]);
  });
});
