import { act } from 'react';
import { createRoot } from 'react-dom/client';
import { expect, it, vi } from 'vitest';
import { PartnerKnowledgeBasePage } from './PartnerKnowledgeBasePage';
vi.mock('../../hooks/useLanguage', () => ({ useLanguage: () => ({ language: 'en' }) }));
vi.mock('../../services/partnerService', () => ({ partnerService: { getKnowledgeBase: async () => [{
  _id: 'guide', title: 'Guide', body: 'Instructions', videoUrl: '', fileUrl: 'https://example.test/guide.pdf',
}] } }));
it('shows a file resource when the video field is empty', async () => {
  (globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
  const host = document.createElement('div'); document.body.append(host);
  const root = createRoot(host);
  try {
    await act(async () => root.render(<PartnerKnowledgeBasePage />));
    expect(host.querySelector('a')?.href).toBe('https://example.test/guide.pdf');
    expect(host.textContent).toContain('Open resource');
  } finally { act(() => root.unmount()); host.remove(); }
});
