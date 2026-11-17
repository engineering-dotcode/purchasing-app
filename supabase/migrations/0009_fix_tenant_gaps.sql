-- Fixes three gaps covered by supabase/tests/004_integrity.sql:
--   1. vendor_id / product_id could reference another organization's rows.
--   2. One global sequence numbered every organization's orders.
--   3. A user could not soft-delete their own order through RLS.

-------------------------------------------------------------------------------
-- 1. References stay inside the organization
-------------------------------------------------------------------------------

-- Foreign keys are checked without RLS, so a plain FK on vendor_id accepts any
-- vendor in the database. A composite FK forces the vendor's organization to
-- match the order's.
create unique index vendors_org_id_uq on vendors (organization_id, id);

alter table purchase_orders
  add constraint purchase_orders_vendor_same_org_fk
  foreign key (organization_id, vendor_id) references vendors (organization_id, id);

-- purchase_order_lines has no organization_id to build a composite FK on,
-- so a trigger compares the product's organization with the parent order's.
create or replace function check_purchase_order_line_org() returns trigger
language plpgsql security invoker as $$
declare
  v_org uuid;
begin
  select organization_id into v_org from purchase_orders where id = new.purchase_order_id;
  if not found then
    -- Order not visible: the RLS policy (or the FK, if it does not exist) rejects the row.
    return new;
  end if;

  if not exists (
    select 1 from products where id = new.product_id and organization_id = v_org
  ) then
    raise exception 'Product % does not belong to the organization of this purchase order', new.product_id
      using errcode = '23503';
  end if;
  return new;
end $$;

create trigger purchase_order_lines_same_org
  before insert or update of purchase_order_id, product_id on purchase_order_lines
  for each row execute function check_purchase_order_line_org();

-------------------------------------------------------------------------------
-- 2. Order numbers per organization
-------------------------------------------------------------------------------

-- One row per organization holding its last used number. Not a business
-- record: never soft-deleted, so no deleted_at.
create table purchase_order_counters (
  organization_id uuid primary key references organizations(id),
  last_number     integer not null check (last_number >= 0)
);

alter table purchase_order_counters enable row level security;

create policy purchase_order_counters_tenant on purchase_order_counters
  for all
  using (organization_id = current_org_id())
  with check (organization_id = current_org_id());

-- Continue after the highest number each organization already has (deleted
-- orders included, so a number is never reused).
insert into purchase_order_counters (organization_id, last_number)
select organization_id, max(substring(order_number from '\d+$')::integer)
from purchase_orders
group by organization_id;

create or replace function create_purchase_order(
  p_vendor_id   uuid,
  p_expected_at date,
  p_notes       text,
  p_lines       jsonb  -- [{ "productId": uuid, "quantity": number, "unitPrice": number }]
) returns purchase_orders
language plpgsql security invoker as $$
declare
  v_order  purchase_orders;
  v_number integer;
begin
  if jsonb_array_length(coalesce(p_lines, '[]'::jsonb)) = 0 then
    raise exception 'A purchase order needs at least one line';
  end if;

  -- The row lock on the counter serializes concurrent creates within one organization.
  insert into purchase_order_counters as c (organization_id, last_number)
  values (current_org_id(), 1)
  on conflict (organization_id) do update set last_number = c.last_number + 1
  returning c.last_number into v_number;

  insert into purchase_orders (organization_id, vendor_id, order_number, expected_at, notes, created_by)
  values (
    current_org_id(),
    p_vendor_id,
    'PO-' || lpad(v_number::text, 6, '0'),
    p_expected_at,
    p_notes,
    auth.uid()
  )
  returning * into v_order;

  insert into purchase_order_lines (purchase_order_id, product_id, quantity, unit_price)
  select v_order.id,
         (line ->> 'productId')::uuid,
         (line ->> 'quantity')::numeric,
         (line ->> 'unitPrice')::numeric
  from jsonb_array_elements(p_lines) as line;

  update purchase_orders
     set total_amount = (
       select coalesce(sum(quantity * unit_price), 0)
       from purchase_order_lines where purchase_order_id = v_order.id
     )
   where id = v_order.id
  returning * into v_order;

  return v_order;
end $$;

drop sequence purchase_order_number_seq;

-------------------------------------------------------------------------------
-- 3. Soft delete of an order
-------------------------------------------------------------------------------

-- Why security definer: an UPDATE with a WHERE clause must also pass the
-- policy's USING for the new row, and USING requires `deleted_at is null`.
-- So setting deleted_at is impossible as the invoker without exposing deleted
-- rows to SELECT. This function runs as the owner and does its own tenant check
-- with current_org_id(), touching exactly one live row of the caller's organization.
create or replace function archive_purchase_order(p_order_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.purchase_orders
     set deleted_at = now(),
         updated_at = now()
   where id = p_order_id
     and organization_id = public.current_org_id()
     and deleted_at is null;

  if not found then
    raise exception 'Purchase order not found';
  end if;
end $$;

revoke execute on function archive_purchase_order(uuid) from public, anon;
grant execute on function archive_purchase_order(uuid) to authenticated;
