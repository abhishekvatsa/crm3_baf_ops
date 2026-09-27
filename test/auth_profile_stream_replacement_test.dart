import 'dart:async';

import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final nextUid in <String?>[null, 'B']) {
    test(
      'obsolete mapped generation stays invalid after returning to A ($nextUid)',
      () async {
        final auth = StreamController<String?>();
        final profile = StreamController<String?>.broadcast();
        String? currentUid = 'A';
        final values = <String?>[];
        final errors = <Object>[];
        final subscription = switchLatestNullableStream<String, String>(
          source: auth.stream,
          isCurrentSource: (uid) => uid == currentUid,
          mapper: (_) => profile.stream,
        ).listen(values.add, onError: errors.add);
        addTearDown(() async {
          await subscription.cancel();
          await auth.close();
          await profile.close();
        });
        auth.add('A');
        await _flushEvents();
        profile.add('approved-A');
        await _flushEvents();
        currentUid = nextUid;
        profile.addError(StateError('obsolete denied'));
        await _flushEvents();
        currentUid = 'A';
        profile.add('stale-approved-A');
        profile.addError(StateError('stale same-UID denial'));
        await _flushEvents();
        expect(values, ['approved-A', null]);
        expect(errors, isEmpty);
        auth.add('A');
        await _flushEvents();
        profile.add('fresh-approved-A');
        await _flushEvents();
        expect(values, ['approved-A', null, 'fresh-approved-A']);
      },
    );
  }

  test(
    'obsolete token clears obsolete A but does not disturb current B',
    () async {
      final auth = StreamController<String?>();
      final profiles = <String, StreamController<String?>>{
        'A': StreamController<String?>.broadcast(),
        'B': StreamController<String?>.broadcast(),
      };
      var currentUid = 'A';
      final values = <String?>[];
      final observedTokens = <String?>[];
      final subscription = switchLatestNullableStream<String, String>(
        source: auth.stream,
        isCurrentSource: (uid) => uid == currentUid,
        onSourceEvent: observedTokens.add,
        mapper: (uid) => profiles[uid]!.stream,
      ).listen(values.add);
      addTearDown(() async {
        await subscription.cancel();
        await auth.close();
        for (final profile in profiles.values) {
          await profile.close();
        }
      });
      auth.add('A');
      await _flushEvents();
      profiles['A']!.add('profile-A');
      await _flushEvents();
      currentUid = 'B';
      auth.add('A');
      await _flushEvents();
      expect(values, ['profile-A', null]);
      expect(observedTokens, ['A']);

      auth.add('B');
      await _flushEvents();
      profiles['B']!.add('profile-B');
      await _flushEvents();
      auth.add('A');
      await _flushEvents();
      expect(values, ['profile-A', null, 'profile-B']);
      expect(observedTokens, ['A', 'B']);
      expect(profiles['B']!.hasListener, isTrue);
    },
  );

  test(
    'live account invalidation precedes delayed token stream events',
    () async {
      final auth = StreamController<String?>();
      final profileA = StreamController<String?>.broadcast();
      final profileB = StreamController<String?>.broadcast();
      String? currentUid = 'A';
      final values = <String?>[];
      final errors = <Object>[];
      final subscription = switchLatestNullableStream<String, String>(
        source: auth.stream,
        isCurrentSource: (uid) => uid == currentUid,
        mapper: (uid) => uid == 'A' ? profileA.stream : profileB.stream,
      ).listen(values.add, onError: errors.add);
      addTearDown(() async {
        await subscription.cancel();
        await auth.close();
        await profileA.close();
        await profileB.close();
      });

      auth.add('A');
      await _flushEvents();
      profileA.add('profile-A');
      await _flushEvents();
      currentUid = null;
      profileA.addError(StateError('old profile permission denied'));
      await _flushEvents();
      expect(errors, isEmpty);
      expect(values, ['profile-A', null]);

      currentUid = 'B';
      profileA.add('stale-profile-A');
      await _flushEvents();
      expect(values.last, isNull);
      auth.add('B');
      await _flushEvents();
      profileB.add('profile-B');
      final currentError = StateError('current profile permission denied');
      profileB.addError(currentError);
      await _flushEvents();
      expect(values.last, 'profile-B');
      expect(errors, [same(currentError)]);
    },
  );

  test(
    'new account replaces an old profile stream that remains open',
    () async {
      final auth = StreamController<String?>();
      var cancelledA = 0;
      final profileA = StreamController<String?>(onCancel: () => cancelledA++);
      final profileB = StreamController<String?>();
      final values = <String?>[];
      final subscription = switchLatestNullableStream<String, String>(
        source: auth.stream,
        mapper: (uid) => uid == 'A' ? profileA.stream : profileB.stream,
      ).listen(values.add);

      auth.add('A');
      await _flushEvents();
      profileA.add('profile-A');
      await _flushEvents();

      auth.add(null);
      await _flushEvents();
      auth.add('B');
      await _flushEvents();
      profileA.add('stale-profile-A');
      profileB.add('profile-B');
      await _flushEvents();

      expect(cancelledA, 1);
      expect(values, <String?>['profile-A', null, 'profile-B']);

      await subscription.cancel();
      await auth.close();
      await profileA.close();
      await profileB.close();
    },
  );

  test('rapid account changes expose only the latest profile', () async {
    final auth = StreamController<String?>();
    final profiles = <String, StreamController<String?>>{
      'A': StreamController<String?>(),
      'B': StreamController<String?>(),
      'C': StreamController<String?>(),
    };
    final values = <String?>[];
    final subscription = switchLatestNullableStream<String, String>(
      source: auth.stream,
      mapper: (uid) => profiles[uid]!.stream,
    ).listen(values.add);

    auth
      ..add('A')
      ..add('B')
      ..add('C');
    await _flushEvents();
    profiles['A']!.add('profile-A');
    profiles['B']!.add('profile-B');
    profiles['C']!.add('profile-C');
    await _flushEvents();

    expect(values, <String?>['profile-C']);

    await subscription.cancel();
    await auth.close();
    for (final profile in profiles.values) {
      await profile.close();
    }
  });
}

Future<void> _flushEvents() => Future<void>.delayed(Duration.zero);
