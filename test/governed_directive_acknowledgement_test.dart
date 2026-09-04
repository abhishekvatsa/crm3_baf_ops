import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/features/directives/data/governed_directive_acknowledgement.dart';
import 'package:crm3_baf_ops/features/directives/data/operational_directive_model.dart';
import 'package:crm3_baf_ops/features/directives/data/remote_operational_directive_reader.dart';
import 'package:crm3_baf_ops/features/directives/providers/operational_directive_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_test/flutter_test.dart';

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
    final local =
        acknowledge(remote)
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
