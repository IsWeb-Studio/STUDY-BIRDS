import { useEffect, useState } from 'react';
import { api } from '../../lib/api';
import { useLanguage } from '../../hooks/useLanguage';
type Reminder = { _id: string; message: string; reminderApplication: string; reminderDueAt: string; isRead: boolean };
export function FollowUpReminders({ onOpen }: { onOpen: (id: string) => void }) {
 const {language} = useLanguage(); const ar=language==='ar';
 const [rows,setRows]=useState<Reminder[]>([]); const [error,setError]=useState(false); const [busy,setBusy]=useState(false);
 async function load() { setBusy(true); setError(false); try {setRows((await api.get<Reminder[]>('/applications/follow-up-reminders')).data);} catch {setError(true);} finally {setBusy(false);} }
 useEffect(()=>{void load();},[]);
 async function read(id:string) {setBusy(true); try {await api.patch(`/applications/follow-up-reminders/${id}/read`); await load();} catch {setError(true);} finally {setBusy(false);} }
 return <section className="rounded-2xl border border-slate-200 bg-white p-5">
  <div className="flex flex-wrap items-center justify-between gap-3"><h2 className="font-semibold">{ar?'تذكيرات متابعتي':'My follow-up reminders'}</h2><button disabled={busy} onClick={()=>void load()} className="min-h-11 rounded-xl border border-slate-200 px-4 text-sm">{ar?'تحديث':'Refresh'}</button></div>
  {!!rows.length && <p className="mt-2 text-sm text-slate-500">{ar?'قراءة التذكير لا تعني إنجاز المتابعة. حدّث موعدها من الطلب بعد المراجعة.':'Reading a reminder does not complete follow-up. Update its deadline after review.'}</p>}
  {rows.map(row=><div key={row._id} className="mt-3 rounded-xl bg-orange-50 p-3">
   <p>{row.message}</p><p className="mt-1 text-sm">{ar?'رقم الطلب: ':'Application: '}{row.reminderApplication} — {new Date(row.reminderDueAt).toLocaleString(ar?'ar':'en')}</p>
   <button onClick={()=>onOpen(row.reminderApplication)} className="min-h-11 px-3 text-sm font-semibold">{ar?'عرض الطلب':'Open application'}</button>
   {!row.isRead && <button disabled={busy} onClick={()=>void read(row._id)} className="min-h-11 text-sm font-semibold">{ar?'تمت القراءة':'Mark read'}</button>}
  </div>)}
  {!busy && !rows.length && !error && <p className="mt-2 text-sm text-slate-500">{ar?'لا توجد تذكيرات متابعة حالية.':'No current follow-up reminders.'}</p>}
  {error && <p role="alert" className="mt-2 text-red-700">{ar?'تعذر تحميل التذكيرات أو تحديثها.':'Unable to load or update reminders.'}</p>}
 </section>;
}
