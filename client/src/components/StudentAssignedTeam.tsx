import { useEffect, useState } from 'react';
import { api } from '../lib/api';

type Member = { _id: string; name: string };
export function StudentAssignedTeam({ ar }: { ar: boolean }) {
  const [members, setMembers] = useState<Member[]>([]);
  const [status, setStatus] = useState<'loading' | 'ready' | 'error'>('loading');
  useEffect(() => {
    let active = true;
    let busy = false;
    async function refresh() {
      if (busy) return;
      busy = true;
      try {
        const { data } = await api.get<Member[]>('/students/support-team');
        if (active) { setMembers(data); setStatus('ready'); }
      } catch {
        if (active) { setMembers([]); setStatus('error'); }
      } finally { busy = false; }
    }
    const update = () => { if (!document.hidden) void refresh(); };
    void refresh();
    const timer = window.setInterval(update, 15000);
    window.addEventListener('focus', update);
    document.addEventListener('visibilitychange', update);
    return () => { active = false; window.clearInterval(timer); window.removeEventListener('focus', update); document.removeEventListener('visibilitychange', update); };
  }, []);
  return <section className="panel space-y-3 p-6" aria-label={ar ? 'فريقي' : 'My team'}>
    <h2 className="text-xl font-semibold">{ar ? 'الموظفون المسؤولون عن متابعتك' : 'Your assigned support team'}</h2>
    {status === 'loading' ? <p>{ar ? 'جاري تحميل الفريق...' : 'Loading team...'}</p>
      : status === 'error' ? <p role="alert">{ar ? 'تعذر تحميل الفريق. سنحاول مجددًا تلقائيًا.' : 'Unable to load your team. Retrying automatically.'}</p>
      : members.length ? <ul className="space-y-2">{members.map(member => <li className="rounded-xl border border-slate-200 p-3" key={member._id}>{member.name}</li>)}</ul>
      : <p>{ar ? 'لم يتم تعيين موظفين مسؤولين عنك بعد.' : 'No support team has been assigned yet.'}</p>}
  </section>;
}
