import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/inspections/data/inspection_campaign.dart';
import 'package:crm3_baf_ops/features/inspections/repositories/inspection_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'inspection_campaign_model_test.dart'
    show campaignTarget, observationMap, frozenDefinition;

Map<String, dynamic> installedTarget({
  int base = 205,
  String serial = 'N4',
  String id = 'cover-n4',
  int version = 7,
}) => {
  ...campaignTarget(assetNumber: 1),
  'assetTypeKey': 'innerCover',
  'assetClassId': 'class-inner-cover',
  'assetInstanceId': id,
  'assetInstanceVersion': version,
  'assetInstanceName': 'Inner Cover $serial',
  'assetNumber': base,
  'targetKey':
      'class-inner-cover:$id|pressure-transmitter|Gas train|link:link-$id-base-$base',
  'hostAssetClassId': 'class-base',
  'hostAssetInstanceId': 'base-$base',
  'hostAssetInstanceVersion': 2,
  'hostAssetNumber': base,
  'hostAssetInstanceName': 'Base $base',
  'subjectSerialNumber': serial,
  'linkageId': 'link-$id-base-$base',
  'linkageVersion': 1,
  'linkedAt': '2026-08-21T04:00:00.000Z',
};
Map<String, dynamic> review(Map<String, dynamic> current) => {
  'schemaVersion': 1,
  'revision': 1,
  'auditId': 'review-1',
  'reviewedAt': '2026-08-22T04:00:00.000Z',
  'reviewedByUid': 'manager',
  'reviewedByName': 'Manager',
  'reason': 'Same serial after repair and relocation.',
  'context': current,
};

void main() {
  test(
    'review parser retains original target and shows approved same-serial current host',
    () {
      final original = installedTarget();
      final target = InspectionCampaignTarget.fromMap({
        ...original,
        'contextReview': review(installedTarget(base: 206, version: 8)),
      }, source: 'target');
      expect(target.assetNumber, 205);
      expect(target.assetInstanceVersion, 7);
      expect(target.targetKey, original['targetKey']);
      expect(target.contextRevision, 1);
      expect(target.currentContext.assetNumber, 206);
      expect(target.rowLabel, 'Base 206 (N4)');
      expect(
        target.contextReview!.reason,
        'Same serial after repair and relocation.',
      );
    },
  );
  for (final mode in [
    'serial',
    'class',
    'component',
    'nested',
    'actor',
    'revision',
  ]) {
    test('malformed or rebound context $mode is refused', () {
      final current = installedTarget(base: 206, version: 8);
      if (mode == 'serial') current['subjectSerialNumber'] = 'N5';
      if (mode == 'class') current['assetClassId'] = 'another-class';
      if (mode == 'component') current['componentNodeId'] = 'another-component';
      if (mode == 'nested') {
        current['contextReview'] = review(installedTarget());
      }
      final evidence = review(current);
      if (mode == 'actor') evidence.remove('reviewedByUid');
      if (mode == 'revision') evidence['revision'] = 0;
      expect(
        () => InspectionCampaignTarget.fromMap({
          ...installedTarget(),
          'contextReview': evidence,
        }, source: 'target'),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });
  }
  test(
    'reviewed relocated observation retains logical original key with explicit review evidence',
    () {
      final original = installedTarget();
      final current = installedTarget(base: 206, version: 8);
      final map = {
        ...observationMap(),
        ...current,
        'schemaVersion': 1,
        'observationId': 'later',
        'definition': {
          ...frozenDefinition(),
          'assetTypeKeys': ['innerCover'],
          'assetClassIds': ['class-inner-cover'],
        },
        'targetKey': original['targetKey'],
        'targetContextRevision': 1,
        'targetContextAuditId': 'review-1',
        'targetContextOriginalLinkageId': original['linkageId'],
      };
      final observation = InspectionObservation.fromMap(map, 'later');
      expect(observation.assetNumber, 206);
      expect(observation.targetKey, original['targetKey']);
      expect(observation.targetContextRevision, 1);
      expect(
        () => InspectionObservation.fromMap({
          ...map,
          'targetContextAuditId': null,
        }, 'later'),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => InspectionObservation.fromMap({
          ...map,
          'targetContextOriginalLinkageId': current['linkageId'],
        }, 'later'),
        throwsA(isA<PersistedDataFormatException>()),
      );
    },
  );

  test(
    'real context reader follows the original serial and requires server evidence',
    () async {
      final database = _Database();
      final target = InspectionCampaignTarget.fromMap(
        installedTarget(),
        source: 'target',
      );
      final repository = InspectionRepository(firestore: database);
      final context = await repository.readTargetContext(target);
      expect(context['assetInstanceId'], 'cover-n4');
      expect(context['assetNumber'], 206);
      expect(context['assetInstanceVersion'], 8);
      expect(context['linkageId'], 'link-cover-n4-base-206');
      expect(database.reads, [
        'inner_cover_profiles/cover-n4',
        'asset_instances/base-206',
        'base_inner_cover_assignments/base-206',
        'inner_cover_linkages/link-cover-n4-base-206',
      ]);
      expect(database.sources, everyElement(Source.server));
      database.cached = true;
      await expectLater(repository.readTargetContext(target), throwsStateError);
      database.cached = false;
      database.rows['inner_cover_profiles/cover-n4']!['serialNumber'] = 'N5';
      await expectLater(repository.readTargetContext(target), throwsStateError);
    },
  );
}

class _Database extends Fake implements FirebaseFirestore {
  bool cached = false;
  final reads = <String>[];
  final sources = <Source?>[];
  final rows = <String, Map<String, dynamic>>{
    'inner_cover_profiles/cover-n4': {
      'innerCoverId': 'cover-n4',
      'assetClassId': 'class-inner-cover',
      'serialNumber': 'N4',
      'lifecycleState': 'installed',
      'currentBaseAssetInstanceId': 'base-206',
      'currentBaseAssetNumber': 206,
      'currentLinkageId': 'link-cover-n4-base-206',
      'version': 8,
    },
    'asset_instances/base-206': {
      'assetInstanceId': 'base-206',
      'assetClassId': 'class-base',
      'assetNumber': 206,
      'name': 'Base 206',
      'status': 'active',
      'version': 2,
    },
    'base_inner_cover_assignments/base-206': {
      'baseAssetInstanceId': 'base-206',
      'baseAssetClassId': 'class-base',
      'baseAssetNumber': 206,
      'innerCoverId': 'cover-n4',
      'innerCoverSerialNumber': 'N4',
      'linkageId': 'link-cover-n4-base-206',
      'linkedAt': '2026-08-21T04:00:00.000Z',
      'version': 1,
    },
    'inner_cover_linkages/link-cover-n4-base-206': {
      'linkageId': 'link-cover-n4-base-206',
      'baseAssetInstanceId': 'base-206',
      'innerCoverId': 'cover-n4',
      'innerCoverSerialNumber': 'N4',
      'active': true,
      'version': 1,
      'installedAt': '2026-08-21T04:00:00.000Z',
    },
  };
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
}

// Test-only SDK boundary: verifies exact paths, server source and metadata.
// ignore: subtype_of_sealed_class
class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.database, this.path);
  final _Database database;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      _Document(database, '$path/$id');
}

// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.database, this.path);
  final _Database database;
  @override
  final String path;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    database.reads.add(path);
    database.sources.add(options?.source);
    return _Snapshot(database, path);
  }
}

// ignore: subtype_of_sealed_class
class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.database, this.path);
  final _Database database;
  final String path;
  @override
  bool get exists => database.rows.containsKey(path);
  @override
  Map<String, dynamic>? data() => database.rows[path];
  @override
  SnapshotMetadata get metadata => _Metadata(database.cached);
}

class _Metadata extends Fake implements SnapshotMetadata {
  _Metadata(this.cached);
  final bool cached;
  @override
  bool get isFromCache => cached;
  @override
  bool get hasPendingWrites => false;
}
