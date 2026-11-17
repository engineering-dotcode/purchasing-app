import { useEffect } from 'react';
import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/lib/supabase';
import {
  createPurchaseOrder,
  getPurchaseOrder,
  listPurchaseOrders,
  submitPurchaseOrder,
  transitionPurchaseOrder,
  type ListParams,
} from './api';
import type { PurchaseOrderStatus } from './model';

export const purchaseOrderKeys = {
  all: ['purchase-orders'] as const,
  list: (params: ListParams) => [...purchaseOrderKeys.all, 'list', params] as const,
  detail: (id: string) => [...purchaseOrderKeys.all, 'detail', id] as const,
};

export const usePurchaseOrders = (params: ListParams) =>
  useQuery({
    queryKey: purchaseOrderKeys.list(params),
    queryFn: () => listPurchaseOrders(params),
    placeholderData: keepPreviousData,
  });

export const usePurchaseOrder = (id: string) =>
  useQuery({
    queryKey: purchaseOrderKeys.detail(id),
    queryFn: () => getPurchaseOrder(id),
    enabled: Boolean(id),
  });

export const useCreatePurchaseOrder = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: createPurchaseOrder,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: purchaseOrderKeys.all }),
  });
};

export const useTransitionPurchaseOrder = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, next }: { id: string; next: PurchaseOrderStatus }) =>
      transitionPurchaseOrder(id, next),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: purchaseOrderKeys.all }),
  });
};

// Also on failure: a 502 means the order is SUBMITTED but the email still has to be retried.
export const useSubmitPurchaseOrder = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: submitPurchaseOrder,
    onSettled: () => queryClient.invalidateQueries({ queryKey: purchaseOrderKeys.all }),
  });
};

// Changes made by teammates show up without a page reload; RLS scopes events to the tenant
export const usePurchaseOrdersLiveUpdates = () => {
  const queryClient = useQueryClient();

  useEffect(() => {
    const channel = supabase
      .channel('purchase-orders')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'purchase_orders' }, () =>
        queryClient.invalidateQueries({ queryKey: purchaseOrderKeys.all })
      )
      .subscribe();

    return () => {
      void supabase.removeChannel(channel);
    };
  }, [queryClient]);
};
