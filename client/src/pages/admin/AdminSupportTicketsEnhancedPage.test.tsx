import { act } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import { AdminSupportTicketsEnhancedPage } from './AdminSupportTicketsEnhancedPage';
import { adminService } from '../../services/adminService';
import type { SupportTicketItem } from '../../types';
vi.mock('../../hooks/useLanguage', () => ({ useLanguage: () => ({ language: 'en' }) }));
vi.mock('../../services/adminService', () => ({ adminService: { getSupportTickets: vi.fn(), replySupportTicket: vi.fn() } }));
const ticket = { _id: 'ticket', subject: 'Question', message: 'Help', status: 'open', replies: [], createdAt: '2026-10-30T00:00:00Z' } as unknown as SupportTicketItem;
let host: HTMLDivElement;
let root: Root;
beforeEach(async () => {
  vi.clearAllMocks();
  vi.mocked(adminService.getSupportTickets).mockResolvedValue([ticket]);
  vi.mocked(adminService.replySupportTicket).mockResolvedValue({ ...ticket, status: 'in-progress' });
  (globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
  host = document.createElement('div'); document.body.append(host); root = createRoot(host);
  await act(async () => root.render(<AdminSupportTicketsEnhancedPage />));
});
afterEach(() => { act(() => root.unmount()); host.remove(); });
it('saves a staff status change without requiring a typed reply and preserves drafts', async () => {
  const textarea = host.querySelector('textarea')!;
  act(() => {
    Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value')!.set!.call(textarea, 'Unsent draft');
    textarea.dispatchEvent(new Event('input', { bubbles: true }));
    const select = host.querySelector('article select') as HTMLSelectElement;
    select.value = 'in-progress'; select.dispatchEvent(new Event('change', { bubbles: true }));
  });
  const button = [...host.querySelectorAll('button')].find(b => b.textContent === 'Save status')!;
  await act(async () => button.click());
  expect(adminService.replySupportTicket).toHaveBeenCalledWith('ticket', { status: 'in-progress', message: 'Ticket status changed to: In progress' });
  expect(textarea.value).toBe('Unsent draft');
  expect(host.textContent).toContain('Status updated.');
});
