// Sends a purchase order to its vendor:
//   1. moves it to SUBMITTED through the transition_purchase_order RPC
//      (transition rules stay in the database);
//   2. emails the vendor the order number, lines and expected date.
//
// Runs as the calling user: the client is built with the anon key and the
// caller's JWT, so RLS and current_org_id() apply exactly as in the frontend.
// Never use the service role key here.
//
// Email goes through Resend when RESEND_API_KEY is set. Without it the
// function is in dry-run mode: the status still changes and the email that
// would have been sent is returned in the response.
//
// POST /functions/v1/submit-purchase-order   { "orderId": "<uuid>" }

import { createClient } from 'npm:@supabase/supabase-js@2';

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json(405, { error: 'Use POST' });

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json(401, { error: 'Missing Authorization header' });

  const { orderId } = await req.json().catch(() => ({}));
  if (typeof orderId !== 'string') return json(400, { error: 'orderId is required' });

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );

  // Preconditions first, so nothing changes when the email cannot be sent.
  const { data: order, error: readError } = await supabase
    .from('purchase_orders')
    .select(`
      id, order_number, status, expected_at,
      vendor:vendors!purchase_orders_vendor_id_fkey ( name, email ),
      lines:purchase_order_lines ( quantity, product:products ( sku, name ) )
    `)
    .eq('id', orderId)
    .maybeSingle();

  if (readError) return json(500, { error: readError.message });
  // RLS hides other organizations' orders, so "not yours" is also 404.
  if (!order) return json(404, { error: 'Purchase order not found' });
  if (!order.vendor?.email) return json(422, { error: 'Vendor has no email' });
  if (order.lines.length === 0) return json(422, { error: 'Purchase order has no lines' });

  const { error: rpcError } = await supabase.rpc('transition_purchase_order', {
    p_order_id: orderId,
    p_next: 'SUBMITTED',
  });
  // The RPC rejects invalid transitions, including a second submit: no duplicate email.
  if (rpcError) return json(409, { error: rpcError.message });

  const email = {
    to: order.vendor.email,
    subject: `Purchase order ${order.order_number}`,
    text: [
      `Hello ${order.vendor.name},`,
      '',
      `Please find our purchase order ${order.order_number}.`,
      `Expected delivery: ${order.expected_at ?? 'not set'}`,
      '',
      ...order.lines.map((l) => `- ${l.product?.sku} ${l.product?.name}: ${l.quantity}`),
    ].join('\n'),
  };

  const resendKey = Deno.env.get('RESEND_API_KEY');
  if (!resendKey) return json(200, { status: 'SUBMITTED', dryRun: true, email });

  const sent = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${resendKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from: Deno.env.get('EMAIL_FROM') ?? 'onboarding@resend.dev',
      to: email.to,
      subject: email.subject,
      text: email.text,
    }),
  });

  if (!sent.ok) {
    // The order is already SUBMITTED and cannot go back; report it so it can be resent by hand.
    console.error('Email failed', order.order_number, sent.status, await sent.text());
    return json(502, { status: 'SUBMITTED', error: 'Order submitted, but the email was not sent' });
  }

  return json(200, { status: 'SUBMITTED', dryRun: false, to: email.to });
});
