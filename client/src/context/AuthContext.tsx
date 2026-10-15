import { isAxiosError } from "axios";
import { createContext, useEffect, useRef, useState, type ReactNode } from "react";
import { connectivity } from "../lib/connectivity";
import { configureStaffReadTracking } from "../lib/sharedReadState";
import { authService } from "../services/authService";
import type { StudentProfile, User } from "../types";

interface AuthContextValue {
  user: User | null;
  profile: StudentProfile | null;
  token: string | null;
  loading: boolean;
  login: (email: string, password: string, twoFactorCode?: string) => Promise<User>;
  acceptIdentity: (response: { token: string; user: User }) => Promise<User>;
  googleLogin: (credential: string, emailCode?: string) => Promise<User>;
  emailOtpLogin: (email: string, code: string) => Promise<User>;
  register: (payload: { name: string; email: string; password: string; referralCode?: string }) => Promise<User>;
  logout: () => void;
  refreshSession: () => Promise<void>;
  sessionUnverified: boolean;
}

export const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export const AuthProvider = ({ children }: { children: ReactNode }) => {
  const [user, setUser] = useState<User | null>(null);
  useEffect(() => {
    configureStaffReadTracking(Boolean(user && ['admin', 'employee'].includes(user.role)));
    return () => configureStaffReadTracking(false);
  }, [user?._id, user?.role]);
  const [profile, setProfile] = useState<StudentProfile | null>(null);
  const [token, setToken] = useState<string | null>(localStorage.getItem("studyBirdsToken"));
  const [loading, setLoading] = useState(true);
  // True when a saved login exists but the server could not be reached to verify
  // it. The saved token is kept (no logout); routes show a retry state.
  const [sessionUnverified, setSessionUnverified] = useState(false);

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
      setSessionUnverified(false);
    } catch (error) {
      if (!isAxiosError(error) || ![401, 403].includes(error.response?.status ?? 0)) {
        setSessionUnverified(true);
        throw error;
      }
      setSessionUnverified(false);
      localStorage.removeItem("studyBirdsToken");
      setToken(null);
      setUser(null);
      setProfile(null);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void refreshSession().catch(() => setLoading(false));
  }, []);

  // When verified connectivity returns, re-check a session that could not be
  // verified (once per reconnect, never in a loop).
  const unverifiedRef = useRef(false);
  unverifiedRef.current = sessionUnverified;
  useEffect(
    () =>
      connectivity.onReconnected(() => {
        if (unverifiedRef.current) void refreshSession().catch(() => undefined);
      }),
    []
  );

  const login = async (email: string, password: string, twoFactorCode?: string) => {
    const data = await authService.login({ email, password, twoFactorCode });
    persistAuth(data.token, data.user);
    const session = await authService.me();
    setProfile(session.profile ?? null);
    return data.user;
  };

  const acceptIdentity = async (response: { token: string; user: User }) => {
    persistAuth(response.token, response.user);
    const session = await authService.me();
    setProfile(session.profile ?? null);
    return response.user;
  };

  const googleLogin = async (credential: string, emailCode?: string) => {
    const data = await authService.googleLogin({ credential, emailCode });
    persistAuth(data.token, data.user);
    const session = await authService.me();
    setProfile(session.profile ?? null);
    return data.user;
  };

  const emailOtpLogin = async (email: string, code: string) => {
    const data = await authService.verifyEmailOtp(email, code);
    persistAuth(data.token, data.user);
    const session = await authService.me();
    setProfile(session.profile ?? null);
    return data.user;
  };

  const register = async (payload: { name: string; email: string; password: string; referralCode?: string }) => {
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
        emailOtpLogin,
        acceptIdentity,
        register,
        logout,
        refreshSession,
        sessionUnverified,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};
