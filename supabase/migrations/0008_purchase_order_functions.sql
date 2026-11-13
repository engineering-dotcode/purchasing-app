create or replace function create_purchase_order(
  p_vendor_id   uuid,
  p_expected_at date,
  p_notes       text,
  p_lines       jsonb  -- [{ "productId": uuid, "quantity": number, "unitPrice": number }]
) returns purchase_orders
language plpgsql security invoker as $$
declare
  v_order purchase_orders;
begin
  if jsonb_array_length(coalesce(p_lines, '[]'::jsonb)) = 0 then
    raise exception 'A purchase order needs at least one line';
  end if;

  insert into purchase_orders (organization_id, vendor_id, order_number, expected_at, notes, created_by)
  values (
    current_org_id(),
    p_vendor_id,
    'PO-' || lpad(nextval('purchase_order_number_seq')::text, 6, '0'),
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

create or replace function transition_purchase_order(
  p_order_id uuid,
  p_next     purchase_order_status
) returns purchase_orders
language plpgsql security invoker as $$
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

  update purchase_orders
     set status      = p_next,
         received_at = case when p_next = 'RECEIVED' then now() else received_at end,
         updated_at  = now()
   where id = p_order_id
  returning * into v_order;

  return v_order;
end $$;
