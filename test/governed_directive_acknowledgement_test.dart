import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/core/persistence/app_database.dart' as app;
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/directives/data/governed_directive_acknowledgement.dart';
import 'package:crm3_baf_ops/features/directives/data/operational_directive_model.dart';
import 'package:crm3_baf_ops/features/directives/data/remote_operational_directive_reader.dart';
import 'package:crm3_baf_ops/features/directives/providers/operational_directive_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';

OperationalDirective serverRecord() {
  final at = DateTime.utc(2026, 9, 4, 9, 13, 45, 818);
  final data =
      (OperationalDirective()
            ..firestoreId = 'burner_round_red_hot_test'
            ..title = 'Red-hot burner block: B2, B4'
            ..description = 'Furnace 3 requires I&A attendance.'
            ..directedTo = AppRole.seniorInstrumentation
            ..assetType = AssetType.furnace
            ..assetNumber = 3
            ..priority = DirectivePriority.critical
            ..status = DirectiveStatus.open
            ..createdByUid = 'issuer'
            ..issuedByUid = 'issuer'
            ..createdAt = at
            ..updatedAt = at
            ..issuedAt = at
            ..version = 1
            ..isActive = true
            ..metadataJson = '{"burnerPositions":[2,4]}')
          .toMap();
  for (final key in ['createdAt', 'issuedAt', 'updatedAt']) {
    data[key] = Timestamp.fromDate(at);
  }
  data['_globalPullServerUpdatedAt'] = Timestamp.fromDate(at);
  return readRemoteOperationalDirective(
    data,
    documentId: 'burner_round_red_hot_test',
  );
}

OperationalDirective acknowledge(OperationalDirective remote) =>
    copyOperationalDirective(remote)
      ..status = DirectiveStatus.acknowledged
      ..acknowledgedByUid = 'ia'
      ..acknowledgedByName = 'Instrumentation'
      ..acknowledgedAt = DateTime.utc(2026, 9, 4, 10)
      ..updatedAt = DateTime.utc(2026, 9, 4, 10)
      ..version = remote.version + 1
      ..isSynced = false;

void main() {
  setUpAll(initializeTestIsarCore);

  for (final boundary in ['createdAt', 'issuedAt', 'updatedAt']) {
    test('clock-behind acknowledgement refuses canonical $boundary', () {
      final remote = serverRecord();
      final boundaryAt = remote.createdAt.add(const Duration(minutes: 2));
      if (boundary == 'createdAt') remote.createdAt = boundaryAt;
      if (boundary == 'issuedAt') remote.issuedAt = boundaryAt;
      remote.updatedAt = boundaryAt;
      final local = acknowledge(remote)
        ..acknowledgedAt = boundaryAt.subtract(const Duration(microseconds: 1))
        ..updatedAt = boundaryAt.subtract(const Duration(microseconds: 1));
      final original = local.toMap();
      expect(
        () =>
            governedDirectiveAcknowledgementPatch(local: local, remote: remote),
        throwsStateError,
      );
      expect(
        local.toMap(),
        original,
        reason: 'Never clamp retained event time.',
      );
    });
  }

  test('malformed pending acknowledgement is not accepted as exact replay', () {
    final local = acknowledge(serverRecord());
    local
      ..acknowledgedAt = local.createdAt.subtract(const Duration(seconds: 1))
      ..updatedAt = local.acknowledgedAt!;
    final remote = copyOperationalDirective(local);
    expect(
      () => governedDirectiveAcknowledgementPatch(local: local, remote: remote),
      throwsStateError,
    );
  });

  test(
    'valid exact replay permits an update recorded after acknowledgement',
    () {
      final local = acknowledge(serverRecord());
      local.updatedAt = local.acknowledgedAt!.add(const Duration(minutes: 1));
      final remote = readRemoteOperationalDirective(
        local.toMap(),
        documentId: local.firestoreId!,
      );
      expect(
        governedDirectiveAcknowledgementPatch(local: local, remote: remote),
        isEmpty,
      );
    },
  );

  test('acknowledgement after its own updatedAt is refused', () {
    final remote = serverRecord();
    final local = acknowledge(remote)..updatedAt = remote.updatedAt;
    expect(
      () => governedDirectiveAcknowledgementPatch(local: local, remote: remote),
      throwsStateError,
    );
  });

  for (final delay in [Duration.zero, const Duration(minutes: 2)]) {
    test('valid $delay acknowledgement writes UTC and round-trips exactly', () {
      final remote = serverRecord();
      final at = remote.updatedAt.add(delay).toLocal();
      final local = acknowledge(remote)
        ..acknowledgedAt = at
        ..updatedAt = at;
      final patch = governedDirectiveAcknowledgementPatch(
        local: local,
        remote: remote,
      );
      expect(patch['acknowledgedAt'], at.toUtc().toIso8601String());
      expect(patch['updatedAt'], at.toUtc().toIso8601String());
      final accepted = readRemoteOperationalDirective({
        ...remote.toMap(),
        ...patch,
      }, documentId: remote.firestoreId!);
      expect(accepted.acknowledgedAt!.isAtSameMomentAs(at), isTrue);
      expect(
        governedDirectiveAcknowledgementPatch(local: local, remote: accepted),
        isEmpty,
      );
    });
  }

  test(
    'native clock-behind attempt leaves the stored directive unchanged',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'governed_ack_clock_',
      );
      final database = await Isar.open(
        [OperationalDirectiveSchema],
        directory: directory.path,
        name: 'governed_ack_clock_test',
      );
      app.isar = database;
      try {
        final future = DateTime.now().toUtc().add(const Duration(minutes: 5));
        final record = serverRecord()
          ..createdAt = future
          ..issuedAt = future
          ..updatedAt = future;
        await database.writeTxn(
          () => database.operationalDirectives.put(record),
        );
        final before = (await database.operationalDirectives.get(
          record.id,
        ))!.toMap();
        await expectLater(
          IsarDirectiveRepository().acknowledgeDirective(
            record.id,
            actor: AppUser(
              uid: 'ia',
              name: 'Instrumentation',
              email: 'ia@example.invalid',
              roles: const [AppRole.seniorInstrumentation],
              isApproved: true,
              createdAt: DateTime.utc(2026),
            ),
            expectedVersion: record.version,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('clock'),
            ),
          ),
        );
        expect(
          (await database.operationalDirectives.get(record.id))!.toMap(),
          before,
        );
      } finally {
        await database.close(deleteFromDisk: true);
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'native server timestamps are not included in the acknowledgement write',
    () {
      final remote = serverRecord();
      final local = acknowledge(remote);
      final patch = governedDirectiveAcknowledgementPatch(
        local: local,
        remote: remote,
      );
      expect(patch.keys.toSet(), {
        'status',
        'isActive',
        'acknowledgedByUid',
        'acknowledgedByName',
        'acknowledgedAt',
        'closedByUid',
        'closedByName',
        'closedAt',
        'closedWithoutAcknowledgement',
        'updatedAt',
        'version',
      });
      expect(patch['version'], 2);
      expect(patch['acknowledgedByUid'], 'ia');
      expect(patch, isNot(contains('createdAt')));
      expect(patch, isNot(contains('issuedAt')));
      expect(patch, isNot(contains('_globalPullServerUpdatedAt')));
    },
  );
  test('a lost-response retry accepts only the exact committed evidence', () {
    final local = acknowledge(serverRecord());
    final remote = copyOperationalDirective(local)..isSynced = true;
    expect(
      governedDirectiveAcknowledgementPatch(local: local, remote: remote),
      isEmpty,
    );
    remote.acknowledgedByUid = 'another-ia';
    expect(
      () => governedDirectiveAcknowledgementPatch(local: local, remote: remote),
      throwsStateError,
    );
  });
  test('equal instants in local and UTC formats preserve source identity', () {
    final remote = serverRecord();
    final local = acknowledge(remote)
      ..createdAt = remote.createdAt.toLocal()
      ..issuedAt = remote.issuedAt!.toLocal();
    expect(
      governedDirectiveAcknowledgementPatch(local: local, remote: remote),
      isNotEmpty,
    );
  });
  test(
    'changed source evidence cannot be silently discarded or overwritten',
    () {
      final remote = serverRecord();
      for (final change in <void Function(OperationalDirective)>[
        (d) => d.metadataJson = '{"burnerPositions":[8]}',
        (d) => d.assetNumber = 4,
        (d) => d.description = 'Different direction',
        (d) => d.createdAt = d.createdAt.add(const Duration(seconds: 1)),
      ]) {
        final local = acknowledge(remote);
        change(local);
        expect(
          () => governedDirectiveAcknowledgementPatch(
            local: local,
            remote: remote,
          ),
          throwsStateError,
        );
      }
    },
  );
  test(
    'stale versions and terminal server rows are not rebased or reopened',
    () {
      final remote = serverRecord();
      final local = acknowledge(remote);
      remote.version = 5;
      expect(
        () =>
            governedDirectiveAcknowledgementPatch(local: local, remote: remote),
        throwsStateError,
      );
      remote.version = 1;
      remote.status = DirectiveStatus.closed;
      expect(
        () =>
            governedDirectiveAcknowledgementPatch(local: local, remote: remote),
        throwsStateError,
      );
    },
  );
  test(
    'local delete and closure cannot escape the governed compliance route',
    () {
      final remote = serverRecord();
      final local = acknowledge(remote)..isDeleted = true;
      expect(
        () =>
            governedDirectiveAcknowledgementPatch(local: local, remote: remote),
        throwsStateError,
      );
      local.isDeleted = false;
      local.status = DirectiveStatus.closed;
      expect(
        () =>
            governedDirectiveAcknowledgementPatch(local: local, remote: remote),
        throwsStateError,
      );
    },
  );
}
