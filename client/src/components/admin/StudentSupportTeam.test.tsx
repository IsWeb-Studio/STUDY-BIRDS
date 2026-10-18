import { act } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import { api } from '../../lib/api';
import { StudentSupportTeam } from './StudentSupportTeam';
vi.mock('../../lib/api', () => ({ api: { get: vi.fn(), put: vi.fn() } }));
let root: Root, host: HTMLDivElement;
beforeEach(() => {
  (globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
  host = document.createElement('div'); document.body.append(host); root = createRoot(host);
  vi.mocked(api.get).mockResolvedValue({ data: { members: [{ _id: 'one', name: 'One' }], candidates: [{ _id: 'one', name: 'One' }, { _id: 'two', name: 'Two' }], canEdit: true } });
  vi.mocked(api.put).mockResolvedValue({ data: { members: [{ _id: 'one', name: 'One' }, { _id: 'two', name: 'Two' }] } });
});
afterEach(() => { act(() => root.unmount()); host.remove(); vi.clearAllMocks(); });
it('loads assigned members and saves multiple selected staff', async () => {
  await act(async () => root.render(<StudentSupportTeam studentId="student" ar={false} />));
  const inputs = host.querySelectorAll<HTMLInputElement>('input');
  expect(inputs[0].checked).toBe(true); expect(inputs[1].checked).toBe(false);
  await act(async () => inputs[1].click());
  await act(async () => host.querySelector<HTMLButtonElement>('button')!.click());
  expect(api.put).toHaveBeenCalledWith('/admin/students/student/support-team', { memberIds: ['one', 'two'] });
  expect(host.textContent).toContain('Team saved.');
});
it('read-only staff see names without assignment controls', async () => {
  vi.mocked(api.get).mockResolvedValue({ data: { members: [{ _id: 'one', name: 'One' }], candidates: [], canEdit: false } });
  await act(async () => root.render(<StudentSupportTeam studentId="student" ar={false} />));
  expect(host.textContent).toContain('One'); expect(host.querySelector('input')).toBeNull(); expect(host.querySelector('button')).toBeNull();
});
