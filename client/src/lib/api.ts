import axios from "axios";
import { configureConnectivity, connectivity } from "./connectivity";
import { installResilience } from "./apiResilience";
import { broadcastLogout, sessionStore } from './sessionStore';

const resolveApiUrl = () => {
  const configuredApiUrl = import.meta.env.VITE_API_URL?.trim();

  if (configuredApiUrl) {
    return configuredApiUrl;
  }

  if (typeof window !== "undefined") {
    const { hostname } = window.location;

    if (hostname === "localhost" || hostname === "127.0.0.1") {
      return "http://localhost:5000/api";
    }
  }

  return "https://study-birds1.onrender.com/api";
};

export const API_URL = resolveApiUrl();
const API_ORIGIN = API_URL.replace(/\/api\/?$/, "");

export const api = axios.create({
  baseURL: API_URL,
  withCredentials: true,
});

configureConnectivity(API_ORIGIN);
installResilience(api, connectivity);

// Serialize cookie rotations/login/logout, including across tabs when Web Locks is available.
const sessionAdapter = axios.getAdapter(api.defaults.adapter);
let authQueue: Promise<unknown> = Promise.resolve();
api.defaults.adapter = (config) => {
  if (!/^\/(auth|identity)\//.test(config.url || '') || config.method === 'get') return sessionAdapter(config);
  const execute = async () => navigator.locks
    ? navigator.locks.request('studyBirdsAuth', async () => await sessionAdapter(config))
    : sessionAdapter(config);
  const request = authQueue.then(execute, execute);
  authQueue = request.catch(() => undefined);
  return request;
};

api.interceptors.request.use((config) => {
  config.headers["X-Study-Birds-Client"] = "web";
  const target = new URL(config.url || '', `${API_URL.replace(/\/$/, '')}/`);
  if (target.origin !== new URL(API_URL).origin) throw new Error('External API origin rejected');
  const token = sessionStore.get().token;
  if (token && !config.headers.Authorization) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

export const getApiAssetUrl = (path?: string) => {
  if (!path) {
    return "";
  }

  const normalizedPath = path.trim().replace(/\\/g, "/");

  if (/^https?:\/\//i.test(normalizedPath)) {
    return normalizedPath;
  }

  const uploadsMatch = normalizedPath.match(/(?:^|\/)(uploads\/.+)$/i);
  const resolvedPath = uploadsMatch ? `/${uploadsMatch[1]}` : normalizedPath;

  return `${API_ORIGIN}${resolvedPath.startsWith("/") ? resolvedPath : `/${resolvedPath}`}`;
};

const CLOUDINARY_DOCUMENT_PATTERN = /^https?:\/\/res\.cloudinary\.com\/.+\.(pdf|doc|docx|xls|xlsx|ppt|pptx|txt|zip)(?:[?#].*)?$/i;

export const getDownloadableAssetUrl = (path?: string) => {
  const assetUrl = getApiAssetUrl(path);

  if (!assetUrl) {
    return "";
  }

  if (CLOUDINARY_DOCUMENT_PATTERN.test(assetUrl)) {
    return `${API_URL}/content/file-open?url=${encodeURIComponent(assetUrl)}`;
  }

  return assetUrl;
};

export const privateDocumentId = (path?: string) => path?.match(/^\/api\/(?:documents|payment-proofs|support-attachments|verification-documents)\/([a-f0-9]{24})\/access$/i)?.[1];

export const downloadApiAsset = async (path?: string, fileName?: string) => {
  const documentId = privateDocumentId(path);
  if (documentId) {
    const { data } = await api.post<{url: string; expiresAt: number}>(path!.slice(4));
    const url = new URL(data.url);
    if (url.protocol !== 'https:' || url.hostname !== 'api.cloudinary.com') throw new Error('Invalid document download URL');
    const link = document.createElement('a');
    link.href = data.url; link.rel = 'noreferrer'; link.referrerPolicy = 'no-referrer';
    document.body.appendChild(link); link.click(); link.remove();
    return;
  }
  const assetUrl = getDownloadableAssetUrl(path);

  if (!assetUrl) {
    throw new Error("File URL is missing");
  }

  const response = await fetch(assetUrl);

  if (!response.ok) {
    throw new Error("Unable to download file");
  }

  const blob = await response.blob();
  const blobUrl = window.URL.createObjectURL(blob);
  const link = document.createElement("a");

  link.href = blobUrl;
  link.download = fileName || assetUrl.split("/").pop() || "download";
  document.body.appendChild(link);
  link.click();
  link.remove();
  window.URL.revokeObjectURL(blobUrl);
};

// Share renewal across requests when a suspended tab wakes with an expired token.
let renewal: Promise<string | null> | null = null;
let lastRenewal: { previous: string; current: string; generation: number } | null = null;
export const renewAccessToken = (failedToken: string): Promise<string | null> => {
  if (sessionStore.get().token !== failedToken) return Promise.resolve(null);
  if (renewal) return renewal;
  const generation = sessionStore.generation();
  const pending = api.post('/auth/refresh', {}).then(({ data }) => {
    if (generation !== sessionStore.generation()) return null;
    if (typeof data.token !== 'string' || !data.token) throw new Error('Missing access token');
    sessionStore.rotate(data.token, data.user);
    lastRenewal = { previous: failedToken, current: data.token, generation: sessionStore.generation() };
    return data.token as string;
  }).catch(error => {
    if (generation === sessionStore.generation() && [400, 401, 403].includes(error.response?.status)) {
      sessionStore.clear(); broadcastLogout();
    }
    throw error;
  }).finally(() => { if (renewal === pending) renewal = null; });
  renewal = pending;
  return pending;
};

// Password changes replace the current session and invalidate all older tokens.
api.interceptors.response.use((response) => {
  if (response.config.url === '/auth/change-password' && response.data?.token &&
      response.config.headers.Authorization === `Bearer ${sessionStore.get().token}`) {
    sessionStore.rotate(response.data.token, response.data.user);
    broadcastLogout();
  }
  return response;
}, async (error) => {
  const token = sessionStore.get().token;
  // A parallel request may finish after its peer already renewed this session.
  if (error.response?.status === 401 && token && lastRenewal &&
      lastRenewal.current === token && lastRenewal.generation === sessionStore.generation() &&
      error.config?.headers?.Authorization === `Bearer ${lastRenewal.previous}` &&
      !error.config._sessionRetried && !/^\/(auth|identity)\//.test(error.config.url || '')) {
    error.config._sessionRetried = true;
    error.config.headers.Authorization = `Bearer ${token}`;
    return api.request(error.config);
  }
  if (error.response?.status === 401 && token &&
      error.config?.headers?.Authorization === `Bearer ${token}` &&
      (!/^\/(auth|identity)\//.test(error.config?.url || '') ||
       /^\/auth\/(me|change-password|account)$/.test(error.config?.url || ''))) {
    const config = error.config;
    if (!config._sessionRetried) {
      const replacement = await renewAccessToken(token);
      if (replacement) {
        config._sessionRetried = true;
        config.headers.Authorization = `Bearer ${replacement}`;
        return api.request(config);
      }
    } else {
      sessionStore.clear(); broadcastLogout();
    }
  }
  return Promise.reject(error);
});
