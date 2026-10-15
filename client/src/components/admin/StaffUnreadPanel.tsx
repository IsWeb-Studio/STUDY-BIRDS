import { useState } from 'react';
import { useLocation } from 'react-router-dom';
import { api } from '../../lib/api';
import { markStaffRecord, readResourcesForPage } from '../../lib/sharedReadState';
import { useAuth } from '../../hooks/useAuth';
import { useLanguage } from '../../hooks/useLanguage';
import { getErrorMessage } from '../../utils/errors';

const labels: Record<string, string> = { students:'الطلاب',applications:'طلبات الطلاب',documents:'المستندات',financials:'الفواتير',paymentProofs:'إثباتات الدفع',walletEntries:'حركات المحفظة',arrival:'الوصول',support:'تذاكر الدعم',universities:'الجامعات',programs:'البرامج',countries:'الدول',studyFields:'مجالات الدراسة',consultations:'الاستشارات',consultationSlots:'المواعيد',agents:'الوكلاء',agencies:'طلبات الوكالة',parents:'أولياء الأمور',employees:'الموظفون',websiteUsers:'المستخدمون',testimonials:'آراء الطلاب',recognitions:'الاعتمادات',contentServices:'الخدمات',faqs:'الأسئلة الشائعة',knowledge:'قاعدة المعرفة',ourStory:'من نحن',siteSettings:'الإعدادات',events:'تسجيلات الفعاليات',pastEvents:'الفعاليات السابقة',upcomingEvent:'الفعالية القادمة',exhibitions:'المقالات والمعارض',community:'البلاغات',communityPosts:'المنشورات',studentOffers:'العروض',studentOpportunities:'الفرص',name:'الاسم',email:'الإيميل',role:'الدور',employeeRole:'دور الموظف',isActive:'فعال',title:'العنوان',subject:'الموضوع',description:'الوصف',message:'الرسالة',body:'المحتوى',status:'الحالة',detailedStatus:'مرحلة الطلب',amount:'المبلغ',invoiceNumber:'رقم الفاتورة',currency:'العملة',dueDate:'الموعد',category:'التصنيف',notes:'ملاحظات',adminNote:'ملاحظة الإدارة',reviewNote:'ملاحظة المراجعة',university:'الجامعة',program:'البرنامج',country:'الدولة',language:'اللغة',degreeLevel:'الدرجة',fieldOfStudy:'مجال الدراسة',duration:'المدة',tuition:'الرسوم',partnerTuition:'رسوم الشريك',summary:'الملخص',overview:'نبذة',code:'الرمز',replies:'الردود',createdAt:'تاريخ الإنشاء',updatedAt:'آخر تحديث',profile:'بيانات الطالب',phone:'الهاتف',nationality:'الجنسية',displayName:'اسم المرسل',fromRole:'المرسل',user:'المستخدم',source:'المصدر',englishFullName:'الاسم بالإنجليزية',passportNumber:'رقم الجواز',gpa:'المعدل',bio:'نبذة',address:'العنوان' };
function display(value: unknown): string {
  if (value === null || value === undefined || value === '') return '—';
  if (typeof value === 'boolean') return value ? 'نعم' : 'لا';
  if (Array.isArray(value)) return value.map(display).join('\n\n');
  if (typeof value === 'object') return Object.entries(value).filter(([key]) => !['_id','__v','crmActorId'].includes(key)).map(([key, item]) => `${labels[key] || key}: ${display(item)}`).join('\n');
  if (typeof value === 'string' && /^\d{4}-\d\d-\d\dT/.test(value)) return new Date(value).toLocaleString();
  return String(value);
}

export function StaffUnreadPanel() {
  const { user } = useAuth(); const { language } = useLanguage(); const { pathname } = useLocation();
  const [open, setOpen] = useState(false), [resource, setResource] = useState(''), [items, setItems] = useState<Array<{ _id: string; title: string }>>([]);
  const [record, setRecord] = useState<Record<string, unknown> | null>(null), [error, setError] = useState('');
  const resources = readResourcesForPage[pathname.split('/')[2]] || [];
  if (!user || !['admin', 'employee'].includes(user.role) || !resources.length) return null;
  const ar = language === 'ar';
  const load = async (key: string) => { setOpen(true); setResource(key); setRecord(null); setError(''); try { const { data } = await api.get(`/shared-read/${key}/unread`); setItems(data.items); } catch (issue) { setError(getErrorMessage(issue, ar ? 'تعذر التحميل' : 'Unable to load')); } };
  const show = async (id: string) => { setError(''); try { const { data } = await api.get(`/shared-read/${resource}/${id}/detail`); setRecord(data.record); await markStaffRecord(resource, data.record); } catch (issue) { setError(getErrorMessage(issue, ar ? 'تعذر فتح السجل' : 'Unable to open record')); } };
  return <section className="mb-4"><button type="button" onClick={() => open ? setOpen(false) : void load(resources[0])} className="rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700">{ar ? 'العناصر غير المقروءة' : 'Unread items'}</button>{open && <div className="panel mt-3 space-y-3 p-4"><p className="text-sm text-slate-500">{ar ? 'القراءة مشتركة بين الموظفين ولا تغيّر حالة المعالجة. تُعرض أول 100 نتيجة.' : 'Reading is shared by staff and does not change processing status. First 100 results.'}</p><div className="flex flex-wrap gap-2">{resources.map(key => <button key={key} type="button" onClick={() => void load(key)} className="rounded-lg border border-slate-200 px-3 py-2 text-sm">{ar ? labels[key] || key : key}</button>)}</div>{error && <p role="alert" className="text-sm text-rose-700">{error}</p>}{record ? <><dl className="grid min-w-0 gap-3 sm:grid-cols-2">{Object.entries(record).filter(([key]) => !['_id', '__v'].includes(key)).map(([key, value]) => <div key={key} className="min-w-0 rounded-xl bg-slate-50 p-3"><dt className="text-xs text-slate-500">{ar ? labels[key] || key : key}</dt><dd className="mt-2 whitespace-pre-wrap break-words text-sm">{display(value)}</dd></div>)}</dl><button type="button" onClick={() => void load(resource)} className="rounded-lg border px-3 py-2 text-sm">{ar ? 'رجوع للقائمة' : 'Back to list'}</button></> : items.map(item => <button key={item._id} type="button" onClick={() => void show(item._id)} className="block w-full rounded-xl border border-slate-200 px-4 py-3 text-start text-sm">{item.title}</button>)}</div>}</section>;
}
