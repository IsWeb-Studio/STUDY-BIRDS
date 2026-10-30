import { useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { useLanguage } from '../hooks/useLanguage';
import { api } from '../lib/api';
import { getErrorMessage } from '../utils/errors';
import { Seo } from '../components/seo/Seo';

export const AccountDeletionRequestPage = () => {
  const { language } = useLanguage();
  const ar = language === 'ar';
  const [email, setEmail] = useState('');
  const [code, setCode] = useState('');
  const [sent, setSent] = useState(false);
  const [done, setDone] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if (busy) return;
    setBusy(true);
    setError('');
    try {
      await api.post(`/auth/account-deletion/${sent ? 'confirm' : 'request'}`, {
        email: email.trim(), ...(sent ? { code } : {}),
      });
      if (sent) setDone(true);
      else setSent(true);
    } catch (reason) {
      setError(getErrorMessage(reason, ar ? 'تعذر إكمال الطلب. حاول مجددًا.' : 'Unable to complete the request. Please retry.'));
    } finally { setBusy(false); }
  };
  return <main className="mx-auto max-w-xl space-y-6 py-8" dir={ar ? 'rtl' : 'ltr'}>
    <Seo title={ar ? 'حذف حساب COVEY' : 'Delete your COVEY account'}
      description="Request deletion of your COVEY account and associated personal data without installing the app."
      canonicalPath="/delete-account" />
    <h1 className="text-3xl font-semibold">{ar ? 'حذف حساب COVEY' : 'Delete your COVEY account'}</h1>
    <p>{ar
      ? 'يمكنك طلب حذف حسابك وبياناتك الشخصية والمستندات والمحادثات والمحتوى الذي نشرته دون تنزيل التطبيق. نؤكد ملكيتك للحساب برمز يُرسل إلى بريدك. الحذف نهائي.'
      : 'Request deletion of your account, personal data, documents, conversations and published content without installing the app. We verify ownership using a code sent to your email. Deletion is permanent.'}</p>
    <p>{ar
      ? 'بعد التأكيد يُوقف الحساب وتبدأ الإزالة الآلية. تُعاد المحاولة عند تعطل التخزين. تُحتفظ سجلات المحاسبة الضرورية بعد إزالة بيانات الملف الشخصي منها. تواصل معنا للاستفسار عن السجلات المطلوب الاحتفاظ بها.'
      : 'After confirmation, access is disabled and automated cleanup begins. Storage failures are retried. Necessary accounting records are retained with profile information removed. Contact us about applicable record retention.'}</p>
    {done ? <p role="status" className="panel p-6">{ar
      ? 'تم تأكيد طلب الحذف وإيقاف الحساب. بدأت إزالة البيانات؛ لا يلزم تنزيل التطبيق أو إرسال طلب آخر.'
      : 'Deletion confirmed and account access disabled. Data removal has started. You do not need to reinstall the app or submit another request.'}</p>
      : <form onSubmit={submit} className="panel space-y-4 p-6">
        <label className="block">{ar ? 'بريد الحساب' : 'Account email'}
          <input className="mt-2 w-full rounded-xl border p-3" type="email" autoComplete="email"
            dir="ltr" required maxLength={254} value={email} disabled={busy || sent}
            onChange={event => setEmail(event.target.value)} />
        </label>
        {sent && <>
          <p role="status">{ar ? 'إذا كان البريد مرتبطًا بحساب نشط، سيصلك رمز صالح لعشر دقائق.' : 'If the email belongs to an active account, a code valid for ten minutes will arrive.'}</p>
          <label className="block">{ar ? 'رمز تأكيد الحذف' : 'Deletion confirmation code'}
            <input className="mt-2 w-full rounded-xl border p-3" dir="ltr" inputMode="numeric"
              autoComplete="one-time-code" required pattern="[0-9]{6}" maxLength={6} value={code}
              disabled={busy} onChange={event => setCode(event.target.value)} />
          </label>
        </>}
        {error && <p role="alert" className="text-rose-700">{error}</p>}
        <button className="rounded-full bg-rose-700 px-6 py-3 text-white disabled:opacity-50" disabled={busy}>
          {busy ? (ar ? 'جارٍ التنفيذ…' : 'Processing…') : sent
            ? (ar ? 'تأكيد الحذف النهائي' : 'Confirm permanent deletion')
            : (ar ? 'إرسال رمز التأكيد' : 'Send confirmation code')}
        </button>
        {sent && <button type="button" disabled={busy} className="mx-4 underline"
          onClick={() => { setSent(false); setCode(''); setError(''); }}>
          {ar ? 'تعديل البريد أو إعادة إرسال الرمز' : 'Change email or resend code'}
        </button>}
      </form>}
    <div className="flex gap-6 underline"><Link to="/privacy-policy">{ar ? 'سياسة الخصوصية' : 'Privacy policy'}</Link>
      <Link to="/contact">{ar ? 'تواصل معنا' : 'Contact us'}</Link></div>
  </main>;
};
