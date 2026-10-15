import { useEffect, useState } from 'react';
import { api } from '../lib/api';
import { useAuth } from './useAuth';
import type { ReadSummary } from '../lib/sharedReadState';

export function useStaffReadSummary() {
  const { user } = useAuth();
  const [summary, setSummary] = useState<ReadSummary>({ resources: {} });
  useEffect(() => {
    setSummary({ resources: {} });
    if (!user || !['admin', 'employee'].includes(user.role)) return;
    let active = true, pending = false;
    const update = async () => {
      if (document.hidden || pending) return;
      pending = true;
      try { const { data } = await api.get<ReadSummary>('/shared-read'); if (active) setSummary(previous => ({ ...data, resources: { ...Object.fromEntries(Object.entries(previous.resources).filter(([key]) => data.errors?.[key])), ...data.resources } })); }
      catch { /* Retain the last known counters; never turn an outage into zero unread. */ }
      finally { pending = false; }
    };
    void update();
    const interval = window.setInterval(update, 15000);
    window.addEventListener('focus', update); window.addEventListener('shared-read-changed', update); document.addEventListener('visibilitychange', update);
    return () => { active = false; window.clearInterval(interval); window.removeEventListener('focus', update); window.removeEventListener('shared-read-changed', update); document.removeEventListener('visibilitychange', update); };
  }, [user?._id, user?.role]);
  return summary;
}
