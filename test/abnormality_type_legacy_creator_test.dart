// Real native/online repositories and durable journals; only remote transport
// is replaced. Historical records are seeded directly, never through saveType.
// ignore_for_file: subtype_of_sealed_class
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:crm3_baf_ops/core/persistence/app_database.dart' as database;
import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/core/services/online_retained_row_mutations.dart';
import 'package:crm3_baf_ops/core/services/retained_row_mutations.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_command_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/test_support/test_isar_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  final created = DateTime.utc(2026, 9, 20, 10);
  final actor = AppUser(
    uid: 'current-admin',
    name: 'Current administrator',
    email: 'current-admin@example.invalid',
    roles: [AppRole.admin],
    isApproved: true,
    createdAt: created,
  );
  late Directory directory;
  late Isar db;
  late DurableSubmissionRepository store;
  late RetainedRowMutations retained;
  late _Transport transport;
  late SharedPreferences preferences;
  var currentUid = actor.uid;

  AbnormalityType fresh() =>
      AbnormalityType.seedRaCoilColour(
          createdByUid: actor.uid,
          createdByName: actor.name,
        )
        ..firestoreId = 'type-one'
        ..createdAt = created
        ..updatedAt = created;

  setUp(() async {
    currentUid = actor.uid;
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    transport = _Transport();
    directory = await Directory.systemTemp.createTemp('legacy_type_creator_');
    db = await Isar.open(
      [AbnormalityTypeSchema, DurableSubmissionRecordSchema],
      directory: directory.path,
      name: 'legacy-type-creator',
      inspector: false,
    );
    database.isar = db;
    store = DurableSubmissionRepository(db);
    retained = RetainedRowMutations(
      store: store,
      projectId: () => 'demo-legacy-type-creator',
      currentActorUid: () => currentUid,
      gateway: transport,
    );
  });
  tearDown(() async {
    await db.close(deleteFromDisk: true);
    await directory.delete(recursive: true);
  });

  for (final native in [true, false]) {
    final label = native ? 'native' : 'online';
    AbnormalityRepository repository() => native
        ? IsarAbnormalityRepository(retainedMutations: retained)
        : FirestoreAbnormalityRepository(
            firestore: transport,
            retainedMutations: OnlineRetainedRowMutations(
              preferences: () async => preferences,
              projectId: () => 'demo-legacy-type-creator',
              currentActorUid: () => currentUid,
              gateway: transport,
            ),
          );

    Future<AbnormalityType> seed(String attribution) async {
      final wire = fresh().toMap()
        ..['version'] = 4
        ..['lastEditedByUid'] = null
        ..['lastEditedByName'] = null;
      if (attribution == 'absent') {
        wire.remove('createdByUid');
        wire.remove('createdByName');
      } else {
        wire['createdByUid'] = attribution == 'uid-only'
            ? 'historical-admin'
            : null;
        wire['createdByName'] = null;
      }
      transport.current = wire;
      final row = AbnormalityType.fromMap(wire, 'type-one')..isSynced = true;
      if (native) await db.writeTxn(() => db.abnormalityTypes.put(row));
      return row;
    }

    Future<AbnormalityType> settle(AbnormalityType row) async {
      if (native) {
        final local = (await db.abnormalityTypes.get(row.id))!;
        final pending = (await store.listForActor(actor.uid))
            .where((value) => value.state != DurableSubmissionState.reconciled)
            .single;
        final envelope = jsonDecode(pending.envelopeJson) as Map;
        expect(envelope['originActorUid'], actor.uid);
        expect(envelope['command']['expectedVersion'], local.version - 1);
        expect(
          envelope['command']['payload']['projectId'],
          'demo-legacy-type-creator',
        );
        expect(
          envelope['command']['payload']['record'],
          RetainedRowMutations.wire(local),
        );
        await retained.synchronize(RetainedRowKind.abnormalityType, local);
        return (await db.abnormalityTypes.get(row.id))!;
      }
      expect(transport.readSources, everyElement(fs.Source.server));
      return AbnormalityType.fromMap(transport.current!, 'type-one');
    }

    Future<void> expectNothingSaved(Map<String, dynamic>? original) async {
      expect(transport.envelopes, isEmpty);
      expect(transport.current, original);
      expect(await store.listForActor(actor.uid), isEmpty);
      expect(preferences.getKeys(), isEmpty);
      if (native && original != null) {
        final local = (await db.abnormalityTypes.where().findFirst())!;
        expect(local.version, 4);
        expect(local.isSynced, isTrue);
        expect(local.title, original['title']);
        expect(local.createdByUid, original['createdByUid']);
        expect(local.createdByName, original['createdByName']);
      }
    }

    for (final attribution in ['absent', 'null', 'uid-only']) {
      test(
        '$label: $attribution creator survives edit, deactivation and deletion',
        () async {
          var row = await seed(attribution);
          final creator = row.createdByUid;
          row
            ..title = 'Revised observation classification'
            ..lastEditedByUid = actor.uid
            ..lastEditedByName = actor.name;
          await repository().updateType(row, actor: actor);
          row = await settle(row);
          expect(row.title, 'Revised observation classification');
          expect(row.createdByUid, creator);
          expect(row.createdByName, isNull);
          expect(row.createdAt.toUtc(), created);
          expect(row.lastEditedByUid, actor.uid);
          expect(row.lastEditedByName, actor.name);
          expect(row.version, 5);

          row.isActive = false;
          await repository().updateType(row, actor: actor);
          row = await settle(row);
          expect(row.isActive, isFalse);
          expect(row.isDeleted, isFalse);
          expect(row.createdByUid, creator);
          expect(row.createdByName, isNull);
          expect(row.version, 6);

          await repository().softDeleteType(
            native ? row.id : row.firestoreId,
            actor: actor,
          );
          row = await settle(row);
          expect(row.isDeleted, isTrue);
          expect(row.isActive, isFalse);
          expect(row.createdByUid, creator);
          expect(row.createdByName, isNull);
          expect(row.createdAt.toUtc(), created);
          expect(row.deletedByUid, actor.uid);
          expect(row.deletedByName, actor.name);
          expect(row.lastEditedByUid, actor.uid);
          expect(row.lastEditedByName, actor.name);
          expect(row.version, 7);
          expect(transport.envelopes, hasLength(3));
        },
      );
    }

    for (final rawNative in native ? [true, false] : [false]) {
      final baseline = rawNative ? 'raw Isar' : 'reader-normalized';
      const rawCreatorUid = '  historical-admin\t';
      const rawCreatorName = '\tHistorical Administrator  ';

      Future<AbnormalityType> seedPadded() async {
        final wire = fresh().toMap()
          ..['version'] = 4
          ..['createdByUid'] = rawCreatorUid
          ..['createdByName'] = rawCreatorName;
        transport
          ..current = wire
          ..preserveCanonicalCreator = true;
        final row = AbnormalityType.fromMap(wire, 'type-one')..isSynced = true;
        if (rawNative) {
          // An older clean native row need not have traversed today's reader.
          row
            ..createdByUid = rawCreatorUid
            ..createdByName = rawCreatorName;
        }
        if (native) await db.writeTxn(() => db.abnormalityTypes.put(row));
        return copyAbnormalityType(row);
      }

      test(
        '$label: padded $baseline creator adopts raw canonical receipts through edit, deactivation and deletion',
        () async {
          var row = await seedPadded();
          for (final operation in ['edit', 'deactivate', 'delete']) {
            if (operation == 'delete') {
              await repository().softDeleteType(
                native ? row.id : row.firestoreId,
                actor: actor,
              );
            } else {
              row
                ..title = 'Revised historical classification'
                ..isActive = operation == 'edit'
                ..lastEditedByUid = actor.uid
                ..lastEditedByName = actor.name;
              await repository().updateType(row, actor: actor);
            }
            row = await settle(row);
            expect(row.isSynced, isTrue);
            expect(row.createdByUid, 'historical-admin');
            expect(row.createdByName, 'Historical Administrator');
            expect(row.createdAt.toUtc(), created);
            expect(row.lastEditedByUid, actor.uid);
            expect(row.lastEditedByName, actor.name);
            expect(row.isActive, operation == 'edit');
            expect(row.isDeleted, operation == 'delete');
            expect(transport.current!['createdByUid'], rawCreatorUid);
            expect(transport.current!['createdByName'], rawCreatorName);
            final sent = transport.envelopes.last;
            expect(sent['originActorUid'], actor.uid);
            expect(
              sent['command']['payload']['record']['createdByUid'],
              'historical-admin',
            );
            expect(
              sent['command']['payload']['record']['createdByName'],
              'Historical Administrator',
            );
            if (native) {
              final saved =
                  (await store.listForActor(
                    actor.uid,
                    includeTerminal: true,
                  )).singleWhere(
                    (value) => value.requestId == sent['command']['commandId'],
                  );
              expect(saved.state, DurableSubmissionState.reconciled);
              expect(jsonDecode(saved.envelopeJson), sent);
              final canonical =
                  jsonDecode(saved.receiptJson!)['result']['record'] as Map;
              expect(canonical['createdByUid'], rawCreatorUid);
              expect(canonical['createdByName'], rawCreatorName);
            } else {
              expect(preferences.getKeys(), isEmpty);
            }
          }
          expect(row.version, 7);
          expect(row.deletedByUid, actor.uid);
          expect(row.deletedByName, actor.name);
          expect(transport.envelopes, hasLength(3));
        },
      );

      test(
        '$label: padded $baseline creator still refuses identity replacement',
        () async {
          final seeded = await seedPadded();
          for (final field in ['UID', 'name']) {
            final row = copyAbnormalityType(seeded);
            final original = Map<String, dynamic>.from(transport.current!);
            final localBefore = native
                ? RetainedRowMutations.wire(
                    (await db.abnormalityTypes.get(row.id))!,
                  )
                : null;
            row
              ..lastEditedByUid = actor.uid
              ..lastEditedByName = actor.name;
            if (field == 'UID') {
              row.createdByUid = 'replacement-creator';
            } else {
              row.createdByName = 'Replacement Creator';
            }
            await expectLater(
              repository().updateType(row, actor: actor),
              throwsArgumentError,
            );
            expect(transport.current, original);
            expect(transport.envelopes, isEmpty);
            expect(await store.listForActor(actor.uid), isEmpty);
            expect(preferences.getKeys(), isEmpty);
            if (native) {
              expect(
                RetainedRowMutations.wire(
                  (await db.abnormalityTypes.get(row.id))!,
                ),
                localBefore,
              );
            }
          }
        },
      );
    }

    if (native) {
      for (final field in ['UID', 'name']) {
        test(
          'native: blank historical creator $field cannot become absent on edit',
          () async {
            final stored = fresh()
              ..version = 4
              ..isSynced = true;
            if (field == 'UID') {
              stored
                ..createdByUid = '  '
                ..createdByName = null;
            } else {
              stored.createdByName = '  ';
            }
            await db.writeTxn(() => db.abnormalityTypes.put(stored));
            final original = RetainedRowMutations.wire(stored);
            final edit = copyAbnormalityType(stored)
              ..lastEditedByUid = actor.uid
              ..lastEditedByName = actor.name;
            await expectLater(
              repository().updateType(edit, actor: actor),
              throwsArgumentError,
            );
            expect(transport.envelopes, isEmpty);
            expect(await store.listForActor(actor.uid), isEmpty);
            expect(
              RetainedRowMutations.wire(
                (await db.abnormalityTypes.get(stored.id))!,
              ),
              original,
            );
          },
        );
      }
    }

    for (final invalid in [
      'both-missing',
      'name-missing',
      'uid-missing',
      'blank-name',
      'blank-uid',
    ]) {
      test(
        '$label: new catalogue entry refuses $invalid creator before any save',
        () async {
          final row = fresh();
          switch (invalid) {
            case 'both-missing':
              row.createdByUid = null;
              row.createdByName = null;
            case 'name-missing':
              row.createdByName = null;
            case 'uid-missing':
              row.createdByUid = null;
            case 'blank-name':
              row.createdByName = '   ';
            case 'blank-uid':
              row.createdByUid = '   ';
          }
          await expectLater(
            repository().saveType(row, actor: actor),
            throwsArgumentError,
          );
          await expectNothingSaved(null);
          expect(await db.abnormalityTypes.count(), 0);
        },
      );
    }

    test(
      '$label: an existing unknown creator cannot be fabricated by an edit',
      () async {
        final row = await seed('null');
        final original = Map<String, dynamic>.from(transport.current!);
        row
          ..createdByUid = actor.uid
          ..createdByName = actor.name
          ..lastEditedByUid = actor.uid
          ..lastEditedByName = actor.name;
        await expectLater(
          repository().updateType(row, actor: actor),
          throwsArgumentError,
        );
        await expectNothingSaved(original);
      },
    );

    test(
      '$label: historical creator compatibility does not allow a missing current editor name',
      () async {
        final row = await seed('uid-only');
        final original = Map<String, dynamic>.from(transport.current!);
        row.lastEditedByUid = actor.uid;
        await expectLater(
          repository().updateType(row, actor: actor),
          throwsArgumentError,
        );
        await expectNothingSaved(original);
      },
    );

    test(
      '$label: complete new creator remains accepted and current-actor bound',
      () async {
        var row = fresh();
        await repository().saveType(row, actor: actor);
        row = await settle(row);
        expect(row.createdByUid, actor.uid);
        expect(row.createdByName, actor.name);
        expect(row.lastEditedByUid, actor.uid);
        expect(row.lastEditedByName, actor.name);
        expect(transport.envelopes.single['originActorUid'], actor.uid);
        expect(transport.envelopes.single['command']['expectedVersion'], 0);
      },
    );

    test(
      '$label: historical creator absence cannot bypass the live account guard',
      () async {
        final row = await seed('null');
        final original = Map<String, dynamic>.from(transport.current!);
        row
          ..lastEditedByUid = actor.uid
          ..lastEditedByName = actor.name;
        currentUid = 'another-admin';
        await expectLater(
          repository().updateType(row, actor: actor),
          throwsA(anything),
        );
        await expectNothingSaved(original);
      },
    );
  }
}

class _Transport
    implements fs.FirebaseFirestore, OriginBoundWorkflowCommandGateway {
  Map<String, dynamic>? current;
  bool preserveCanonicalCreator = false;
  final envelopes = <Map<String, dynamic>>[];
  final readSources = <fs.Source?>[];

  @override
  fs.CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'abnormality_types');
    return _Collection(this);
  }

  @override
  Future<WorkflowCommandReceipt> executeOriginBoundEnvelope(
    String envelopeJson,
  ) async {
    final envelope = jsonDecode(envelopeJson) as Map<String, dynamic>;
    envelopes.add(envelope);
    final command = envelope['command'] as Map;
    final original = current;
    current = Map<String, dynamic>.from(command['payload']['record'] as Map);
    if (preserveCanonicalCreator && original != null) {
      current!
        ..['createdByUid'] = original['createdByUid']
        ..['createdByName'] = original['createdByName'];
    }
    return WorkflowCommandReceipt(
      commandId: command['commandId'] as String,
      resultKey: 'retained-queue-mutation-applied',
      aggregateVersion: current!['version'] as int,
      appliedAt: DateTime.now().toUtc(),
      result: {
        'collection': 'abnormality_types',
        'recordId': 'type-one',
        'record': current,
      },
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Collection implements fs.CollectionReference<Map<String, dynamic>> {
  _Collection(this.owner);
  final _Transport owner;
  @override
  fs.DocumentReference<Map<String, dynamic>> doc([String? path]) {
    expect(path, 'type-one');
    return _Reference(owner);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reference implements fs.DocumentReference<Map<String, dynamic>> {
  _Reference(this.owner);
  final _Transport owner;
  @override
  Future<fs.DocumentSnapshot<Map<String, dynamic>>> get([
    fs.GetOptions? options,
  ]) async {
    owner.readSources.add(options?.source);
    return _Snapshot(owner.current);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Snapshot implements fs.DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.value);
  final Map<String, dynamic>? value;
  @override
  String get id => 'type-one';
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
