import { useEffect, useState, useSyncExternalStore, type ReactNode } from 'react';
import { dashboardLoading } from '../../lib/dashboardLoading';
import { ContentLoading } from '../ContentLoading';

export const DashboardDataBoundary = ({ route, children }: { route: string; children: ReactNode }) => {
  const pending = useSyncExternalStore(dashboardLoading.subscribe, () => dashboardLoading.count(route), () => 0);
  const [registered, setRegistered] = useState(false), [loaded, setLoaded] = useState(false);
  useEffect(() => {
    // Child effects and Axios interceptors register reads before the next frame.
    const frame = requestAnimationFrame(() => setRegistered(true));
    return () => cancelAnimationFrame(frame);
  }, []);
  useEffect(() => { if (registered && dashboardLoading.count(route) === 0) setLoaded(true); }, [registered, pending, route]);
  return <div aria-busy={!loaded || pending > 0}>
    {!loaded ? <ContentLoading layout="cards" /> : pending > 0 ? <ContentLoading compact /> : null}
    {/* Keep children mounted so their effects can fetch data; preserve content on refresh. */}
    <div hidden={!loaded}>{children}</div>
  </div>;
};
