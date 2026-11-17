-- submit_purchase_order queues exactly one vendor email together with the
-- SUBMITTED transition; send attempts are recorded; other organizations can
-- neither see nor touch the email rows.
begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

-- Acme Foods buyer
set local role authenticated;
set local request.jwt.claims = '{"sub": "a0000000-0000-0000-0000-000000000001", "app_metadata": {"org_id": "10000000-0000-0000-0000-000000000001"}, "role": "authenticated"}';

-- PO-000001 is DRAFT, vendor Fresh Farms has an email
select results_eq(
  $$select to_email, attempts, sent_at is null from submit_purchase_order('d1000000-0000-0000-0000-000000000001')$$,
  $$values ('orders@freshfarms.test', 0, true)$$,
  'Submit queues one unsent email to the vendor');
select results_eq(
  $$select status::text from purchase_orders where id = 'd1000000-0000-0000-0000-000000000001'$$,
  array['SUBMITTED'], 'Submit moves the order to SUBMITTED');
select throws_ok(
  $$select submit_purchase_order('d1000000-0000-0000-0000-000000000001')$$,
  'P0001', 'Cannot move purchase order from SUBMITTED to SUBMITTED',
  'A second submit is rejected, so no duplicate email');
select results_eq(
  $$select count(*) from purchase_order_emails where purchase_order_id = 'd1000000-0000-0000-0000-000000000001'$$,
  array[1::bigint], 'Still exactly one email row');

-- Send attempts
select results_eq(
  $$select attempts, sent_at is null, last_error
      from record_purchase_order_email_attempt(
        (select id from purchase_order_emails where purchase_order_id = 'd1000000-0000-0000-0000-000000000001'),
        'SMTP timeout')$$,
  $$values (1, true, 'SMTP timeout')$$,
  'A failed attempt stays unsent and keeps the error');
select results_eq(
  $$select attempts, sent_at is not null, last_error is null
      from record_purchase_order_email_attempt(
        (select id from purchase_order_emails where purchase_order_id = 'd1000000-0000-0000-0000-000000000001'),
        null)$$,
  $$values (2, true, true)$$,
  'A successful retry marks the email sent');
select throws_ok(
  $$select record_purchase_order_email_attempt(
      (select id from purchase_order_emails where purchase_order_id = 'd1000000-0000-0000-0000-000000000001'), null)$$,
  'P0002', 'Email not found or already sent',
  'A sent email is final');

-- The outbox is read-only for clients: no redirecting or faking an email
select throws_ok(
  $$insert into purchase_order_emails (organization_id, purchase_order_id, to_email, created_by)
    values (current_org_id(), 'd1000000-0000-0000-0000-000000000002', 'x@evil.test', auth.uid())$$,
  '42501', null, 'Direct insert into the outbox is rejected');
select is_empty(
  $$update purchase_order_emails set to_email = 'x@evil.test' returning 1$$,
  'Direct update of the outbox changes nothing');
select is_empty(
  $$delete from purchase_order_emails returning 1$$,
  'Direct delete from the outbox removes nothing');
select results_eq(
  $$select to_email from purchase_order_emails where purchase_order_id = 'd1000000-0000-0000-0000-000000000001'$$,
  array['orders@freshfarms.test'], 'The queued email still goes to the vendor');

-- Preconditions: nothing changes when they fail
update vendors set email = null where id = 'b1000000-0000-0000-0000-000000000001';
select throws_ok(
  $$select submit_purchase_order('d1000000-0000-0000-0000-000000000002')$$,
  '22023', 'Vendor has no email', 'Vendor without email cannot be submitted to');
select results_eq(
  $$select status::text from purchase_orders where id = 'd1000000-0000-0000-0000-000000000002'$$,
  array['PENDING_APPROVAL'], 'Failed precondition leaves the status unchanged');

insert into purchase_orders (id, organization_id, vendor_id, order_number, created_by)
values ('d1000000-0000-0000-0000-0000000000ff', current_org_id(),
        'b1000000-0000-0000-0000-000000000002', 'PO-EMPTY', auth.uid());
select throws_ok(
  $$select submit_purchase_order('d1000000-0000-0000-0000-0000000000ff')$$,
  '22023', 'Purchase order has no lines', 'An order without lines cannot be submitted');

-- Globex Retail buyer
set local request.jwt.claims = '{"sub": "a0000000-0000-0000-0000-000000000002", "app_metadata": {"org_id": "20000000-0000-0000-0000-000000000002"}, "role": "authenticated"}';

select is_empty('select 1 from purchase_order_emails', 'Globex sees no Acme emails');
select throws_ok(
  $$select submit_purchase_order('d1000000-0000-0000-0000-000000000003')$$,
  'P0002', 'Purchase order not found', 'Globex cannot submit an Acme order');
select throws_ok(
  $$insert into purchase_order_emails (organization_id, purchase_order_id, to_email, created_by)
    values (current_org_id(), 'd1000000-0000-0000-0000-000000000003', 'x@evil.test', auth.uid())$$,
  '42501', null, 'Globex cannot queue an email for an Acme order');

-- Anonymous visitor
set local role anon;
set local request.jwt.claims = '{"role": "anon"}';
select throws_ok(
  $$select submit_purchase_order('d1000000-0000-0000-0000-000000000003')$$,
  '42501', null, 'Anonymous cannot call submit_purchase_order');

select * from finish();
rollback;
