import { useState } from 'react';
import { useDebouncedValue } from '@/hooks/useDebouncedValue';
import { usePurchaseOrders, usePurchaseOrdersLiveUpdates, useTransitionPurchaseOrder } from './hooks';
import { STATUS_LABEL, type PurchaseOrderDetails, type PurchaseOrderStatus } from './model';

const PAGE_SIZE = 25;

const currency = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' });

const STATUS_STYLE: Partial<Record<PurchaseOrderStatus, string>> = {
  DRAFT: 'bg-slate-100 text-slate-700',
  SUBMITTED: 'bg-blue-100 text-blue-700',
  CONFIRMED: 'bg-indigo-100 text-indigo-700',
  RECEIVED: 'bg-emerald-100 text-emerald-700',
  CANCELLED: 'bg-rose-100 text-rose-700',
  REJECTED: 'bg-rose-100 text-rose-700',
};

export function PurchaseOrderList() {
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(0);
  const debouncedSearch = useDebouncedValue(search, 300);

  const { data, isLoading, isError } = usePurchaseOrders({
    search: debouncedSearch,
    page,
    pageSize: PAGE_SIZE,
  });
  usePurchaseOrdersLiveUpdates();

  const totalPages = Math.max(1, Math.ceil((data?.total ?? 0) / PAGE_SIZE));

  return (
    <section className="flex flex-col gap-4 p-6">
      <input
        className="w-80 rounded-lg border border-slate-300 px-3 py-2"
        placeholder="Search by PO number"
        value={search}
        onChange={(e) => {
          setSearch(e.target.value);
          setPage(0);
        }}
      />

      {isLoading && <p className="text-slate-500">Loading…</p>}
      {isError && <p className="text-rose-600">Could not load purchase orders.</p>}

      <ul className="flex flex-col gap-2">
        {data?.items.map((order) => (
          <PurchaseOrderRow key={order.id} order={order} />
        ))}
      </ul>

      <nav className="flex items-center gap-3">
        <button disabled={page === 0} onClick={() => setPage((p) => p - 1)}>
          Prev
        </button>
        <span className="text-sm text-slate-500">
          {page + 1} / {totalPages}
        </span>
        <button disabled={page + 1 >= totalPages} onClick={() => setPage((p) => p + 1)}>
          Next
        </button>
      </nav>
    </section>
  );
}

function PurchaseOrderRow({ order }: { order: PurchaseOrderDetails }) {
  const { mutate: transition, isPending, error } = useTransitionPurchaseOrder();

  return (
    <li className="flex items-center justify-between rounded-lg border border-slate-200 p-4">
      <div className="flex flex-col">
        <span className="font-medium">{order.order_number}</span>
        <span className="text-sm text-slate-500">
          {order.vendor?.name ?? 'No vendor'} · {order.lines.length} lines ·{' '}
          {currency.format(order.total_amount)}
        </span>
        {error && <span className="text-sm text-rose-600">{error.message}</span>}
      </div>

      <div className="flex items-center gap-3">
        <span className={`rounded-full px-3 py-1 text-sm ${STATUS_STYLE[order.status] ?? 'bg-slate-100'}`}>
          {STATUS_LABEL[order.status]}
        </span>

        {order.status === 'DRAFT' && (
          <button
            className="rounded-lg bg-blue-600 px-3 py-1.5 text-white disabled:opacity-50"
            disabled={isPending}
            onClick={() => transition({ id: order.id, next: 'SUBMITTED' })}
          >
            Submit to vendor
          </button>
        )}
      </div>
    </li>
  );
}
