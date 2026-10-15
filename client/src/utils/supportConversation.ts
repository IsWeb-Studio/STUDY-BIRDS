import type { SupportTicketItem } from "../types";

export const supportConversation = (ticket: SupportTicketItem) => {
  const replies = ticket.replies || [];
  const first = replies[0];
  // Older tickets also saved their opening message as the first reply.
  return first && first.fromRole !== "admin" && first.message.trim() === ticket.message.trim() ? replies.slice(1) : replies;
};
