import { describe, expect, it } from 'vitest';
import {
  ALLOWED_TRANSITIONS,
  STATUS_LABEL,
  canTransition,
  isClosed,
  unsentEmail,
  type PurchaseOrderDetails,
} from './model';

describe('canTransition', () => {
  it('allows the happy path from draft to received', () => {
    expect(canTransition('DRAFT', 'SUBMITTED')).toBe(true);
    expect(canTransition('SUBMITTED', 'CONFIRMED')).toBe(true);
    expect(canTransition('CONFIRMED', 'PARTIALLY_RECEIVED')).toBe(true);
    expect(canTransition('PARTIALLY_RECEIVED', 'RECEIVED')).toBe(true);
  });

  it('does not allow skipping approval backwards', () => {
    expect(canTransition('SUBMITTED', 'DRAFT')).toBe(false);
    expect(canTransition('CONFIRMED', 'PENDING_APPROVAL')).toBe(false);
  });

  it('has no transitions out of closed statuses', () => {
    expect(ALLOWED_TRANSITIONS.RECEIVED).toEqual([]);
    expect(ALLOWED_TRANSITIONS.CANCELLED).toEqual([]);
    expect(ALLOWED_TRANSITIONS.REJECTED).toEqual([]);
  });
});

describe('isClosed', () => {
  it('treats received, cancelled and rejected as closed', () => {
    expect(isClosed('RECEIVED')).toBe(true);
    expect(isClosed('CANCELLED')).toBe(true);
    expect(isClosed('REJECTED')).toBe(true);
    expect(isClosed('CONFIRMED')).toBe(false);
  });
});

describe('STATUS_LABEL', () => {
  it('has a label for every status', () => {
    for (const status of Object.keys(ALLOWED_TRANSITIONS)) {
      expect(STATUS_LABEL[status as keyof typeof STATUS_LABEL]).toBeTruthy();
    }
  });
});

describe('unsentEmail', () => {
  const email = { id: 'e1', to_email: 'v@x.test', attempts: 1, last_error: 'down', sent_at: null };
  const order = (status: PurchaseOrderDetails['status'], emails = [email]) =>
    ({ status, emails }) as unknown as PurchaseOrderDetails;

  it('returns the unsent email of a submitted order, so the UI offers a retry', () => {
    expect(unsentEmail(order('SUBMITTED'))).toBe(email);
  });

  it('returns nothing once the email is sent or the order moved on', () => {
    expect(unsentEmail(order('SUBMITTED', [{ ...email, sent_at: '2026-11-17T00:00:00Z' }]))).toBeUndefined();
    expect(unsentEmail(order('CONFIRMED'))).toBeUndefined();
  });
});
