import 'package:crm3_baf_ops/core/serialization/persisted_json_equality.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('map insertion order does not create a persisted JSON mismatch', () {
    const local =
        '{"burnerLockout":{"positions":[3,4,5]},"qualityIntent":{"assessment":"notSuspected"}}';
    const remote =
        '{"qualityIntent":{"assessment":"notSuspected"},"burnerLockout":{"positions":[3,4,5]}}';

    expect(persistedJsonEquivalent(local, remote), isTrue);
  });

  test('different nested values and list order remain different', () {
    expect(
      persistedJsonEquivalent('{"positions":[3,4]}', '{"positions":[4,3]}'),
      isFalse,
    );
    expect(
      persistedJsonEquivalent('{"commonMode":true}', '{"commonMode":false}'),
      isFalse,
    );
  });

  test('malformed or absent JSON fails closed', () {
    expect(persistedJsonEquivalent('{', '{}'), isFalse);
    expect(persistedJsonEquivalent('{', '{'), isFalse);
    expect(persistedJsonEquivalent(null, '{}'), isFalse);
    expect(persistedJsonEquivalent(null, null), isTrue);
  });
}
