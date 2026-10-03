import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/core/serialization/tolerant_snapshot_decode.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_availability_record.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/data/furnace_stuckup_record.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/assets/domain/apply_inner_cover_dependencies.dart';
import 'package:crm3_baf_ops/features/assets/domain/inner_cover_dependencies.dart';
import 'package:crm3_baf_ops/features/assets/domain/inner_cover_stock_summary.dart';
import 'package:crm3_baf_ops/features/assets/domain/physical_plant_inventory.dart';
import 'package:crm3_baf_ops/features/assets/domain/qualified_plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/firestore_workflow_read_repository.dart';
import 'package:crm3_baf_ops/features/reports/domain/base_inner_cover_register.dart';

// Executes only the pure fixture builder: no service, actor, callable or seed.
Map<String, Map<String, dynamic>> fixtureDocuments() {
  final result = Process.runSync(Platform.isWindows ? 'python' : 'python3', [
    '-c',
    "import sys,json; sys.path.insert(0,'tools/testing'); import seed_ci_business_journeys as s; from datetime import datetime,timezone; d=s.inner_cover_fixture_documents(datetime(2026,10,3,tzinfo=timezone.utc),{'uid':'fixture-author','name':'Synthetic fixture'}); print(json.dumps({p:{k:s.wire(v) for k,v in d.items()} for p,d in d.items()}))",
  ]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
  dynamic unwire(Map<String, dynamic> value) {
    if (value.containsKey('timestampValue')) {
      return DateTime.parse(value['timestampValue'] as String);
    }
    if (value.containsKey('integerValue')) {
      return int.parse(value['integerValue'] as String);
    }
    if (value.containsKey('arrayValue')) {
      return ((value['arrayValue'] as Map)['values'] as List)
          .map((v) => unwire(Map<String, dynamic>.from(v as Map)))
          .toList();
    }
    return value.values.single;
  }

  return (jsonDecode(result.stdout as String) as Map).map(
    (path, fields) => MapEntry(
      path as String,
      (fields as Map).map(
        (key, value) => MapEntry(
          key as String,
          unwire(Map<String, dynamic>.from(value as Map)),
        ),
      ),
    ),
  );
}

DecodedSnapshotBatch<T> batch<T>(List<T> values) =>
    DecodedSnapshotBatch(records: values, rejectedDocumentIds: const []);

void main() {
  test(
    'actual CI IC fixture decodes to two qualified available linked pairs without seeded business outcomes',
    () {
      final docs = fixtureDocuments();
      expect(docs, hasLength(14));
      expect(
        docs.keys.any(
          (path) => RegExp(
            r'^(furnace_stuckup_cases|maintenance_records|maintenance_workflows|workflow_command_results|asset_condition_declarations)/',
          ).hasMatch(path),
        ),
        isFalse,
      );
      List<T> read<T>(
        String collection,
        T Function(Map<String, dynamic>, String) decode,
      ) => docs.entries
          .where((entry) => entry.key.startsWith('$collection/'))
          .map((entry) => decode(entry.value, entry.key.split('/').last))
          .toList();
      final classes = read('asset_classes', AssetClassRecord.fromMap);
      final assets = read('asset_instances', AssetInstanceRecord.fromMap);
      final covers = read('inner_cover_profiles', InnerCoverProfile.fromMap);
      final assignments = read(
        'base_inner_cover_assignments',
        BaseInnerCoverAssignment.fromMap,
      );
      final links = read('inner_cover_linkages', InnerCoverLinkage.fromMap);
      final availability = read(
        'asset_availability_current',
        AssetAvailabilityRecord.fromMap,
      );
      final workflow = read(
        'equipment_status',
        (data, id) =>
            equipmentStatusRecordFromFirestoreData(documentId: id, data: data),
      );
      expect(
        classes.map((c) => c.legacyAssetTypeKey),
        unorderedEquals(['base', 'innerCover']),
      );
      expect(assets.map((a) => a.assetNumber), orderedEquals([101, 102]));
      expect(
        covers.map((c) => c.serialNumber),
        orderedEquals(['DEV-IC-FITNESS-31', 'DEV-IC-COMPARISON-31']),
      );
      for (final cover in covers) {
        expect(cover.version, 3);
        expect(cover.isInstalled, isTrue);
        expect(cover.acceptedAt!.isBefore(DateTime.utc(2026, 10, 3)), isTrue);
        expect(cover.requiresReacceptance, isFalse);
      }
      final register = buildBaseInnerCoverRegister(
        classes: batch(classes),
        assets: batch(assets),
        assignments: batch(assignments),
        covers: batch(covers),
        linkages: batch(links),
      );
      expect(register.populationConfirmed, isTrue);
      expect(register.evidenceConfirmed, isTrue);
      expect(
        register.rows.every((row) => row.state == BaseCoverLinkState.linked),
        isTrue,
      );
      final dependencies = qualifyInnerCoverDependencyProjections(
        deriveInnerCoverDependencies(
          profiles: batch(covers),
          tickets: batch([]),
          workflows: batch([]),
          executions: batch([]),
          stuckupCases: batch([]),
        ),
        batch(workflow),
      );
      final stock = annotateInnerCoverStockDependencies(
        buildInnerCoverStockSummary(
          classes: batch(classes),
          profiles: batch(covers),
          assignments: batch(assignments),
          links: batch(links),
          register: register,
          cases: batch(<FurnaceStuckupRecord>[]),
          declarations: batch(<AssetConditionDeclarationRecord>[]),
        ),
        dependencies,
      );
      expect(stock.inventoryConfirmed, isTrue);
      expect(stock.linkageConfirmed, isTrue);
      expect(stock.bulgeEvidenceConfirmed, isTrue);
      expect(stock.dependencyEvidenceConfirmed, isTrue);
      expect(stock.installed, 2);
      expect(stock.review, isEmpty);
      final view = applyInnerCoverDependencies(
        overview: physicalPlantInventory(
          overview: qualifiedPlantAssetOverview(
            classes: classes,
            assets: assets,
            conditions: [],
            workflow: workflow,
            availability: availability,
            tickets: [],
            populationWarnings: [],
            manualSourcesCurrent: true,
          ),
          classes: classes,
          profiles: covers,
          innerCoverStock: stock,
        ),
        register: register,
        dependencies: dependencies,
      );
      for (final cls in view.classes) {
        expect(cls.total, 2);
        expect(cls.available, 2);
        expect(cls.unavailable, 0);
        expect(cls.unverifiedAvailability, 0);
      }
      expect(view.evidenceWarnings, isEmpty);
      expect(view.down, 0);
      expect(view.unfit, 0);
    },
  );
}
