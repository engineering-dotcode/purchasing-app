-- Tenant isolation on write: a user cannot create, change or soft-delete rows
-- of another organization, and cannot move their own rows into one.
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

-- Acme Foods buyer
set local role authenticated;
set local request.jwt.claims = '{"sub": "a0000000-0000-0000-0000-000000000001", "org_id": "10000000-0000-0000-0000-000000000001", "role": "authenticated"}';

-- Inserts
select lives_ok(
  $$insert into vendors (organization_id, name, created_by)
    values ('10000000-0000-0000-0000-000000000001', 'New Acme vendor', auth.uid())$$,
  'Acme can add a vendor to its own organization');

select throws_ok(
  $$insert into vendors (organization_id, name, created_by)
    values ('20000000-0000-0000-0000-000000000002', 'Planted vendor', auth.uid())$$,
  '42501', null,
  'Acme cannot add a vendor to Globex');

select throws_ok(
  $$insert into products (organization_id, sku, name, created_by)
    values ('20000000-0000-0000-0000-000000000002', 'X-1', 'Planted product', auth.uid())$$,
  '42501', null,
  'Acme cannot add a product to Globex');

select throws_ok(
  $$insert into purchase_orders (organization_id, vendor_id, order_number, created_by)
    values ('20000000-0000-0000-0000-000000000002', 'b2000000-0000-0000-0000-000000000001', 'PO-X', auth.uid())$$,
  '42501', null,
  'Acme cannot add an order to Globex');

select throws_ok(
  $$insert into purchase_order_lines (purchase_order_id, product_id, quantity, unit_price)
    values ('d2000000-0000-0000-0000-000000000001', 'c2000000-0000-0000-0000-000000000001', 1, 1)$$,
  '42501', null,
  'Acme cannot add a line to a Globex order');

select throws_ok(
  $$insert into organizations (name) values ('Rogue Org')$$,
  '42501', null,
  'Organizations cannot be created from the client');

-- Updates of another organization's rows match nothing.
select is_empty(
  $$update purchase_orders set notes = 'hacked'
    where id = 'd2000000-0000-0000-0000-000000000001' returning id$$,
  'Acme cannot update a Globex order');

select is_empty(
  $$update vendors set name = 'hacked'
    where id = 'b2000000-0000-0000-0000-000000000001' returning id$$,
  'Acme cannot update a Globex vendor');

select is_empty(
  $$update purchase_order_lines set quantity = 1
    where purchase_order_id = 'd2000000-0000-0000-0000-000000000001' returning id$$,
  'Acme cannot update lines of a Globex order');

-- Moving an own row into another organization is rejected by WITH CHECK.
select throws_ok(
  $$update vendors set organization_id = '20000000-0000-0000-0000-000000000002'
    where id = 'b1000000-0000-0000-0000-000000000001'$$,
  '42501', null,
  'Acme cannot move its vendor into Globex');

-- Soft delete of another organization's order matches nothing.
select is_empty(
  $$update purchase_orders set deleted_at = now()
    where id = 'd2000000-0000-0000-0000-000000000001' returning id$$,
  'Acme cannot soft-delete a Globex order');

-- Check as Globex that its rows are untouched.
set local request.jwt.claims = '{"sub": "a0000000-0000-0000-0000-000000000002", "org_id": "20000000-0000-0000-0000-000000000002", "role": "authenticated"}';

select results_eq(
  $$select notes from purchase_orders where id = 'd2000000-0000-0000-0000-000000000001' and deleted_at is null$$,
  array[null::text],
  'The Globex order is unchanged and not deleted');

select * from finish();
rollback;
