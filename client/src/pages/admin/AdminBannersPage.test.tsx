import { act } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import { AdminBannersPage } from './AdminBannersPage';
import { adminService } from '../../services/adminService';

vi.mock('../../hooks/useLanguage', () => ({ useLanguage: () => ({ language: 'en' }) }));
vi.mock('../../services/adminService', () => ({ adminService: {
  getBanners: vi.fn(), uploadBannerImage: vi.fn(), createBanner: vi.fn(), updateBanner: vi.fn(),
} }));
let host: HTMLDivElement;
let root: Root;
beforeEach(async () => {
  vi.clearAllMocks();
  vi.mocked(adminService.getBanners).mockResolvedValue([]);
  (globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
  host = document.createElement('div'); document.body.append(host); root = createRoot(host);
  await act(async () => root.render(<AdminBannersPage />));
});
afterEach(() => { act(() => root.unmount()); host.remove(); });
async function pick() {
  const input = host.querySelector<HTMLInputElement>('input[type=file]')!;
  Object.defineProperty(input, 'files', { value: [new File(['image'], 'chosen.png', { type: 'image/png' })] });
  await act(async () => input.dispatchEvent(new Event('change', { bubbles: true })));
}
async function submit() {
  await act(async () => host.querySelector('form')!.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true })));
}
it('waits for the selected image and saves its uploaded URL', async () => {
  let complete!: (url: string) => void;
  vi.mocked(adminService.uploadBannerImage).mockReturnValue(new Promise(resolve => { complete = resolve; }));
  await pick();
  expect(host.querySelector<HTMLButtonElement>('button[type=submit]')!.disabled).toBe(true);
  await submit(); expect(adminService.createBanner).not.toHaveBeenCalled();
  await act(async () => complete('https://example.test/chosen.png'));
  expect(host.querySelector('img')?.getAttribute('src')).toBe('https://example.test/chosen.png');
  await submit();
  expect(adminService.createBanner).toHaveBeenCalledWith(expect.objectContaining({ imageUrl: 'https://example.test/chosen.png' }));
});
it('shows upload failure and blocks silently saving a fallback image', async () => {
  vi.mocked(adminService.uploadBannerImage).mockRejectedValue(new Error('Upload unavailable'));
  await pick(); await submit();
  expect(host.textContent).toContain('Upload unavailable');
  expect(adminService.createBanner).not.toHaveBeenCalled();
  expect(host.querySelector<HTMLButtonElement>('button[type=submit]')!.disabled).toBe(true);
});
