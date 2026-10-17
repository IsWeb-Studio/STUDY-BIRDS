import React, { act, useContext } from 'react';
import { createRoot } from 'react-dom/client';
import { renderToStaticMarkup } from 'react-dom/server';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';
const mocks = vi.hoisted(() => ({ get: vi.fn(), post: vi.fn(), login: vi.fn() }));
vi.mock('../services/authService', () => ({ authService: { login: mocks.login } }));
vi.mock('../lib/api', () => ({ api: { get: mocks.get, post: mocks.post } }));
vi.mock('../lib/sharedReadState', () => ({ configureStaffReadTracking: vi.fn() }));
vi.mock('../lib/connectivity', () => ({ connectivity: { onReconnected: () => () => {} } }));
import { AuthProvider, AuthContext } from './AuthContext';
import { sessionStore } from '../lib/sessionStore';
import { renderRichTextLines } from '../utils/richText';
let state: any;
let root: ReturnType<typeof createRoot> | undefined;
function Probe() { state = useContext(AuthContext); return null; }
async function mount() { (globalThis as any).IS_REACT_ACT_ENVIRONMENT = true; root = createRoot(document.createElement('div')); await act(async () => root!.render(<AuthProvider><Probe /></AuthProvider>)); }
beforeEach(() => { localStorage.clear(); sessionStore.clear(); vi.resetAllMocks(); mocks.post.mockResolvedValue({ data: {} }); });
afterEach(async () => { if (root) await act(async () => root!.unmount()); root = undefined; });
it('escapes HTML and rejects javascript shortcode links', () => {
  const holder = document.createElement('div');
  holder.innerHTML = renderToStaticMarkup(<>{renderRichTextLines('<img src=x onerror=alert(1)> [button:<svg onload=alert(1)>|https://example.test] [button:x|javascript:alert(1)]')}</>);
  expect(holder.querySelector('img,svg,script')).toBeNull(); expect(holder.querySelectorAll('a')).toHaveLength(1);
});
it('does not restore user/profile from delayed me after logout', async () => {
  let resolve: any; mocks.get.mockReturnValueOnce(new Promise(r => { resolve = r; }));
  sessionStore.rotate('old'); await mount();
  await act(async () => state.logout());
  await act(async () => resolve({ data: { user: { id: 'old-user' }, profile: { id: 'private-profile' } } }));
  expect(state.user).toBeNull(); expect(state.profile).toBeNull(); expect(state.token).toBeNull();
});
it('old 401 cannot delete newer login', async () => {
  let reject: any; mocks.get.mockReturnValueOnce(new Promise((_r, j) => { reject = j; }));
  sessionStore.rotate('old'); await mount();
  mocks.login.mockResolvedValueOnce({ token: 'new', user: { id: 'new-user' } });
  mocks.get.mockResolvedValueOnce({ data: { user: { id: 'new-user' }, profile: null } });
  await act(async () => state.login('email', 'password'));
  await act(async () => reject({ isAxiosError: true, response: { status: 401 } }));
  expect(state.token).toBe('new'); expect(state.user.id).toBe('new-user');
  expect(localStorage.getItem('studyBirdsToken')).toBeNull();
});
it('pending login cannot restore credentials after logout', async () => {
  mocks.post.mockRejectedValueOnce({ isAxiosError: true, response: { status: 400 } }); await mount();
  let resolve: any; mocks.login.mockReturnValueOnce(new Promise(r => { resolve = r; }));
  let pending: Promise<any>;
  await act(async () => { pending = state.login('email', 'password').catch(() => undefined); });
  await act(async () => state.logout());
  await act(async () => { resolve({ token: 'late', user: { id: 'old' } }); await pending; });
  expect(state.user).toBeNull(); expect(state.token).toBeNull();
});
it('logout in another tab clears all displayed session data', async () => {
  sessionStore.rotate('old'); mocks.get.mockResolvedValue({ data: { user: { id: 'user' }, profile: { id: 'private' } } }); await mount();
  await act(async () => window.dispatchEvent(new StorageEvent('storage', { key: 'studyBirdsLogout', newValue: 'signal' })));
  expect(state.user).toBeNull(); expect(state.profile).toBeNull(); expect(state.token).toBeNull();
});
