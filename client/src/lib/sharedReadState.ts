import { api } from './api';

export type ReadState = { id: string; resource: string; canonical: string; version: string; unread: boolean; readAt: string | null };
export type ReadSummary = { resources: Record<string, { canonical: string; unread: number; total: number }>; errors?: Record<string, string> };
export const readResourcesForPage: Record<string, string[]> = {
  students: ['students'], applications: ['applications'], 'student-documents': ['documents'], 'student-financials': ['financials', 'paymentProofs', 'walletEntries'],
  'student-arrivals': ['arrival'], 'student-orientation-results': ['orientation'], 'student-favorites': ['favorites'],
  universities: ['universities'], programs: ['programs'], countries: ['countries'], 'study-fields': ['studyFields'],
  consultations: ['consultations', 'consultationSlots'], 'support-tickets': ['support'], 'service-requests': ['services'],
  'accommodation-bookings': ['housing'], 'accommodation-listings': ['housingListings'],
  agents: ['agents'], 'agency-requests': ['agencies'], 'partner-students': ['agentStudents'], 'payout-requests': ['payouts'],
  'verification-queue': ['verification'], 'marketing-assets': ['marketingAssets'], 'university-accounts': ['universityAccounts'],
  employees: ['employees'], users: ['websiteUsers'], 'parent-links': ['parents'], 'site-settings': ['siteSettings'],
  testimonials: ['testimonials'], recognitions: ['recognitions'], services: ['contentServices'], faqs: ['faqs'],
  'knowledge-base': ['knowledge'], exhibitions: ['exhibitions'], 'our-story': ['ourStory'], events: ['events', 'pastEvents', 'upcomingEvent'],
  community: ['communityPosts', 'community', 'studentOffers', 'studentOpportunities'], visa: ['visaCases'],
};
export const countUnread = (summary: ReadSummary, resources: string[]) => {
  const counts = new Map<string, number>();
  for (const resource of resources) { const item = summary.resources[resource]; if (item) counts.set(item.canonical, Math.max(counts.get(item.canonical) || 0, item.unread)); }
  return [...counts.values()].reduce((sum, count) => sum + count, 0);
};
export async function markStaffRecord(resource: string, record: { _id: string; updatedAt?: string }) {
  if (!record?._id || document.hidden) return;
  const { data } = await api.post<Record<string, ReadState>>(`/shared-read/${resource}/states`, { ids: [record._id] });
  const snapshot = data[record._id];
  // Do not acknowledge an update newer than the data the employee actually opened.
  if (!snapshot?.unread || record.updatedAt && snapshot.version.slice(0, 24) !== new Date(record.updatedAt).toISOString()) return;
  await api.post(`/shared-read/${resource}/${record._id}/read`, { version: snapshot.version });
  window.dispatchEvent(new Event('shared-read-changed'));
}

let staff = false;
export function configureStaffReadTracking(enabled: boolean) { staff = enabled; }
api.interceptors.response.use(response => {
  if (!staff || response.config.method?.toLowerCase() !== 'get') return response;
  const url = response.config.url || '';
  const match = url.match(/^\/admin\/([^/]+)\/([a-f\d]{24})$/i) || url.match(/^\/(programs|universities)\/([a-f\d]{24})$/i);
  if (!match) return response;
  const resource = readResourcesForPage[match[1]]?.[0];
  if (!resource || !window.location.pathname.endsWith(`/${match[2]}`)) return response;
  let record = response.data?.student || response.data?.partner || response.data?.application || response.data;
  const profile = response.data?.profile || record?.profile;
  if (profile?.updatedAt && new Date(profile.updatedAt).getTime() > new Date(record?.updatedAt || 0).getTime()) record = { ...record, updatedAt: profile.updatedAt };
  if (record?._id) window.requestAnimationFrame(() => { if (staff && !document.hidden && window.location.pathname.endsWith(`/${match[2]}`)) void markStaffRecord(resource, record).catch(() => {}); });
  return response;
});
