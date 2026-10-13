import { useEffect, useState } from 'react';
import { api } from '../../lib/api';
import { useLanguage } from '../../hooks/useLanguage';
import { AdminConfirmationModal } from './AdminConfirmationModal';

type Stage = { key: string; titleAr: string; titleEn: string; recordedStatus: string; descriptionAr: string; dueAt: string | null; reference: string; updatedAt: string | null };
type Journey = { version: number; eligible: boolean; stages: Stage[] };
const statuses = [
  ['not-started', 'لم تبدأ', 'Not started'], ['in-progress', 'قيد التنفيذ', 'In progress'],
  ['action-required', 'مطلوب من الطالب', 'Student action required'], ['waiting-team', 'بانتظار الفريق', 'Waiting for team'],
  ['waiting-university', 'بانتظار الجامعة', 'Waiting for university'], ['completed', 'مكتملة', 'Completed'],
  ['not-required', 'غير مطلوبة', 'Not required'],
];
export function ApplicationPostAdmission({ id }: { id: string }) {
  const ar = useLanguage().language === 'ar';
  const [data, setData] = useState<Journey>();
  const [stage, setStage] = useState('visa');
  const [status, setStatus] = useState('not-started');
  const [note, setNote] = useState(''); const [reference, setReference] = useState('');
  const [due, setDue] = useState(''); const [busy, setBusy] = useState(false);
  const [error, setError] = useState(''); const [confirm, setConfirm] = useState(false);
  function choose(key: string, journey = data) {
    setStage(key);
    const row = journey?.stages.find(s => s.key === key);
    setStatus(row?.recordedStatus || 'not-started');
    setNote(row?.updatedAt ? row.descriptionAr : ''); setReference(row?.reference || '');
    const date = row?.dueAt ? new Date(row.dueAt) : null;
    setDue(date ? new Date(date.getTime() - date.getTimezoneOffset() * 60000).toISOString().slice(0, 16) : '');
  }
  async function load() {
    setBusy(true); setError('');
    try {
      const result = (await api.get<Journey>(`/applications/${id}/post-admission`)).data;
      setData(result); choose(stage, result);
    } catch { setError(ar ? 'تعذر تحميل المراحل. أعد المحاولة.' : 'Unable to load stages. Retry.'); }
    finally { setBusy(false); }
  }
  useEffect(() => { void load(); }, [id]);
  async function save() {
    if (!data) return;
    setBusy(true); setError('');
    try {
      const result = (await api.patch<Journey>(`/applications/${id}/post-admission`, {
        version: data.version, stage, status, note: note.trim(), reference: reference.trim(),
        dueAt: due ? new Date(due).toISOString() : null,
      })).data;
      setData(result); choose(stage, result);
    } catch { setError(ar ? 'تعذر الحفظ. حدّث البيانات إذا تغير الطلب، وتحقق من الملاحظة ومرجع الإكمال.' : 'Unable to save. Refresh if the application changed; check the note and completion reference.'); }
    finally { setBusy(false); setConfirm(false); }
  }
  const ready = note.trim() && (status !== 'completed' || reference.trim());
  const inputClass = 'mt-1 min-h-11 w-full rounded-xl border border-slate-200 bg-white p-2';
  return <section className="my-4 rounded-2xl border border-slate-200 p-4">
    <h3 className="font-semibold">{ar ? 'رحلة ما بعد القبول' : 'Post-admission journey'}</h3>
    <p className="mt-2 text-sm text-slate-600">{ar ? 'الملاحظات والمواعيد والمراجع أدناه تظهر للطالب. لا تسجل مرحلة كمكتملة قبل التحقق منها.' : 'Notes, deadlines and references are visible to the student. Verify each stage before marking it complete.'}</p>
    {data && !data.eligible && <p className="mt-3 text-sm">{ar ? 'تتاح المتابعة بعد القبول النهائي للطلب غير المغلق.' : 'Available after final admission on an open application.'}</p>}
    {data?.eligible && <div className="mt-3 grid gap-3 sm:grid-cols-2">
      <label>{ar ? 'المرحلة' : 'Stage'}<select className={inputClass} disabled={busy} value={stage} onChange={e => choose(e.target.value)}>{data.stages.map(s => <option key={s.key} value={s.key}>{ar ? s.titleAr : s.titleEn}</option>)}</select></label>
      <label>{ar ? 'الحالة' : 'Status'}<select className={inputClass} disabled={busy} value={status} onChange={e => setStatus(e.target.value)}>{statuses.map(s => <option key={s[0]} value={s[0]}>{s[ar ? 1 : 2]}</option>)}</select></label>
      <label>{ar ? 'الموعد بتوقيت جهازك (اختياري)' : 'Deadline in local time (optional)'}<input type="datetime-local" className={inputClass} disabled={busy} value={due} onChange={e => setDue(e.target.value)} /></label>
      <label>{ar ? 'مرجع التحقق (إلزامي عند الإكمال)' : 'Verification reference (required for completion)'}<input maxLength={250} className={inputClass} disabled={busy} value={reference} onChange={e => setReference(e.target.value)} /></label>
      <label className="sm:col-span-2">{ar ? 'ملاحظة واضحة للطالب والخطوة المطلوبة' : 'Student-facing note and required next step'}<textarea maxLength={2000} rows={3} className={inputClass} disabled={busy} value={note} onChange={e => setNote(e.target.value)} /></label>
      <button className="min-h-11 rounded-xl bg-slate-900 px-4 text-white disabled:opacity-50" disabled={busy || !ready} onClick={() => setConfirm(true)}>{ar ? 'حفظ المرحلة' : 'Save stage'}</button>
    </div>}
    {error && <p role="alert" className="mt-3 text-sm text-red-700">{error}</p>}
    <button className="mt-2 min-h-11 text-sm" disabled={busy} onClick={() => void load()}>{ar ? 'تحديث المراحل' : 'Refresh stages'}</button>
    <AdminConfirmationModal open={confirm} title={ar ? 'تأكيد تحديث المرحلة' : 'Confirm stage update'} description={`${data?.stages.find(s => s.key === stage)?.[ar ? 'titleAr' : 'titleEn']} — ${statuses.find(s => s[0] === status)?.[ar ? 1 : 2]}: ${note}`} confirmLabel={ar ? 'تأكيد' : 'Confirm'} cancelLabel={ar ? 'رجوع' : 'Back'} loading={busy} onClose={() => { if (!busy) setConfirm(false); }} onConfirm={() => void save()} />
  </section>;
}
