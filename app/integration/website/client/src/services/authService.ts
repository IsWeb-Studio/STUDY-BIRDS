import { api } from "../lib/api";
import type { AuthResponse } from "../types";

export const authService = {
  register: async (payload: { name: string; email: string; password: string }) => {
    const { data } = await api.post<AuthResponse>("/auth/register", payload);
    return data;
  },
  login: async (payload: { email: string; password: string; twoFactorCode?: string }) => {
    const { data } = await api.post<AuthResponse>("/auth/login", payload);
    return data;
  },
  googleLogin: async (payload: { credential: string }) => {
    const { data } = await api.post<AuthResponse>("/auth/google", payload);
    return data;
  },
  me: async () => {
    const { data } = await api.get("/auth/me");
    return data;
  },
  changePassword: async (payload: { currentPassword: string; newPassword: string }) => {
    const { data } = await api.post<{ message: string }>("/auth/change-password", payload);
    return data;
  },
};
