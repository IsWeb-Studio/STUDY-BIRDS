import axios from "axios";
import { configureConnectivity, connectivity } from "./connectivity";
import { installResilience } from "./apiResilience";

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
});

configureConnectivity(API_ORIGIN);
installResilience(api, connectivity);

api.interceptors.request.use((config) => {
  config.headers["X-Study-Birds-Client"] = "web";
  const token = localStorage.getItem("studyBirdsToken");
  if (token) {
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

export const privateDocumentId = (path?: string) => path?.match(/^\/api\/(?:documents|payment-proofs|support-attachments)\/([a-f0-9]{24})\/access$/i)?.[1];

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
