import { DocumentPicker } from "./forms/DocumentPicker";
import { useEffect, useState } from 'react';
import { api } from '../lib/api';
import { studentService } from '../services/studentService';
import { useLanguage } from '../hooks/useLanguage';
import type { Application, DocumentItem } from '../types';

export type DocumentRequest = { _id: string; type: string; note: string; document?: string; status: "requested" | "submitted" | "approved" | "cancelled" };
export type RevisionApplication = Application & { __v: number; documentRequests?: DocumentRequest[]; requiredDocumentTypes?: string[]; detailedStatus?: string };
const invalid = (doc: DocumentItem) => doc.status === 'rejected' || ['missing', 'rejected', 'needs-revision', 'needs-translation', 'expired'].includes((doc as DocumentItem & { detailedStatus?: string }).detailedStatus || '');
const labels: Record<string, [string, string]> = { passport: ['جواز السفر', 'Passport'], 'biometric-photo': ['الصورة الشخصية', 'Photo'], 'latest-qualification': ['آخر مؤهل', 'Latest qualification'], transcript: ['كشف الدرجات', 'Transcript'], 'language-certificate': ['شهادة اللغة', 'Language certificate'], other: ['مستند إضافي', 'Other document'] };

export function ApplicationDocumentUpdates({ applicationId, onUpdated }: { applicationId: string; onUpdated: () => void }) {
  const { language } = useLanguage();
  const ar = language === 'ar';
  const [application, setApplication] = useState<RevisionApplication>();
  const [documents, setDocuments] = useState<DocumentItem[]>([]);
  const [selected, setSelected] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [confirmType, setConfirmType] = useState<string>();
  async function load() {
    setBusy(true); setError('');
    try {
      const [response, docs] = await Promise.all([api.get<RevisionApplication>(`/applications/${applicationId}`), studentService.getDocuments()]);
      setApplication(response.data); setDocuments(docs); setSelected({}); setConfirmType(undefined);
    } catch { setError(ar ? 'تعذر تحميل المستندات. حاول مجددًا.' : 'Unable to load documents. Please retry.'); }
    finally { setBusy(false); }
  }
  useEffect(() => { void load(); }, [applicationId]);
  async function upload(type: string, file?: File) {
    if (!file) return;
    setBusy(true); setError(''); setSuccess('');
    try { await studentService.uploadDocument(file, type); await load(); }
    catch { setError(ar ? 'تعذر رفع المستند.' : 'Unable to upload document.'); }
    finally { setBusy(false); }
  }
  async function attach(type: string) {
    if (!application) return;
    setBusy(true); setError(''); setSuccess('');
    try {
      const { data } = await api.patch<RevisionApplication>(`/applications/${applicationId}/documents`, { documentId: selected[type], version: application.__v });
      setApplication(data); setConfirmType(undefined); setSelected({});
      setSuccess(ar ? 'أُرفق المستند بالطلب؛ بانتظار مراجعة الفريق.' : 'Document attached. Awaiting team review.'); onUpdated();
    } catch { setError(ar ? 'تعذر الإرفاق. ربما تغير الطلب أو لم يعد يقبل التعديل؛ حدّث البيانات.' : 'Unable to attach. The application may have changed or no longer allow edits. Refresh the data.'); }
    finally { setBusy(false); }
  }
  const editable = application && !["accepted", "rejected"].includes(application.status) && ["draft", "documents-missing", "ready-to-apply", "submitted", "under-review", "additional-documents-required"].includes(application.detailedStatus || application.status);
  const requests = (application?.documentRequests || []).filter(item => ["requested", "submitted"].includes(item.status));
  const types = [...new Set([...(application?.requiredDocumentTypes ?? application?.program?.requiredDocumentTypes ?? ['passport', 'biometric-photo', 'latest-qualification']), ...requests.map(item => item.type), ...(application?.documents || []).map(doc => doc.type)])];
  return <section className="mt-4 rounded-2xl border border-orange-100 bg-white p-4" aria-busy={busy}>
    <h3 className="font-semibold">{ar ? 'استكمال مستندات الطلب' : 'Update application documents'}</h3>
    {application && types.map(type => {
      const current = application.documents?.filter(doc => doc.type === type) || [];
      const needsUpdate = !current.length || current.every(invalid) || requests.some(item => item.type === type && item.status === "requested");
      const choices = documents.filter(doc => doc.type === type && !invalid(doc) && !current.some(old => old._id === doc._id));
      return <div key={type} className="mt-4 space-y-3 border-t border-slate-100 pt-4">
        <p className="font-medium">{labels[type]?.[ar ? 0 : 1] || type}</p>
        {requests.filter(item => item.type === type).map(item => <p key={item._id} className="text-sm">{item.status === 'requested' ? (ar ? 'مطلوب من الفريق: ' : 'Team request: ') : (ar ? 'أُرسل للمراجعة: ' : 'Submitted for review: ')}{item.note}</p>)}
        {needsUpdate && !editable && <p className="text-sm text-slate-600">{ar ? 'هذا الطلب لا يقبل تعديل المستندات حاليًا. تواصل مع فريقك.' : 'Documents cannot be changed at this stage. Contact your team.'}</p>}
        {!needsUpdate ? <p className="text-sm text-slate-500">{ar ? 'المستند مرفق؛ تابع نتيجة المراجعة.' : 'Document attached. Follow its review status.'}</p> : editable ? <>
          <p className="text-sm text-orange-700">{ar ? 'مطلوب استكمال أو تصحيح المستند' : 'A document is missing or needs correction'}</p>
          <select aria-label={ar ? 'اختر المستند البديل' : 'Choose replacement document'} disabled={busy} value={selected[type] || ''} onChange={e => { setSelected(current => ({...current, [type]: e.target.value})); setConfirmType(undefined); }} className="min-h-11 w-full rounded-xl border p-2">
            <option value="">{ar ? 'اختر من مستنداتك' : 'Choose from your documents'}</option>
            {choices.map(doc => <option key={doc._id} value={doc._id}>{doc.fileName}</option>)}
          </select>
          <div className="space-y-2 text-sm"><p>{ar ? 'رفع مستند جديد' : 'Upload new document'}</p><DocumentPicker disabled={busy} accept=".pdf,.jpg,.jpeg,.png" onSelect={file => { void upload(type, file); }} /></div>
          {selected[type] && (confirmType === type ? <div className="rounded-xl bg-orange-50 p-3">
            <p className="text-sm">{ar ? 'سيُحفظ مرجع المستند السابق ويُرسل البديل للمراجعة. تأكيد الإرفاق؟' : 'The previous reference will be retained and the replacement sent for review. Confirm?'}</p>
            <button disabled={busy} onClick={() => void attach(type)} className="min-h-11 px-4 font-semibold">{ar ? 'تأكيد الإرفاق' : 'Confirm attachment'}</button>
            <button disabled={busy} onClick={() => setConfirmType(undefined)} className="min-h-11 px-4">{ar ? 'رجوع' : 'Back'}</button>
          </div> : <button disabled={busy} onClick={() => setConfirmType(type)} className="min-h-11 rounded-xl bg-orange-500 px-4 font-semibold text-white">{ar ? 'إرفاق بالطلب' : 'Attach to application'}</button>)}
        </> : null}
      </div>;
    })}
    {error && <p role="alert" className="mt-3 text-sm text-red-700">{error}</p>}
    {success && <p role="status" className="mt-3 text-sm text-green-700">{success}</p>}
    <button disabled={busy} onClick={() => void load()} className="mt-3 min-h-11 px-3 text-sm">{busy ? (ar ? 'جاري المعالجة...' : 'Working...') : (ar ? 'تحديث البيانات' : 'Refresh')}</button>
  </section>;
}
