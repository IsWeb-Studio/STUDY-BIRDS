import { useEffect, useState } from 'react';
import { api } from '../../lib/api';

type User = { _id: string; name: string; email: string; role: string; isActive?: boolean };
type Access = { user: string; students: string[]; university?: string; manager: boolean };
type Task = { _id: string; title: string; status: string; assignedTo?: User; student?: User };
type Message = { _id: string; body: string; sender: User; recipient: User };
const roles: Record<string, string> = { student: 'طالب', parent: 'ولي أمر', partner: 'وكيل', university: 'جامعة', employee: 'موظف' };
const input = 'w-full rounded-xl border border-slate-300 bg-white p-3';
const button = 'rounded-xl bg-slate-900 px-5 py-3 text-white disabled:opacity-50';
const blank = { name: '', email: '', password: '', role: 'parent' };
export function MobileAccountsPanel() {
  const [data, setData] = useState<{ users: User[]; access: Access[]; universities: { _id: string; name: string }[]; tasks: Task[] }>({ users: [], access: [], universities: [], tasks: [] });
  const [account, setAccount] = useState(blank);
  const [selected, setSelected] = useState('');
  const [permission, setPermission] = useState({ students: [] as string[], university: '', manager: false });
  const [task, setTask] = useState({ title: '', description: '', assignedTo: '', student: '', dueDate: '', priority: 'normal' });
  const [messages, setMessages] = useState<Message[]>([]);
  const [reply, setReply] = useState({ recipient: '', body: '' });
  const [credit, setCredit] = useState({ user: '', amount: '', description: '' });
  const [credits, setCredits] = useState<{ _id: string; user?: User; amount: number; description: string }[]>([]);
  const [error, setError] = useState(''); const [busy, setBusy] = useState(false); const [notice, setNotice] = useState('');
  const load = async () => {
    const [result, inbox, ledger] = await Promise.all([api.get('/mobile-workspace/admin/accounts'), api.get('/mobile-workspace/messages'), api.get('/mobile-workspace/admin/credits')]);
    setData(result.data); setMessages(inbox.data); setCredits(ledger.data);
  };
  const act = async (work: () => Promise<unknown>, saved = true) => {
    setBusy(true); setError(''); setNotice('');
    try { await work(); await load(); setNotice(saved ? 'تم الحفظ' : ''); }
    catch (e) { setError((e as { response?: { data?: { message?: string } } }).response?.data?.message || 'تعذر تنفيذ العملية'); }
    finally { setBusy(false); }
  };
  useEffect(() => { void act(async () => {}, false); }, []);
  const user = data.users.find(x => x._id === selected);
  return <div className="space-y-6">
    {error && <p role="alert" className="rounded-xl bg-red-50 p-3 text-red-800">{error}</p>}
    {notice && <p role="status" className="text-green-700">{notice}</p>}
    <form className="space-y-3 rounded-2xl bg-white p-5" onSubmit={e => { e.preventDefault(); void act(async () => { await api.post('/mobile-workspace/admin/accounts', account); setAccount(blank); }); }}>
      <h2 className="text-xl font-bold">إنشاء حساب التطبيق</h2>
      <fieldset disabled={busy} className="grid gap-3 sm:grid-cols-2">
        <label>الاسم<input required className={input} value={account.name} onChange={e => setAccount({ ...account, name: e.target.value })} /></label>
        <label>البريد الإلكتروني<input required type="email" className={input} value={account.email} onChange={e => setAccount({ ...account, email: e.target.value })} /></label>
        <label>كلمة المرور الأولية<input required minLength={8} type="password" autoComplete="new-password" className={input} value={account.password} onChange={e => setAccount({ ...account, password: e.target.value })} /></label>
        <label>نوع الحساب<select className={input} value={account.role} onChange={e => setAccount({ ...account, role: e.target.value })}>{Object.entries(roles).map(([key, name]) => <option key={key} value={key}>{name}</option>)}</select></label>
        <button className={button}>إنشاء الحساب</button>
      </fieldset>
    </form>
    <section className="space-y-3 rounded-2xl bg-white p-5"><h2 className="text-xl font-bold">حسابات التطبيق</h2><div className="max-h-80 overflow-auto">{data.users.filter(x => x.role !== 'admin').map(x => <div key={x._id} className="flex flex-wrap items-center justify-between gap-3 border-b py-3"><p>{x.name} — {roles[x.role]}<br /><span dir="ltr">{x.email}</span></p><button disabled={busy} className={button} onClick={() => void act(() => api.patch(`/admin/users/${x._id}`, { isActive: x.isActive === false }))}>{x.isActive === false ? 'تفعيل الحساب' : 'تعطيل الحساب'}</button></div>)}</div></section>
    <form className="space-y-3 rounded-2xl bg-white p-5" onSubmit={e => { e.preventDefault(); void act(() => api.put(`/mobile-workspace/admin/accounts/${selected}/access`, permission)); }}>
      <h2 className="text-xl font-bold">ربط الحسابات وتحديد الصلاحيات</h2>
      <p>حدّد الطلاب الذين يمكن لولي الأمر أو الموظف الاطلاع عليهم، أو الجامعة التي يمثلها الحساب.</p>
      <fieldset disabled={busy} className="space-y-3">
        <select required aria-label="الحساب" className={input} value={selected} onChange={e => {
          setSelected(e.target.value); const found = data.access.find(x => x.user === e.target.value);
          setPermission({ students: found?.students || [], university: found?.university || '', manager: found?.manager || false });
        }}><option value="">اختر الحساب</option>{data.users.filter(x => ['parent', 'employee', 'university'].includes(x.role)).map(x => <option key={x._id} value={x._id}>{x.name} — {roles[x.role]} — {x.email}</option>)}</select>
        {user?.role === 'university' ? <label>الجامعة<select required className={input} value={permission.university} onChange={e => setPermission({ ...permission, university: e.target.value })}><option value="">اختر الجامعة</option>{data.universities.map(x => <option key={x._id} value={x._id}>{x.name}</option>)}</select></label>
          : user && <div className="max-h-72 overflow-auto rounded-xl border p-3">{data.users.filter(x => x.role === 'student').map(x => <label className="flex gap-3 p-2" key={x._id}><input type="checkbox" checked={permission.students.includes(x._id)} onChange={e => setPermission({ ...permission, students: e.target.checked ? [...permission.students, x._id] : permission.students.filter(id => id !== x._id) })} />{x.name} — {x.email}</label>)}</div>}
        {user?.role === 'employee' && <label className="flex gap-3"><input type="checkbox" checked={permission.manager} onChange={e => setPermission({ ...permission, manager: e.target.checked })} />السماح بمتابعة مهام الفريق للطلاب المرتبطين بهذا الموظف</label>}
        <button disabled={!selected} className={button}>حفظ الصلاحيات</button>
      </fieldset>
    </form>
    <form className="space-y-3 rounded-2xl bg-white p-5" onSubmit={e => { e.preventDefault(); void act(async () => { await api.post('/mobile-workspace/admin/tasks', task); setTask({ ...task, title: '', description: '' }); }); }}>
      <h2 className="text-xl font-bold">إسناد مهمة لموظف</h2>
      <fieldset disabled={busy} className="grid gap-3 sm:grid-cols-2">
        <label>عنوان المهمة<input required className={input} value={task.title} onChange={e => setTask({ ...task, title: e.target.value })} /></label>
        <label>التفاصيل<textarea className={input} value={task.description} onChange={e => setTask({ ...task, description: e.target.value })} /></label>
        <label>الموظف<select required className={input} value={task.assignedTo} onChange={e => setTask({ ...task, assignedTo: e.target.value, student: '' })}><option value="">اختر الموظف</option>{data.users.filter(x => x.role === 'employee').map(x => <option key={x._id} value={x._id}>{x.name}</option>)}</select></label>
        <label>الطالب<select className={input} value={task.student} onChange={e => setTask({ ...task, student: e.target.value })}><option value="">مهمة عامة</option>{data.users.filter(x => data.access.find(a => a.user === task.assignedTo)?.students.includes(x._id)).map(x => <option key={x._id} value={x._id}>{x.name}</option>)}</select></label>
        <label>الموعد النهائي<input type="date" className={input} value={task.dueDate} onChange={e => setTask({ ...task, dueDate: e.target.value })} /></label>
        <label>الأولوية<select className={input} value={task.priority} onChange={e => setTask({ ...task, priority: e.target.value })}><option value="normal">عادية</option><option value="urgent">عاجلة</option></select></label>
        <button className={button}>إسناد المهمة</button>
      </fieldset>
      {data.tasks.map(x => <p key={x._id} className="rounded-xl border p-3">{x.title} — {x.assignedTo?.name} — {({ pending: 'لم تبدأ', 'in-progress': 'قيد التنفيذ', completed: 'مكتملة' } as Record<string, string>)[x.status] || x.status}</p>)}
    </form>
    <form className="space-y-3 rounded-2xl bg-white p-5" onSubmit={e => { e.preventDefault(); void act(async () => { await api.post('/mobile-workspace/admin/credits', { ...credit, amount: Number(credit.amount) }); setCredit({ ...credit, amount: '', description: '' }); }); }}>
      <h2 className="text-xl font-bold">رصيد الطلاب ومكافآت الإحالة</h2><p>تسجيل إضافة أو خصم من رصيد الخدمات بالدولار. هذه العملية لا تحوّل أموالاً خارج النظام.</p>
      <fieldset disabled={busy} className="grid gap-3 sm:grid-cols-2">
        <label>الطالب<select required className={input} value={credit.user} onChange={e => setCredit({ ...credit, user: e.target.value })}><option value="">اختر الطالب</option>{data.users.filter(x => x.role === 'student').map(x => <option key={x._id} value={x._id}>{x.name}</option>)}</select></label>
        <label>المبلغ (سالب للخصم)<input required type="number" step="0.01" className={input} value={credit.amount} onChange={e => setCredit({ ...credit, amount: e.target.value })} /></label>
        <label>سبب الحركة<input required maxLength={500} className={input} value={credit.description} onChange={e => setCredit({ ...credit, description: e.target.value })} /></label>
        <button className={button}>تسجيل حركة الرصيد</button>
      </fieldset>
      {credits.map(x => <p key={x._id} className="rounded-xl border p-3">{x.user?.name} — {x.amount} USD — {x.description}</p>)}
    </form>
    <section className="space-y-3 rounded-2xl bg-white p-5"><h2 className="text-xl font-bold">محادثات التطبيق</h2>
      <button disabled={busy} className={button} onClick={() => void act(async () => {}, false)}>تحديث</button>
      {messages.map(x => <article className="rounded-xl border p-3" key={x._id}><b>{x.sender?.name} ← {x.recipient?.name}</b><p className="whitespace-pre-wrap">{x.body}</p><button onClick={() => setReply({ recipient: x.sender?._id || '', body: '' })} className="text-orange-700">رد</button></article>)}
      <form className="space-y-3" onSubmit={e => { e.preventDefault(); void act(async () => { await api.post('/mobile-workspace/messages', reply); setReply({ ...reply, body: '' }); }); }}><fieldset disabled={busy} className="space-y-3">
        <select required className={input} aria-label="المستلم" value={reply.recipient} onChange={e => setReply({ ...reply, recipient: e.target.value })}><option value="">المستلم</option>{data.users.filter(x => x.role !== 'admin').map(x => <option key={x._id} value={x._id}>{x.name} — {roles[x.role]}</option>)}</select>
        <textarea required maxLength={4000} className={input} aria-label="الرسالة" value={reply.body} onChange={e => setReply({ ...reply, body: e.target.value })} /><button className={button}>إرسال</button>
      </fieldset></form>
    </section>
  </div>;
}
