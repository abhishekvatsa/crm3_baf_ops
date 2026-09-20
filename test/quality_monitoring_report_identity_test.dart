import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/quality/data/quality_warning.dart';
import 'package:crm3_baf_ops/features/reports/models/operations_report.dart';
import 'package:crm3_baf_ops/features/reports/providers/operations_report_provider.dart';

Map<String, dynamic> _produced() => Map<String, dynamic>.from(
  jsonDecode(
        File(
          'functions/test/fixtures/quality_monitoring_governed_producer.json',
        ).readAsStringSync(),
      )
      as Map,
);
QualityMonitoringRequest _request([Map<String, dynamic>? override]) {
  final data = {..._produced(), ...?override};
  return QualityMonitoringRequest.fromMap(data, data['requestId'] as String);
}

AssetClassRecord _class(String id, {bool retired = false}) => AssetClassRecord(
  id: id,
  code: 'BASE',
  name: retired ? 'Historical Bases' : 'Current Bases',
  majorArea: 'BAF',
  legacyAssetTypeKey: 'base',
  status: retired ? AssetHierarchyStatus.retired : AssetHierarchyStatus.active,
  version: 1,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  createdByUid: 'admin',
  updatedByUid: 'admin',
  lastMutationId: 'class-setup',
);
AssetInstanceRecord _asset(
  String id,
  String classId, {
  int number = 12,
  int version = 4,
  bool retired = false,
}) => AssetInstanceRecord(
  id: id,
  assetClassId: classId,
  assetClassCode: 'BASE',
  assetClassName: 'Base',
  assetNumber: number,
  name: 'Base $number',
  serviceState: AssetServiceState.inService,
  ownershipStatus: AssetOwnershipStatus.confirmed,
  status: retired ? AssetHierarchyStatus.retired : AssetHierarchyStatus.active,
  activeComponentCount: 0,
  version: version,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026, 9),
  lastMutationId: 'asset-setup',
);
OperationsReport _report({
  String? selectedClass,
  String? selectedAsset,
  List<AssetClassRecord>? classes,
  List<AssetInstanceRecord>? assets,
  QualityMonitoringRequest? request,
}) => buildOperationsReport(
  filter: OperationsReportFilter(
    startDate: DateTime(2026, 8, 1),
    endDate: DateTime(2026, 8, 31),
    assetClassId: selectedClass,
    assetInstanceId: selectedAsset,
  ),
  tickets: const [],
  executions: const [],
  events: const [],
  qualityMonitoringRequests: [request ?? _request()],
  assetClasses:
      classes ??
      [_class('base-class', retired: true), _class('replacement-base-class')],
  assetInstances:
      assets ??
      [
        _asset('base-12', 'base-class', retired: true),
        _asset('new-base-12', 'replacement-base-class'),
      ],
  overview: const PlantAssetOverview(classes: [], assets: []),
);
void main() {
  test(
    'actual backend record survives Dart decode and retired canonical Base selection',
    () {
      final report = _report(
        selectedClass: 'base-class',
        selectedAsset: 'base-12',
      );
      expect(
        report.qualityMonitoringRequests.single.requestId,
        _request().requestId,
      );
      expect(report.activeQualityMonitoringCount, 1);
    },
  );
  test(
    'class-only and unfiltered reports preserve modern identity despite duplicate legacy class roles',
    () {
      expect(
        _report(selectedClass: 'base-class').qualityMonitoringRequests,
        hasLength(1),
      );
      expect(_report().qualityMonitoringRequests, hasLength(1));
      expect(
        _report(
          selectedClass: 'replacement-base-class',
        ).qualityMonitoringRequests,
        isEmpty,
      );
      expect(
        _report(selectedAsset: 'new-base-12').qualityMonitoringRequests,
        isEmpty,
      );
    },
  );
  test(
    'later number/name/version changes do not rewrite historical physical identity',
    () {
      final report = _report(
        selectedAsset: 'base-12',
        assets: [
          _asset(
            'base-12',
            'base-class',
            number: 112,
            version: 5,
            retired: true,
          ),
        ],
      );
      expect(report.qualityMonitoringRequests.single.baseNumber, 12);
      expect(
        report.qualityMonitoringRequests.single.baseAssetInstanceId,
        'base-12',
      );
    },
  );
  test(
    'contradictory canonical class and missing instance cannot fall back to number',
    () {
      expect(
        () => _report(
          request: _request({'baseAssetClassId': 'replacement-base-class'}),
        ),
        throwsStateError,
      );
      expect(
        () =>
            _report(request: _request({'baseAssetInstanceId': 'missing-base'})),
        throwsStateError,
      );
    },
  );
  test(
    'same-version number contradiction and older registry view are not authoritative',
    () {
      expect(
        () => _report(assets: [_asset('base-12', 'base-class', number: 99)]),
        throwsStateError,
      );
      expect(
        () => _report(assets: [_asset('base-12', 'base-class', version: 3)]),
        throwsStateError,
      );
    },
  );
  test(
    'genuinely legacy number-only rows retain unambiguous compatibility',
    () {
      final data = _produced()
        ..['schemaVersion'] = 2
        ..remove('baseAssetClassId')
        ..remove('baseAssetInstanceId')
        ..remove('baseAssetInstanceVersion');
      final legacy = QualityMonitoringRequest.fromMap(
        data,
        data['requestId'] as String,
      );
      expect(
        _report(
          selectedAsset: 'base-12',
          request: legacy,
          classes: [_class('base-class')],
          assets: [_asset('base-12', 'base-class')],
        ).qualityMonitoringRequests,
        hasLength(1),
      );
      expect(
        _report(
          selectedAsset: 'new-base-12',
          request: legacy,
        ).qualityMonitoringRequests,
        isEmpty,
      );
    },
  );
  test(
    'the persisted reader refuses partial modern identity before report filtering',
    () {
      final data = _produced()..remove('baseAssetInstanceVersion');
      expect(
        () =>
            QualityMonitoringRequest.fromMap(data, data['requestId'] as String),
        throwsFormatException,
      );
    },
  );
}
