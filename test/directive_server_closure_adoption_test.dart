import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import '../tool/test_support/test_isar_core.dart';

import 'package:crm3_baf_ops/core/persistence/app_database.dart' as app;
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/directives/data/operational_directive_model.dart';
import 'package:crm3_baf_ops/features/directives/providers/operational_directive_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';

Future<void> _withDirectiveIsar(Future<void> Function(Isar isar) body) async {
  final directory = await Directory.systemTemp.createTemp(
    'directive_server_closure_',
  );
  final instance = await Isar.open(
    [OperationalDirectiveSchema],
    directory: directory.path,
    name: 'directive_server_closure_test',
  );
  app.isar = instance;
  try {
    await body(instance);
  } finally {
    await instance.close(deleteFromDisk: true);
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

OperationalDirective _directive() {
  final created = DateTime.utc(2026, 8, 28, 8);
  return OperationalDirective()
    ..firestoreId = 'burner_round_red_hot_11111111-1111-4111-8111-111111111111'
    ..isSynced = true
    ..version = 3
    ..title = 'Red-hot burner block: B3'
    ..description = 'Governed burner compliance directive.'
    ..assetType = AssetType.furnace
    ..assetNumber = 7
    ..component = 'Burner block'
    ..subsystem = 'Burner system'
    ..directedTo = AppRole.seniorInstrumentation
    ..status = DirectiveStatus.acknowledged
    ..priority = DirectivePriority.critical
    ..createdByUid = 'operations-1'
    ..issuedByUid = 'operations-1'
    ..isActive = true
    ..acknowledgedByUid = 'ia-1'
    ..acknowledgedAt = DateTime.utc(2026, 8, 28, 8, 5)
    ..createdAt = created
    ..updatedAt = created;
}

AppUser _actor() => AppUser(
  uid: 'ia-1',
  name: 'I&A One',
  email: 'ia@example.com',
  roles: const [AppRole.seniorInstrumentation],
  isApproved: true,
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  setUpAll(initializeTestIsarCore);

  test('exact server receipt closes the clean local directive', () async {
    await _withDirectiveIsar((isar) async {
      final directive = _directive();
      await isar.writeTxn(() => isar.operationalDirectives.put(directive));
      final closedAt = DateTime.utc(2026, 8, 28, 9);

      await IsarDirectiveRepository().adoptServerDirectiveClosure(
        firestoreId: directive.firestoreId!,
        expectedBeforeVersion: 3,
        committedVersion: 4,
        actor: _actor(),
        closedAt: closedAt,
        wasUnacknowledged: false,
        remarks: 'UV returned to service.',
      );

      final retained = await isar.operationalDirectives.get(directive.id);
      expect(retained, isNotNull);
      expect(retained!.status, DirectiveStatus.closed);
      expect(retained.isActive, isFalse);
      expect(retained.closedByUid, 'ia-1');
      expect(retained.closedAt!.toUtc(), closedAt);
      expect(retained.version, 4);
      expect(retained.isSynced, isTrue);
      expect(retained.remarks, 'UV returned to service.');
    });
  });

  test(
    'stale or dirty local rows are never overwritten by the receipt',
    () async {
      await _withDirectiveIsar((isar) async {
        final directive =
            _directive()
              ..version = 4
              ..isSynced = false;
        await isar.writeTxn(() => isar.operationalDirectives.put(directive));

        await expectLater(
          IsarDirectiveRepository().adoptServerDirectiveClosure(
            firestoreId: directive.firestoreId!,
            expectedBeforeVersion: 3,
            committedVersion: 4,
            actor: _actor(),
            closedAt: DateTime.utc(2026, 8, 28, 9),
            wasUnacknowledged: false,
          ),
          throwsStateError,
        );

        final retained = await isar.operationalDirectives.get(directive.id);
        expect(retained!.status, DirectiveStatus.acknowledged);
        expect(retained.isSynced, isFalse);
        expect(retained.version, 4);
      });
    },
  );

  test('an already exact local closure is an idempotent adoption', () async {
    await _withDirectiveIsar((isar) async {
      final closedAt = DateTime.utc(2026, 8, 28, 9);
      final directive =
          _directive()
            ..status = DirectiveStatus.closed
            ..isActive = false
            ..closedByUid = 'ia-1'
            ..closedByName = 'I&A One'
            ..closedAt = closedAt
            ..closedWithoutAcknowledgement = false
            ..remarks = 'UV returned to service.'
            ..updatedAt = closedAt
            ..version = 4;
      await isar.writeTxn(() => isar.operationalDirectives.put(directive));

      await IsarDirectiveRepository().adoptServerDirectiveClosure(
        firestoreId: directive.firestoreId!,
        expectedBeforeVersion: 3,
        committedVersion: 4,
        actor: _actor(),
        closedAt: closedAt,
        wasUnacknowledged: false,
        remarks: 'UV returned to service.',
      );

      final retained = await isar.operationalDirectives.get(directive.id);
      expect(retained!.version, 4);
      expect(retained.isSynced, isTrue);
      expect(retained.closedAt!.toUtc(), closedAt);
    });
  });
}
