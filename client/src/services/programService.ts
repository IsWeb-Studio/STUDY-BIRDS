import { api } from "../lib/api";
import type { PaginatedResponse, Program } from "../types";

type ProgramPayload = {
  expectedVersion?: number;
  university?: string;
  title?: string;
  degreeLevel?: string;
  fieldOfStudy?: string;
  fieldsOfStudy?: string[];
  language?: string;
  duration?: string;
  tuition?: number;
  partnerTuition?: number;
  applicationDeadline?: string;
  intake?: string;
  requirements?: string[];
  summary?: string;
  articleTitle?: string;
  articleTitleColor?: string;
  articleHeadingColor?: string;
  articleBodyColor?: string;
  articleHeadings?: string[];
  articleBodies?: string[];
  featured?: boolean;
  popularity?: number;
  coverImage?: string;
};

export const programService = {
  getAll: async (params?: Record<string, string | number | boolean>) => {
    const { data } = await api.get<Program[] | PaginatedResponse<Program>>("/programs", { params });
    return data;
  },
  getById: async (id: string) => {
    const { data } = await api.get<Program>(`/programs/${id}`);
    return data;
  },
  create: async (payload: ProgramPayload) => {
    const { data } = await api.post<Program>("/programs", payload);
    return data;
  },
  update: async (id: string, payload: ProgramPayload & { expectedVersion: number }) => {
    const { data } = await api.put<Program>(`/programs/${id}`, payload, {
      headers: { 'If-Match': `"${payload.expectedVersion}"` },
    });
    return data;
  },
  uploadCoverImage: async (file: File) => {
    const formData = new FormData();
    formData.append("file", file);
    const { data } = await api.post<{ url: string }>("/programs/upload-cover", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    });
    return data.url;
  },
  remove: async (id: string, expectedVersion: number) => {
    const { data } = await api.delete(`/programs/${id}`, {
      data: { expectedVersion }, headers: { 'If-Match': `"${expectedVersion}"` },
    });
    return data;
  },
};
