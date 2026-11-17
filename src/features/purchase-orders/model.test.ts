import { describe, expect, it } from 'vitest';
import { ALLOWED_TRANSITIONS, STATUS_LABEL, canTransition, isClosed } from './model';

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

  it('allows cancelling a partially received order', () => {
    expect(canTransition('PARTIALLY_RECEIVED', 'CANCELLED')).toBe(true);
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
