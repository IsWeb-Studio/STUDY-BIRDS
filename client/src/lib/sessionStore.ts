import { useSyncExternalStore } from 'react';
import type { StudentProfile, User } from '../types';

type Session = { token: string | null; user: User | null; profile: StudentProfile | null; loading: boolean; sessionUnverified: boolean };
let session: Session = { token: null, user: null, profile: null, loading: true, sessionUnverified: false };
let generation = 0;
const listeners = new Set<() => void>();
const publish = () => listeners.forEach(fn => fn());
export const sessionStore = {
  get: () => session,
  generation: () => generation,
  begin: () => ++generation,
  update: (expected: number, patch: Partial<Session>) => {
    if (expected !== generation) return false;
    session = { ...session, ...patch }; publish(); return true;
  },
  clear: () => {
    ++generation;
    session = { token: null, user: null, profile: null, loading: false, sessionUnverified: false };
    publish();
  },
  rotate: (token: string, user?: User) => {
    ++generation;
    const changedUser = user && user._id !== session.user?._id;
    session = { ...session, token, ...(user ? { user } : {}), ...(changedUser ? { profile: null } : {}) };
    publish();
  },
};
export const useSession = () => useSyncExternalStore(
  (fn) => { listeners.add(fn); return () => { listeners.delete(fn); }; },
  sessionStore.get,
  sessionStore.get,
);
// Only a logout signal is persisted. Credentials never enter browser storage.
export const broadcastLogout = () => localStorage.setItem('studyBirdsLogout', crypto.randomUUID());
if (typeof window !== 'undefined') {
  localStorage.removeItem('studyBirdsToken');
  window.addEventListener('storage', event => {
    if (event.key === 'studyBirdsLogout' || (event.key === 'studyBirdsToken' && !event.newValue)) sessionStore.clear();
  });
}
