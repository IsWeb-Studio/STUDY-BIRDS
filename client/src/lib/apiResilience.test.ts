import axios, { AxiosError, type AxiosAdapter, type InternalAxiosRequestConfig } from "axios";
import { describe, expect, it } from "vitest";
import { ConnectivityManager } from "./connectivity";
import { installResilience } from "./apiResilience";
import { ERROR_COPY, getErrorMessage, isConnectivityError } from "../utils/errors";

const ok = (config: InternalAxiosRequestConfig, data: unknown = {}, status = 200) => ({
  data,
  status,
  statusText: "",
  headers: {},
  config,
});

const networkError = (config: InternalAxiosRequestConfig) => new AxiosError("Network Error", "ERR_NETWORK", config);

const setup = (adapter: AxiosAdapter) => {
  const client = axios.create({ adapter, baseURL: "http://x" });
  const manager = new ConnectivityManager({ probe: async () => true, isNavigatorOnline: () => true });
  installResilience(client, manager, () => 0);
  return { client, manager };
};

describe("api resilience", () => {
  it("sets a default timeout so nothing loads forever", () => {
    const { client } = setup(async (c) => ok(c));
    expect(client.defaults.timeout).toBe(30000);
  });

  it("retries transport failures of GET a bounded number of times, then succeeds", async () => {
    let calls = 0;
    const { client } = setup(async (config) => {
      calls += 1;
      if (calls < 3) throw networkError(config);
      return ok(config, { ok: true });
    });
    const response = await client.get("/a");
    expect(response.data).toEqual({ ok: true });
    expect(calls).toBe(3);
  });

  it("gives up after the retry budget and surfaces the error", async () => {
    let calls = 0;
    const { client } = setup(async (config) => {
      calls += 1;
      throw networkError(config);
    });
    await expect(client.get("/a")).rejects.toBeTruthy();
    expect(calls).toBe(3); // 1 try + 2 retries
  });

  it("never auto-retries writes (payments, registration, OTP)", async () => {
    let calls = 0;
    const { client } = setup(async (config) => {
      calls += 1;
      throw networkError(config);
    });
    await expect(client.post("/payments", { a: 1 })).rejects.toBeTruthy();
    expect(calls).toBe(1);
  });

  it("does not retry server answers (503) and does not leak their text", async () => {
    let calls = 0;
    const { client } = setup(async (config) => {
      calls += 1;
      throw new AxiosError("fail", "ERR_BAD_RESPONSE", config, null, {
        ...ok(config, { message: "MongoServerError E11000" }, 503),
      });
    });
    const error = await client.get("/a").catch((e) => e);
    expect(calls).toBe(1);
    expect(getErrorMessage(error, "fallback")).toBe(ERROR_COPY.unavailable.en);
  });

  it("shares identical concurrent GETs in a single request", async () => {
    let calls = 0;
    let release: () => void = () => undefined;
    const gate = new Promise<void>((resolve) => {
      release = resolve;
    });
    const { client } = setup(async (config) => {
      calls += 1;
      await gate;
      return ok(config, [1, 2]);
    });
    const all = Promise.all([1, 2, 3, 4, 5].map(() => client.get("/list")));
    release();
    const results = await all;
    expect(results.every((r) => (r.data as number[]).length === 2)).toBe(true);
    expect(calls).toBe(1);
  });

  it("adds a unique Idempotency-Key to writes only", async () => {
    const seen: Array<string | undefined> = [];
    const { client } = setup(async (config) => {
      seen.push(config.headers.get("Idempotency-Key") as string | undefined);
      return ok(config);
    });
    await client.post("/a", {});
    await client.post("/a", {});
    await client.get("/a?x=1");
    expect(seen[0]).toBeTruthy();
    expect(seen[0]).not.toBe(seen[1]);
    expect(seen[2]).toBeUndefined();
  });

  it("uploads get a longer timeout than normal requests", async () => {
    let timeout: number | undefined;
    const { client } = setup(async (config) => {
      timeout = config.timeout;
      return ok(config);
    });
    await client.post("/upload", new FormData());
    expect(timeout).toBeGreaterThan(30000);
  });

  it("a successful call reports reachability", async () => {
    const manager = new ConnectivityManager({ probe: async () => false, isNavigatorOnline: () => true, confirmDelayMs: 5 });
    const client = axios.create({ adapter: async (c) => ok(c), baseURL: "http://x" });
    installResilience(client, manager, () => 0);
    manager.start();
    manager.reportFailure();
    await new Promise((r) => setTimeout(r, 80));
    expect(manager.getSnapshot().status).toBe("unreachable");
    await client.get("/ping");
    expect(manager.getSnapshot().status).toBe("online");
    manager.stop();
  });
});

describe("error messages", () => {
  const cfg = {} as InternalAxiosRequestConfig;

  it("maps offline, timeout, server down and rate limiting to friendly text", () => {
    expect(getErrorMessage(new AxiosError("Network Error", "ERR_NETWORK", cfg), "x")).toBe(ERROR_COPY.offline.en);
    expect(getErrorMessage(new AxiosError("timeout", "ECONNABORTED", cfg), "x")).toBe(ERROR_COPY.timeout.en);
    const rate = new AxiosError("r", "ERR_BAD_REQUEST", cfg, null, ok(cfg, { message: "Too many" }, 429));
    expect(getErrorMessage(rate, "x")).toBe(ERROR_COPY.rateLimited.en);
  });

  it("keeps useful 4xx messages (wrong password stays 'wrong password')", () => {
    const bad = new AxiosError("b", "ERR_BAD_REQUEST", cfg, null, ok(cfg, { message: "Invalid credentials" }, 401));
    expect(getErrorMessage(bad, "x")).toBe("Invalid credentials");
  });

  it("recognises fetch failures and never prints raw network errors", () => {
    expect(isConnectivityError(new TypeError("Failed to fetch"))).toBe(true);
    expect(getErrorMessage(new TypeError("Failed to fetch"), "x")).toBe(ERROR_COPY.offline.en);
  });

  it("uses Arabic copy when the site language is Arabic", () => {
    localStorage.setItem("studyBirdsLanguage", "ar");
    expect(getErrorMessage(new AxiosError("Network Error", "ERR_NETWORK", cfg), "x")).toBe(ERROR_COPY.offline.ar);
    localStorage.removeItem("studyBirdsLanguage");
  });
});
