import { afterEach, expect, it, vi } from 'vitest';
import { AxiosError } from 'axios';
vi.mock('./connectivity', () => ({ configureConnectivity: vi.fn(), connectivity: {} }));
vi.mock('./apiResilience', () => ({ installResilience: vi.fn() }));
import { api } from './api';
import { sessionStore } from './sessionStore';

const adapter = api.defaults.adapter;
afterEach(() => { api.defaults.adapter = adapter; sessionStore.clear(); });
it('renews an expired session and saves the same program payload once', async () => {
  sessionStore.rotate('expired');
  let saved = 0;
  let refreshed = 0;
  api.defaults.adapter = async config => {
    if (config.url === '/auth/refresh') {
      refreshed++;
      return { data: { token: 'renewed' }, status: 200, statusText: 'OK', headers: {}, config };
    }
    if (config.headers.Authorization === 'Bearer expired') throw new AxiosError('Expired', 'ERR_BAD_RESPONSE', config, undefined,
      { data: {}, status: 401, statusText: 'Unauthorized', headers: {}, config });
    expect(config.headers.Authorization).toBe('Bearer renewed');
    expect(JSON.parse(config.data)).toEqual({ title: 'Third program' });
    saved++;
    return { data: { ok: true }, status: 201, statusText: 'Created', headers: {}, config };
  };
  await api.post('/admin/programs', { title: 'Third program' });
  expect(refreshed).toBe(1);
  expect(saved).toBe(1);
  expect(sessionStore.get().token).toBe('renewed');
});
it('preserves the session when renewal fails temporarily', async () => {
  sessionStore.rotate('expired');
  api.defaults.adapter = async config => {
    const status = config.url === '/auth/refresh' ? 503 : 401;
    throw new AxiosError('Unavailable', 'ERR_BAD_RESPONSE', config, undefined,
      { data: {}, status, statusText: 'Unavailable', headers: {}, config });
  };
  await expect(api.post('/admin/programs', { title: 'Third program' })).rejects.toThrow();
  expect(sessionStore.get().token).toBe('expired');
});
