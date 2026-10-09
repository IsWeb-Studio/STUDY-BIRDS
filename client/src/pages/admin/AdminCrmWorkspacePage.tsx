import {useEffect,useRef,useState} from 'react';
import {api} from '../../lib/api';
export const AdminCrmWorkspacePage=()=>{
  const frame=useRef<HTMLIFrameElement>(null);
  const [session,setSession]=useState<{token:string;user:unknown;webOrigin:string}|null>(null);
  const [error,setError]=useState('');
  useEffect(()=>{let active=true;api.post('/crm/workspace-session').then(({data})=>{if(active)setSession(data);}).catch(e=>{if(active)setError(e.response?.data?.message || 'تعذر فتح مساحة CRM.');});return()=>{active=false;};},[]);
  useEffect(()=>{
    if(!session)return;
    const receive=(event:MessageEvent)=>{
      if(event.origin!==session.webOrigin || event.source!==frame.current?.contentWindow)return;
      if(event.data?.type==='STUDY_BIRDS_CRM_READY') frame.current?.contentWindow?.postMessage({type:'STUDY_BIRDS_CRM_SESSION',token:session.token},session.webOrigin);
      if(event.data?.type==='STUDY_BIRDS_CRM_ERROR')setError('تعذر تأكيد حساب CRM المرتبط. أعد تحميل الصفحة بعد التحقق من ربط الحساب.');
    };
    window.addEventListener('message',receive);return()=>window.removeEventListener('message',receive);
  },[session]);
  return <section className="space-y-4"><h1 className="text-2xl font-bold">مساحة إدارة CRM</h1><p>المهام والمتابعات والمكالمات والمبيعات والحضور والرواتب تعمل على بيانات CRM نفسها حسب صلاحيات حسابك.</p>{error && <p role="alert">{error}</p>}{session ? <iframe ref={frame} src={`${session.webOrigin}/login?workspace=1`} title="مساحة CRM" style={{width:'100%',height:'85vh',border:0,borderRadius:16}} referrerPolicy="origin" /> : !error && <p>جارٍ فتح مساحة العمل…</p>}</section>;
};
