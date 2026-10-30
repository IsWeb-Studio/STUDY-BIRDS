import { act } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import { AccountDeletionRequestPage } from './AccountDeletionRequestPage';
import { api } from '../lib/api';

vi.mock('../hooks/useLanguage', () => ({ useLanguage: () => ({ language: 'en' }) }));
vi.mock('../lib/api', () => ({ api: { post: vi.fn() } }));
vi.mock('../components/seo/Seo', () => ({ Seo: () => null }));
let host: HTMLDivElement;
let root: Root;
beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(api.post).mockResolvedValue({ data: { ok: true } });
  (globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
  host = document.createElement('div');
  document.body.append(host);
  root = createRoot(host);
  act(() => root.render(<MemoryRouter><AccountDeletionRequestPage /></MemoryRouter>));
});
afterEach(() => { act(() => root.unmount()); host.remove(); });
function fill(selector: string, value: string) {
  const input = host.querySelector<HTMLInputElement>(selector)!;
  act(() => {
    Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')!.set!.call(input, value);
    input.dispatchEvent(new Event('input', { bubbles: true }));
  });
}
async function submit() {
  await act(async () => { host.querySelector('form')!.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true })); });
}
it('requests email verification before accepting permanent deletion without login or app installation', async () => {
  expect(api.post).not.toHaveBeenCalled();
  fill('input[type=email]', 'alice@example.test');
  await submit();
  expect(api.post).toHaveBeenLastCalledWith('/auth/account-deletion/request', { email: 'alice@example.test' });
  expect(host.textContent).toContain('If the email belongs to an active account');
  fill('input[autocomplete=one-time-code]', '123456');
  await submit();
  expect(api.post).toHaveBeenLastCalledWith('/auth/account-deletion/confirm', { email: 'alice@example.test', code: '123456' });
  expect(host.textContent).toContain('Deletion confirmed and account access disabled');
  expect(host.querySelector('form')).toBeNull();
});
it('keeps the verification step available after a failed confirmation', async () => {
  fill('input[type=email]', 'alice@example.test');
  await submit();
  vi.mocked(api.post).mockRejectedValueOnce(new Error('Synthetic unavailable service'));
  fill('input[autocomplete=one-time-code]', '000000');
  await submit();
  expect(host.querySelector('[role=alert]')).not.toBeNull();
  expect(host.querySelector('input[autocomplete=one-time-code]')).not.toBeNull();
  expect(host.textContent).not.toContain('Deletion confirmed');
});
