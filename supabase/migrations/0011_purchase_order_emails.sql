-- Outbox for "send the order to the vendor" emails.
--
-- submit_purchase_order() queues the email and moves the order to SUBMITTED in
-- one transaction. transition_purchase_order() now refuses SUBMITTED without a
-- queued email, so an order is never SUBMITTED without one. The
-- submit-purchase-order Edge Function then sends the email and records each
-- attempt; an unsent email (sent_at is null) can be retried by calling the
-- function again for the same order.
--
-- Clients can only read the outbox. Writes go through the two RPCs below, so a
-- user cannot redirect an email (to_email) or insert/delete rows through
-- PostgREST. Known gap: record_purchase_order_email_attempt is callable by any
-- member of the organization (the Edge Function uses the caller's JWT, so the
-- database cannot tell them apart), so a member can mark a queued email as sent
-- without sending it. It cannot affect another organization.

-- Lets purchase_order_emails reference an order of the same organization.
create unique index purchase_orders_org_id_uq on purchase_orders (organization_id, id);

create table purchase_order_emails (
  id                uuid primary key default gen_random_uuid(),
  organization_id   uuid not null references organizations(id),
  purchase_order_id uuid not null,
  to_email          text not null,
  attempts          integer not null default 0 check (attempts >= 0),
  last_error        text,
  sent_at           timestamptz,
  created_by        uuid not null references auth.users(id),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz,
  foreign key (organization_id, purchase_order_id)
    references purchase_orders (organization_id, id)
);

-- One live email per order: a second submit cannot queue a duplicate.
create unique index purchase_order_emails_order_uq
  on purchase_order_emails (purchase_order_id)
  where deleted_at is null;

create index purchase_order_emails_unsent_idx
  on purchase_order_emails (organization_id, created_at)
  where sent_at is null and deleted_at is null;

alter table purchase_order_emails enable row level security;

-- Read-only for clients: there are no insert/update/delete policies, so RLS
-- rejects direct writes. Rows of archived orders are hidden with their order.
create policy purchase_order_emails_tenant_read on purchase_order_emails
  for select
  using (
    organization_id = current_org_id()
    and deleted_at is null
    and exists (
      select 1 from purchase_orders po
      where po.id = purchase_order_id and po.deleted_at is null
    )
  );

-- Queues the vendor email and moves the order to SUBMITTED, atomically.
--
-- Why security definer: the outbox has no write policy for clients (see
-- above), so only this function and record_purchase_order_email_attempt may
-- write it. It runs as the owner, so RLS does not apply inside: every query
-- below checks organization_id = current_org_id() and deleted_at itself, and
-- the order is locked before anything changes.
create or replace function submit_purchase_order(p_order_id uuid)
returns public.purchase_order_emails
language plpgsql security definer set search_path = '' as $$
declare
  v_order public.purchase_orders;
  v_email text;
  v_row   public.purchase_order_emails;
begin
  select * into v_order
    from public.purchase_orders
   where id = p_order_id
     and organization_id = public.current_org_id()
     and deleted_at is null
     for update;
  if not found then
    raise exception 'Purchase order not found' using errcode = 'P0002';
  end if;

  -- A readable error for an order that is already submitted (instead of the
  -- unique index on the outbox); transition_purchase_order still owns the rules.
  if exists (
    select 1 from public.purchase_order_emails
     where purchase_order_id = p_order_id and deleted_at is null
  ) then
    raise exception 'Cannot move purchase order from % to SUBMITTED', v_order.status;
  end if;

  select email into v_email
    from public.vendors
   where id = v_order.vendor_id
     and organization_id = v_order.organization_id
     and deleted_at is null;
  if v_email is null or btrim(v_email) = '' then
    raise exception 'Vendor has no email' using errcode = '22023';
  end if;

  if not exists (select 1 from public.purchase_order_lines where purchase_order_id = p_order_id) then
    raise exception 'Purchase order has no lines' using errcode = '22023';
  end if;

  -- Queue first: transition_purchase_order requires the queued email for SUBMITTED.
  -- If the transition is not allowed (e.g. already SUBMITTED) it raises and the
  -- whole function rolls back, including this insert.
  insert into public.purchase_order_emails (organization_id, purchase_order_id, to_email, created_by)
  values (v_order.organization_id, p_order_id, v_email, auth.uid())
  returning * into v_row;

  perform public.transition_purchase_order(p_order_id, 'SUBMITTED');

  return v_row;
end $$;

-- Records one send attempt: p_error null = sent. A sent email is final.
-- Why security definer: same as submit_purchase_order; the tenant check is explicit.
create or replace function record_purchase_order_email_attempt(p_email_id uuid, p_error text)
returns public.purchase_order_emails
language plpgsql security definer set search_path = '' as $$
declare
  v_row public.purchase_order_emails;
begin
  update public.purchase_order_emails
     set attempts   = attempts + 1,
         sent_at    = case when p_error is null then now() end,
         last_error = left(p_error, 500),
         updated_at = now()
   where id = p_email_id
     and organization_id = public.current_org_id()
     and deleted_at is null
     and sent_at is null
     and exists (
       select 1 from public.purchase_orders po
        where po.id = purchase_order_id and po.deleted_at is null
     )
  returning * into v_row;

  if not found then
    raise exception 'Email not found or already sent' using errcode = 'P0002';
  end if;
  return v_row;
end $$;

revoke execute on function submit_purchase_order(uuid) from public, anon;
grant execute on function submit_purchase_order(uuid) to authenticated;
revoke execute on function record_purchase_order_email_attempt(uuid, text) from public, anon;
grant execute on function record_purchase_order_email_attempt(uuid, text) to authenticated;

-- Same transitions as 0008, plus: SUBMITTED needs a queued vendor email, so
-- calling this RPC directly cannot submit an order past the outbox. Use
-- submit_purchase_order (or the submit-purchase-order Edge Function) instead.
-- search_path is pinned because submit_purchase_order calls it with an empty one.
create or replace function transition_purchase_order(
  p_order_id uuid,
  p_next     purchase_order_status
) returns purchase_orders
language plpgsql security invoker set search_path = public, pg_temp as $$
declare
  v_order purchase_orders;
begin
  select * into v_order from purchase_orders where id = p_order_id for update;
  if not found then
    raise exception 'Purchase order not found';
  end if;

  if not (
    (v_order.status = 'DRAFT'              and p_next in ('PENDING_APPROVAL', 'SUBMITTED', 'CANCELLED')) or
    (v_order.status = 'PENDING_APPROVAL'   and p_next in ('SUBMITTED', 'REJECTED', 'CANCELLED')) or
    (v_order.status = 'SUBMITTED'          and p_next in ('CONFIRMED', 'CANCELLED')) or
    (v_order.status = 'CONFIRMED'          and p_next in ('PARTIALLY_RECEIVED', 'RECEIVED', 'CANCELLED')) or
    (v_order.status = 'PARTIALLY_RECEIVED' and p_next = 'RECEIVED')
  ) then
    raise exception 'Cannot move purchase order from % to %', v_order.status, p_next;
  end if;

  if p_next = 'SUBMITTED' and not exists (
    select 1 from purchase_order_emails
     where purchase_order_id = p_order_id and deleted_at is null
  ) then
    raise exception 'Use submit_purchase_order to submit a purchase order';
  end if;

  update purchase_orders
     set status      = p_next,
         received_at = case when p_next = 'RECEIVED' then now() else received_at end,
         updated_at  = now()
   where id = p_order_id
  returning * into v_order;

  return v_order;
end $$;
