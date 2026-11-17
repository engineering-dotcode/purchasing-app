// End-to-end test of the submit-purchase-order Edge Function against the local
// Supabase stack (seed data). Run through scripts/test-edge-functions.sh, which
// serves the function with RESEND_API_URL pointing at the mock below.
//
// Named e2e.mjs, not *.test.*, so vitest does not pick it up: it needs the
// running stack. It changes data, so run it on a fresh `supabase db reset`.

import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import http from 'node:http';

const API_URL = process.env.API_URL ?? 'http://127.0.0.1:54321';
const ANON_KEY = process.env.ANON_KEY;
const JWT_SECRET = process.env.JWT_SECRET;
const MOCK_PORT = Number(process.env.MOCK_EMAIL_PORT ?? 54399);
assert.ok(ANON_KEY && JWT_SECRET, 'ANON_KEY and JWT_SECRET must be set (supabase status -o env)');

const ACME = { sub: 'a0000000-0000-0000-0000-000000000001', org: '10000000-0000-0000-0000-000000000001' };
const GLOBEX = { sub: 'a0000000-0000-0000-0000-000000000002', org: '20000000-0000-0000-0000-000000000002' };
const PO_DRAFT = 'd1000000-0000-0000-0000-000000000001'; // Acme, DRAFT
const PO_PENDING = 'd1000000-0000-0000-0000-000000000002'; // Acme, PENDING_APPROVAL
const PO_CONFIRMED = 'd1000000-0000-0000-0000-000000000003'; // Acme, CONFIRMED

// Same shape as a token issued by Supabase Auth: the tenant is in app_metadata.
function jwt({ sub, org }) {
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const header = b64({ alg: 'HS256', typ: 'JWT' });
  const payload = b64({
    sub,
    role: 'authenticated',
    aud: 'authenticated',
    app_metadata: { org_id: org },
    exp: Math.floor(Date.now() / 1000) + 600,
  });
  const sig = crypto.createHmac('sha256', JWT_SECRET).update(`${header}.${payload}`).digest('base64url');
  return `${header}.${payload}.${sig}`;
}

async function submit(user, orderId) {
  const headers = { 'Content-Type': 'application/json' };
  if (user) headers.Authorization = `Bearer ${jwt(user)}`;
  const res = await fetch(`${API_URL}/functions/v1/submit-purchase-order`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ orderId }),
  });
  return { status: res.status, body: await res.json() };
}

// Reads through the REST API as the user, so RLS applies.
async function emailRow(user, orderId) {
  const url = `${API_URL}/rest/v1/purchase_order_emails` +
    `?purchase_order_id=eq.${orderId}&select=to_email,attempts,sent_at,last_error`;
  const res = await fetch(url, { headers: { apikey: ANON_KEY, Authorization: `Bearer ${jwt(user)}` } });
  assert.equal(res.status, 200, await res.clone().text());
  return res.json();
}

// Mock email provider: records requests, fails while `failNext` > 0.
const sent = [];
let failNext = 0;
const mock = http.createServer((req, res) => {
  let body = '';
  req.on('data', (c) => (body += c));
  req.on('end', () => {
    if (failNext > 0) {
      failNext--;
      res.writeHead(503).end('provider down');
      return;
    }
    sent.push(JSON.parse(body));
    res.writeHead(200, { 'Content-Type': 'application/json' }).end('{"id":"mock"}');
  });
});
before(() => new Promise((r) => mock.listen(MOCK_PORT, '0.0.0.0', r)));
after(() => mock.close());

test('no token → 401', async () => {
  assert.equal((await submit(null, PO_DRAFT)).status, 401);
});

test("another organization's order → 404, nothing changes", async () => {
  const r = await submit(GLOBEX, PO_DRAFT);
  assert.equal(r.status, 404);
  assert.equal(sent.length, 0);
  assert.deepEqual(await emailRow(ACME, PO_DRAFT), []);
});

test('own DRAFT order → 200, SUBMITTED, one email sent to the vendor', async () => {
  const r = await submit(ACME, PO_DRAFT);
  assert.equal(r.status, 200, JSON.stringify(r.body));
  assert.equal(r.body.emailSent, true);
  assert.equal(sent.length, 1);
  assert.equal(sent[0].to, 'orders@freshfarms.test');
  assert.match(sent[0].text, /FLOUR-25/);

  const [row] = await emailRow(ACME, PO_DRAFT);
  assert.equal(row.attempts, 1);
  assert.ok(row.sent_at);
});

test('submitting again → 409, no duplicate email', async () => {
  const r = await submit(ACME, PO_DRAFT);
  assert.equal(r.status, 409);
  assert.equal(sent.length, 1);
});

test('the other organization cannot see the email row', async () => {
  assert.deepEqual(await emailRow(GLOBEX, PO_DRAFT), []);
});

test('provider down → 502, order SUBMITTED, email kept for retry; retry sends it', async () => {
  failNext = 1;
  const failed = await submit(ACME, PO_PENDING);
  assert.equal(failed.status, 502, JSON.stringify(failed.body));
  assert.equal(failed.body.status, 'SUBMITTED');
  let [row] = await emailRow(ACME, PO_PENDING);
  assert.equal(row.attempts, 1);
  assert.equal(row.sent_at, null);
  assert.match(row.last_error, /503/);

  const retried = await submit(ACME, PO_PENDING);
  assert.equal(retried.status, 200, JSON.stringify(retried.body));
  assert.equal(retried.body.attempts, 2);
  assert.equal(sent.length, 2);
  [row] = await emailRow(ACME, PO_PENDING);
  assert.ok(row.sent_at);

  assert.equal((await submit(ACME, PO_PENDING)).status, 409, 'sent email is final');
});

test('order in a status that cannot be submitted → 409', async () => {
  assert.equal((await submit(ACME, PO_CONFIRMED)).status, 409);
  assert.equal(sent.length, 2);
});
