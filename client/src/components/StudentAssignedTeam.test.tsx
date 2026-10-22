import { act } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import { StudentAssignedTeam } from './StudentAssignedTeam';
import { api } from '../lib/api';
vi.mock('../lib/api', () => ({ api: { get: vi.fn() } }));
let root: Root, host: HTMLDivElement;
beforeEach(() => {
  vi.useFakeTimers();
  Object.defineProperty(document, 'hidden', { configurable: true, value: false });
  (globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
  host = document.createElement('div'); document.body.append(host); root = createRoot(host);
});
afterEach(() => { act(() => root.unmount()); host.remove(); vi.useRealTimers(); vi.resetAllMocks(); });
it('refreshes assigned members and removes previous members without listing other accounts', async () => {
  vi.mocked(api.get).mockResolvedValueOnce({ data: [{ _id: 'one', name: 'First employee' }] });
  await act(async () => root.render(<StudentAssignedTeam ar={false} />));
  expect(api.get).toHaveBeenCalledWith('/students/support-team');
  expect(host.textContent).toContain('First employee');
  vi.mocked(api.get).mockResolvedValueOnce({ data: [{ _id: 'two', name: 'New employee' }] });
  await act(async () => { await vi.advanceTimersByTimeAsync(15000); });
  expect(host.textContent).toContain('New employee');
  expect(host.textContent).not.toContain('First employee');
  vi.mocked(api.get).mockResolvedValueOnce({ data: [] });
  await act(async () => { window.dispatchEvent(new Event('focus')); });
  expect(host.textContent).toContain('No support team has been assigned yet.');
  expect(host.textContent).not.toContain('New employee');
});
it('clears stale names on failure and recovers on refresh', async () => {
  vi.mocked(api.get).mockRejectedValueOnce(new Error('offline'));
  await act(async () => root.render(<StudentAssignedTeam ar />));
  expect(host.querySelector('[role="alert"]')).not.toBeNull();
  vi.mocked(api.get).mockResolvedValueOnce({ data: [{ _id: 'one', name: 'Assigned employee' }] });
  await act(async () => { await vi.advanceTimersByTimeAsync(15000); });
  expect(host.textContent).toContain('Assigned employee');
  expect(host.querySelector('[role="alert"]')).toBeNull();
});
