const {
  ClosureValidationError,
  completePlannedJobWithDb,
  parseExpectedCompletionVersion,
} = require('../lib/plannedJobClosure');

describe('parseExpectedCompletionVersion', () => {
  test('returns null for omitted/null/undefined', () => {
    expect(parseExpectedCompletionVersion(undefined)).toBe(null);
    expect(parseExpectedCompletionVersion(null)).toBe(null);
  });

  test('accepts non-negative safe integers', () => {
    expect(parseExpectedCompletionVersion(0)).toBe(0);
    expect(parseExpectedCompletionVersion(1)).toBe(1);
    expect(parseExpectedCompletionVersion(99)).toBe(99);
  });

  test('rejects strings, even numeric-looking ones', () => {
    expect(() => parseExpectedCompletionVersion('3')).toThrow(ClosureValidationError);
    expect(() => parseExpectedCompletionVersion('')).toThrow(ClosureValidationError);
  });

  test('rejects floats', () => {
    expect(() => parseExpectedCompletionVersion(3.5)).toThrow(ClosureValidationError);
    expect(() => parseExpectedCompletionVersion(0.1)).toThrow(ClosureValidationError);
  });

  test('rejects NaN, Infinity, and negative numbers', () => {
    expect(() => parseExpectedCompletionVersion(NaN)).toThrow(ClosureValidationError);
    expect(() => parseExpectedCompletionVersion(Infinity)).toThrow(ClosureValidationError);
    expect(() => parseExpectedCompletionVersion(-1)).toThrow(ClosureValidationError);
  });

  test('throws invalid-argument code, not generic', () => {
    try {
      parseExpectedCompletionVersion('3');
      throw new Error('should have thrown');
    } catch (error) {
      expect(error).toBeInstanceOf(ClosureValidationError);
      expect(error.code).toBe('invalid-argument');
    }
  });
});

describe('completePlannedJobWithDb bad input handling', () => {
  function fakeDbReturningNothing() {
    return {
      collection: () => ({
        doc: () => ({
          path: 'unused',
          async get() {
            return {
              exists: true,
              data: () => ({
                isApproved: true,
                roles: ['shiftSupervisor'],
                name: 'Supervisor',
              }),
            };
          },
        }),
        where: () => { throw new Error('should not run'); },
      }),
      async runTransaction() { throw new Error('should not run'); },
    };
  }

  test('rejects non-integer expectedCompletionVersion before doing any DB work', async () => {
    await expect(completePlannedJobWithDb({
      db: fakeDbReturningNothing(),
      authUid: 'supervisor1',
      data: {executionId: 'job_1', expectedCompletionVersion: '3'},
    })).rejects.toMatchObject({
      name: 'ClosureValidationError',
      code: 'invalid-argument',
    });
  });

  test('rejects float expectedCompletionVersion', async () => {
    await expect(completePlannedJobWithDb({
      db: fakeDbReturningNothing(),
      authUid: 'supervisor1',
      data: {executionId: 'job_1', expectedCompletionVersion: 3.5},
    })).rejects.toMatchObject({code: 'invalid-argument'});
  });

  test('omitted expectedCompletionVersion is allowed (no precondition check)', async () => {
    // We don't expect this to fully succeed without a real DB; we just
    // expect the FIRST error not to be about expectedCompletionVersion.
    // The fake DB throws when the transaction starts, so any failure here
    // must come from later code, not from the version parser.
    await expect(completePlannedJobWithDb({
      db: fakeDbReturningNothing(),
      authUid: 'supervisor1',
      data: {executionId: 'job_1'},
    })).rejects.toThrow(/should not run/);
  });
});

describe('audit timestamp factory injection', () => {
  test('audit_logs.timestamp is produced by the injected factory, not an ISO string', async () => {
    const captured = {};
    const fakeTimestamp = Symbol('FirestoreTimestamp');
    let auditDataWritten = null;

    const executionData = {
      firestoreId: 'job_1',
      isDeleted: false,
      isCompleted: false,
      version: 6,
      metadataJson: '{}',
      createdAt: '2026-05-15T08:00:00.000Z',
      updatedAt: '2026-05-15T08:00:00.000Z',
    };

    const fakeDb = {
      collection(name) {
        return {
          doc(id) {
            return {
              path: `${name}/${id ?? 'auto'}`,
              async get() {
                throw new Error('authority must be read inside the transaction');
              },
            };
          },
          where() {
            const chain = {where: () => chain};
            captured.queryBuilt = true;
            return chain;
          },
        };
      },
      async runTransaction(fn) {
        return fn({
          async get(refOrQuery) {
            if (refOrQuery && refOrQuery.path === 'users/supervisor1') {
              return {
                exists: true,
                data: () => ({
                  isApproved: true,
                  roles: ['shiftSupervisor'],
                  name: 'Supervisor',
                }),
              };
            }
            if (refOrQuery && refOrQuery.path === 'job_executions/job_1') {
              return {exists: true, data: () => executionData};
            }
            // The modules query: return empty doc set so closure passes
            // trivially (no required modules → no issues).
            return {docs: []};
          },
          update() { /* noop */ },
          set(ref, data) {
            if (ref.path && ref.path.startsWith('audit_logs/')) {
              auditDataWritten = data;
            }
          },
        });
      },
    };

    const result = await completePlannedJobWithDb({
      db: fakeDb,
      authUid: 'supervisor1',
      data: {executionId: 'job_1', expectedCompletionVersion: 7},
      timestampFromDate: () => fakeTimestamp,
    });

    expect(result.ok).toBe(true);
    expect(auditDataWritten).not.toBeNull();
    expect(auditDataWritten.timestamp).toBe(fakeTimestamp);
    // The execution doc's completedAt still uses ISO string, not the factory.
    expect(typeof result.execution.completedAt).toBe('string');
    expect(result.execution.completedAt).toMatch(/^\d{4}-\d{2}-\d{2}T/);
  });

  test('default factory (when omitted) returns ISO string for backward compatibility', async () => {
    let auditDataWritten = null;
    const executionData = {
      firestoreId: 'job_1',
      isDeleted: false,
      isCompleted: false,
      version: 6,
      metadataJson: '{}',
    };
    const fakeDb = {
      collection(name) {
        return {
          doc(id) {
            return {
              path: `${name}/${id}`,
              async get() {
                throw new Error('authority must be read inside the transaction');
              },
            };
          },
          where() {
            const chain = {where: () => chain};
            return chain;
          },
        };
      },
      async runTransaction(fn) {
        return fn({
          async get(refOrQuery) {
            if (refOrQuery && refOrQuery.path === 'users/admin1') {
              return {
                exists: true,
                data: () => ({isApproved: true, roles: ['admin']}),
              };
            }
            if (refOrQuery && refOrQuery.path === 'job_executions/job_1') {
              return {exists: true, data: () => executionData};
            }
            return {docs: []};
          },
          update() {},
          set(ref, data) {
            if (ref.path && ref.path.startsWith('audit_logs/')) {
              auditDataWritten = data;
            }
          },
        });
      },
    };

    await completePlannedJobWithDb({
      db: fakeDb,
      authUid: 'admin1',
      data: {executionId: 'job_1'},
      // timestampFromDate intentionally omitted
    });

    expect(typeof auditDataWritten.timestamp).toBe('string');
    expect(auditDataWritten.timestamp).toMatch(/^\d{4}-\d{2}-\d{2}T/);
  });
});


describe('Issue 63 callable region migration guard', () => {
  test('keeps completePlannedJobExecution in asia-south1 with a stable name', () => {
    const fs = require('fs');
    const path = require('path');
    const source = fs.readFileSync(path.join(__dirname, '../src/index.ts'), 'utf8');

    expect(source).toContain('const CALLABLE_REGION = "asia-south1"');
    expect(source).toContain('region: CALLABLE_REGION');
    expect(source).toContain('export const completePlannedJobExecution');
    expect(source).not.toContain('completePlannedJobExecutionAsiaSouth1');
    expect(source).not.toContain('const CALLABLE_REGION = "us-central1"');
    expect(source).not.toContain('CALLABLE_REGIONS');
  });
});
