import type { AxiosInstance } from 'axios';

const pending = new Map<string, number>();
const listeners = new Set<() => void>();
const installed = new WeakSet<AxiosInstance>();
const notify = () => listeners.forEach(listener => listener());
export const dashboardLoading = {
  subscribe(listener: () => void) { listeners.add(listener); return () => { listeners.delete(listener); }; },
  count(route: string) { return pending.get(route) || 0; },
  begin(route: string, method = 'get', url = '') {
    if (!/^\/admin(\/|\?|$)/.test(route) || method.toLowerCase() !== 'get' || /^\/(auth|identity|shared-read)(\/|$)/.test(url) || /\/health(?:\?|$)/.test(url)) return () => {};
    pending.set(route, (pending.get(route) || 0) + 1); notify();
    let finished = false;
    return () => {
      if (finished) return; finished = true;
      const count = (pending.get(route) || 1) - 1;
      if (count) pending.set(route, count); else pending.delete(route);
      notify();
    };
  },
};

/** Track the complete request promise, including retries and session renewal. */
export function installDashboardLoading(client: AxiosInstance, currentRoute = () => typeof window === 'undefined' ? '' : window.location.pathname + window.location.search) {
  if (installed.has(client)) return; installed.add(client);
  const get = client.get.bind(client);
  client.get = ((...args: Parameters<AxiosInstance['get']>) => {
    const finish = dashboardLoading.begin(currentRoute(), 'get', args[0]);
    try { return get(...args).finally(finish); } catch (error) { finish(); throw error; }
  }) as AxiosInstance['get'];
  // Internal api.request calls during session renewal remain covered by the
  // original get promise; tracking them again could assign an old read to a new route.
}
