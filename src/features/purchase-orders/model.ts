import type { Database } from '@/types/database';

type Tables = Database['public']['Tables'];

export type PurchaseOrder = Tables['purchase_orders']['Row'];
export type PurchaseOrderLine = Tables['purchase_order_lines']['Row'];
export type PurchaseOrderEmail = Tables['purchase_order_emails']['Row'];
export type PurchaseOrderStatus = Database['public']['Enums']['purchase_order_status'];

export type PurchaseOrderDetails = PurchaseOrder & {
  vendor: { id: string; name: string } | null;
  lines: PurchaseOrderLine[];
  emails: Pick<PurchaseOrderEmail, 'id' | 'to_email' | 'attempts' | 'last_error' | 'sent_at'>[];
};

// Statuses from which the submit-purchase-order Edge Function sends the order to the vendor.
export const SUBMITTABLE_STATUSES: PurchaseOrderStatus[] = ['DRAFT', 'PENDING_APPROVAL'];

// The vendor email that is queued but not sent yet (a failed send waiting for a retry).
export const unsentEmail = (order: PurchaseOrderDetails) =>
  order.status === 'SUBMITTED' ? order.emails.find((e) => !e.sent_at) : undefined;

export const CLOSED_STATUSES: PurchaseOrderStatus[] = ['RECEIVED', 'CANCELLED', 'REJECTED'];

// Mirrors transition_purchase_order() in 0008_purchase_order_functions.sql.
// The database is the source of truth; this map only drives which actions the UI offers.
export const ALLOWED_TRANSITIONS: Record<PurchaseOrderStatus, PurchaseOrderStatus[]> = {
  DRAFT: ['PENDING_APPROVAL', 'SUBMITTED', 'CANCELLED'],
  PENDING_APPROVAL: ['SUBMITTED', 'REJECTED', 'CANCELLED'],
  SUBMITTED: ['CONFIRMED', 'CANCELLED'],
  CONFIRMED: ['PARTIALLY_RECEIVED', 'RECEIVED', 'CANCELLED'],
  PARTIALLY_RECEIVED: ['RECEIVED'],
  RECEIVED: [],
  CANCELLED: [],
  REJECTED: [],
};

export const canTransition = (from: PurchaseOrderStatus, to: PurchaseOrderStatus) =>
  ALLOWED_TRANSITIONS[from].includes(to);

export const isClosed = (status: PurchaseOrderStatus) => CLOSED_STATUSES.includes(status);

export const STATUS_LABEL: Record<PurchaseOrderStatus, string> = {
  DRAFT: 'Draft',
  PENDING_APPROVAL: 'Pending approval',
  SUBMITTED: 'Submitted',
  CONFIRMED: 'Confirmed',
  PARTIALLY_RECEIVED: 'Partially received',
  RECEIVED: 'Received',
  CANCELLED: 'Cancelled',
  REJECTED: 'Rejected',
};
