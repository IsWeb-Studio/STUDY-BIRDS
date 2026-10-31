import { useState, type FormEvent } from 'react';
import { api } from '../../lib/api';
import { getErrorMessage } from '../../utils/errors';
export function AgentWalletAdjustment({ ar }: { ar: boolean }) {
  const [agent, setAgent] = useState('');
  const [amount, setAmount] = useState('');
  const [notes, setNotes] = useState('');
  const [direction, setDirection] = useState('credit');
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  async function submit(event: FormEvent) {
    event.preventDefault();
    if (busy) return;
    const value = Number(amount);
    if (!/^[a-f\d]{24}$/i.test(agent.trim()) || !Number.isFinite(value) || value <= 0 || !notes.trim()) {
      setMessage(ar ? 'أدخل معرّف الوكيل والمبلغ والسبب.' : 'Enter the agent ID, amount and reason.'); return;
    }
    if (!window.confirm(`${ar ? 'تأكيد تسجيل تسوية الرصيد' : 'Confirm wallet adjustment'}: ${direction} ${value} USD — ${agent}`)) return;
    setBusy(true); setMessage('');
    try {
      await api.post('/admin/payout-requests/wallet-entries', { studentId: agent.trim(), amount: value, direction, notes: notes.trim() });
      setMessage(ar ? 'تم تسجيل التسوية. الرصيد يظهر في محفظة الوكيل.' : 'Adjustment recorded in the agent wallet.');
      setAmount(''); setNotes('');
    } catch (error) { setMessage(getErrorMessage(error, ar ? 'تعذر تسجيل التسوية.' : 'Could not record adjustment.')); }
    finally { setBusy(false); }
  }
  return <section className="panel p-6">
    <h2 className="text-xl font-semibold">{ar ? 'تسجيل رصيد أو تسوية لوكيل' : 'Agent wallet adjustment'}</h2>
    <p>{ar ? 'سجّل المبلغ المعتمد وسبب التسوية. هذه العملية تسجل رصيدًا داخليًا؛ التحويل البنكي يتم خارج التطبيق.' : 'Record an approved amount and its reason. This updates the internal ledger; bank transfers are handled separately.'}</p>
    <form onSubmit={submit} className="mt-4 grid gap-3 md:grid-cols-2">
      <input aria-label="Agent ID" placeholder={ar ? 'معرّف الوكيل من ملفه' : 'Agent ID from profile'} value={agent} onChange={e => setAgent(e.target.value)} required />
      <input aria-label="Amount" type="number" min="0.01" step="0.01" placeholder="USD" value={amount} onChange={e => setAmount(e.target.value)} required />
      <select aria-label="Direction" value={direction} onChange={e => setDirection(e.target.value)}><option value="credit">{ar ? 'إضافة رصيد' : 'Credit'}</option><option value="debit">{ar ? 'خصم رصيد' : 'Debit'}</option></select>
      <input aria-label="Reason" placeholder={ar ? 'سبب التسوية' : 'Reason'} maxLength={500} value={notes} onChange={e => setNotes(e.target.value)} required />
      <button type="submit" disabled={busy} className="rounded-full bg-slate-950 px-5 py-3 text-white">{ar ? 'تسجيل التسوية' : 'Record adjustment'}</button>
    </form>{message && <p role="status" className="mt-3">{message}</p>}
  </section>;
}
