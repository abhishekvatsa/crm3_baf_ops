// FILE: test/server_anchored_clock_test.dart

import 'dart:io';

import 'package:crm3_baf_ops/core/services/server_anchored_clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ServerAnchoredClock.reset();
  });

  tearDown(ServerAnchoredClock.reset);

  group('ServerAnchoredClock', () {
    final device = DateTime.utc(2026, 9, 9, 12);

    test('falls back to the device clock until an anchor is observed', () {
      ServerAnchoredClock.overrideDeviceClock(() => device);

      expect(ServerAnchoredClock.isAnchored, isFalse);
      expect(ServerAnchoredClock.offset, Duration.zero);
      expect(ServerAnchoredClock.now(), device);
    });

    test('a device running ahead is pulled back onto the server timeline', () {
      // The handset believes it is 12:00; the server says 11:55. Persisted
      // timestamps must not sit five minutes in the server's future, because a
      // later higher-version server record would then look stale on ingest.
      ServerAnchoredClock.overrideDeviceClock(() => device);
      ServerAnchoredClock.anchorToServer(
        serverAnchor: device.subtract(const Duration(minutes: 5)),
        deviceObservedAt: device,
      );

      expect(ServerAnchoredClock.isAnchored, isTrue);
      expect(ServerAnchoredClock.offset, const Duration(minutes: -5));
      expect(
        ServerAnchoredClock.now(),
        device.subtract(const Duration(minutes: 5)),
      );
    });

    test('a device running behind is pushed forward', () {
      ServerAnchoredClock.overrideDeviceClock(() => device);
      ServerAnchoredClock.anchorToServer(
        serverAnchor: device.add(const Duration(minutes: 3)),
        deviceObservedAt: device,
      );

      expect(ServerAnchoredClock.offset, const Duration(minutes: 3));
      expect(ServerAnchoredClock.now(), device.add(const Duration(minutes: 3)));
    });

    test('an anchored clock keeps pace with the device clock', () {
      var reading = device;
      ServerAnchoredClock.overrideDeviceClock(() => reading);
      ServerAnchoredClock.anchorToServer(
        serverAnchor: device.subtract(const Duration(minutes: 5)),
        deviceObservedAt: device,
      );

      reading = device.add(const Duration(minutes: 30));

      expect(
        ServerAnchoredClock.now(),
        device.add(const Duration(minutes: 25)),
      );
    });

    test('an implausible offset is rejected and the prior offset retained', () {
      ServerAnchoredClock.overrideDeviceClock(() => device);
      ServerAnchoredClock.anchorToServer(
        serverAnchor: device.subtract(const Duration(minutes: 5)),
        deviceObservedAt: device,
      );

      // A corrupt or hostile anchor must not relocate local evidence far
      // outside any window the server can corroborate.
      ServerAnchoredClock.anchorToServer(
        serverAnchor: device.subtract(const Duration(days: 400)),
        deviceObservedAt: device,
      );

      expect(ServerAnchoredClock.offset, const Duration(minutes: -5));
    });

    test('the offset survives a restart so an offline launch stays anchored', () async {
      ServerAnchoredClock.overrideDeviceClock(() => device);
      ServerAnchoredClock.anchorToServer(
        serverAnchor: device.subtract(const Duration(minutes: 7)),
        deviceObservedAt: device,
      );
      // Let the fire-and-forget persist complete before simulating a restart.
      await Future<void>.delayed(Duration.zero);

      ServerAnchoredClock.reset();
      ServerAnchoredClock.overrideDeviceClock(() => device);
      await ServerAnchoredClock.restorePersistedOffset();

      expect(ServerAnchoredClock.isAnchored, isTrue);
      expect(ServerAnchoredClock.offset, const Duration(minutes: -7));
    });

    test('a fresh anchor is not overwritten by a restore', () async {
      ServerAnchoredClock.overrideDeviceClock(() => device);
      ServerAnchoredClock.anchorToServer(
        serverAnchor: device.subtract(const Duration(minutes: 2)),
        deviceObservedAt: device,
      );
      await ServerAnchoredClock.restorePersistedOffset();

      expect(ServerAnchoredClock.offset, const Duration(minutes: -2));
    });
  });

  group('persisted timestamp source contract', () {
    // The Build 27 sync stalls were caused by locally persisted timestamps
    // being stamped from the raw device clock. A handset running ahead of the
    // server produced rows whose updatedAt exceeded every subsequent server
    // timestamp, which made a higher server version look stale during ingest
    // and blocked domain cursor completion. This contract keeps that cause
    // from returning to any synchronised write path.
    test('no synchronised write stamps updatedAt or deletedAt from DateTime.now', () {
      final offenders = <String>[];
      final directory = Directory('lib');
      final pattern = RegExp(r'\b(updatedAt|deletedAt)\s*=\s*DateTime\.now\(\)');

      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('.g.dart')) continue;
        final source = entity.readAsStringSync();
        final lines = source.split('\n');
        for (var i = 0; i < lines.length; i++) {
          if (pattern.hasMatch(lines[i])) {
            offenders.add(
              '${entity.path.replaceAll(r'\', '/')}:${i + 1}  ${lines[i].trim()}',
            );
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Persisted, server-comparable timestamps must come from '
            'ServerAnchoredClock.now() so that a device whose clock differs '
            'from the backend cannot stall a domain pull cursor. Offending '
            'assignments:\n${offenders.join('\n')}',
      );
    });

    test('the pull run adopts the server anchor it already receives', () {
      final source = File(
        'lib/core/services/global_pull_service.dart',
      ).readAsStringSync();

      expect(
        source,
        contains(
          'ServerAnchoredClock.anchorToServer(serverAnchor: authority.serverAnchor)',
        ),
      );
    });

    test('the local database bootstrap restores the persisted offset', () {
      final source = File('lib/main.dart').readAsStringSync();

      expect(
        source,
        contains('await ServerAnchoredClock.restorePersistedOffset();'),
      );
    });
  });
}
