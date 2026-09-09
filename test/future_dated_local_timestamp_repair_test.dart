// FILE: test/future_dated_local_timestamp_repair_test.dart

import 'dart:io';

import 'package:crm3_baf_ops/core/services/future_dated_local_timestamp_repair.dart';
import 'package:crm3_baf_ops/core/services/server_anchored_clock.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';

/// The server's real instant in these scenarios.
final _serverNow = DateTime.utc(2026, 9, 9, 12);

/// The handset believes it is five minutes later than the backend.
const _deviceAhead = Duration(minutes: 5);

Future<void> _withIsar(Future<void> Function(Isar isar) body) async {
  final dir = await Directory.systemTemp.createTemp('future_dated_repair_');
  final isar = await Isar.open(
    [MaintenanceRecordSchema],
    directory: dir.path,
    name: 'future_dated_repair_test',
  );
  try {
    await body(isar);
  } finally {
    await isar.close(deleteFromDisk: true);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

MaintenanceRecord _record({
  required String firestoreId,
  required DateTime updatedAt,
  required bool isSynced,
  int version = 3,
}) =>
    MaintenanceRecord()
      ..firestoreId = firestoreId
      ..assetType = AssetType.furnace
      ..assetNumber = 7
      ..maintenanceType = MaintenanceType.breakdown
      ..description = 'Burner 3 will not light'
      ..routedTo = RoutedTo.instrumentation
      ..startDate = _serverNow.subtract(const Duration(hours: 2))
      ..createdAt = _serverNow.subtract(const Duration(hours: 2))
      ..updatedAt = updatedAt
      ..version = version
      ..isSynced = isSynced;

Future<MaintenanceRecord> _reload(Isar isar, String firestoreId) async {
  final row = await isar.maintenanceRecords
      .filter()
      .firestoreIdEqualTo(firestoreId)
      .findFirst();
  return row!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);

  setUp(() {
    ServerAnchoredClock.reset();
    // The handset runs five minutes fast, and the clock has learned it.
    ServerAnchoredClock.overrideDeviceClock(() => _serverNow.add(_deviceAhead));
    ServerAnchoredClock.anchorToServer(
      serverAnchor: _serverNow,
      deviceObservedAt: _serverNow.add(_deviceAhead),
    );
  });

  tearDown(ServerAnchoredClock.reset);

  group('repairFutureDatedLocalTimestamps', () {
    test('re-anchors a clean row stamped ahead of the server', () async {
      await _withIsar((isar) async {
        // Written two minutes ago by device reckoning, so stored three minutes
        // in the server's future. A later server version carrying a real
        // instant would be rejected against this.
        final stamped = _serverNow.add(const Duration(minutes: 3));
        await isar.writeTxn(
          () => isar.maintenanceRecords.put(
            _record(firestoreId: 'MT-1', updatedAt: stamped, isSynced: true),
          ),
        );

        final report = await repairFutureDatedLocalTimestamps(isar);

        expect(report, isNotNull);
        expect(report!.changed, isTrue);
        expect(report.repairedRecords, 1);
        expect(report.repairedByCollection['maintenance_records'], 1);

        final repaired = await _reload(isar, 'MT-1');
        // Reconstructed onto the server timeline: stamped + offset.
        expect(
          repaired.updatedAt.toUtc(),
          _serverNow.subtract(const Duration(minutes: 2)),
        );
        // The row is now behind the server's now, so any pending higher
        // version will apply and the domain cursor can advance.
        expect(repaired.updatedAt.toUtc().isAfter(_serverNow), isFalse);
      });
    });

    test('preserves version and sync state', () async {
      await _withIsar((isar) async {
        await isar.writeTxn(
          () => isar.maintenanceRecords.put(
            _record(
              firestoreId: 'MT-2',
              updatedAt: _serverNow.add(const Duration(minutes: 4)),
              isSynced: true,
              version: 9,
            ),
          ),
        );

        await repairFutureDatedLocalTimestamps(isar);

        final repaired = await _reload(isar, 'MT-2');
        expect(repaired.version, 9);
        expect(repaired.isSynced, isTrue);
        expect(repaired.description, 'Burner 3 will not light');
      });
    });

    test('never touches a dirty row', () async {
      await _withIsar((isar) async {
        // A dirty row holds unpushed local evidence. Its timestamp is part of
        // that evidence and must survive untouched.
        final stamped = _serverNow.add(const Duration(minutes: 3));
        await isar.writeTxn(
          () => isar.maintenanceRecords.put(
            _record(firestoreId: 'MT-3', updatedAt: stamped, isSynced: false),
          ),
        );

        final report = await repairFutureDatedLocalTimestamps(isar);

        expect(report!.changed, isFalse);
        final untouched = await _reload(isar, 'MT-3');
        expect(untouched.updatedAt.toUtc(), stamped);
      });
    });

    test('leaves a correctly mirrored past instant alone', () async {
      await _withIsar((isar) async {
        final mirrored = _serverNow.subtract(const Duration(hours: 1));
        await isar.writeTxn(
          () => isar.maintenanceRecords.put(
            _record(firestoreId: 'MT-4', updatedAt: mirrored, isSynced: true),
          ),
        );

        final report = await repairFutureDatedLocalTimestamps(isar);

        expect(report!.changed, isFalse);
        final untouched = await _reload(isar, 'MT-4');
        expect(untouched.updatedAt.toUtc(), mirrored);
      });
    });

    test('tolerates a recent server instant within the anchor margin', () async {
      await _withIsar((isar) async {
        // The anchor is deliberately conservative, so a very recent server
        // write can read a few seconds ahead of it. That is not a poisoned row.
        final recent = _serverNow.add(const Duration(seconds: 10));
        await isar.writeTxn(
          () => isar.maintenanceRecords.put(
            _record(firestoreId: 'MT-5', updatedAt: recent, isSynced: true),
          ),
        );

        final report = await repairFutureDatedLocalTimestamps(isar);

        expect(report!.changed, isFalse);
        expect((await _reload(isar, 'MT-5')).updatedAt.toUtc(), recent);
      });
    });

    test('clamps to the anchored now when the offset alone is insufficient',
        () async {
      await _withIsar((isar) async {
        // A row stamped far further ahead than the current offset explains,
        // for example after the device clock was corrected between writes.
        final stamped = _serverNow.add(const Duration(hours: 2));
        await isar.writeTxn(
          () => isar.maintenanceRecords.put(
            _record(firestoreId: 'MT-6', updatedAt: stamped, isSynced: true),
          ),
        );

        await repairFutureDatedLocalTimestamps(isar);

        final repaired = await _reload(isar, 'MT-6');
        expect(repaired.updatedAt.toUtc(), _serverNow);
      });
    });

    test('does nothing when the device is not running ahead', () async {
      await _withIsar((isar) async {
        await isar.writeTxn(
          () => isar.maintenanceRecords.put(
            _record(
              firestoreId: 'MT-7',
              updatedAt: _serverNow.add(const Duration(minutes: 3)),
              isSynced: true,
            ),
          ),
        );

        // A device running behind cannot have produced an instant the server
        // could not, so the repair must decline rather than rewrite rows.
        final report = await repairFutureDatedLocalTimestamps(
          isar,
          offset: const Duration(minutes: 4),
          anchoredNow: () => _serverNow,
        );

        expect(report, isNull);
      });
    });

    test('declines while the clock is unanchored', () async {
      ServerAnchoredClock.reset();
      await _withIsar((isar) async {
        await isar.writeTxn(
          () => isar.maintenanceRecords.put(
            _record(
              firestoreId: 'MT-8',
              updatedAt: _serverNow.add(const Duration(minutes: 3)),
              isSynced: true,
            ),
          ),
        );

        // Without an anchor there is nothing to reconstruct against. Guessing
        // would be worse than waiting for the next pull.
        expect(await repairFutureDatedLocalTimestamps(isar), isNull);
      });
    });

    test('is idempotent across repeated runs', () async {
      await _withIsar((isar) async {
        await isar.writeTxn(
          () => isar.maintenanceRecords.put(
            _record(
              firestoreId: 'MT-9',
              updatedAt: _serverNow.add(const Duration(minutes: 3)),
              isSynced: true,
            ),
          ),
        );

        await repairFutureDatedLocalTimestamps(isar);
        final afterFirst = (await _reload(isar, 'MT-9')).updatedAt.toUtc();
        final second = await repairFutureDatedLocalTimestamps(isar);

        expect(second!.changed, isFalse);
        expect((await _reload(isar, 'MT-9')).updatedAt.toUtc(), afterFirst);
      });
    });
  });

  group('stalled-domain recovery contract', () {
    test('a repaired row admits the higher server version that blocked it',
        () async {
      await _withIsar((isar) async {
        // Reproduces the field failure: the row was pushed at device time, the
        // server later raised its version with a real instant, and the guard
        // preserved the local row and blocked the domain cursor.
        final stampedAhead = _serverNow.add(const Duration(minutes: 3));
        final pendingRemoteInstant = _serverNow.subtract(
          const Duration(minutes: 1),
        );

        await isar.writeTxn(
          () => isar.maintenanceRecords.put(
            _record(
              firestoreId: 'MT-10',
              updatedAt: stampedAhead,
              isSynced: true,
              version: 4,
            ),
          ),
        );

        bool remoteWouldApply(DateTime localUpdatedAt) =>
            !localUpdatedAt.toUtc().isAfter(pendingRemoteInstant);

        expect(
          remoteWouldApply(stampedAhead),
          isFalse,
          reason: 'Precondition: the domain is stalled before repair.',
        );

        await repairFutureDatedLocalTimestamps(isar);

        expect(
          remoteWouldApply((await _reload(isar, 'MT-10')).updatedAt),
          isTrue,
          reason:
              'After repair the blocked higher server version must be able to '
              'apply, so the domain cursor can advance.',
        );
      });
    });
  });
}
