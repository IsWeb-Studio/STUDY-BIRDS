import { useEffect, useRef } from 'react';
import { markStaffRecord } from '../../lib/sharedReadState';

// Use on a full visible record, never on a summary row in a list.
export function StaffReadReceipt({ resource, record }: { resource: string; record: { _id: string; updatedAt?: string } }) {
  const marker = useRef<HTMLSpanElement>(null);
  useEffect(() => {
    const element = marker.current?.closest('article') || marker.current;
    if (!element) return;
    let visible = false;
    const read = () => { if (visible && !document.hidden) void markStaffRecord(resource, record).catch(() => {}); };
    const observer = new IntersectionObserver(entries => { visible = entries[0].isIntersecting; read(); }, { threshold: 0.5 });
    observer.observe(element); document.addEventListener('visibilitychange', read);
    return () => { observer.disconnect(); document.removeEventListener('visibilitychange', read); };
  }, [resource, record._id, record.updatedAt]);
  return <span ref={marker} aria-hidden="true" />;
}
