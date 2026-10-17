import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { AxiosError, type AxiosAdapter } from 'axios';
vi.mock('./connectivity', () => ({ configureConnectivity: vi.fn(), connectivity: {} }));
vi.mock('./apiResilience', () => ({ installResilience: vi.fn() }));
import { api, downloadApiAsset, privateDocumentId } from './api';
import { sessionStore } from './sessionStore';
import { authService } from '../services/authService';

const originalAdapter = api.defaults.adapter;
function adapter(run: AxiosAdapter) { api.defaults.adapter = run; }
beforeEach(() => { localStorage.clear(); sessionStore.clear(); });
afterEach(() => { api.defaults.adapter = originalAdapter; localStorage.clear(); });

describe('security credential replacement and logout', () => {
  it('sends the captured logout token after local credentials have been removed', async () => {
    sessionStore.rotate('old-token');
    adapter(async config => {
      expect(config.url).toBe('/auth/logout');
      expect(config.headers.Authorization).toBe('Bearer old-token');
      return { data: { ok: true }, status: 200, statusText: 'OK', headers: {}, config };
    });
    const pending = authService.logout('old-token');
    sessionStore.clear();
    await pending;
  });
  it('never replaces explicit logout credentials with a new account token', async () => {
    sessionStore.rotate('new-account');
    adapter(async config => {
      expect(config.headers.Authorization).toBe('Bearer old-account');
      return { data: { ok: true }, status: 200, statusText: 'OK', headers: {}, config };
    });
    await authService.logout('old-account');
  });
  it('keeps replacement credentials only in memory after password change', async () => {
    sessionStore.rotate('old-token');
    adapter(async config => ({ data: { token: 'replacement' }, status: 200, statusText: 'OK', headers: {}, config }));
    await api.post('/auth/change-password', {});
    expect(sessionStore.get().token).toBe('replacement');
  });
  it('does not restore a logged-out or switched session from a late response', async () => {
    sessionStore.rotate('old-token');
    adapter(async config => {
      sessionStore.rotate('different-session');
      return { data: { token: 'replacement' }, status: 200, statusText: 'OK', headers: {}, config };
    });
    await api.post('/auth/change-password', {});
    expect(sessionStore.get().token).toBe('different-session');
  });
  it('clears the current session on authenticated API 401, but preserves it on 403', async () => {
    sessionStore.rotate('current');
    adapter(async config => { throw new AxiosError('Forbidden', 'ERR_BAD_RESPONSE', config, undefined,
      { data: {}, status: 403, statusText: 'Forbidden', headers: {}, config }); });
    await expect(api.get('/students/profile')).rejects.toThrow();
    expect(sessionStore.get().token).toBe('current');
    adapter(async config => { throw new AxiosError('Expired', 'ERR_BAD_RESPONSE', config, undefined,
      { data: {}, status: 401, statusText: 'Unauthorized', headers: {}, config }); });
    await expect(api.get('/students/profile')).rejects.toThrow();
    expect(sessionStore.get().token).toBeNull();
  });
  it('an old request 401 cannot clear another account session', async () => {
    sessionStore.rotate('old');
    adapter(async config => {
      sessionStore.rotate('new');
      throw new AxiosError('Expired', 'ERR_BAD_RESPONSE', config, undefined,
        { data: {}, status: 401, statusText: 'Unauthorized', headers: {}, config });
    });
    await expect(api.get('/students/profile')).rejects.toThrow();
    expect(sessionStore.get().token).toBe('new');
  });
  it('auth/me 401 clears the matching session; login failure does not', async () => {
    sessionStore.rotate('current');
    adapter(async config => { throw new AxiosError('Unauthorized', 'ERR_BAD_RESPONSE', config, undefined,
      { data: {}, status: 401, statusText: 'Unauthorized', headers: {}, config }); });
    await expect(api.post('/auth/login', {})).rejects.toThrow();
    expect(sessionStore.get().token).toBe('current');
    await expect(api.get('/auth/me')).rejects.toThrow();
    expect(sessionStore.get().token).toBeNull();
    expect(sessionStore.get().user).toBeNull();
    expect(sessionStore.get().profile).toBeNull();
  });
  it('never sends API credentials to an external origin', async () => {
    sessionStore.rotate('current');
    const send = vi.fn(); adapter(send);
    await expect(api.get('https://evil.example/collect')).rejects.toThrow('External API origin rejected');
    expect(send).not.toHaveBeenCalled();
  });
});

it('verification documents use the protected POST endpoint, never a public anchor', async () => {
  const path = '/api/verification-documents/012345678901234567890123/access';
  expect(privateDocumentId(path)).toBe('012345678901234567890123');
  sessionStore.rotate('verification-session');
  adapter(async config => {
    expect(config.url).toBe(path.slice(4));
    expect(config.method).toBe('post');
    expect(config.headers.Authorization).toBe('Bearer verification-session');
    return { data: { url: 'https://api.cloudinary.com/v1_1/test/raw/download?signature=test' }, status: 200, statusText: 'OK', headers: {}, config };
  });
  const click = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => {});
  try { await downloadApiAsset(path); expect(click).toHaveBeenCalledOnce(); }
  finally { click.mockRestore(); }
});
