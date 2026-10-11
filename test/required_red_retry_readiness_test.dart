import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/required_red_retry.dart';

void main() {
  test(
    'startup claim can advance backoff after the original row was read',
    () async {
      final fixture = _RetryFixture();
      fixture.current = RequiredRedRetrySnapshot(
        stateKey: 'sending',
        attemptCount: 1,
        lastAttemptAt: fixture.clock,
        nextRetryAt: fixture.clock.subtract(const Duration(seconds: 15)),
      );
      fixture.onWait = () {
        if (fixture.elapsed == 2) {
          fixture.current = fixture.uncertain(dueAt: 5, attempt: 2);
        }
      };

      await fixture.run();

      expect(fixture.tapTimes, [5]);
      expect(fixture.current.hasReceipt, isTrue);
      expect(
        fixture.observations.map(
          (row) => (row['lastState'] as Map)['stateKey'],
        ),
        containsAllInOrder(['sending', 'uncertainOutcome']),
      );
    },
  );

  test(
    'deadline changed during UI navigation is checked before the tap',
    () async {
      final fixture = _RetryFixture();
      fixture.onNavigate = () {
        if (fixture.navigationCount == 1) {
          fixture.current = fixture.uncertain(dueAt: 4, attempt: 2);
        }
      };

      await fixture.run();

      expect(fixture.navigationCount, 2);
      expect(fixture.refusedTaps, 1);
      expect(fixture.tapTimes, [4]);
    },
  );

  test('receipt arriving during a backoff wait needs no UI retry', () async {
    final fixture = _RetryFixture();
    fixture.current = fixture.uncertain(dueAt: 10);
    fixture.onWait = () {
      if (fixture.elapsed == 2) fixture.accept();
    };

    await fixture.run();

    expect(fixture.tapTimes, isEmpty);
    expect(fixture.navigationCount, 0);
  });

  test(
    'receipt arriving during pointer preparation prevents the tap',
    () async {
      final fixture = _RetryFixture();
      fixture.onNavigate = fixture.accept;

      await fixture.run();

      expect(fixture.tapTimes, isEmpty);
      expect(fixture.refusedTaps, 1);
    },
  );

  test(
    'an in-flight claim fails within a finite wait without being rewritten',
    () async {
      final fixture = _RetryFixture();
      final original = RequiredRedRetrySnapshot(
        stateKey: 'sending',
        attemptCount: 2,
        lastAttemptAt: fixture.clock,
        nextRetryAt: fixture.clock,
      );
      fixture.current = original;

      await expectLater(
        fixture.run(timeout: const Duration(seconds: 3)),
        throwsA(isA<TimeoutException>()),
      );

      expect(identical(fixture.current, original), isTrue);
      expect(fixture.elapsed, 3);
      expect(fixture.tapTimes, isEmpty);
      expect(fixture.observations.last['phase'], 'timeout');
      expect(fixture.observations.last['lastState'], original.toJson());
    },
  );

  test(
    'a terminal row fails without pressing Sync or treating it as accepted',
    () async {
      final fixture = _RetryFixture();
      fixture.current = const RequiredRedRetrySnapshot(
        stateKey: 'manualReview',
        attemptCount: 8,
        lastErrorCode: 'unavailable',
      );

      await expectLater(fixture.run(), throwsA(isA<StateError>()));

      expect(fixture.tapTimes, isEmpty);
      expect(fixture.current.hasReceipt, isFalse);
    },
  );

  test(
    'repeated real transport failures exhaust the bounded UI attempt limit',
    () async {
      final fixture = _RetryFixture();
      fixture.onTap = () {
        fixture.current = fixture.uncertain(
          dueAt: fixture.elapsed + 1,
          attempt: fixture.tapTimes.length + 1,
        );
      };

      await expectLater(
        fixture.run(maxSyncAttempts: 2),
        throwsA(isA<StateError>()),
      );

      expect(fixture.tapTimes, [0, 1]);
      expect(fixture.current.hasReceipt, isFalse);
    },
  );

  test(
    'unchanged due state is not hammered by repeated manual gestures',
    () async {
      final fixture = _RetryFixture();
      fixture.onTap = () {};

      await expectLater(
        fixture.run(timeout: const Duration(seconds: 3)),
        throwsA(isA<TimeoutException>()),
      );

      expect(fixture.tapTimes, [0]);
      expect(fixture.current.hasReceipt, isFalse);
    },
  );
}

class _RetryFixture {
  static final epoch = DateTime.utc(2026, 10, 11);
  DateTime clock = epoch;
  late RequiredRedRetrySnapshot current = uncertain(dueAt: 0);
  final tapTimes = <int>[];
  final observations = <Map<String, Object?>>[];
  int navigationCount = 0;
  int refusedTaps = 0;
  void Function()? onWait;
  void Function()? onNavigate;
  void Function()? onTap;

  int get elapsed => clock.difference(epoch).inSeconds;

  RequiredRedRetrySnapshot uncertain({required int dueAt, int attempt = 1}) =>
      RequiredRedRetrySnapshot(
        stateKey: 'uncertainOutcome',
        attemptCount: attempt,
        lastAttemptAt: clock,
        nextRetryAt: epoch.add(Duration(seconds: dueAt)),
        lastErrorCode: 'unavailable',
      );

  void accept() {
    current = const RequiredRedRetrySnapshot(hasReceipt: true);
  }

  Future<void> run({
    Duration timeout = const Duration(seconds: 20),
    int maxSyncAttempts = 3,
  }) => waitForRequiredRedReceipt(
    readCurrent: () async => current,
    now: () => clock,
    wait: () async {
      clock = clock.add(const Duration(seconds: 1));
      onWait?.call();
    },
    syncThroughUi: (canTap) async {
      navigationCount++;
      onNavigate?.call();
      if (!await canTap()) {
        refusedTaps++;
        return false;
      }
      tapTimes.add(elapsed);
      if (onTap != null) {
        onTap!();
      } else {
        accept();
      }
      return true;
    },
    onObservation: observations.add,
    timeout: timeout,
    maxSyncAttempts: maxSyncAttempts,
  );
}
