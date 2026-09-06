import 'dart:async';

import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
