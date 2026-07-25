import test from 'node:test';
import assert from 'node:assert/strict';
import {
  validateContractDocument,
  validateUserDocument,
} from './firestore_integrity_sweep.mjs';

const ts = {toDate: () => new Date('2026-07-22T00:00:00Z'), toMillis: () => 1784678400000};

test('canonical user document passes', () => {
  assert.deepEqual(validateUserDocument('u1', {
    name: 'User', email: 'user@example.com', roles: ['operations'],
    isApproved: true, createdAt: ts, photoUrl: null, fcmToken: null,
  }), []);
});

test('legacy and malformed user fields are reported', () => {
  const findings = validateUserDocument('u2', {
    name: '', email: 'u@example.com', roles: ['admin', 'bogus'],
    isApproved: true, approved: true, createdAt: '2026-07-22T00:00:00Z',
  });
  assert.ok(findings.some((x) => x.reason === 'unexpected-top-level-field'));
  assert.ok(findings.some((x) => x.reason === 'unknown-or-malformed-role'));
  assert.ok(findings.some((x) => x.reason === 'invalid-firestore-timestamp'));
});

test('collection contract catches missing ordered fields without orderBy', () => {
  const findings = validateContractDocument('compliance_requests', 'c1', {
    firestoreId: 'c1', jobExecutionFirestoreId: 'j1', laneKey: 'mechanical',
    status: 'open', version: 1, createdAt: ts,
  }, {
    strings: ['firestoreId', 'jobExecutionFirestoreId', 'laneKey', 'status'],
    integers: ['version'],
    timestamps: ['createdAt', 'updatedAt'],
  });
  assert.equal(findings.length, 1);
  assert.equal(findings[0].field, 'updatedAt');
});
