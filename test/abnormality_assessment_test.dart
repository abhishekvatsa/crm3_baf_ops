import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/core/persistence/app_database.dart' as app;
import 'package:crm3_baf_ops/core/services/sync_push_snapshot.dart';
import 'package:crm3_baf_ops/features/abnormalities/domain/charge_abnormality_identity.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';

ChargeAbnormality record() => ChargeAbnormality.createRaCoilColour(
  firestoreId: 'finding-1',
  sourceChargeNo: 70001,
  affectedAssets: const [
    AffectedAssetRef(assetType: AssetType.furnace, assetNumber: 1),
  ],
  observedReason: 'Uneven colour observed',
  loggedByUid: 'operator',
  loggedByName: 'Operator',
);

void main() {
  setUpAll(initializeTestIsarCore);

  test(
    'assessment-only queued edits are not falsely converged with an older server readback',
    () {
      final local = record();
      final remote = copyChargeAbnormality(local);
      expect(sameChargeAbnormalitySyncContent(local, remote), isTrue);
      local.assessment = const AbnormalityAssessment(
        observationKind: AbnormalityObservationKind.resultFinding,
        candidateCauses: [
          CandidateProcessCause(
            id: 'c',
            description: 'Atmosphere hypothesis',
            assessment: CauseAssessment.suspected,
            evidence: null,
          ),
        ],
      );
      expect(sameChargeAbnormalitySyncContent(local, remote), isFalse);
      expect(
        sameChargeAbnormalitySyncContent(local, copyChargeAbnormality(local)),
        isTrue,
      );
    },
  );

  test(
    'colour finding starts pending; no cause or RA occurrence is inferred',
    () {
      final value = record();
      expect(value.reannealingStatus, ReannealingStatus.pendingDecision);
      expect(value.observationKind, AbnormalityObservationKind.resultFinding);
      expect(value.assessment!.candidateCauses, isEmpty);
      expect(value.raPerformedAt, isNull);
      expect(AbnormalityType.seedRaCoilColour().suggestsReannealing, isFalse);
    },
  );

  test(
    'metadata survives asset replacement, copy and remote serialization',
    () {
      final value = record()
        ..reannealingStatus = ReannealingStatus.completed
        ..reannealedToChargeNo = 70002;
      value.assessment = AbnormalityAssessment(
        observationKind: AbnormalityObservationKind.resultFinding,
        raPerformedAt: DateTime.utc(2026, 9, 20, 8),
        candidateCauses: const [
          CandidateProcessCause(
            id: 'cause-1',
            description: 'Atmosphere interruption',
            assessment: CauseAssessment.suspected,
            evidence: null,
            maintenanceTicketId: 'ticket-1',
          ),
        ],
      );
      final expected = value.assessment!.toMap();
      value.affectedAssets = const [
        AffectedAssetRef(assetType: AssetType.base, assetNumber: 2),
      ];
      final copied = copyChargeAbnormality(value);
      final map = copied.toMap();
      expect(map['affectedAssets'], isA<List>());
      expect(map['assessment'], expected);
      final remote = ChargeAbnormality.fromMap(map, 'finding-1');
      expect(remote.assessment!.toMap(), expected);
      expect(remote.affectedAssets.single.assetNumber, 2);
    },
  );

  test(
    'legacy completed RA remains undated despite later edits and post-RA inspection',
    () {
      final value = record()
        ..assessment = null
        ..reannealingStatus = ReannealingStatus.completed
        ..reannealedToChargeNo = 70002
        ..updatedAt = DateTime.utc(2026, 9, 25);
      expect(jsonDecode(value.affectedAssetsJson), isA<List>());
      expect(value.observationKind, isNull);
      expect(value.raPerformedAt, isNull);
      value.assessment = const AbnormalityAssessment(
        observationKind: AbnormalityObservationKind.legacyUnknown,
        postRaResult: PostRaResult.acceptable,
        postRaObservation: 'Later coil inspection satisfactory',
      );
      expect(value.toMap()['assessment'], containsPair('raPerformedAt', null));
      expect(value.observationKind, isNull);
    },
  );

  test(
    'malformed envelope fails closed instead of losing assets and evidence',
    () {
      final value = record()
        ..affectedAssetsJson =
            '{"schemaVersion":1,"assets":[],"assessment":{}}';
      expect(
        () => value.affectedAssets,
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(() => value.toMap(), throwsA(isA<PersistedDataFormatException>()));
    },
  );

  test('confirmed and ruled-out hypotheses need explicit evidence', () {
    for (final status in [
      CauseAssessment.confirmed,
      CauseAssessment.ruledOut,
    ]) {
      expect(
        () => CandidateProcessCause.fromMap(
          CandidateProcessCause(
            id: 'c',
            description: 'Suspected burner problem',
            assessment: status,
            evidence: null,
          ).toMap(),
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
    }
  });

  test('RA occurrence and post-RA result cannot attach to undecided RA', () {
    final value = record()
      ..assessment = AbnormalityAssessment(
        observationKind: AbnormalityObservationKind.resultFinding,
        raPerformedAt: DateTime.utc(2026, 9, 20),
      );
    expect(() => value.toMap(), throwsA(isA<PersistedDataFormatException>()));
  });

  test(
    'native Isar reopen retains the optional envelope without a schema migration',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'abnormality_assessment_',
      );
      var db = await Isar.open(
        [ChargeAbnormalitySchema],
        directory: directory.path,
        name: 'assessment',
      );
      try {
        final value = record()
          ..assessment = const AbnormalityAssessment(
            observationKind: AbnormalityObservationKind.processEquipment,
            candidateCauses: [
              CandidateProcessCause(
                id: 'c',
                description: 'Burner imbalance',
                assessment: CauseAssessment.ruledOut,
                evidence: 'All burner readings within range',
              ),
            ],
          );
        await db.writeTxn(() => db.chargeAbnormalitys.put(value));
        await db.close();
        db = await Isar.open(
          [ChargeAbnormalitySchema],
          directory: directory.path,
          name: 'assessment',
        );
        final restored = (await db.chargeAbnormalitys.get(value.id))!;
        expect(restored.assessment!.toMap(), value.assessment!.toMap());
        expect(restored.affectedAssets.single.assetNumber, 1);
        expect(restored.raPerformedAt, isNull);
        app.isar = db;
        final accepted = copyChargeAbnormality(restored)
          ..version = restored.version + 1
          ..updatedAt = restored.updatedAt.add(const Duration(seconds: 1))
          ..assessment = const AbnormalityAssessment(
            observationKind: AbnormalityObservationKind.processEquipment,
            candidateCauses: [
              CandidateProcessCause(
                id: 'c',
                description: 'Burner imbalance',
                assessment: CauseAssessment.confirmed,
                evidence: 'Measured flame imbalance recorded',
              ),
            ],
          );
        expect(
          await IsarAbnormalityRepository()
              .applyAbnormalityServerReadbackIfUnchanged(
                accepted,
                expectedLocal: SyncPushSnapshot(
                  id: restored.id,
                  version: restored.version,
                  updatedAt: restored.updatedAt,
                ),
                expectedLocalSynced: false,
              ),
          isTrue,
        );
        final reconciled = (await db.chargeAbnormalitys.get(restored.id))!;
        expect(reconciled.assessment!.toMap(), accepted.assessment!.toMap());
        expect(reconciled.isSynced, isTrue);
      } finally {
        await db.close(deleteFromDisk: true);
        await directory.delete(recursive: true);
      }
    },
  );
}
