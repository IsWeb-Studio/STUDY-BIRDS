import { useEffect, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { api } from '../lib/api';
import { useLanguage } from '../hooks/useLanguage';

type Stage = { key: string; titleAr: string; titleEn: string; status: string; descriptionAr: string; dueAt: string | null; reference: string };
const labels: Record<string, [string, string]> = {
  'not-started': ['لم تبدأ', 'Not started'], 'in-progress': ['قيد التنفيذ', 'In progress'],
  'action-required': ['مطلوب منك', 'Action required'], 'waiting-team': ['بانتظار الفريق', 'Waiting for team'],
  'waiting-university': ['بانتظار الجامعة', 'Waiting for university'], 'completed': ['مكتملة', 'Completed'],
  'not-required': ['غير مطلوبة', 'Not required'], 'overdue': ['متأخرة', 'Overdue'],
};
export function StudentPostAdmission({ applicationId }: { applicationId: string }) {
  const ar = useLanguage().language === 'ar'; const { hash } = useLocation();
  const [open, setOpen] = useState(false); const [data, setData] = useState<Stage[]>();
  const [busy, setBusy] = useState(false); const [error, setError] = useState(false);
  async function load() {
    setBusy(true); setError(false);
    try { setData((await api.get<{ stages: Stage[] }>(`/applications/${applicationId}/post-admission`)).data.stages); }
    catch { setError(true); }
    finally { setBusy(false); }
  }
  useEffect(() => {
    if (hash === `#journey-${applicationId}`) {
      setOpen(true); void load();
      document.getElementById(`journey-${applicationId}`)?.scrollIntoView({ block: 'start' });
    }
  }, [hash, applicationId]);
  return <section id={`journey-${applicationId}`} className="mt-4 rounded-2xl bg-white p-4">
    <button className="min-h-11 font-semibold" aria-expanded={open} onClick={() => { setOpen(!open); if (!open && !data) void load(); }}>{ar ? 'مراحل ما بعد القبول' : 'Post-admission journey'}</button>
    {open && <div className="space-y-3">
      {busy && <p role="status">{ar ? 'جاري التحميل…' : 'Loading…'}</p>}
      {error && <p role="alert">{ar ? 'تعذر تحميل المراحل. أعد المحاولة.' : 'Unable to load stages. Retry.'}</p>}
      {data?.length === 0 && <p>{ar ? 'تظهر المراحل بعد تسجيل القبول النهائي.' : 'Stages become available after final admission.'}</p>}
      {data?.map(s => <div key={s.key} className="rounded-xl border border-slate-200 p-3">
        <h3 className="font-semibold">{ar ? s.titleAr : s.titleEn} — <span className={s.status === 'overdue' ? 'text-red-700' : 'text-slate-600'}>{labels[s.status]?.[ar ? 0 : 1] || s.status}</span></h3>
        <p className="mt-2 text-sm">{s.descriptionAr}</p>
        {s.dueAt && <p className="mt-1 text-sm">{ar ? 'الموعد: ' : 'Deadline: '}{new Date(s.dueAt).toLocaleString(ar ? 'ar' : 'en')}</p>}
        {s.reference && <p className="mt-1 text-sm">{ar ? 'مرجع التحقق: ' : 'Verification reference: '}{s.reference}</p>}
      </div>)}
      <button disabled={busy} className="min-h-11 text-sm" onClick={() => void load()}>{ar ? 'تحديث المراحل' : 'Refresh stages'}</button>
      <Link to="/student/support" className="mx-3 inline-flex min-h-11 items-center text-sm text-brand-700">{ar ? 'التواصل مع الفريق' : 'Contact your team'}</Link>
    </div>}
  </section>;
}
