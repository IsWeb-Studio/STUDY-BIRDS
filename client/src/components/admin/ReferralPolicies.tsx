import { useEffect, useState, type FormEvent } from 'react';
import { api } from '../../lib/api';
import { useLanguage } from '../../hooks/useLanguage';
import { getErrorMessage } from '../../utils/errors';
type Policy={_id:string;scope:string;amount:number;enabled:boolean;__v:number;student?:{_id:string;name:string;email:string}};
export const ReferralPolicies=()=>{
  const {language}=useLanguage();const ar=language==='ar';const text=(a:string,b:string)=>ar?a:b;
  const [rows,setRows]=useState<Policy[]>([]),[students,setStudents]=useState<{_id:string;name:string;email:string}[]>([]);
  const [error,setError]=useState(''),[success,setSuccess]=useState(''),[busy,setBusy]=useState(false),[ready,setReady]=useState(false);
  const [studentId,setStudentId]=useState(''),[amount,setAmount]=useState('15');
  const base='/admin/student-financials/referral-policies';
  const load=async()=>{const response=await api.get<Policy[]>(base);setRows(response.data);setReady(true);};
  useEffect(()=>{void load().catch(e=>setError(getErrorMessage(e,'Unable to load referral policies')));void api.get<typeof students>('/admin/student-financials/referral-students').then(r=>setStudents(r.data)).catch(e=>setError(getErrorMessage(e,'Unable to load students')));},[]);
  async function save(row?:Policy){
    setBusy(true);setError('');setSuccess('');
    try{
      if(row)await api.put(`${base}/${row._id}`,{amount:row.amount,enabled:row.enabled,expectedVersion:row.__v});
      else await api.post(base,{studentId,amount:Number(amount),enabled:true});
      setSuccess(text('تم حفظ إعدادات الإحالة.','Referral policy saved.'));await load();if(!row)setStudentId('');
    }catch(e){setError(getErrorMessage(e,text('تعذر الحفظ. حدّث البيانات قبل إعادة المحاولة.','Unable to save. Refresh before retrying.')));}finally{setBusy(false);}
  }
  async function remove(row:Policy){setBusy(true);setError('');try{await api.delete(`${base}/${row._id}`,{data:{expectedVersion:row.__v}});await load();}catch(e){setError(getErrorMessage(e,'Unable to remove override'));}finally{setBusy(false);}}
  const change=(id:string,patch:Partial<Policy>)=>setRows(current=>current.map(row=>row._id===id?{...row,...patch}:row));
  const input='rounded-xl border border-slate-300 p-3';
  return <section className="space-y-4 rounded-2xl border bg-white p-5">
    <h2 className="text-xl font-semibold">{text('مكافآت إحالات الطلاب','Student referral rewards')}</h2>
    <p className="text-sm text-slate-600">{text('المبالغ بالدولار. التخصيص يخص الطالب صاحب كود الدعوة. تُثبّت المكافأة عند تسجيل صديقه وتُصرف عند أول طلب جامعة. التغييرات تخص الإحالات الجديدة فقط. إيقاف الافتراضي يوقف المكافآت الجديدة للجميع.','Amounts are USD. Overrides apply to the student who owns the invitation code. The reward is fixed at signup and credited on the first university application. Changes affect new referrals only. Disabling the default pauses new rewards for everyone.')}</p>
    {error&&<p role="alert" className="text-red-700">{error}</p>}{success&&<p role="status" className="text-emerald-700">{success}</p>}
    <button type="button" disabled={busy} onClick={()=>{void load().catch(e=>setError(getErrorMessage(e,'Unable to refresh')));}}>{text('تحديث الإعدادات','Refresh policies')}</button>
    {!ready&&<p role="status">{text('جارٍ التحميل…','Loading…')}</p>}
    {rows.map(row=><form key={row._id} className="flex flex-wrap items-end gap-3 rounded-xl bg-slate-50 p-4" onSubmit={(event:FormEvent)=>{event.preventDefault();void save(row);}}>
      <div className="flex-1"><strong>{row.scope==='default'?text('المبلغ الافتراضي','Default reward'):row.student?.name}</strong><p className="text-sm">{row.student?.email}</p></div>
      <label>{text('المبلغ USD','Amount USD')}<input className={`${input} block w-32`} type="number" min="0" max="10000" step="0.01" required disabled={busy} value={row.amount} onChange={e=>change(row._id,{amount:Number(e.target.value)})}/></label>
      <label><input type="checkbox" checked={row.enabled} disabled={busy} onChange={e=>change(row._id,{enabled:e.target.checked})}/>{text('مفعّل','Enabled')}</label>
      <button disabled={busy} className={input}>{text('حفظ','Save')}</button>
      {row.scope!=='default'&&<button type="button" disabled={busy} onClick={()=>void remove(row)}>{text('العودة للمبلغ الافتراضي','Use default reward')}</button>}
    </form>)}
    <form className="flex flex-wrap items-end gap-3 border-t pt-4" onSubmit={e=>{e.preventDefault();void save();}}>
      <label>{text('تخصيص لطالب','Student override')}<select required className={`${input} block max-w-sm`} value={studentId} disabled={busy||!ready} onChange={e=>setStudentId(e.target.value)}><option value="">{text('اختر صاحب كود الدعوة','Choose the invitation owner')}</option>{students.filter(s=>!rows.some(r=>r.scope===s._id)).map(s=><option key={s._id} value={s._id}>{s.name} — {s.email}</option>)}</select></label>
      <label>{text('المبلغ USD','Amount USD')}<input className={`${input} block w-32`} type="number" min="0" max="10000" step="0.01" value={amount} required disabled={busy} onChange={e=>setAmount(e.target.value)}/></label>
      <button disabled={busy||!ready||!studentId} className={input}>{text('إضافة تخصيص','Add override')}</button>
    </form>
  </section>;
};
