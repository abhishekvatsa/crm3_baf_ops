import 'dart:async';

import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/assets/providers/plant_asset_overview_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/critical_alarm/providers/critical_alarm_providers.dart';
import 'package:crm3_baf_ops/features/directives/providers/operational_directive_provider.dart';
import 'package:crm3_baf_ops/features/inspections/providers/inspection_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:crm3_baf_ops/features/operational_events/providers/operational_event_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/maintenance_intelligence_provider.dart';
import 'package:crm3_baf_ops/features/quality/data/quality_warning.dart';
import 'package:crm3_baf_ops/features/quality/providers/quality_provider.dart';
import 'package:crm3_baf_ops/features/reports/models/operations_report.dart';
import 'package:crm3_baf_ops/features/reports/providers/operations_report_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'scoped warning follows corrected abnormality identity without a warning update',
    () async {
      final h = _ReportHarness();
      addTearDown(h.dispose);
      await h.settle();
      expect(h.report.requireValue.qualityWarnings.single.warningId, 'warning');
      expect(h.report.requireValue.abnormalities, isEmpty);
      expect(h.warningEmissions, 1);

      h.repository.records = [_source(h.hoist)];
      h.repository.updates.add(h.repository.records);
      await h.settle();
      expect(h.report.requireValue.qualityWarnings, isEmpty);
      expect(h.warningEmissions, 1, reason: 'Only the native source changed.');
      expect(
        h.report.requireValue.abnormalities,
        isEmpty,
        reason: 'Historical identity rows must not enter the report period.',
      );
      expect(h.report.requireValue.sourceAbnormalityCount, 1);
    },
  );

  test(
    'source errors and disappearance cannot retain a cached scoped warning',
    () async {
      final h = _ReportHarness();
      addTearDown(h.dispose);
      await h.settle();
      expect(h.report.requireValue.qualityWarnings, hasLength(1));
      h.repository.updates.addError(StateError('Native source read failed'));
      await h.settle();
      expect(h.report.hasError, true);
      expect(h.report.error.toString(), contains('Native source read failed'));
      h.repository.updates.add([_source(h.hoist)]);
      await h.settle();
      expect(h.report.requireValue.qualityWarnings, isEmpty);
      h.repository.updates.add([]);
      await h.settle();
      expect(h.report.hasError, true);
      expect(h.report.error.toString(), contains('no verifiable'));
    },
  );

  test(
    'scoped report waits for native identity instead of displaying its cached read',
    () async {
      final h = _ReportHarness(holdSource: true);
      addTearDown(h.dispose);
      await h.settle();
      expect(h.report.isLoading, true);
      h.repository.releaseInitial();
      await h.settle();
      expect(h.report.requireValue.qualityWarnings, hasLength(1));
    },
  );

  test(
    'account switch rejects the old report scope and obtains a fresh identity watch',
    () async {
      final h = _ReportHarness();
      addTearDown(h.dispose);
      await h.settle();
      expect(h.report.requireValue.qualityWarnings, hasLength(1));
      final previousWatches = h.repository.watchCalls;
      h.repository.records = [_source(h.hoist)];
      h.actors.add(_actor('actor-b'));
      await h.settle();
      expect(h.report.hasError, true);
      expect(h.report.error.toString(), contains('Approved report access'));
      final other = operationsReportProvider((
        actorUid: 'actor-b',
        filter: h.filter,
      ));
      final subscription = h.container.listen(other, (_, __) {});
      addTearDown(subscription.close);
      await h.settle();
      expect(h.container.read(other).requireValue.qualityWarnings, isEmpty);
      expect(h.repository.watchCalls, greaterThan(previousWatches));
    },
  );

  test(
    'warning with its own governed identity needs no native source subscription',
    () async {
      final h = _ReportHarness(ownIdentity: true, holdSource: true);
      addTearDown(h.dispose);
      await h.settle();
      expect(h.report.requireValue.qualityWarnings, hasLength(1));
      expect(h.repository.watchCalls, 0);
    },
  );

  test(
    'warning outside the report period needs no native source subscription',
    () async {
      final h = _ReportHarness(outOfPeriod: true, holdSource: true);
      addTearDown(h.dispose);
      await h.settle();
      expect(h.report.requireValue.qualityWarnings, isEmpty);
      expect(h.repository.watchCalls, 0);
    },
  );
  for (final customFirst in [false, true]) {
    test('mixed warning already matching its own asset needs no source watch '
        '(custom first: $customFirst)', () async {
      final h = _ReportHarness(
        holdSource: true,
        mixedIdentity: true,
        customFirst: customFirst,
      );
      addTearDown(h.dispose);
      await h.settle();
      expect(h.report.requireValue.qualityWarnings, hasLength(1));
      expect(h.repository.watchCalls, 0);
    });
  }
}

class _ReportHarness {
  _ReportHarness({
    bool holdSource = false,
    bool ownIdentity = false,
    bool outOfPeriod = false,
    bool mixedIdentity = false,
    bool customFirst = false,
  }) {
    final classes = [
      _assetClass(
        mixedIdentity ? 'furnace' : 'crane',
        legacy: mixedIdentity ? 'furnace' : null,
      ),
      _assetClass('hoist'),
    ];
    crane = _asset(classes.first);
    hoist = _asset(classes.last);
    final assets = [crane, hoist];
    repository = _IdentityAbnormalityRepository([_source(crane)], holdSource);
    final warning = QualityWarning(
      warningId: 'warning',
      sourceType: QualityWarningSourceType.abnormality,
      sourceId: 'historical-source',
      sourceVersion: 1,
      sourceChargeNo: 41001,
      sourceSummary: 'Temperature deviation',
      sourceSeverity: 'high',
      warningReason: 'Inspect coils',
      affectedAssets: [
        if (mixedIdentity && !customFirst)
          const QualityAffectedAsset(assetType: 'furnace', assetNumber: 4),
        QualityAffectedAsset(
          assetType: 'governedCustom',
          assetNumber: 4,
          assetHierarchyReference: ownIdentity ? _reference(crane) : null,
        ),
        if (mixedIdentity && customFirst)
          const QualityAffectedAsset(assetType: 'furnace', assetNumber: 4),
      ],
      status: outOfPeriod
          ? QualityWarningStatus.closed
          : QualityWarningStatus.open,
      createdAt: DateTime.utc(2026, outOfPeriod ? 7 : 8, 6),
      closedAt: outOfPeriod ? DateTime.utc(2026, 7, 7) : null,
      createdByUid: 'ops',
      updatedAt: DateTime.utc(2026, 8, 6),
      updatedByUid: 'ops',
      version: 1,
    );
    filter = OperationsReportFilter(
      startDate: DateTime.utc(2026, 8, 1),
      endDate: DateTime.utc(2026, 8, 31),
      assetInstanceId: crane.id,
    );
    provider = operationsReportProvider((actorUid: 'actor-a', filter: filter));
    container = ProviderContainer(
      overrides: [
        currentAppUserProvider.overrideWith((ref) async* {
          yield _actor('actor-a');
          yield* actors.stream;
        }),
        abnormalityRepositoryProvider.overrideWithValue(repository),
        operationsReportTicketsProvider.overrideWith(
          (ref, scope) => Stream.value([]),
        ),
        operationsReportExecutionsProvider.overrideWith(
          (ref, scope) => Stream.value([]),
        ),
        operationalEventsForReportsProvider.overrideWith(
          (ref, uid) => Stream.value([]),
        ),
        maintenanceDueStatesProvider.overrideWith((ref) => Stream.value([])),
        allInspectionFindingsProvider.overrideWith((ref) => Stream.value([])),
        qualityWarningsForReportsProvider.overrideWith((ref, uid) async* {
          warningEmissions++;
          yield [warning];
        }),
        qualityMonitoringRequestsForReportsProvider.overrideWith(
          (ref, uid) => Stream.value([]),
        ),
        openDirectivesProvider.overrideWith((ref) => Stream.value([])),
        workflowAllLanesProvider.overrideWith((ref) => Stream.value([])),
        workflowAllComplianceProvider.overrideWith((ref) => Stream.value([])),
        criticalAlarmsForReportsProvider.overrideWith(
          (ref, uid) => Stream.value([]),
        ),
        assetClassesProvider.overrideWith((ref) => Stream.value(classes)),
        allAssetInstancesProvider.overrideWith((ref) => Stream.value(assets)),
        innerCoverProfilesProvider.overrideWith((ref) => Stream.value([])),
        plantAssetOverviewProvider.overrideWith(
          (ref) => AsyncData(
            PlantAssetOverview.build(
              assetClasses: classes,
              assetInstances: assets,
              operationalConditions: [],
              workflowStatuses: [],
            ),
          ),
        ),
        operationsReportClockProvider.overrideWith(
          (ref) => Stream.value(DateTime.utc(2026, 9, 1)),
        ),
      ],
    );
    subscription = container.listen(provider, (_, __) {});
  }

  final actors = StreamController<AppUser?>.broadcast();
  late final AssetInstanceRecord crane;
  late final AssetInstanceRecord hoist;
  late final _IdentityAbnormalityRepository repository;
  late final OperationsReportFilter filter;
  late final ProviderContainer container;
  late final ProviderListenable<AsyncValue<OperationsReport>> provider;
  late final ProviderSubscription<AsyncValue<OperationsReport>> subscription;
  int warningEmissions = 0;
  AsyncValue<OperationsReport> get report => container.read(provider);
  Future<void> settle() async {
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> dispose() async {
    subscription.close();
    container.dispose();
    repository.releaseInitial();
    await actors.close();
    await repository.updates.close();
  }
}

class _IdentityAbnormalityRepository extends Fake
    implements AbnormalityRepository {
  _IdentityAbnormalityRepository(this.records, bool hold) {
    if (!hold) releaseInitial();
  }
  List<ChargeAbnormality> records;
  final updates = StreamController<List<ChargeAbnormality>>.broadcast();
  final _initial = Completer<void>();
  int watchCalls = 0;
  void releaseInitial() {
    if (!_initial.isCompleted) _initial.complete();
  }

  @override
  Future<List<ChargeAbnormality>> getAllAbnormalities() async =>
      records.toList();
  @override
  Stream<List<ChargeAbnormality>> watchAbnormalitiesForCharge(
    int sourceChargeNo,
  ) async* {
    watchCalls++;
    expect(sourceChargeNo, 41001);
    await _initial.future;
    yield records;
    yield* updates.stream;
  }
}

AppUser _actor(String uid) => AppUser(
  uid: uid,
  name: uid,
  email: '$uid@example.invalid',
  roles: [AppRole.admin],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);
AssetClassRecord _assetClass(String id, {String? legacy}) => AssetClassRecord(
  id: id,
  code: id.toUpperCase(),
  name: id,
  majorArea: 'BAF',
  legacyAssetTypeKey: legacy,
  status: AssetHierarchyStatus.active,
  version: 1,
  createdAt: DateTime.utc(2026),
  createdByUid: 'admin',
  updatedAt: DateTime.utc(2026),
  updatedByUid: 'admin',
  lastMutationId: 'fixture',
);
AssetInstanceRecord _asset(AssetClassRecord type) => AssetInstanceRecord(
  id: '${type.id}-4',
  assetClassId: type.id,
  assetClassCode: type.code,
  assetClassName: type.name,
  assetNumber: 4,
  name: '${type.name} 4',
  serviceState: AssetServiceState.inService,
  ownershipStatus: AssetOwnershipStatus.confirmed,
  status: AssetHierarchyStatus.active,
  activeComponentCount: 0,
  version: 1,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  lastMutationId: 'fixture',
);
AssetHierarchyReference _reference(AssetInstanceRecord item) =>
    AssetHierarchyReference(
      scope: AssetHierarchyReferenceScope.physicalAsset,
      assetClassId: item.assetClassId,
      assetClassCode: item.assetClassCode,
      assetClassName: item.assetClassName,
      nodeId: item.assetClassId,
      nodeVersion: 1,
      nodeName: item.assetClassName,
      assetInstanceId: item.id,
      assetInstanceVersion: item.version,
      assetNumber: item.assetNumber,
      assetInstanceName: item.name,
      hierarchyPath: [item.assetClassName],
      ownershipStatus: AssetOwnershipStatus.unassigned,
    );
ChargeAbnormality _source(AssetInstanceRecord item) => ChargeAbnormality()
  ..firestoreId = 'historical-source'
  ..sourceChargeNo = 41001
  ..abnormalityTypeId = 'temperature'
  ..abnormalityTypeTitle = 'Temperature deviation'
  ..abnormalityTypeCode = 'TEMP'
  ..observedReason = 'Review coils'
  ..loggedAt = DateTime.utc(2026, 7, 1)
  ..updatedAt = DateTime.utc(2026, 9, 1)
  ..affectedAssets = [
    AffectedAssetRef.fromMap({
      'assetType': 'governedCustom',
      'assetNumber': 4,
      'assetHierarchyRef': _reference(item).toMap(),
    }),
  ];
