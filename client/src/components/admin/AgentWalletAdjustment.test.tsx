import { act } from 'react';
import { createRoot } from 'react-dom/client';
import { expect, it, vi } from 'vitest';
import { AgentWalletAdjustment } from './AgentWalletAdjustment';
import { api } from '../../lib/api';
vi.mock('../../lib/api', () => ({ api: { post: vi.fn() } }));
it('records only an explicitly confirmed adjustment and sends the amount and reason', async () => {
  (globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
  const confirm = vi.spyOn(window, 'confirm').mockReturnValue(false);
  vi.mocked(api.post).mockResolvedValue({ data: { _id: 'entry' } });
  const host = document.createElement('div'); document.body.append(host); const root = createRoot(host);
  try {
    act(() => root.render(<AgentWalletAdjustment ar={false} />));
    for (const [label, value] of [['Agent ID', 'a'.repeat(24)], ['Amount', '100'], ['Reason', 'Approved commission']]) {
      const input = host.querySelector<HTMLInputElement>(`[aria-label="${label}"]`)!;
      act(() => { Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')!.set!.call(input, value); input.dispatchEvent(new Event('input', { bubbles: true })); });
    }
    const submit = async () => { await act(async () => host.querySelector('form')!.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }))); };
    await submit(); expect(api.post).not.toHaveBeenCalled();
    confirm.mockReturnValue(true); await submit();
    expect(api.post).toHaveBeenCalledWith('/admin/payout-requests/wallet-entries', {
      studentId: 'a'.repeat(24), amount: 100, direction: 'credit', notes: 'Approved commission',
    });
    expect(host.textContent).toContain('Adjustment recorded in the agent wallet.');
  } finally { act(() => root.unmount()); host.remove(); confirm.mockRestore(); }
});
