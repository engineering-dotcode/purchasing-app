-- transition_purchase_order: allowed transitions pass, forbidden ones raise,
-- and another organization's order cannot be found at all (RLS inside a security invoker function).
begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

-- Acme Foods buyer
set local role authenticated;
set local request.jwt.claims = '{"sub": "a0000000-0000-0000-0000-000000000001", "app_metadata": {"org_id": "10000000-0000-0000-0000-000000000001"}, "role": "authenticated"}';

-- PO-000001 is DRAFT. SUBMITTED needs the vendor email queued (0011), so
-- transition_purchase_order alone refuses it and submit_purchase_order does it.
select throws_ok(
  $$select transition_purchase_order('d1000000-0000-0000-0000-000000000001', 'SUBMITTED')$$,
  'P0001', 'Use submit_purchase_order to submit a purchase order',
  'DRAFT -> SUBMITTED directly is refused (no queued email)');
select submit_purchase_order('d1000000-0000-0000-0000-000000000001');
select results_eq(
  $$select status::text from purchase_orders where id = 'd1000000-0000-0000-0000-000000000001'$$,
  array['SUBMITTED'], 'DRAFT -> SUBMITTED through submit_purchase_order');
select results_eq(
  $$select status::text from transition_purchase_order('d1000000-0000-0000-0000-000000000001', 'CONFIRMED')$$,
  array['CONFIRMED'], 'SUBMITTED -> CONFIRMED is allowed');
select results_eq(
  $$select status::text from transition_purchase_order('d1000000-0000-0000-0000-000000000001', 'RECEIVED')$$,
  array['RECEIVED'], 'CONFIRMED -> RECEIVED is allowed');
select isnt(
  (select received_at from purchase_orders where id = 'd1000000-0000-0000-0000-000000000001'),
  null, 'RECEIVED sets received_at');

-- Forbidden transitions
select throws_ok(
  $$select transition_purchase_order('d1000000-0000-0000-0000-000000000001', 'DRAFT')$$,
  'P0001', 'Cannot move purchase order from RECEIVED to DRAFT',
  'A closed order cannot be reopened');
select throws_ok(
  $$select transition_purchase_order('d1000000-0000-0000-0000-000000000004', 'CANCELLED')$$,
  'P0001', 'Cannot move purchase order from PARTIALLY_RECEIVED to CANCELLED',
  'A partially received order cannot be cancelled');
select throws_ok(
  $$select transition_purchase_order('d1000000-0000-0000-0000-000000000006', 'SUBMITTED')$$,
  'P0001', 'Cannot move purchase order from CANCELLED to SUBMITTED',
  'A cancelled order stays cancelled');

-- Tenant and soft delete
select throws_ok(
  $$select transition_purchase_order('d2000000-0000-0000-0000-000000000001', 'CONFIRMED')$$,
  'P0001', 'Purchase order not found',
  'Acme cannot transition a Globex order');
select throws_ok(
  $$select transition_purchase_order('d1000000-0000-0000-0000-000000000007', 'SUBMITTED')$$,
  'P0001', 'Purchase order not found',
  'A soft-deleted order cannot be transitioned');

select * from finish();
rollback;
