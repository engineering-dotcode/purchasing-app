-- Known tenant-isolation and soft-delete gaps (1–2 found by rls-reviewer in 0007/0008, 3 by these tests).
-- Marked TODO: they run and report, but do not fail the suite.
-- When a migration fixes a gap, remove its todo() line so the test guards it from then on.
begin;
create extension if not exists pgtap with schema extensions;
select plan(5);

-- Acme Foods buyer
set local role authenticated;
set local request.jwt.claims = '{"sub": "a0000000-0000-0000-0000-000000000001", "org_id": "10000000-0000-0000-0000-000000000001", "role": "authenticated"}';

-- Gap 1: foreign keys are checked without RLS, so an order or line can point
-- at another organization's vendor or product (and confirm its UUID exists).
select todo('Gap 1: vendor_id / product_id FKs are not scoped to the organization', 3);

select throws_ok(
  $$insert into purchase_orders (organization_id, vendor_id, order_number, created_by)
    values (current_org_id(), 'b2000000-0000-0000-0000-000000000001', 'PO-X1', auth.uid())$$,
  null, null,
  'An Acme order cannot use a Globex vendor');

select throws_ok(
  $$insert into purchase_order_lines (purchase_order_id, product_id, quantity, unit_price)
    values ('d1000000-0000-0000-0000-000000000001', 'c2000000-0000-0000-0000-000000000001', 1, 1)$$,
  null, null,
  'An Acme order line cannot use a Globex product');

select throws_ok(
  $$select create_purchase_order('b2000000-0000-0000-0000-000000000001', null, null,
      '[{"productId": "c2000000-0000-0000-0000-000000000001", "quantity": 1, "unitPrice": 1}]')$$,
  null, null,
  'create_purchase_order rejects a Globex vendor and product');

-- Gap 2: one global sequence numbers every organization's orders, so the next
-- number reveals how many orders other organizations have created.
select todo('Gap 2: purchase order numbers come from one global sequence', 1);

set local request.jwt.claims = '{"sub": "a0000000-0000-0000-0000-000000000002", "org_id": "20000000-0000-0000-0000-000000000002", "role": "authenticated"}';

select is(
  (select order_number from create_purchase_order('b2000000-0000-0000-0000-000000000001', null, null,
     '[{"productId": "c2000000-0000-0000-0000-000000000001", "quantity": 1, "unitPrice": 1}]')),
  'PO-000003',
  'Globex numbering continues its own sequence (it has 2 orders)');

-- Gap 3: soft delete from the client is impossible. The policy's USING has
-- `deleted_at is null`, and Postgres also checks the new row of an UPDATE against it,
-- so `.update({ deleted_at })` fails with "new row violates row-level security policy".
select todo('Gap 3: a user cannot soft-delete their own rows', 1);

set local request.jwt.claims = '{"sub": "a0000000-0000-0000-0000-000000000001", "org_id": "10000000-0000-0000-0000-000000000001", "role": "authenticated"}';

select lives_ok(
  $$update purchase_orders set deleted_at = now()
    where id = 'd1000000-0000-0000-0000-000000000001'$$,
  'Acme can soft-delete its own order');

select * from finish();
rollback;
