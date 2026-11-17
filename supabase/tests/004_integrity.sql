-- Cross-tenant references, per-organization order numbers and soft delete.
-- These were open gaps (found by rls-reviewer and by these tests), fixed in 0009_fix_tenant_gaps.sql.
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

-- Acme Foods buyer
set local role authenticated;
set local request.jwt.claims = '{"sub": "a0000000-0000-0000-0000-000000000001", "app_metadata": {"org_id": "10000000-0000-0000-0000-000000000001"}, "role": "authenticated"}';

-- 1. References stay inside the organization
select throws_ok(
  $$insert into purchase_orders (organization_id, vendor_id, order_number, created_by)
    values (current_org_id(), 'b2000000-0000-0000-0000-000000000001', 'PO-X1', auth.uid())$$,
  '23503', null,
  'An Acme order cannot use a Globex vendor');

select throws_ok(
  $$insert into purchase_order_lines (purchase_order_id, product_id, quantity, unit_price)
    values ('d1000000-0000-0000-0000-000000000001', 'c2000000-0000-0000-0000-000000000001', 1, 1)$$,
  '23503', null,
  'An Acme order line cannot use a Globex product');

select throws_ok(
  $$update purchase_order_lines set product_id = 'c2000000-0000-0000-0000-000000000001'
    where purchase_order_id = 'd1000000-0000-0000-0000-000000000001'$$,
  '23503', null,
  'An Acme order line cannot be switched to a Globex product');

select throws_ok(
  $$select create_purchase_order('b2000000-0000-0000-0000-000000000001', null, null,
      '[{"productId": "c2000000-0000-0000-0000-000000000001", "quantity": 1, "unitPrice": 1}]')$$,
  '23503', null,
  'create_purchase_order rejects a Globex vendor');

select lives_ok(
  $$insert into purchase_order_lines (purchase_order_id, product_id, quantity, unit_price)
    values ('d1000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000002', 1, 1)$$,
  'An Acme order line can use an Acme product');

-- 2. Order numbers per organization: Acme's orders do not move Globex's numbering.
set local request.jwt.claims = '{"sub": "a0000000-0000-0000-0000-000000000002", "app_metadata": {"org_id": "20000000-0000-0000-0000-000000000002"}, "role": "authenticated"}';
select is(
  (select order_number from create_purchase_order('b2000000-0000-0000-0000-000000000001', null, null,
     '[{"productId": "c2000000-0000-0000-0000-000000000001", "quantity": 1, "unitPrice": 1}]')),
  'PO-000010', 'Globex continues after its highest number (PO-000009)');

set local request.jwt.claims = '{"sub": "a0000000-0000-0000-0000-000000000001", "app_metadata": {"org_id": "10000000-0000-0000-0000-000000000001"}, "role": "authenticated"}';
select is(
  (select order_number from create_purchase_order('b1000000-0000-0000-0000-000000000001', null, null,
     '[{"productId": "c1000000-0000-0000-0000-000000000001", "quantity": 1, "unitPrice": 1}]')),
  'PO-000008', 'Acme continues after its highest number (PO-000007, soft-deleted, not reused)');

set local request.jwt.claims = '{"sub": "a0000000-0000-0000-0000-000000000002", "app_metadata": {"org_id": "20000000-0000-0000-0000-000000000002"}, "role": "authenticated"}';
select is(
  (select order_number from create_purchase_order('b2000000-0000-0000-0000-000000000001', null, null,
     '[{"productId": "c2000000-0000-0000-0000-000000000001", "quantity": 1, "unitPrice": 1}]')),
  'PO-000011', 'Globex numbering is not affected by Acme creating an order');

-- 3. Soft delete goes through archive_purchase_order
set local request.jwt.claims = '{"sub": "a0000000-0000-0000-0000-000000000001", "app_metadata": {"org_id": "10000000-0000-0000-0000-000000000001"}, "role": "authenticated"}';

select lives_ok(
  $$select archive_purchase_order('d1000000-0000-0000-0000-000000000002')$$,
  'Acme can archive its own order');

select is_empty(
  $$select 1 from purchase_orders where id = 'd1000000-0000-0000-0000-000000000002'$$,
  'An archived order is hidden');

select throws_ok(
  $$select archive_purchase_order('d2000000-0000-0000-0000-000000000001')$$,
  'P0001', 'Purchase order not found',
  'Acme cannot archive a Globex order');

select throws_ok(
  $$select archive_purchase_order('d1000000-0000-0000-0000-000000000007')$$,
  'P0001', 'Purchase order not found',
  'An already archived order cannot be archived again');

select * from finish();
rollback;
