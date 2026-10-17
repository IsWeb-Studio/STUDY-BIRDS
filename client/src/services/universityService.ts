import { api } from "../lib/api";
import type { PaginatedResponse, University } from "../types";

type UniversityPayload = {
  expectedVersion?: number;
  name?: string;
  country?: string;
  city?: string;
  ranking?: number;
  overview?: string;
  articleTitle?: string;
  articleHeadings?: string[];
  articleBodies?: string[];
  featured?: boolean;
  isPartnerInstitution?: boolean;
  logo?: string;
  campusImages?: string[];
  tuitionRange?: {
    min?: number;
    max?: number;
  };
};

export const universityService = {
  getAll: async (params?: { country?: string; featured?: boolean; page?: number; limit?: number; paginate?: boolean }) => {
    const { data } = await api.get<University[] | PaginatedResponse<University>>("/universities", { params });
    return data;
  },
  getById: async (id: string) => {
    const { data } = await api.get<University>(`/universities/${id}`);
    return data;
  },
  create: async (payload: UniversityPayload) => {
    const { data } = await api.post<University>("/universities", payload);
    return data;
  },
  update: async (id: string, payload: UniversityPayload) => {
    const { data } = await api.put<University>(`/universities/${id}`, payload);
    return data;
  },
  remove: async (id: string, expectedVersion?: number) => {
    const { data } = await api.delete(`/universities/${id}`, { data: { expectedVersion } });
    return data;
  },
  uploadImages: async (files: File[]) => {
    const formData = new FormData();
    files.forEach((file) => formData.append("files", file));
    const { data } = await api.post<{ urls: string[] }>("/universities/upload-images", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    });
    return data.urls;
  },
};
