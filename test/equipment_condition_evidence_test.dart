import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/assets/data/plant_condition_evidence.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_operational_condition.dart';
import 'package:crm3_baf_ops/features/assets/domain/qualified_plant_asset_overview.dart';
import 'plant_asset_overview_test.dart' as f;

void main() {
  final cls = f.assetClass(
    id: 'furnace',
    code: 'FURNACE',
    name: 'Furnace',
    legacyKey: 'furnace',
  );
  final good = f.asset(id: 'furnace-7', assetClass: cls, number: 7);
  test('server pull-clock metadata does not impersonate a business revision conflict',(){
    final original=assetMap(good);
    final result=decodePlantEvidence(documents:{good.id:{...original,'_globalPullServerUpdatedAt':DateTime.utc(2026,9,20)}},previous:{good.id:original},decode:AssetInstanceRecord.fromMap,fromServer:true);
    expect(result.complete,isTrue);expect(result.rows.single.id,good.id);
  });
  test('actual asset decoder retains valid rows and reports damaged rows', () {
    final batch = decodePlantEvidence(
      documents: {
        good.id: assetMap(good),
        'damaged': {'version': 1},
      },
      decode: AssetInstanceRecord.fromMap,
      fromServer: true,
    );
    expect(batch.rows.single.id, good.id);
    expect(batch.rejected.keys, contains('damaged'));
    expect(batch.complete, isFalse);
  });
  test(
    'cache and same-version contradiction cannot certify complete evidence',
    () {
      final original = assetMap(good);
      expect(
        decodePlantEvidence(
          documents: {good.id: original},
          decode: AssetInstanceRecord.fromMap,
          fromServer: false,
        ).complete,
        isFalse,
      );
      final conflict = decodePlantEvidence(
        documents: {
          good.id: {...original, 'name': 'Changed without revision'},
        },
        previous: {good.id: original},
        decode: AssetInstanceRecord.fromMap,
        fromServer: true,
      );
      expect(conflict.rows.single.name, good.name);
      expect(conflict.rejected, isNotEmpty);
    },
  );
  test(
    'missing and regressing revisions preserve last known evidence but withhold completeness',
    () {
      final original = assetMap(good);
      final prior = {
        good.id: {...original, 'version': 2},
      };
      for (final docs in <Map<String, Map<String, dynamic>>>[
        {},
        {good.id: original},
      ]) {
        final batch = decodePlantEvidence(
          documents: docs,
          previous: prior,
          decode: AssetInstanceRecord.fromMap,
          fromServer: true,
        );
        expect(batch.complete, isFalse);
        expect(batch.rows.single.version, 2);
        expect(batch.rejected.keys, contains(good.id));
      }
    },
  );
  test(
    'unrelated damaged association leaves healthy selected actions accessible',
    () {
      final other = f.asset(id: 'furnace-99', assetClass: cls, number: 99);
      final wrong = f.asset(
        id: other.id,
        assetClass: f.assetClass(id: 'wrong', code: 'WRONG', name: 'Wrong'),
        number: 99,
      );
      final overview = qualifiedPlantAssetOverview(
        classes: [cls],
        assets: [good, other],
        conditions: [
          f.condition(asset: wrong, condition: AssetOperationalCondition.down),
        ],
        workflow: [f.workflow(key: 'furnace', number: 7)],
        availability: [],
        tickets: [],
        populationWarnings: [],
        manualSourcesCurrent: true,
      );
      expect(
        overview.assets
            .firstWhere((r) => r.asset.id == good.id)
            .permitsManualChange,
        isTrue,
      );
      expect(
        overview.assets.firstWhere((r) => r.asset.id == other.id).isAvailable,
        isFalse,
      );
      expect(
        overview.assets
            .firstWhere((r) => r.asset.id == other.id)
            .permitsManualChange,
        isFalse,
      );
      expect(overview.evidenceWarnings, isNotEmpty);
    },
  );
  test(
    'incomplete source withholds all-clear but retains known restrictions and safe manual actions',
    () {
      final overview = qualifiedPlantAssetOverview(
        classes: [cls],
        assets: [good],
        conditions: [
          f.condition(asset: good, condition: AssetOperationalCondition.down),
        ],
        workflow: [f.workflow(key: 'furnace', number: 7)],
        availability: [],
        tickets: [],
        populationWarnings: ['Issue evidence incomplete'],
        manualSourcesCurrent: true,
      );
      expect(overview.assets.single.isDown, isTrue);
      expect(overview.available, 0);
      expect(overview.assets.single.permitsManualChange, isTrue);
    },
  );
  test(
    'unverified manual source disables manual mutation instead of assuming no declaration',
    () {
      final overview = qualifiedPlantAssetOverview(
        classes: [cls],
        assets: [good],
        conditions: [],
        workflow: [f.workflow(key: 'furnace', number: 7)],
        availability: [],
        tickets: [],
        populationWarnings: ['Manual source unavailable'],
        manualSourcesCurrent: false,
      );
      expect(overview.assets.single.permitsManualChange, isFalse);
      expect(overview.available, 0);
    },
  );
}

Map<String, dynamic> assetMap(AssetInstanceRecord a) => {
  'schemaVersion': 1,
  'assetInstanceId': a.id,
  'assetClassId': a.assetClassId,
  'assetClassCode': a.assetClassCode,
  'assetClassName': a.assetClassName,
  'assetNumber': a.assetNumber,
  'name': a.name,
  'serviceState': a.serviceState.name,
  'ownershipStatus': a.ownershipStatus.name,
  'ownerDiscipline': a.ownerDiscipline,
  'accountableRoleKeys': a.accountableRoleKeys,
  'status': a.status.name,
  'activeComponentCount': 0,
  'version': a.version,
  'createdAt': a.createdAt,
  'updatedAt': a.updatedAt,
  'lastMutationId': a.lastMutationId,
};
