import { createContext, useEffect, useState, type ReactNode } from "react";
import { authService } from "../services/authService";
import type { StudentProfile, User } from "../types";

interface AuthContextValue {
  user: User | null;
  profile: StudentProfile | null;
  token: string | null;
  loading: boolean;
  login: (email: string, password: string, twoFactorCode?: string) => Promise<User>;
  googleLogin: (credential: string) => Promise<User>;
  register: (payload: { name: string; email: string; password: string }) => Promise<User>;
  logout: () => void;
  refreshSession: () => Promise<void>;
}

export const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export const AuthProvider = ({ children }: { children: ReactNode }) => {
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<StudentProfile | null>(null);
  const [token, setToken] = useState<string | null>(localStorage.getItem("studyBirdsToken"));
  const [loading, setLoading] = useState(true);

  const persistAuth = (nextToken: string, nextUser: User) => {
    localStorage.setItem("studyBirdsToken", nextToken);
    setToken(nextToken);
    setUser(nextUser);
  };

  const refreshSession = async () => {
    const storedToken = localStorage.getItem("studyBirdsToken");
    if (!storedToken) {
      setLoading(false);
      return;
    }

    try {
      const data = await authService.me();
      setUser(data.user);
      setProfile(data.profile ?? null);
    } catch (error) {
      localStorage.removeItem("studyBirdsToken");
      setToken(null);
      setUser(null);
      setProfile(null);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    refreshSession();
  }, []);

  const login = async (email: string, password: string, twoFactorCode?: string) => {
    const data = await authService.login({ email, password, twoFactorCode });
    persistAuth(data.token, data.user);
    const session = await authService.me();
    setProfile(session.profile ?? null);
    return data.user;
  };

  const googleLogin = async (credential: string) => {
    const data = await authService.googleLogin({ credential });
    persistAuth(data.token, data.user);
    const session = await authService.me();
    setProfile(session.profile ?? null);
    return data.user;
  };

  const register = async (payload: { name: string; email: string; password: string }) => {
    const data = await authService.register(payload);
    persistAuth(data.token, data.user);
    const session = await authService.me();
    setProfile(session.profile ?? null);
    return data.user;
  };

  const logout = () => {
    localStorage.removeItem("studyBirdsToken");
    if (window.google?.accounts?.id) {
      window.google.accounts.id.disableAutoSelect();
    }
    setToken(null);
    setUser(null);
    setProfile(null);
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        profile,
        token,
        loading,
        login,
        googleLogin,
        register,
        logout,
        refreshSession,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};
