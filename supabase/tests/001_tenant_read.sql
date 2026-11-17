-- Tenant isolation on read: a user sees only their organization's rows,
-- never soft-deleted ones, and nothing at all without an org_id claim.
-- Data comes from supabase/seed.sql (Acme Foods and Globex Retail).
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

-- Acme Foods buyer
set local role authenticated;
set local request.jwt.claims = '{"sub": "a0000000-0000-0000-0000-000000000001", "org_id": "10000000-0000-0000-0000-000000000001", "role": "authenticated"}';

select results_eq('select name from organizations', array['Acme Foods'],
  'Acme sees only its own organization');
select results_eq('select count(*) from vendors', array[2::bigint],
  'Acme sees its 2 vendors');
select results_eq('select count(*) from products', array[3::bigint],
  'Acme sees its 3 products');
select results_eq('select count(*) from purchase_orders', array[6::bigint],
  'Acme sees its 6 live orders');
select is_empty($$select 1 from purchase_orders where order_number = 'PO-000007'$$,
  'Acme does not see its soft-deleted order');
select is_empty($$select 1 from purchase_orders where organization_id <> '10000000-0000-0000-0000-000000000001'$$,
  'Acme sees no Globex orders');
select results_eq('select count(*) from purchase_order_lines', array[8::bigint],
  'Acme sees the lines of its live orders only');
select is_empty($$select 1 from purchase_order_lines where purchase_order_id = 'd1000000-0000-0000-0000-000000000007'$$,
  'Lines of a soft-deleted order are hidden');

-- Globex Retail buyer
set local request.jwt.claims = '{"sub": "a0000000-0000-0000-0000-000000000002", "org_id": "20000000-0000-0000-0000-000000000002", "role": "authenticated"}';

select results_eq('select name from organizations', array['Globex Retail'],
  'Globex sees only its own organization');
select results_eq('select count(*) from vendors', array[1::bigint],
  'Globex sees its 1 vendor');
select results_eq('select count(*) from products', array[2::bigint],
  'Globex sees its 2 products');
select results_eq('select count(*) from purchase_orders', array[2::bigint],
  'Globex sees its 2 orders');
select results_eq('select count(*) from purchase_order_lines', array[3::bigint],
  'Globex sees its 3 order lines');

-- Signed in, but no org_id claim: current_org_id() is null, so nothing matches.
set local request.jwt.claims = '{"sub": "a0000000-0000-0000-0000-000000000001", "role": "authenticated"}';

select is_empty('select 1 from purchase_orders', 'No org_id claim: no orders');
select is_empty('select 1 from vendors', 'No org_id claim: no vendors');

-- Anonymous visitor
set local role anon;
set local request.jwt.claims = '{"role": "anon"}';

select is_empty('select 1 from purchase_orders', 'Anonymous: no orders');

select * from finish();
rollback;
