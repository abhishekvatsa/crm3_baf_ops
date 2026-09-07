const {
  persistedInstantText,
} = require('../lib/maintenanceWorkflow/utils');
const {
  persistedInstantMillis,
} = require('../lib/persistedInstant');

describe('persisted workflow instant decoding', () => {
  const expected = '2026-08-26T08:00:00.123Z';
  const millis = Date.parse(expected);
  const seconds = Math.floor(millis / 1000);
  const nanoseconds = (millis % 1000) * 1000000;

  test('normalizes domain, Date, Firestore, and serialized Firestore values', () => {
    expect(persistedInstantText(expected)).toBe(expected);
    expect(persistedInstantText(new Date(expected))).toBe(expected);
    expect(persistedInstantText({toDate: () => new Date(expected)}))
      .toBe(expected);
    expect(persistedInstantText({
      _seconds: seconds,
      _nanoseconds: nanoseconds,
    })).toBe(expected);
  });

  test('rejects malformed and non-canonical timestamp evidence', () => {
    expect(persistedInstantText('2026-08-26T08:00:00Z')).toBeNull();
    expect(persistedInstantText({_seconds: seconds})).toBeNull();
    expect(persistedInstantText({_seconds: seconds, _nanoseconds: -1}))
      .toBeNull();
    expect(persistedInstantText({toDate: () => new Date(Number.NaN)}))
      .toBeNull();
  });

  test('shared decoder accepts serialized Firestore timestamp fields', () => {
    expect(persistedInstantMillis({
      _seconds: seconds,
      _nanoseconds: nanoseconds,
    })).toBe(millis);
  });

  test('shared decoder rejects timestamp fields outside Firestore bounds', () => {
    expect(persistedInstantMillis({
      _seconds: 253402300800,
      _nanoseconds: 0,
    })).toBeNaN();
    expect(persistedInstantMillis({
      seconds: -62135596801,
      nanoseconds: 0,
    })).toBeNaN();
  });
});
