import 'dart:async';
import 'dart:io';

import 'package:crm3_baf_ops/core/utils/combined_record_stream.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'package:crm3_baf_ops/features/reports/providers/operations_report_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 8, 1);
  final end = DateTime.utc(2026, 9, 1);

  test(
    'native identity refreshes when an out-of-period issue arrives or changes',
    () async {
      final period = (
        actorUid: 'si-1',
        startInclusive: start,
        endExclusive: end,
      );
      final updates = StreamController<List<MaintenanceRecord>>(sync: true);
      final repository = _IdentityMaintenanceRepository();
      final container = ProviderContainer(
        overrides: [
          maintenanceRepositoryProvider.overrideWithValue(repository),
          operationsReportTicketsProvider(
            period,
          ).overrideWith((ref) => updates.stream),
        ],
      );
      final provider = operationsReportIdentitySourcesProvider((
        actorUid: 'si-1',
        period: period,
        executionIds: '[]',
        ticketIds: '["source-1"]',
      ));
      final subscription = container.listen(provider, (_, __) {});
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await updates.close();
      });
      updates.add(<MaintenanceRecord>[]);
      expect((await container.read(provider.future)).tickets, isEmpty);

      repository.records = [
        _ticket(DateTime.utc(2026, 7, 1))
          ..firestoreId = 'source-1'
          ..version = 2,
      ];
      // The report-period result stays empty, but its underlying uncapped
      // repository watch reports the native source's arrival.
      updates.add(<MaintenanceRecord>[]);
      await Future<void>.delayed(Duration.zero);
      expect((await container.read(provider.future)).tickets.single.version, 2);
      repository.records = [
        _ticket(DateTime.utc(2026, 7, 1))
          ..firestoreId = 'source-1'
          ..version = 3,
      ];
      updates.add(<MaintenanceRecord>[]);
      await Future<void>.delayed(Duration.zero);
      expect((await container.read(provider.future)).tickets.single.version, 3);
      repository.records = [
        _ticket(DateTime.utc(2026, 7, 1))
          ..firestoreId = 'source-1'
          ..version = 4,
      ];
      container.invalidate(operationsReportIdentitySourcesProvider);
      expect((await container.read(provider.future)).tickets.single.version, 4);
    },
  );

  test('report query bounds retain the persisted ISO string type', () {
    expect(
      plannedExecutionReportTimestampBound(start),
      '2026-08-01T00:00:00.000Z',
    );
    expect(
      plannedExecutionReportTimestampBound(end),
      '2026-09-01T00:00:00.000Z',
    );
    final offsetInstant = DateTime.parse('2026-08-01T00:00:00+05:30');
    expect(
      plannedExecutionReportTimestampBound(offsetInstant),
      '2026-07-31T18:30:00.000Z',
    );
  });

  test(
    'maintenance overlap includes carry-in and excludes boundary closure',
    () {
      final carryIn = _ticket(start.subtract(const Duration(days: 10)))
        ..endDate = start.add(const Duration(hours: 1));
      final endedAtStart = _ticket(start.subtract(const Duration(days: 10)))
        ..endDate = start;

      expect(maintenanceRecordOverlapsPeriod(carryIn, start, end), isTrue);
      expect(
        maintenanceRecordOverlapsPeriod(endedAtStart, start, end),
        isFalse,
      );
    },
  );

  test('execution overlap includes completed and cancelled carry-in work', () {
    final completed = _execution(start.subtract(const Duration(days: 5)))
      ..isCompleted = true
      ..completedAt = start.add(const Duration(hours: 2));
    final cancelled = _execution(start.subtract(const Duration(days: 5)))
      ..isCancelled = true
      ..cancelledAt = start.add(const Duration(hours: 3));
    final endedAtStart = _execution(start.subtract(const Duration(days: 5)))
      ..isCancelled = true
      ..cancelledAt = start;

    expect(jobExecutionOverlapsPeriod(completed, start, end), isTrue);
    expect(jobExecutionOverlapsPeriod(cancelled, start, end), isTrue);
    expect(jobExecutionOverlapsPeriod(endedAtStart, start, end), isFalse);
  });

  test(
    'combined report query windows deduplicate the same source record',
    () async {
      final older = _execution(start)..firestoreId = 'execution-1';
      final newer = _execution(start.add(const Duration(days: 1)))
        ..firestoreId = 'execution-2';

      final result = await combineLatestUniqueRecordStreams<JobExecution>(
        streams: [
          Stream.value([older, newer]),
          Stream.value([older]),
        ],
        identityOf: (record) => record.firestoreId!,
        compare: (left, right) => right.createdAt.compareTo(left.createdAt),
      ).first;

      expect(result.map((record) => record.firestoreId), [
        'execution-2',
        'execution-1',
      ]);
    },
  );

  test('report authority resolves before any business-data subscription', () {
    final source = File(
      'lib/features/reports/providers/operations_report_provider.dart',
    ).readAsStringSync();
    final providerStart = _sourceIndexOf(
      source,
      'final operationsReportProvider',
    );
    final actorRead = _sourceIndexOf(
      source,
      'ref.watch(currentAppUserProvider)',
      providerStart,
    );
    final authorityRejection = _sourceIndexOf(
      source,
      '!authorizedActor.canViewReports',
      actorRead,
    );
    final firstBusinessRead = _sourceIndexOf(
      source,
      'ref.watch(operationsReportTicketsProvider(periodScope))',
      authorityRejection,
    );

    expect(providerStart, greaterThanOrEqualTo(0));
    expect(actorRead, greaterThan(providerStart));
    expect(authorityRejection, greaterThan(actorRead));
    expect(firstBusinessRead, greaterThan(authorityRejection));
  });

  test('report graph is actor-scoped with an app-root cache lifecycle', () {
    final source = File(
      'lib/features/reports/providers/operations_report_provider.dart',
    ).readAsStringSync();
    final lifecycleSource = File(
      'lib/features/reports/providers/'
      'operations_report_authority_lifecycle.dart',
    ).readAsStringSync();
    final mainSource = File('lib/main.dart').readAsStringSync();
    final burnerSource = File(
      'lib/features/assets/providers/burner_condition_round_provider.dart',
    ).readAsStringSync();
    final burnerScreenSource = File(
      'lib/features/reports/presentation/burner_reliability_screen.dart',
    ).readAsStringSync();
    final qualitySource = File(
      'lib/features/quality/providers/quality_provider.dart',
    ).readAsStringSync();
    final criticalProviderSource = File(
      'lib/features/critical_alarm/providers/'
      'critical_alarm_providers.dart',
    ).readAsStringSync();
    final criticalRepositorySource = File(
      'lib/features/critical_alarm/data/critical_alarm_repository.dart',
    ).readAsStringSync();

    expect(
      source,
      _containsSource(
        'final operationsReportProvider = Provider.autoDispose.family'
        '<AsyncValue<OperationsReport>, OperationsReportScope>',
      ),
    );
    expect(source, _containsSource('authorizedActor.uid != scope.actorUid'));
    expect(
      source,
      _containsSource('operationalEventsForReportsProvider(scope.actorUid)'),
    );
    expect(
      _sourceIndexOf(source, 'ref.watch(operationsReportAuthorityLifecycleProvider)'),
      lessThan(_sourceIndexOf(source, 'ref.watch(currentAppUserProvider)')),
    );
    expect(
      lifecycleSource,
      _containsSource(
        'final operationsReportAuthorityLifecycleProvider = Provider<void>',
      ),
    );
    expect(
      mainSource,
      _containsSource('ref.watch(operationsReportAuthorityLifecycleProvider);'),
    );
    expect(
      burnerSource,
      _containsSource(
        'final burnerConditionRoundsProvider = StreamProvider.autoDispose.family',
      ),
    );
    expect(burnerSource, _containsSource('String actorUid'));
    expect(burnerSource, _containsSource('admitActorSessionSnapshots('));
    expect(burnerSource, _containsSource('includeMetadataChanges: true'));
    expect(burnerSource, _containsSource('snapshot.metadata.isFromCache'));
    expect(burnerSource, _containsSource('snapshot.metadata.hasPendingWrites'));
    expect(burnerScreenSource, _containsSource('actorUid: widget.actor.uid'));
    expect(burnerScreenSource, _containsSource('key: ValueKey(actor.uid)'));
    expect(
      source,
      _containsSource('qualityWarningsForReportsProvider(scope.actorUid)'),
    );
    expect(
      source,
      _containsSource('qualityMonitoringRequestsForReportsProvider(scope.actorUid)'),
    );
    expect(
      source,
      _containsSource('criticalAlarmsForReportsProvider(scope.actorUid)'),
    );
    for (final reportSource in [qualitySource, criticalRepositorySource]) {
      expect(reportSource, _containsSource('admitActorSessionSnapshots('));
      expect(reportSource, _containsSource('includeMetadataChanges: true'));
      expect(reportSource, _containsSource('snapshot.metadata.isFromCache'));
      expect(reportSource, _containsSource('snapshot.metadata.hasPendingWrites'));
    }
    expect(qualitySource, _containsSource('.family<List<QualityWarning>, String>'));
    expect(qualitySource, _containsSource('actor.uid != actorUid'));
    expect(
      criticalProviderSource,
      _containsSource('.family<List<CriticalAlarm>, String>'),
    );
    expect(criticalProviderSource, _containsSource('actor.uid != actorUid'));
    for (final provider in [
      'operationalEventsForReportsProvider',
      'operationsReportIdentitySourcesProvider',
      'qualityWarningsForReportsProvider',
      'qualityReportCacheTrustProvider',
      'workflowAllComplianceProvider',
      'assetClassesProvider',
      'burnerConditionRoundsProvider',
      'burnerConditionRoundCacheTrustProvider',
      'criticalAlarmsForReportsProvider',
      'criticalAlarmReportCacheTrustProvider',
      'operationsReportClockProvider',
    ]) {
      expect(lifecycleSource, _containsSource('ref.invalidate($provider)'));
    }
  });
}

String _compactSource(String source) => source.replaceAll(RegExp(r'\s+'), '');

Matcher _containsSource(String fragment) => predicate<String>(
  (source) => _compactSource(source).contains(_compactSource(fragment)),
  'contains Dart source "$fragment" regardless of formatting whitespace',
);

int _sourceIndexOf(String source, String fragment, [int start = 0]) =>
    start < 0 ? -1 : _compactSource(source).indexOf(_compactSource(fragment), start);

class _IdentityMaintenanceRepository implements MaintenanceRepository {
  List<MaintenanceRecord> records = [];

  @override
  Future<List<MaintenanceRecord>> getTicketsByFirestoreIds(
    List<String> ids,
  ) async =>
      records.where((record) => ids.contains(record.firestoreId)).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MaintenanceRecord _ticket(DateTime started) => MaintenanceRecord()
  ..assetType = AssetType.furnace
  ..assetNumber = 7
  ..maintenanceType = MaintenanceType.breakdown
  ..description = 'Fixture issue'
  ..routedTo = RoutedTo.mechanical
  ..status = TicketStatus.open
  ..isResolved = false
  ..startDate = started
  ..createdAt = started
  ..updatedAt = started
  ..actionsJson = '[]'
  ..resolutionHistoryJson = '[]';

JobExecution _execution(DateTime created) => JobExecution()
  ..templateFirestoreId = 'template-1'
  ..assetType = AssetType.furnace
  ..assetNumber = 7
  ..createdAt = created
  ..updatedAt = created
  ..isCompleted = false
  ..isCancelled = false;
