import { api } from "../lib/api";
import type {
  AdminOverview,
  AdminPartnerDetails,
  AdminPartnerItem,
  AdminStudentDetails,
  AdminStudentItem,
  ArrivalServiceRequestItem,
  AgencyRequest,
  AgentStudentItem,
  Application,
  DocumentItem,
  Country,
  EventRegistration,
  ExhibitionArticle,
  FavoriteItem,
  Faq,
  InvoiceItem,
  KnowledgeBaseItem,
  MarketingAssetItem,
  NotificationItem,
  OrientationTestResultItem,
  OurService,
  OurStory,
  PastEvent,
  PaymentProofItem,
  PayoutRequestItem,
  Recognition,
  SiteSettings,
  StudyField,
  SupportTicketItem,
  Testimonial,
  UpcomingEvent,
  User,
  VerificationDocumentItem,
  // NEW
  ParentLinkItem,
  EmployeeRole,
} from "../types";

export const adminService = {
  getOverview: async () => {
    const { data } = await api.get<AdminOverview>("/admin/overview");
    return data;
  },
  getStats: async () => {
    const { data } = await api.get<{ students: number; universities: number; programs: number; applications: number }>("/admin/stats");
    return data;
  },
  getStudents: async () => {
    const { data } = await api.get<AdminStudentItem[]>("/admin/students");
    return data;
  },
  getStudentDetails: async (id: string) => {
    const { data } = await api.get<AdminStudentDetails>(`/admin/students/${id}`);
    return data;
  },
  getStudentDocuments: async () => {
    const { data } = await api.get<DocumentItem[]>("/admin/student-documents");
    return data;
  },
  // `version` is the document's __v; a stale version returns 409.
  reviewStudentDocument: async (id: string, payload: { detailedStatus: string; reviewNote?: string; expiresAt?: string | null; version: number }) => {
    const { data } = await api.patch<DocumentItem>(`/admin/student-documents/${id}`, payload);
    return data;
  },
  getStudentNotifications: async () => {
    const { data } = await api.get<NotificationItem[]>("/admin/student-notifications");
    return data;
  },
  getUsers: async () => {
    const { data } = await api.get<User[]>("/admin/users");
    return data;
  },
  updateUser: async (id: string, payload: Partial<User>) => {
    const { data } = await api.patch<User>(`/admin/users/${id}`, payload);
    return data;
  },
  updateSectionAccountStatus: async (section: "students" | "partners", id: string, isActive: boolean) => {
    const { data } = await api.patch<User>(`/admin/${section}/${id}/status`, { isActive });
    return data;
  },
  getApplications: async () => {
    const { data } = await api.get<Application[]>("/admin/applications");
    return data;
  },
  getAgencyRequests: async () => {
    const { data } = await api.get<AgencyRequest[]>("/admin/agency-requests");
    return data;
  },
  getPartners: async () => {
    const { data } = await api.get<AdminPartnerItem[]>("/admin/partners");
    return data;
  },
  getPartnerStudents: async (id: string) => {
    const { data } = await api.get<AgentStudentItem[]>(`/admin/partners/${id}/students`);
    return data;
  },
  getAllPartnerStudents: async () => {
    const { data } = await api.get<AgentStudentItem[]>("/admin/partner-students");
    return data;
  },
  updatePartnerStudentStatus: async (studentId: string, payload: { applicationStatus: AgentStudentItem["applicationStatus"]; notes?: string }) => {
    const { data } = await api.patch<AgentStudentItem>(`/admin/partner-students/${studentId}`, payload);
    return data;
  },
  getPartnerDetails: async (id: string) => {
    const { data } = await api.get<AdminPartnerDetails>(`/admin/partners/${id}`);
    return data;
  },
  updateAgencyRequestStatus: async (id: string, payload: { status: AgencyRequest["status"]; adminNote?: string }) => {
    const { data } = await api.patch<AgencyRequest>(`/admin/agency-requests/${id}`, payload);
    return data;
  },
  getPayoutRequests: async () => {
    const { data } = await api.get<PayoutRequestItem[]>("/admin/payout-requests");
    return data;
  },
  updatePayoutRequestStatus: async (id: string, payload: { status: PayoutRequestItem["status"]; reviewNote?: string }) => {
    const { data } = await api.patch<PayoutRequestItem>(`/admin/payout-requests/${id}`, payload);
    return data;
  },
  getMarketingAssets: async () => {
    const { data } = await api.get<MarketingAssetItem[]>("/admin/marketing-assets");
    return data;
  },
  createMarketingAsset: async (payload: { title: string; description?: string; type: string; file: File; published?: boolean }) => {
    const formData = new FormData();
    formData.append("title", payload.title);
    formData.append("description", payload.description || "");
    formData.append("type", payload.type);
    formData.append("published", String(payload.published ?? true));
    formData.append("file", payload.file);
    const { data } = await api.post<MarketingAssetItem>("/admin/marketing-assets", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    });
    return data;
  },
  updateMarketingAsset: async (id: string, payload: Partial<MarketingAssetItem>) => {
    const { data } = await api.put<MarketingAssetItem>(`/admin/marketing-assets/${id}`, payload);
    return data;
  },
  removeMarketingAsset: async (id: string) => {
    const { data } = await api.delete(`/admin/marketing-assets/${id}`);
    return data;
  },
  getVerificationDocuments: async () => {
    const { data } = await api.get<VerificationDocumentItem[]>("/admin/verification-documents");
    return data;
  },
  reviewVerificationDocument: async (id: string, payload: { status: VerificationDocumentItem["status"]; reviewNote?: string }) => {
    const { data } = await api.patch<VerificationDocumentItem>(`/admin/verification-documents/${id}`, payload);
    return data;
  },
  getSupportTickets: async () => {
    const { data } = await api.get<SupportTicketItem[]>("/admin/support-tickets");
    return data;
  },
  replySupportTicket: async (id: string, payload: { message: string; status?: SupportTicketItem["status"] }) => {
    const { data } = await api.patch<SupportTicketItem>(`/admin/support-tickets/${id}/reply`, payload);
    return data;
  },
  getKnowledgeBase: async () => {
    const { data } = await api.get<KnowledgeBaseItem[]>("/admin/knowledge-base");
    return data;
  },
  createKnowledgeBaseItem: async (payload: Partial<KnowledgeBaseItem>) => {
    const { data } = await api.post<KnowledgeBaseItem>("/admin/knowledge-base", payload);
    return data;
  },
  updateKnowledgeBaseItem: async (id: string, payload: Partial<KnowledgeBaseItem>) => {
    const { data } = await api.put<KnowledgeBaseItem>(`/admin/knowledge-base/${id}`, payload);
    return data;
  },
  removeKnowledgeBaseItem: async (id: string) => {
    const { data } = await api.delete(`/admin/knowledge-base/${id}`);
    return data;
  },
  getStudentFinancials: async () => {
    const { data } = await api.get<{ invoices: InvoiceItem[]; paymentProofs: PaymentProofItem[] }>("/admin/student-financials");
    return data;
  },
  createStudentInvoice: async (payload: Partial<InvoiceItem> & { studentId: string; applicationId?: string }) => {
    const { data } = await api.post<InvoiceItem>("/admin/student-financials/invoices", payload);
    return data;
  },
  updateStudentInvoice: async (id: string, payload: Partial<InvoiceItem>) => {
    const { data } = await api.patch<InvoiceItem>(`/admin/student-financials/invoices/${id}`, payload);
    return data;
  },
  reviewPaymentProof: async (id: string, payload: { status: PaymentProofItem["status"]; reviewNote?: string }) => {
    const { data } = await api.patch<PaymentProofItem>(`/admin/student-financials/payment-proofs/${id}`, payload);
    return data;
  },
  getArrivalRequests: async () => {
    const { data } = await api.get<ArrivalServiceRequestItem[]>("/admin/student-arrival-requests");
    return data;
  },
  updateArrivalRequest: async (id: string, payload: Partial<ArrivalServiceRequestItem>) => {
    const { data } = await api.patch<ArrivalServiceRequestItem>(`/admin/student-arrival-requests/${id}`, payload);
    return data;
  },
  getStudentFavorites: async () => {
    const { data } = await api.get<FavoriteItem[]>("/admin/student-favorites");
    return data;
  },
  getOrientationResults: async () => {
    const { data } = await api.get<OrientationTestResultItem[]>("/admin/student-orientation-results");
    return data;
  },
  updateOrientationResult: async (id: string, payload: Partial<OrientationTestResultItem>) => {
    const { data } = await api.patch<OrientationTestResultItem>(`/admin/student-orientation-results/${id}`, payload);
    return data;
  },
  getCountries: async () => {
    const { data } = await api.get<Country[]>("/admin/countries");
    return data;
  },
  getSiteSettings: async () => {
    const { data } = await api.get<SiteSettings>("/admin/site-settings");
    return data;
  },
  getStudyFields: async () => {
    const { data } = await api.get<StudyField[]>("/admin/study-fields");
    return data;
  },
  createCountry: async (payload: Partial<Country>) => {
    const { data } = await api.post<Country>("/admin/countries", payload);
    return data;
  },
  uploadCountryImage: async (file: File) => {
    const formData = new FormData();
    formData.append("file", file);
    const { data } = await api.post<{ url: string }>("/admin/countries/upload-image", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    });
    return data.url;
  },
  updateCountry: async (id: string, payload: Partial<Country>) => {
    const { data } = await api.put<Country>(`/admin/countries/${id}`, payload);
    return data;
  },
  updateSiteSettings: async (payload: Partial<SiteSettings>) => {
    const { data } = await api.put<SiteSettings>("/admin/site-settings", payload);
    return data;
  },
  createStudyField: async (payload: Partial<StudyField>) => {
    const { data } = await api.post<StudyField>("/admin/study-fields", payload);
    return data;
  },
  uploadStudyFieldImage: async (file: File) => {
    const formData = new FormData();
    formData.append("file", file);
    const { data } = await api.post<{ url: string }>("/admin/study-fields/upload-image", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    });
    return data.url;
  },
  updateStudyField: async (id: string, payload: Partial<StudyField>) => {
    const { data } = await api.put<StudyField>(`/admin/study-fields/${id}`, payload);
    return data;
  },
  removeStudyField: async (id: string) => {
    const { data } = await api.delete(`/admin/study-fields/${id}`);
    return data;
  },
  removeCountry: async (id: string) => {
    const { data } = await api.delete(`/admin/countries/${id}`);
    return data;
  },
  getTestimonials: async () => {
    const { data } = await api.get<Testimonial[]>("/admin/testimonials");
    return data;
  },
  getRecognitions: async () => {
    const { data } = await api.get<Recognition[]>("/admin/recognitions");
    return data;
  },
  getOurServices: async () => {
    const { data } = await api.get<OurService[]>("/admin/our-services");
    return data;
  },
  getOurStory: async () => {
    const { data } = await api.get<OurStory>("/admin/our-story");
    return data;
  },
  getFaqs: async () => {
    const { data } = await api.get<Faq[]>("/admin/faqs");
    return data;
  },
  getExhibitions: async () => {
    const { data } = await api.get<ExhibitionArticle[]>("/admin/exhibitions");
    return data;
  },
  getUpcomingEvent: async () => {
    const { data } = await api.get<UpcomingEvent>("/admin/upcoming-event");
    return data;
  },
  updateUpcomingEvent: async (payload: Partial<UpcomingEvent>) => {
    const { data } = await api.put<UpcomingEvent>("/admin/upcoming-event", payload);
    return data;
  },
  uploadUpcomingEventImage: async (file: File) => {
    const formData = new FormData();
    formData.append("file", file);
    const { data } = await api.post<{ url: string }>("/admin/upcoming-event/upload-image", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    });
    return data.url;
  },
  getPastEvents: async () => {
    const { data } = await api.get<PastEvent[]>("/admin/past-events");
    return data;
  },
  createPastEvent: async (payload: Partial<PastEvent>) => {
    const { data } = await api.post<PastEvent>("/admin/past-events", payload);
    return data;
  },
  updatePastEvent: async (id: string, payload: Partial<PastEvent>) => {
    const { data } = await api.put<PastEvent>(`/admin/past-events/${id}`, payload);
    return data;
  },
  removePastEvent: async (id: string) => {
    const { data } = await api.delete(`/admin/past-events/${id}`);
    return data;
  },
  uploadPastEventMedia: async (file: File) => {
    const formData = new FormData();
    formData.append("file", file);
    const { data } = await api.post<{ url: string; type: "image" | "video" }>("/admin/past-events/upload-media", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    });
    return data;
  },
  getEventRegistrations: async () => {
    const { data } = await api.get<EventRegistration[]>("/admin/event-registrations");
    return data;
  },
  createTestimonial: async (payload: Partial<Testimonial>) => {
    const { data } = await api.post<Testimonial>("/admin/testimonials", payload);
    return data;
  },
  uploadTestimonialAvatar: async (file: File) => {
    const formData = new FormData();
    formData.append("file", file);
    const { data } = await api.post<{ url: string }>("/admin/testimonials/upload-avatar", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    });
    return data.url;
  },
  createRecognition: async (payload: Partial<Recognition>) => {
    const { data } = await api.post<Recognition>("/admin/recognitions", payload);
    return data;
  },
  createOurService: async (payload: Partial<OurService>) => {
    const { data } = await api.post<OurService>("/admin/our-services", payload);
    return data;
  },
  createFaq: async (payload: Partial<Faq>) => {
    const { data } = await api.post<Faq>("/admin/faqs", payload);
    return data;
  },
  createExhibition: async (payload: Partial<ExhibitionArticle>) => {
    const { data } = await api.post<ExhibitionArticle>("/admin/exhibitions", payload);
    return data;
  },
  uploadExhibitionImage: async (file: File) => {
    const formData = new FormData();
    formData.append("file", file);
    const { data } = await api.post<{ url: string }>("/admin/exhibitions/upload-image", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    });
    return data.url;
  },
  updateTestimonial: async (id: string, payload: Partial<Testimonial>) => {
    const { data } = await api.put<Testimonial>(`/admin/testimonials/${id}`, payload);
    return data;
  },
  uploadRecognitionImage: async (file: File) => {
    const formData = new FormData();
    formData.append("file", file);
    const { data } = await api.post<{ url: string }>("/admin/recognitions/upload-image", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    });
    return data.url;
  },
  updateRecognition: async (id: string, payload: Partial<Recognition>) => {
    const { data } = await api.put<Recognition>(`/admin/recognitions/${id}`, payload);
    return data;
  },
  uploadOurServiceImage: async (file: File) => {
    const formData = new FormData();
    formData.append("file", file);
    const { data } = await api.post<{ url: string }>("/admin/our-services/upload-image", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    });
    return data.url;
  },
  uploadOurStoryImage: async (file: File) => {
    const formData = new FormData();
    formData.append("file", file);
    const { data } = await api.post<{ url: string }>("/admin/our-story/upload-image", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    });
    return data.url;
  },
  updateOurService: async (id: string, payload: Partial<OurService>) => {
    const { data } = await api.put<OurService>(`/admin/our-services/${id}`, payload);
    return data;
  },
  updateOurStory: async (payload: Partial<OurStory>) => {
    const { data } = await api.put<OurStory>("/admin/our-story", payload);
    return data;
  },
  updateFaq: async (id: string, payload: Partial<Faq>) => {
    const { data } = await api.put<Faq>(`/admin/faqs/${id}`, payload);
    return data;
  },
  updateExhibition: async (id: string, payload: Partial<ExhibitionArticle>) => {
    const { data } = await api.put<ExhibitionArticle>(`/admin/exhibitions/${id}`, payload);
    return data;
  },
  removeTestimonial: async (id: string) => {
    const { data } = await api.delete(`/admin/testimonials/${id}`);
    return data;
  },
  removeRecognition: async (id: string) => {
    const { data } = await api.delete(`/admin/recognitions/${id}`);
    return data;
  },
  removeOurService: async (id: string) => {
    const { data } = await api.delete(`/admin/our-services/${id}`);
    return data;
  },
  removeFaq: async (id: string) => {
    const { data } = await api.delete(`/admin/faqs/${id}`);
    return data;
  },
  removeExhibition: async (id: string) => {
    const { data } = await api.delete(`/admin/exhibitions/${id}`);
    return data;
  },
  // NEW — parent link approvals
  getParentLinks: async (status?: ParentLinkItem["status"] | "all") => {
    const { data } = await api.get<ParentLinkItem[]>("/admin/parent-links", {
      params: status && status !== "all" ? { status } : undefined,
    });
    return data;
  },
  updateParentLinkStatus: async (id: string, payload: { status: "approved" | "rejected"; adminNote?: string }) => {
    const { data } = await api.patch<ParentLinkItem>(`/admin/parent-links/${id}`, payload);
    return data;
  },
  // NEW — university accounts
  getUniversityAccounts: async () => {
    const { data } = await api.get<User[]>("/admin/university-accounts");
    return data;
  },
  createUniversityAccount: async (payload: { name: string; email: string; password: string; universityId: string }) => {
    const { data } = await api.post<User>("/admin/university-accounts", payload);
    return data;
  },
  updateUniversityAccount: async (id: string, payload: { isActive?: boolean; linkedUniversity?: string }) => {
    const { data } = await api.patch<User>(`/admin/university-accounts/${id}`, payload);
    return data;
  },
  // NEW — employee sub-roles
  getEmployees: async () => {
    const { data } = await api.get<User[]>("/admin/employees");
    return data;
  },
  updateEmployeeRole: async (id: string, payload: { employeeRole?: EmployeeRole; permissions?: string[] }) => {
    const { data } = await api.patch<User>(`/admin/employees/${id}/role`, payload);
    return data;
  },
};
