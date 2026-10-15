import { api } from "../lib/api";
import type {
  AgencyRequest,
  ArrivalServiceRequestItem,
  Application,
  DocumentItem,
  FavoriteItem,
  InvoiceItem,
  KnowledgeBaseItem,
  NotificationItem,
  OrientationTestResultItem,
  PaymentProofItem,
  StudentDashboardOverview,
  StudentFinancialsResponse,
  StudentProfile,
  SupportTicketItem,
} from "../types";

export const studentService = {
  getOverview: async () => {
    const { data } = await api.get<StudentDashboardOverview>("/students/overview");
    return data;
  },
  getProfile: async () => {
    const { data } = await api.get<StudentProfile>("/students/profile");
    return data;
  },
  updateProfile: async (payload: Partial<StudentProfile> & { name?: string; email?: string }) => {
    const { data } = await api.put<StudentProfile>("/students/profile", payload);
    return data;
  },
  // `link.replaces` uploads a new version of a document; `link.translationOf` a certified translation of it.
  uploadDocument: async (file: File, type: string, link: { replaces?: string; translationOf?: string } = {}) => {
    const formData = new FormData();
    formData.append("file", file);
    if (type) formData.append("type", type);
    if (link.replaces) formData.append("replaces", link.replaces);
    if (link.translationOf) formData.append("translationOf", link.translationOf);
    const { data } = await api.post<DocumentItem>("/students/documents", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    });
    return data;
  },
  getDocuments: async () => {
    const { data } = await api.get<DocumentItem[]>("/students/documents");
    return data;
  },
  getApplications: async () => {
    const { data } = await api.get<Application[]>("/students/applications");
    return data;
  },
  getNotifications: async () => {
    const { data } = await api.get<NotificationItem[]>("/students/notifications");
    return data;
  },
  markNotificationRead: async (id: string) => {
    const { data } = await api.patch<NotificationItem>(`/students/notifications/${id}/read`);
    return data;
  },
  getSupportTickets: async () => {
    const { data } = await api.get<SupportTicketItem[]>("/students/support-tickets");
    return data;
  },
  replySupportTicket: async (id: string, message: string) => {
    const { data } = await api.patch<SupportTicketItem>(`/students/support-tickets/${id}/reply`, { message });
    return data;
  },
  createSupportTicket: async (payload: { subject: string; message: string; category: string; file?: File | null }) => {
    const formData = new FormData();
    formData.append("subject", payload.subject);
    formData.append("message", payload.message);
    formData.append("category", payload.category);
    if (payload.file) {
      formData.append("file", payload.file);
    }
    const { data } = await api.post<SupportTicketItem>("/students/support-tickets", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    });
    return data;
  },
  getKnowledgeBase: async () => {
    const { data } = await api.get<KnowledgeBaseItem[]>("/students/knowledge-base");
    return data;
  },
  getFinancials: async () => {
    const { data } = await api.get<StudentFinancialsResponse>("/students/financials");
    return data;
  },
  uploadPaymentProof: async (invoiceId: string, payload: { file: File; amount?: number; note?: string }) => {
    const formData = new FormData();
    formData.append("file", payload.file);
    if (payload.amount !== undefined) formData.append("amount", String(payload.amount));
    if (payload.note) formData.append("note", payload.note);
    const { data } = await api.post<PaymentProofItem>(`/students/financials/invoices/${invoiceId}/payment-proof`, formData, {
      headers: { "Content-Type": "multipart/form-data" },
    });
    return data;
  },
  getArrivalServices: async () => {
    const { data } = await api.get<ArrivalServiceRequestItem | null>("/students/arrival-services");
    return data;
  },
  saveArrivalServices: async (payload: Partial<ArrivalServiceRequestItem>) => {
    const { data } = await api.put<ArrivalServiceRequestItem>("/students/arrival-services", payload);
    return data;
  },
  getFavorites: async () => {
    const { data } = await api.get<FavoriteItem[]>("/students/favorites");
    return data;
  },
  toggleFavorite: async (payload: { itemType: "university" | "program"; universityId?: string; programId?: string; notes?: string }) => {
    const { data } = await api.post<FavoriteItem | { removed: boolean; id: string }>("/students/favorites/toggle", payload);
    return data;
  },
  removeFavorite: async (id: string) => {
    const { data } = await api.delete(`/students/favorites/${id}`);
    return data;
  },
  getOrientationTest: async () => {
    const { data } = await api.get<OrientationTestResultItem | null>("/students/orientation-test");
    return data;
  },
  submitOrientationTest: async (payload: OrientationTestResultItem["answers"]) => {
    const { data } = await api.post<OrientationTestResultItem>("/students/orientation-test", payload);
    return data;
  },
  getAgencyRequest: async () => {
    const { data } = await api.get<AgencyRequest | null>("/students/agency-request");
    return data;
  },
  createAgencyRequest: async (studentNote?: string) => {
    const { data } = await api.post<AgencyRequest>("/students/agency-request", {
      studentNote: studentNote || "",
    });
    return data;
  },
};
