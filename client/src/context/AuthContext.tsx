import { isAxiosError } from "axios";
import { createContext, useEffect, useRef, type ReactNode } from "react";
import { api } from '../lib/api';
import { broadcastLogout, sessionStore, useSession } from '../lib/sessionStore';
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
  const session = useSession();
  useEffect(() => {
    configureStaffReadTracking(Boolean(session.user && ['admin', 'employee'].includes(session.user.role)));
    return () => configureStaffReadTracking(false);
  }, [session.user?._id, session.user?.role]);

  const refreshPending = useRef<Promise<void> | null>(null);
  const sessionGeneration = useRef(sessionStore.generation());
  const captureGeneration = () => (sessionGeneration.current = sessionStore.generation());
  const isCurrentGeneration = (generation: number) =>
    generation === sessionGeneration.current && generation === sessionStore.generation();
  const beginSession = () => (sessionGeneration.current = sessionStore.begin());
  const cleanupSession = () => {
    sessionStore.clear();
    sessionGeneration.current = sessionStore.generation();
    refreshPending.current = null;
  };


  const refreshSession = () => {
    if (refreshPending.current) return refreshPending.current;
    const generation = captureGeneration();
    const run = async () => {
      try {
        if (localStorage.getItem('studyBirdsLogoutPending')) {
          await api.post('/auth/logout', {}).catch(error => {
            if (!isAxiosError(error) || ![400, 401].includes(error.response?.status ?? 0)) throw error;
          });
          localStorage.removeItem('studyBirdsLogoutPending');
          if (isCurrentGeneration(generation)) cleanupSession();
          return;
        }
        let token = sessionStore.get().token;
        if (!token) {
          const { data } = await api.post('/auth/refresh', {});
          if (!sessionStore.update(generation, { token: data.token, user: data.user, profile: null })) return;
          token = data.token;
        }
        const { data } = await api.get('/auth/me', { headers: { Authorization: `Bearer ${token}` } });
        sessionStore.update(generation, { user: data.user, profile: data.profile ?? null, loading: false, sessionUnverified: false });
      } catch (error) {
        if (!isCurrentGeneration(generation)) return;
        if (isAxiosError(error) && [400, 401, 403].includes(error.response?.status ?? 0)) cleanupSession();
        else sessionStore.update(generation, { loading: false, sessionUnverified: true });
      }
    };
    const pending = run().finally(() => { if (refreshPending.current === pending) refreshPending.current = null; });
    refreshPending.current = pending;
    return pending;
  };

  useEffect(() => {
    void refreshSession();
    const unsubscribe = connectivity.onReconnected(() => {
      if (sessionStore.get().sessionUnverified || localStorage.getItem('studyBirdsLogoutPending')) void refreshSession();
    });
    return unsubscribe;
  }, []);

  const accept = async (response: { token: string; user: User }, generation: number) => {
    if (!sessionStore.update(generation, { token: response.token, user: response.user, profile: null, loading: false, sessionUnverified: false })) {
      throw new Error('Session changed');
    }
    broadcastLogout();
    try {
      const { data } = await api.get('/auth/me', { headers: { Authorization: `Bearer ${response.token}` } });
      if (!sessionStore.update(generation, { user: data.user, profile: data.profile ?? null })) throw new Error('Session changed');
    } catch (error) {
      if (isCurrentGeneration(generation)) {
        if (isAxiosError(error) && [401, 403].includes(error.response?.status ?? 0)) cleanupSession();
        else sessionStore.update(generation, { sessionUnverified: true });
      }
      throw error;
    }
    return response.user;
  };
  const authenticate = async (request: () => Promise<{ token: string; user: User }>) => {
    // Do not let a delayed offline logout revoke a newly created session.
    if (localStorage.getItem('studyBirdsLogoutPending')) await refreshSession();
    if (localStorage.getItem('studyBirdsLogoutPending')) throw new Error('Connect to finish signing out first');
    const generation = beginSession();
    sessionStore.update(generation, { token: null, user: null, profile: null, sessionUnverified: false });
    return accept(await request(), generation);
  };
  const login = (email: string, password: string, twoFactorCode?: string) => authenticate(() => authService.login({ email, password, twoFactorCode }));
  const googleLogin = (credential: string, emailCode?: string) => authenticate(() => authService.googleLogin({ credential, emailCode }));
  const emailOtpLogin = (email: string, code: string) => authenticate(() => authService.verifyEmailOtp(email, code));
  const register = (payload: { name: string; email: string; password: string; referralCode?: string }) => authenticate(() => authService.register(payload));
  const acceptIdentity = (response: { token: string; user: User }) => accept(response, beginSession());
  const logout = () => {
    cleanupSession();
    const generation = captureGeneration();
    localStorage.setItem('studyBirdsLogoutPending', '1');
    broadcastLogout();
    // Cookie logout can revoke even an expired access token. Serialized after pending authentication.
    void api.post('/auth/logout', {}).then(() => localStorage.removeItem('studyBirdsLogoutPending')).catch(error => {
      if (isAxiosError(error) && [400, 401].includes(error.response?.status ?? 0)) localStorage.removeItem('studyBirdsLogoutPending');
      else sessionStore.update(generation, { sessionUnverified: true });
    });
    window.google?.accounts?.id?.disableAutoSelect();
  };

  // Rotate before the short-lived access token expires. Requests are serialized across tabs.
  useEffect(() => {
    const timer = window.setInterval(() => {
      if (!sessionStore.get().token) return;
      const generation = captureGeneration();
      void api.post('/auth/refresh', {}).then(({ data }) => {
        if (isCurrentGeneration(generation)) {
          sessionStore.rotate(data.token, data.user);
          void refreshSession();
        }
      }).catch(error => {
        if (isCurrentGeneration(generation) && isAxiosError(error) && [400, 401, 403].includes(error.response?.status ?? 0)) cleanupSession();
      });
    }, 10 * 60 * 1000);
    return () => window.clearInterval(timer);
  }, []);

  return <AuthContext.Provider value={{ ...session, login, googleLogin, emailOtpLogin, register, acceptIdentity, logout, refreshSession }}>{children}</AuthContext.Provider>;
};
