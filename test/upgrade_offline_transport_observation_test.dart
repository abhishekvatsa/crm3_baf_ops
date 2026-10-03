import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/upgrade_saved_work.dart';

void main() {
  const aggregate =
      'java.util.concurrent.ExecutionException: '
      '1 out of 2 underlying tasks failed';
  String classify({
    String code = 'unknown',
    String? message = aggregate,
    bool emulator = true,
    String uid = 'retained-actor',
    String? beforeUid = 'retained-actor',
    String? afterUid = 'retained-actor',
    Set<int> before = const {19099, 18080, 15001},
    Set<int> after = const {19099, 18080, 15001},
    String firestore = 'unavailable',
  }) => classifyUpgradeCallableObservation(
    code: code,
    message: message,
    governedAndroidEmulator: emulator,
    expectedUid: uid,
    actorBefore: beforeUid,
    actorAfter: afterUid,
    blockedPortsBefore: before,
    blockedPortsAfter: after,
    serverReadFailure: firestore,
  );

  test('observed aggregate is separate from callable transport evidence', () {
    expect(classify(), 'client-context-prerequisite-blocked');
    expect(classify(), isNot('callable-failure-while-offline'));
  });
  for (final code in ['unavailable', 'deadline-exceeded', 'internal']) {
    test('retains $code without claiming callable HTTP was observed', () {
      expect(
        classify(code: code, message: null),
        'callable-failure-while-offline',
      );
    });
  }
  test('bounded timeout remains distinctly recorded', () {
    expect(classify(code: 'bounded-timeout', message: null), 'bounded-timeout');
  });
  for (final message in [
    null,
    '',
    'UNKNOWN',
    'network unavailable',
    'java.util.concurrent.ExecutionException: other task failed',
    'java.util.concurrent.ExecutionException: 2 out of 2 underlying tasks failed',
    '$aggregate extra text',
  ]) {
    test('rejects unrecognized unknown signature: $message', () {
      expect(() => classify(message: message), throwsStateError);
    });
  }
  for (final code in [
    'permission-denied',
    'unauthenticated',
    'invalid-argument',
    'failed-precondition',
    'not-found',
  ]) {
    test('does not hide $code behind the aggregate text', () {
      expect(() => classify(code: code), throwsStateError);
    });
  }
  test('aggregate is specific to the governed Android emulator', () {
    expect(() => classify(emulator: false), throwsStateError);
  });
  for (final port in [19099, 18080, 15001]) {
    test('requires blocked port $port before and after the call', () {
      final missing = {19099, 18080, 15001}..remove(port);
      expect(() => classify(before: missing), throwsStateError);
      expect(() => classify(after: missing), throwsStateError);
    });
  }
  test('rejects extraneous or empty transport observations', () {
    expect(() => classify(before: {}), throwsStateError);
    expect(
      () => classify(after: {19099, 18080, 15001, 9999}),
      throwsStateError,
    );
  });
  test('requires an actual forced-server refusal', () {
    for (final code in ['', 'permission-denied', 'unknown', 'cached']) {
      expect(() => classify(firestore: code), throwsStateError);
    }
  });
  test('requires the same nonempty actor across the observation', () {
    expect(
      () => classify(uid: '', beforeUid: '', afterUid: ''),
      throwsStateError,
    );
    expect(() => classify(beforeUid: null), throwsStateError);
    expect(() => classify(afterUid: null), throwsStateError);
    expect(() => classify(beforeUid: 'other'), throwsStateError);
    expect(() => classify(afterUid: 'other'), throwsStateError);
  });
  test('even conventional errors cannot replace independent offline proof', () {
    expect(() => classify(code: 'unavailable', before: {}), throwsStateError);
    expect(
      () => classify(code: 'internal', afterUid: 'other'),
      throwsStateError,
    );
  });
}
