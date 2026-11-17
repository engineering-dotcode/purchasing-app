// Sends a purchase order to its vendor.
//
//   DRAFT / PENDING_APPROVAL → submit_purchase_order RPC: moves the order to
//     SUBMITTED (through transition_purchase_order) and queues the vendor email
//     in purchase_order_emails, in one transaction.
//   SUBMITTED with an unsent email → retries that email.
//   Anything else → 409.
//
// Then the email is sent and the attempt recorded with
// record_purchase_order_email_attempt. If sending fails the order stays
// SUBMITTED with the email unsent (502); calling the function again retries it.
//
// Runs as the calling user: the client is built with the anon key and the
// caller's JWT, so RLS and current_org_id() apply exactly as in the frontend.
// Never use the service role key here.
//
// Email goes through Resend with RESEND_API_KEY (RESEND_API_URL can point
// elsewhere for tests). Dry-run only with an explicit DRY_RUN=true: nothing is
// sent, the attempt is recorded as sent and the email is returned. A missing
// key without DRY_RUN is a failed attempt (502), retryable once the key is set,
// so a forgotten secret never marks real emails as sent.
//
// POST /functions/v1/submit-purchase-order   { "orderId": "<uuid>" }

import { createClient } from 'npm:@supabase/supabase-js@2';

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Postgres error code → HTTP status for submit_purchase_order.
const RPC_STATUS: Record<string, number> = {
  P0002: 404, // order not found (RLS hides other organizations' orders)
  '22023': 422, // vendor has no email / order has no lines
  P0001: 409, // transition not allowed
};

type EmailRow = { id: string; to_email: string; sent_at: string | null };

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
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

  const { data: order, error: readError } = await supabase
    .from('purchase_orders')
    .select(`
      id, order_number, status, expected_at,
      vendor:vendors!purchase_orders_vendor_id_fkey ( name ),
      lines:purchase_order_lines ( quantity, product:products ( sku, name ) ),
      emails:purchase_order_emails ( id, to_email, sent_at )
    `)
    .eq('id', orderId)
    .maybeSingle();

  if (readError) return json(500, { error: readError.message });
  if (!order) return json(404, { error: 'Purchase order not found' });

  let email: EmailRow | undefined;
  if (order.status === 'DRAFT' || order.status === 'PENDING_APPROVAL') {
    const { data, error } = await supabase.rpc('submit_purchase_order', { p_order_id: orderId });
    if (error) return json(RPC_STATUS[error.code] ?? 500, { error: error.message });
    email = data as EmailRow;
  } else {
    email = (order.emails as EmailRow[]).find((e) => !e.sent_at);
    if (order.status !== 'SUBMITTED' || !email) {
      return json(409, { error: `Order is ${order.status} and its email was already sent` });
    }
  }

  const message = {
    to: email.to_email,
    subject: `Purchase order ${order.order_number}`,
    text: [
      `Hello ${order.vendor?.name},`,
      '',
      `Please find our purchase order ${order.order_number}.`,
      `Expected delivery: ${order.expected_at ?? 'not set'}`,
      '',
      ...order.lines.map((l) => `- ${l.product?.sku} ${l.product?.name}: ${l.quantity}`),
    ].join('\n'),
  };

  const sendError = await send(message);

  const { data: recorded, error: recordError } = await supabase.rpc(
    'record_purchase_order_email_attempt',
    { p_email_id: email.id, p_error: sendError },
  );
  if (recordError) {
    console.error('Could not record email attempt', order.order_number, recordError.message);
  }

  if (sendError) {
    console.error('Email failed', order.order_number, sendError);
    return json(502, {
      status: 'SUBMITTED',
      emailSent: false,
      attempts: recorded?.attempts,
      error: 'Order submitted, but the email was not sent. Call again to retry.',
    });
  }

  const dryRun = isDryRun();
  return json(200, {
    status: 'SUBMITTED',
    emailSent: true,
    attempts: recorded?.attempts,
    dryRun,
    ...(dryRun ? { email: message } : { to: message.to }),
  });
});

const isDryRun = () => Deno.env.get('DRY_RUN') === 'true';

// Returns null when sent, otherwise the error text.
async function send(message: { to: string; subject: string; text: string }): Promise<string | null> {
  if (isDryRun()) return null;
  const key = Deno.env.get('RESEND_API_KEY');
  if (!key) return 'RESEND_API_KEY is not set';

  try {
    const res = await fetch(Deno.env.get('RESEND_API_URL') ?? 'https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: Deno.env.get('EMAIL_FROM') ?? 'onboarding@resend.dev',
        ...message,
      }),
    });
    return res.ok ? null : `Email provider returned ${res.status}: ${(await res.text()).slice(0, 500)}`;
  } catch (e) {
    return `Email provider unreachable: ${e instanceof Error ? e.message : String(e)}`;
  }
}
