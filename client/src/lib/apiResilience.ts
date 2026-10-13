import axios, { type AxiosError, type AxiosInstance, type AxiosResponse, type InternalAxiosRequestConfig } from "axios";
import type { ConnectivityManager } from "./connectivity";

const MAX_GET_RETRIES = 2;
const DEFAULT_TIMEOUT_MS = 30000;
const UPLOAD_TIMEOUT_MS = 120000;

type RetryConfig = InternalAxiosRequestConfig & { __retries?: number };

const newOperationId = () =>
  typeof crypto !== "undefined" && "randomUUID" in crypto
    ? crypto.randomUUID()
    : `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * Adds, in one place for every request the site makes:
 *  - a default timeout (no request can leave the UI loading forever),
 *  - reporting of real request outcomes to the connectivity manager,
 *  - bounded retries (exponential backoff + jitter) for idempotent GETs only,
 *  - sharing of identical concurrent GETs (no pile-up after reconnecting),
 *  - an Idempotency-Key on writes (honoured only if the server supports it).
 * Writes are never retried automatically (payments, account creation, OTP...).
 */
export const installResilience = (client: AxiosInstance, connectivity: ConnectivityManager, random: () => number = Math.random) => {
  client.defaults.timeout = DEFAULT_TIMEOUT_MS;

  client.interceptors.request.use((config) => {
    const method = (config.method ?? "get").toLowerCase();
    if (method !== "get" && method !== "head" && !config.headers.has("Idempotency-Key")) {
      config.headers.set("Idempotency-Key", newOperationId());
    }
    if (typeof FormData !== "undefined" && config.data instanceof FormData && config.timeout === DEFAULT_TIMEOUT_MS) {
      config.timeout = UPLOAD_TIMEOUT_MS;
    }
    return config;
  });

  const baseAdapter = axios.getAdapter(client.defaults.adapter);
  const inflight = new Map<string, Promise<AxiosResponse>>();
  client.defaults.adapter = (config) => {
    const method = (config.method ?? "get").toLowerCase();
    if (method !== "get" || config.responseType === "blob" || config.responseType === "stream" || config.signal) {
      return baseAdapter(config);
    }
    const key = `${String(config.headers?.get?.("Authorization") ?? "")}|${client.getUri(config)}`;
    const pending = inflight.get(key);
    if (pending) return pending;
    const request = baseAdapter(config).finally(() => inflight.delete(key));
    inflight.set(key, request);
    return request;
  };

  client.interceptors.response.use(
    (response) => {
      connectivity.reportSuccess();
      return response;
    },
    async (error: AxiosError) => {
      const config = error.config as RetryConfig | undefined;
      if (!error.response && error.code !== "ERR_CANCELED") {
        connectivity.reportFailure();
        const method = (config?.method ?? "get").toLowerCase();
        const retries = config?.__retries ?? 0;
        // Retry only safe reads, only transport failures, never while the
        // browser already knows it has no network at all.
        if (config && method === "get" && retries < MAX_GET_RETRIES && connectivity.getSnapshot().status !== "offline") {
          config.__retries = retries + 1;
          const backoff = 400 * 2 ** retries;
          await sleep(backoff + Math.floor(random() * backoff));
          return client.request(config);
        }
      } else if (error.response) {
        // The server answered: the network path works.
        connectivity.reportSuccess();
      }
      return Promise.reject(error);
    }
  );
};
