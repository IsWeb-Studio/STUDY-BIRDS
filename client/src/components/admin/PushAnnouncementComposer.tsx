import { useEffect, useRef, useState } from 'react';
import { api } from '../../lib/api';
import { useAuth } from '../../hooks/useAuth';
import { useLanguage } from '../../hooks/useLanguage';
import { getErrorMessage } from '../../utils/errors';

type Announcement = { _id: string; requestId: string; title: string; body: string; status: string; createdAt: string };

export function PushAnnouncementComposer() {
  const { user } = useAuth();
  const { language } = useLanguage();
  const ar = language === 'ar';
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [requestId, setRequestId] = useState('');
  const [items, setItems] = useState<Announcement[]>([]);
  const [enabled, setEnabled] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const locked = useRef(false);
  const status = (value: string) => value === 'accepted'
    ? (ar ? 'قبلت خدمة الإشعارات طلب الإرسال؛ لا يعني وصوله لكل جهاز.' : 'Accepted by push service; delivery to every device is not guaranteed.')
    : value === 'no_subscribers' ? (ar ? 'لا توجد أجهزة مشتركة.' : 'No subscribed devices.')
    : (ar ? 'الإرسال غير مؤكد؛ أعد محاولة نفس الإعلان.' : 'Unconfirmed; retry the same announcement.');
  const load = async () => {
    const { data } = await api.get<{ enabled: boolean; items: Announcement[] }>('/admin/push-announcements');
    setEnabled(data.enabled); setItems(data.items);
  };
  useEffect(() => {
    if (user?.role === 'admin') load().catch(issue => setError(getErrorMessage(issue, 'Unable to load announcements.')));
  }, [user?.role]);
  if (user?.role !== 'admin') return null;
  const send = async (previous?: Announcement) => {
    if (locked.current) return;
    const payload = previous || { title: title.trim(), body: body.trim(), requestId: requestId || crypto.randomUUID() };
    if (!previous && !requestId && !window.confirm(ar ? 'إرسال هذا الإعلان الآن لكل مشتركي إشعارات التطبيق؟' : 'Send this announcement now to all mobile push subscribers?')) return;
    locked.current = true; setBusy(true); setError(''); setMessage('');
    if (!previous) setRequestId(payload.requestId);
    try {
      const { data } = await api.post<Announcement>('/admin/push-announcements', { title: payload.title, body: payload.body, requestId: payload.requestId, ...(previous ? { announcementId: previous._id } : {}) });
      setMessage(status(data.status));
      if (!previous) { setTitle(''); setBody(''); setRequestId(''); }
      await load();
    } catch (issue) { setError(getErrorMessage(issue, ar ? 'تعذر تأكيد الإرسال. أعد المحاولة بنفس الإعلان.' : 'Unable to confirm delivery. Retry the same announcement.')); }
    finally { locked.current = false; setBusy(false); }
  };
  return <section className="panel space-y-4 p-6">
    <h2 className="text-xl font-semibold">{ar ? 'إعلان عام للتطبيق' : 'Mobile app announcement'}</h2>
    <p>{ar ? 'يرسل إلى مشتركي إشعارات أندرويد وآيفون من كل أنواع الحسابات. المستخدم الذي رفض الإشعارات لن يستلمه.' : 'Send to Android and iPhone push subscribers across all account roles. Users who disabled notifications will not receive it.'}</p>
    {!enabled && <p role="status">{ar ? 'الإرسال غير متاح حتى تفعيل OneSignal على السيرفر.' : 'Sending is unavailable until OneSignal is configured on the server.'}</p>}
    <form className="space-y-3" onSubmit={event => { event.preventDefault(); void send(); }}>
      <label className="block">{ar ? 'العنوان' : 'Title'}<input required maxLength={80} disabled={busy || !!requestId} value={title} onChange={e => setTitle(e.target.value)} className="block w-full rounded-xl border p-3" /></label>
      <label className="block">{ar ? 'نص الإعلان' : 'Message'}<textarea required maxLength={1000} disabled={busy || !!requestId} value={body} onChange={e => setBody(e.target.value)} className="block w-full rounded-xl border p-3" /></label>
      <div className="rounded-xl bg-slate-50 p-4" aria-label={ar ? 'معاينة' : 'Preview'}><strong>{title || 'Study Birds'}</strong><p className="whitespace-pre-wrap">{body}</p></div>
      <button disabled={busy || !enabled || !title.trim() || !body.trim()} className="rounded-xl bg-slate-900 px-4 py-3 text-white disabled:opacity-50">{busy ? (ar ? 'جارٍ الإرسال…' : 'Sending…') : requestId ? (ar ? 'إعادة محاولة نفس الإعلان' : 'Retry same announcement') : (ar ? 'إرسال للجميع' : 'Send to all')}</button>
    </form>
    {error && <p role="alert">{error}</p>}{message && <p role="status">{message}</p>}
    <h3 className="font-semibold">{ar ? 'آخر الإعلانات' : 'Recent announcements'}</h3>
    <button disabled={busy} onClick={() => void load().catch(issue => setError(getErrorMessage(issue, 'Unable to refresh announcements.')))} className="underline">{ar ? 'تحديث السجل' : 'Refresh history'}</button>
    {items.map(item => <article key={item._id} className="rounded-xl border p-3"><strong>{item.title}</strong><p className="whitespace-pre-wrap">{item.body}</p><small>{new Date(item.createdAt).toLocaleString()} — {status(item.status)}</small>{!['accepted', 'no_subscribers'].includes(item.status) && <button disabled={busy || !enabled} onClick={() => void send(item)} className="block underline">{ar ? 'إعادة المحاولة دون تكرار' : 'Retry without duplicate delivery'}</button>}</article>)}
  </section>;
}
