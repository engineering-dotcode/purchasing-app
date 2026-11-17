import { supabase } from '@/lib/supabase';
import { CLOSED_STATUSES, type PurchaseOrderDetails, type PurchaseOrderStatus } from './model';

const SELECT_DETAILS = `
  *,
  vendor:vendors!purchase_orders_vendor_id_fkey ( id, name ),
  lines:purchase_order_lines ( * )
`;

export type ListParams = {
  search?: string;
  includeClosed?: boolean;
  page: number;
  pageSize: number;
};

export type CreatePurchaseOrderInput = {
  vendorId: string;
  expectedAt?: string;
  notes?: string;
  lines: { productId: string; quantity: number; unitPrice: number }[];
};

export async function listPurchaseOrders({ search, includeClosed, page, pageSize }: ListParams) {
  let query = supabase
    .from('purchase_orders')
    .select(SELECT_DETAILS, { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(page * pageSize, (page + 1) * pageSize - 1);

  if (search) query = query.ilike('order_number', `%${search}%`);
  if (!includeClosed) query = query.not('status', 'in', `(${CLOSED_STATUSES.join(',')})`);

  const { data, count, error } = await query;
  if (error) throw error;
  return { items: data as PurchaseOrderDetails[], total: count ?? 0 };
}

export async function getPurchaseOrder(id: string) {
  const { data, error } = await supabase
    .from('purchase_orders')
    .select(SELECT_DETAILS)
    .eq('id', id)
    .single();
  if (error) throw error;
  return data as PurchaseOrderDetails;
}

export async function createPurchaseOrder(input: CreatePurchaseOrderInput) {
  const { data, error } = await supabase.rpc('create_purchase_order', {
    p_vendor_id: input.vendorId,
    p_expected_at: input.expectedAt ?? null,
    p_notes: input.notes ?? null,
    p_lines: input.lines,
  });
  if (error) throw error;
  return data;
}

export async function transitionPurchaseOrder(id: string, next: PurchaseOrderStatus) {
  const { data, error } = await supabase.rpc('transition_purchase_order', {
    p_order_id: id,
    p_next: next,
  });
  if (error) throw error;
  return data;
}

export async function archivePurchaseOrder(id: string) {
  // RPC, not .update({ deleted_at }): RLS rejects that update (see 0009_fix_tenant_gaps.sql).
  const { error } = await supabase.rpc('archive_purchase_order', { p_order_id: id });
  if (error) throw error;
}
