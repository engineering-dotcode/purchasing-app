import type { Database } from '@/types/database';

type Tables = Database['public']['Tables'];

export type PurchaseOrder = Tables['purchase_orders']['Row'];
export type PurchaseOrderLine = Tables['purchase_order_lines']['Row'];
export type PurchaseOrderStatus = Database['public']['Enums']['purchase_order_status'];

export type PurchaseOrderDetails = PurchaseOrder & {
  vendor: { id: string; name: string } | null;
  lines: PurchaseOrderLine[];
};

export const CLOSED_STATUSES: PurchaseOrderStatus[] = ['RECEIVED', 'CANCELLED', 'REJECTED'];

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
