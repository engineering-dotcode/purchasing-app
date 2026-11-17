-- Demo data: two organizations, so tenant isolation has something to isolate.
-- Applied by `supabase db reset` (local) or `supabase db push --include-seed` (remote).
-- Fixed UUIDs keep the data easy to reference in queries and docs.
--
-- Rows are inserted directly, as the database owner, so RLS and the RPC functions
-- are bypassed here on purpose: there is no JWT (and no org_id) during seeding.

-- Users: one per organization. No password, so they cannot sign in; they only own rows.
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                        created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'a0000000-0000-0000-0000-000000000001',
   'authenticated', 'authenticated', 'buyer@acme.test', '', now(),
   '{"org_id": "10000000-0000-0000-0000-000000000001"}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'a0000000-0000-0000-0000-000000000002',
   'authenticated', 'authenticated', 'buyer@globex.test', '', now(),
   '{"org_id": "20000000-0000-0000-0000-000000000002"}', '{}', now(), now());

insert into organizations (id, name) values
  ('10000000-0000-0000-0000-000000000001', 'Acme Foods'),
  ('20000000-0000-0000-0000-000000000002', 'Globex Retail');

insert into vendors (id, organization_id, name, email, created_by) values
  ('b1000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001',
   'Fresh Farms Ltd', 'orders@freshfarms.test', 'a0000000-0000-0000-0000-000000000001'),
  ('b1000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001',
   'PackRight Supplies', 'sales@packright.test', 'a0000000-0000-0000-0000-000000000001'),
  ('b2000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002',
   'Northwind Wholesale', 'po@northwind.test', 'a0000000-0000-0000-0000-000000000002');

insert into products (id, organization_id, sku, name, unit_price, created_by) values
  ('c1000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001',
   'FLOUR-25', 'Wheat flour 25 kg', 18.50, 'a0000000-0000-0000-0000-000000000001'),
  ('c1000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001',
   'SUGAR-10', 'Cane sugar 10 kg', 12.00, 'a0000000-0000-0000-0000-000000000001'),
  ('c1000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001',
   'BOX-M', 'Cardboard box, medium', 0.45, 'a0000000-0000-0000-0000-000000000001'),
  ('c2000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002',
   'TEA-100', 'Black tea, 100 bags', 3.20, 'a0000000-0000-0000-0000-000000000002'),
  ('c2000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002',
   'MUG-W', 'White ceramic mug', 2.10, 'a0000000-0000-0000-0000-000000000002');

-- Orders cover every interesting status, plus one soft-deleted row.
insert into purchase_orders (id, organization_id, vendor_id, order_number, status,
                             expected_at, notes, received_at, created_by, created_at, deleted_at)
values
  -- Acme Foods
  ('d1000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001',
   'b1000000-0000-0000-0000-000000000001', 'PO-000001', 'DRAFT',
   current_date + 14, 'Weekly flour order', null,
   'a0000000-0000-0000-0000-000000000001', now() - interval '1 day', null),
  ('d1000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001',
   'b1000000-0000-0000-0000-000000000001', 'PO-000002', 'PENDING_APPROVAL',
   current_date + 10, null, null,
   'a0000000-0000-0000-0000-000000000001', now() - interval '3 days', null),
  ('d1000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001',
   'b1000000-0000-0000-0000-000000000002', 'PO-000003', 'CONFIRMED',
   current_date - 2, 'Overdue: expected two days ago', null,
   'a0000000-0000-0000-0000-000000000001', now() - interval '12 days', null),
  ('d1000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000001',
   'b1000000-0000-0000-0000-000000000001', 'PO-000004', 'PARTIALLY_RECEIVED',
   current_date - 5, 'Sugar short-shipped', null,
   'a0000000-0000-0000-0000-000000000001', now() - interval '20 days', null),
  ('d1000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000001',
   'b1000000-0000-0000-0000-000000000002', 'PO-000005', 'RECEIVED',
   current_date - 30, null, now() - interval '28 days',
   'a0000000-0000-0000-0000-000000000001', now() - interval '40 days', null),
  ('d1000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000001',
   'b1000000-0000-0000-0000-000000000002', 'PO-000006', 'CANCELLED',
   null, 'Duplicate of PO-000003', null,
   'a0000000-0000-0000-0000-000000000001', now() - interval '12 days', null),
  ('d1000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000001',
   'b1000000-0000-0000-0000-000000000001', 'PO-000007', 'DRAFT',
   null, 'Soft-deleted: hidden by RLS', null,
   'a0000000-0000-0000-0000-000000000001', now() - interval '6 days', now() - interval '5 days'),
  -- Globex Retail
  ('d2000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002',
   'b2000000-0000-0000-0000-000000000001', 'PO-000008', 'SUBMITTED',
   current_date + 7, null, null,
   'a0000000-0000-0000-0000-000000000002', now() - interval '2 days', null),
  ('d2000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002',
   'b2000000-0000-0000-0000-000000000001', 'PO-000009', 'REJECTED',
   null, 'Over budget', null,
   'a0000000-0000-0000-0000-000000000002', now() - interval '9 days', null);

insert into purchase_order_lines (purchase_order_id, product_id, quantity, received_quantity, unit_price) values
  ('d1000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 40, 0, 18.50),
  ('d1000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000001', 20, 0, 18.50),
  ('d1000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000002', 10, 0, 12.00),
  ('d1000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000003', 2000, 0, 0.45),
  ('d1000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000001', 30, 30, 18.50),
  ('d1000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000002', 25, 10, 12.00),
  ('d1000000-0000-0000-0000-000000000005', 'c1000000-0000-0000-0000-000000000003', 1000, 1000, 0.45),
  ('d1000000-0000-0000-0000-000000000006', 'c1000000-0000-0000-0000-000000000003', 2000, 0, 0.45),
  ('d1000000-0000-0000-0000-000000000007', 'c1000000-0000-0000-0000-000000000001', 5, 0, 18.50),
  ('d2000000-0000-0000-0000-000000000001', 'c2000000-0000-0000-0000-000000000001', 200, 0, 3.20),
  ('d2000000-0000-0000-0000-000000000001', 'c2000000-0000-0000-0000-000000000002', 150, 0, 2.10),
  ('d2000000-0000-0000-0000-000000000002', 'c2000000-0000-0000-0000-000000000002', 5000, 0, 2.10);

update purchase_orders po
   set total_amount = (
     select coalesce(sum(quantity * unit_price), 0)
     from purchase_order_lines l where l.purchase_order_id = po.id
   );

-- create_purchase_order() numbers each organization's orders from its counter; continue after the seed.
insert into purchase_order_counters (organization_id, last_number)
select organization_id, max(substring(order_number from '\d+$')::integer)
from purchase_orders
group by organization_id;
