import { useEffect, useState } from 'react';
import { api } from '../../lib/api';
import { getErrorMessage } from '../../utils/errors';

type Member = { _id: string; name: string };
type Team = { members: Member[]; candidates: Member[]; canEdit: boolean };
export function StudentSupportTeam({ studentId, ar }: { studentId: string; ar: boolean }) {
  const [team, setTeam] = useState<Team | null>(null);
  const [selected, setSelected] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [saved, setSaved] = useState(false);
  useEffect(() => {
    let active = true;
    setTeam(null); setError(''); setSaved(false);
    api.get<Team>(`/admin/students/${studentId}/support-team`).then(({ data }) => {
      if (active) { setTeam(data); setSelected(data.members.map(member => member._id)); }
    }).catch(issue => { if (active) setError(getErrorMessage(issue, ar ? 'تعذر تحميل الفريق' : 'Unable to load team')); });
    return () => { active = false; };
  }, [studentId, ar]);
  async function save() {
    if (busy) return;
    setBusy(true); setError(''); setSaved(false);
    try {
      const { data } = await api.put<{ members: Member[] }>(`/admin/students/${studentId}/support-team`, { memberIds: selected });
      setTeam(current => current ? { ...current, members: data.members } : current);
      setSaved(true);
    } catch (issue) { setError(getErrorMessage(issue, ar ? 'تعذر حفظ الفريق' : 'Unable to save team')); }
    finally { setBusy(false); }
  }
  return <section className="space-y-3 rounded-3xl border border-slate-200 p-5">
    <h3 className="font-semibold">{ar ? 'الموظفون المسؤولون عن الطالب' : 'Student support team'}</h3>
    <p className="text-sm text-slate-500">{ar ? 'يظهر هؤلاء الموظفون للطالب في «فريقي» ويتابعون تذاكره. يمكنك اختيار عدة موظفين لديهم صلاحية الدعم.' : 'These employees appear in My Team and handle this student’s tickets. Select multiple employees with support access.'}</p>
    {error && <p role="alert" className="text-sm text-rose-600">{error}</p>}
    {!team && !error && <p>{ar ? 'جارٍ التحميل...' : 'Loading...'}</p>}
    {team?.canEdit ? <>
      <div className="max-h-64 space-y-2 overflow-auto">
        {team.candidates.map(member => <label key={member._id} className="flex items-center gap-3 rounded-xl border p-3">
          <input type="checkbox" disabled={busy} checked={selected.includes(member._id)} onChange={event => {
            setSaved(false); setSelected(current => event.target.checked ? [...current, member._id] : current.filter(id => id !== member._id));
          }} />{member.name}
        </label>)}
        {!team.candidates.length && <p>{ar ? 'لا يوجد موظفون نشطون لديهم صلاحية الدعم.' : 'No active support employees.'}</p>}
      </div>
      <button type="button" disabled={busy} onClick={save} className="rounded-xl bg-brand-700 px-4 py-2 text-white disabled:opacity-50">{busy ? (ar ? 'جارٍ الحفظ...' : 'Saving...') : (ar ? 'حفظ الفريق' : 'Save team')}</button>
    </> : team && <p>{team.members.map(member => member.name).join('، ') || (ar ? 'لم يتم تعيين فريق بعد.' : 'No team assigned yet.')}</p>}
    {saved && <p role="status" className="text-sm text-emerald-700">{ar ? 'تم حفظ الفريق.' : 'Team saved.'}</p>}
  </section>;
}
