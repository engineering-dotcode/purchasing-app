create type purchase_order_status as enum (
  'DRAFT', 'PENDING_APPROVAL', 'SUBMITTED', 'CONFIRMED',
  'PARTIALLY_RECEIVED', 'RECEIVED', 'CANCELLED', 'REJECTED'
);

create sequence purchase_order_number_seq;

create table purchase_orders (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id),
  vendor_id       uuid not null references vendors(id),
  order_number    text not null,
  status          purchase_order_status not null default 'DRAFT',
  notes           text,
  expected_at     date,
  total_amount    numeric(14,2) not null default 0,
  received_at     timestamptz,
  created_by      uuid not null references auth.users(id),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);

create unique index purchase_orders_number_uq
  on purchase_orders (organization_id, order_number)
  where deleted_at is null;

create index purchase_orders_org_status_idx
  on purchase_orders (organization_id, status)
  where deleted_at is null;

create table purchase_order_lines (
  id                uuid primary key default gen_random_uuid(),
  purchase_order_id uuid not null references purchase_orders(id),
  product_id        uuid not null references products(id),
  quantity          numeric(14,2) not null check (quantity > 0),
  received_quantity numeric(14,2) not null default 0,
  unit_price        numeric(14,2) not null check (unit_price >= 0)
);

-- Tenant comes from the signed JWT, never from the request payload
create or replace function current_org_id() returns uuid
language sql stable as $$
  select (auth.jwt() ->> 'org_id')::uuid
$$;

alter table purchase_orders enable row level security;
alter table purchase_order_lines enable row level security;

create policy purchase_orders_tenant on purchase_orders
  for all
  using (organization_id = current_org_id() and deleted_at is null)
  with check (organization_id = current_org_id());

create policy purchase_order_lines_tenant on purchase_order_lines
  for all
  using (exists (
    select 1 from purchase_orders po
    where po.id = purchase_order_id
      and po.organization_id = current_org_id()
      and po.deleted_at is null
  ));
