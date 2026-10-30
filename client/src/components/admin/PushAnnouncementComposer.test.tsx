import { act } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import { api } from '../../lib/api';
import { PushAnnouncementComposer } from './PushAnnouncementComposer';

const auth = vi.hoisted(() => ({ role: 'admin' }));
vi.mock('../../hooks/useAuth', () => ({ useAuth: () => ({ user: auth }) }));
vi.mock('../../hooks/useLanguage', () => ({ useLanguage: () => ({ language: 'en' }) }));
vi.mock('../../lib/api', () => ({ api: { get: vi.fn(), post: vi.fn() } }));
let host: HTMLDivElement, root: Root;
beforeEach(async () => {
  vi.clearAllMocks(); auth.role = 'admin';
  vi.spyOn(window, 'confirm').mockReturnValue(true);
  vi.mocked(api.get).mockResolvedValue({ data: { enabled: true, items: [] } });
  vi.mocked(api.post).mockResolvedValue({ data: { status: 'accepted' } });
  (globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
  host = document.createElement('div'); document.body.append(host); root = createRoot(host);
  await act(async () => root.render(<PushAnnouncementComposer />));
});
afterEach(() => { act(() => root.unmount()); host.remove(); vi.restoreAllMocks(); });
function fill(selector: string, value: string, type: typeof HTMLInputElement | typeof HTMLTextAreaElement) {
  const input = host.querySelector(selector)!;
  act(() => { Object.getOwnPropertyDescriptor(type.prototype, 'value')!.set!.call(input, value); input.dispatchEvent(new Event('input', { bubbles: true })); });
}
async function submit() { await act(async () => { host.querySelector('form')!.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true })); }); }
it('confirms mass sends and uses the same key after an uncertain failure', async () => {
  fill('input', 'App update', HTMLInputElement); fill('textarea', 'New features', HTMLTextAreaElement);
  vi.mocked(window.confirm).mockReturnValueOnce(false);
  await submit(); expect(api.post).not.toHaveBeenCalled();
  vi.mocked(api.post).mockRejectedValueOnce(new Error('Synthetic timeout'));
  await submit();
  const first = vi.mocked(api.post).mock.calls[0][1];
  expect(host.textContent).toContain('Retry same announcement');
  expect(host.querySelector('textarea')!.disabled).toBe(true);
  await submit();
  expect(vi.mocked(api.post).mock.calls[1][1]).toEqual(first);
  expect(host.textContent).toContain('Accepted by push service');
  expect(host.querySelector('input')!.value).toBe('');
});
it('retries a historical campaign by its original ID', async () => {
  vi.mocked(api.get).mockResolvedValue({ data: { enabled: true, items: [{ _id: 'original', requestId: 'original-request', title: 'Update', body: 'Features', status: 'uncertain', createdAt: new Date().toISOString() }] } });
  await act(async () => root.render(<PushAnnouncementComposer key="history" />));
  const retry = [...host.querySelectorAll('button')].find(b => b.textContent === 'Retry without duplicate delivery')!;
  await act(async () => retry.click());
  expect(api.post).toHaveBeenCalledWith('/admin/push-announcements', { title: 'Update', body: 'Features', requestId: 'original-request', announcementId: 'original' });
});
it('hides publishing from non-admin accounts', async () => {
  auth.role = 'employee'; vi.mocked(api.get).mockClear();
  await act(async () => root.render(<PushAnnouncementComposer key="employee" />));
  expect(host.querySelector('form')).toBeNull(); expect(api.get).not.toHaveBeenCalled();
});
