import 'dart:async';

import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/quality/data/quality_warning.dart';
import 'package:crm3_baf_ops/features/quality/domain/issue_quality_intent.dart';
import 'package:crm3_baf_ops/features/quality/domain/quality_warning_projection.dart';
import 'package:crm3_baf_ops/features/quality/presentation/quality_home_screen.dart';
import 'package:crm3_baf_ops/features/quality/providers/quality_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('quality warning projections', () {
    test('suspected issue produces a deterministic warning projection', () {
      final createdAt = DateTime.utc(2026, 8, 14, 8);
      final ticket =
          MaintenanceRecord()
            ..firestoreId = 'ticket-1'
            ..assetType = AssetType.furnace
            ..assetNumber = 7
            ..assetHierarchyRefJson = _qualityHierarchyReference.encode()
            ..description = 'Atmosphere interruption during cycle'
            ..component = 'Atmosphere control'
            ..chargeNoAtEvent = 12001
            ..loggedByUid = 'ops-1'
            ..loggedByName = 'Operations One'
            ..createdAt = createdAt
            ..version = 3
            ..isCritical = true
            ..qualityIntent = const IssueQualityIntent(
              assessment: IssueQualityAssessment.suspected,
              warningReason: 'Atmosphere interruption may affect coil quality.',
              abnormalityTypeId: 'ATMOSPHERE_DEVIATION',
            );

      expect(qualityWarningProjectionForIssue(ticket), <String, dynamic>{
        'schemaVersion': 1,
        'warningId': 'issue_ticket-1',
        'sourceType': 'issue',
        'sourceId': 'ticket-1',
        'sourceVersion': 3,
        'sourceChargeNo': 12001,
        'sourceSummary': 'Atmosphere interruption during cycle',
        'sourceSeverity': 'critical',
        'warningReason': 'Atmosphere interruption may affect coil quality.',
        'affectedAssets': <Map<String, dynamic>>[
          <String, dynamic>{
            'assetType': 'furnace',
            'assetNumber': 7,
            'assetHierarchyRef': _qualityHierarchyReference.toMap(),
          },
        ],
        'component': 'Atmosphere control',
        'status': 'open',
        'closureRequestReason': null,
        'closureRequestedAt': null,
        'closureRequestedByUid': null,
        'closureRequestedByName': null,
        'closedAt': null,
        'closedByUid': null,
        'closedByName': null,
        'closureDisposition': null,
        'linkedReannealingChargeNos': <int>[],
        'decisionReason': null,
        'createdAt': createdAt.toIso8601String(),
        'createdByUid': 'ops-1',
        'createdByName': 'Operations One',
        'updatedAt': createdAt.toIso8601String(),
        'updatedByUid': 'ops-1',
        'updatedByName': 'Operations One',
        'version': 1,
      });
    });

    test('issue without suspected impact does not create a warning', () {
      final ticket =
          MaintenanceRecord()
            ..firestoreId = 'ticket-2'
            ..qualityIntent = const IssueQualityIntent(
              assessment: IssueQualityAssessment.notSuspected,
            );

      expect(qualityWarningProjectionForIssue(ticket), isNull);
    });

    test('every abnormality produces a source-bound warning', () {
      final loggedAt = DateTime.utc(2026, 8, 14, 9);
      final abnormality =
          ChargeAbnormality()
            ..firestoreId = 'abn-1'
            ..sourceChargeNo = 12002
            ..abnormalityTypeTitle = 'Unexpected coil colour'
            ..severity = AbnormalitySeverity.high
            ..affectedAssets = <AffectedAssetRef>[
              const AffectedAssetRef(
                assetType: AssetType.furnace,
                assetNumber: 7,
                assetHierarchyReference: _qualityHierarchyReference,
              ),
            ]
            ..component = 'Cooling circuit'
            ..observedReason = 'Observed colour requires quality review.'
            ..loggedAt = loggedAt
            ..loggedByUid = 'ops-1'
            ..loggedByName = 'Operations One'
            ..version = 2;

      expect(
        qualityWarningProjectionForAbnormality(abnormality),
        containsPair('warningId', 'abnormality_abn-1'),
      );
      expect(
        qualityWarningProjectionForAbnormality(abnormality),
        containsPair(
          'warningReason',
          'Observed colour requires quality review.',
        ),
      );
      final projection = qualityWarningProjectionForAbnormality(abnormality);
      expect(projection['affectedAssets'], <Map<String, dynamic>>[
        <String, dynamic>{'assetType': 'furnace', 'assetNumber': 7},
      ]);
      final warning = QualityWarning.fromMap(projection, 'abnormality_abn-1');
      expect(warning.affectedAssets.single.componentLabel, isNull);
    });
  });

  group('quality warning strict reader', () {
    test('accepts a complete open warning', () {
      final warning = QualityWarning.fromMap(_warning(), 'issue_ticket-1');

      expect(warning.status, QualityWarningStatus.open);
      expect(warning.sourceChargeNo, 12001);
    });

    test('accepts a historical warning with no affected asset', () {
      final warning = QualityWarning.fromMap(
        _warning()..['affectedAssets'] = <Map<String, dynamic>>[],
        'issue_ticket-1',
      );

      expect(warning.affectedAssets, isEmpty);
    });

    test('rejects an explicitly null governed hierarchy reference', () {
      expect(
        () => QualityWarning.fromMap(
          _warning()
            ..['affectedAssets'] = <Map<String, dynamic>>[
              <String, dynamic>{
                'assetType': 'furnace',
                'assetNumber': 7,
                'assetHierarchyRef': null,
              },
            ],
          'issue_ticket-1',
        ),
        throwsFormatException,
      );
    });

    test('rejects unsupported schema and partial closure request evidence', () {
      expect(
        () => QualityWarning.fromMap(
          _warning()..['schemaVersion'] = 2,
          'issue_ticket-1',
        ),
        throwsFormatException,
      );
      expect(
        () => QualityWarning.fromMap(
          _warning()
            ..['status'] = 'closureRequested'
            ..['closureRequestReason'] =
                'Coils checked and found satisfactory.',
          'issue_ticket-1',
        ),
        throwsFormatException,
      );
    });

    test('rejects a warning whose deterministic source identity differs', () {
      expect(
        () => QualityWarning.fromMap(
          _warning()..['sourceId'] = 'different-ticket',
          'issue_ticket-1',
        ),
        throwsFormatException,
      );
    });

    test('rejects RA references for a non-RA disposition', () {
      final warning =
          _warning()
            ..['status'] = 'closed'
            ..['closedAt'] = DateTime.utc(2026, 8, 14, 12)
            ..['closedByUid'] = 'si-1'
            ..['closedByName'] = 'SI One'
            ..['closureDisposition'] = 'coilFoundAcceptable'
            ..['linkedReannealingChargeNos'] = <int>[13001]
            ..['decisionReason'] =
                'Inspection evidence found the coil acceptable.';

      expect(
        () => QualityWarning.fromMap(warning, 'issue_ticket-1'),
        throwsFormatException,
      );
    });

    test('rejects malformed RA charges and reversed lifecycle time', () {
      final malformedCharge =
          _warning()
            ..['status'] = 'closed'
            ..['closedAt'] = DateTime.utc(2026, 8, 14, 12)
            ..['closedByUid'] = 'si-1'
            ..['closedByName'] = 'SI One'
            ..['closureDisposition'] = 'reannealingCompleted'
            ..['linkedReannealingChargeNos'] = <int>[123]
            ..['decisionReason'] = 'Re-annealing was completed.'
            ..['updatedAt'] = DateTime.utc(2026, 8, 14, 12);
      expect(
        () => QualityWarning.fromMap(malformedCharge, 'issue_ticket-1'),
        throwsFormatException,
      );

      final reversedClosure =
          _warning()
            ..['status'] = 'closed'
            ..['closureRequestReason'] = 'Operations requested review.'
            ..['closureRequestedAt'] = DateTime.utc(2026, 8, 14, 11)
            ..['closureRequestedByUid'] = 'ops-1'
            ..['closureRequestedByName'] = 'Operations One'
            ..['closedAt'] = DateTime.utc(2026, 8, 14, 10)
            ..['closedByUid'] = 'si-1'
            ..['closedByName'] = 'SI One'
            ..['closureDisposition'] = 'qualityAdjudication'
            ..['decisionReason'] = 'The coils were adjudicated.'
            ..['updatedAt'] = DateTime.utc(2026, 8, 14, 12);
      expect(
        () => QualityWarning.fromMap(reversedClosure, 'issue_ticket-1'),
        throwsFormatException,
      );
    });

    test('non-closed window preserves old warnings and removes duplicates', () {
      final open = QualityWarning.fromMap(_warning(), 'issue_ticket-1');
      final reviewMap =
          _warning()
            ..['warningId'] = 'issue_ticket-2'
            ..['sourceId'] = 'ticket-2'
            ..['status'] = 'closureRequested'
            ..['closureRequestReason'] =
                'Coils were inspected and found satisfactory.'
            ..['closureRequestedAt'] = DateTime.utc(2026, 8, 14, 11)
            ..['closureRequestedByUid'] = 'operations-1'
            ..['closureRequestedByName'] = 'Operations One'
            ..['updatedAt'] = DateTime.utc(2026, 8, 14, 11)
            ..['updatedByUid'] = 'operations-1'
            ..['updatedByName'] = 'Operations One';
      final review = QualityWarning.fromMap(reviewMap, 'issue_ticket-2');
      final merged = mergeQualityWarningWindows([open, review], [open]);
      expect(merged.map((warning) => warning.warningId), [
        'issue_ticket-2',
        'issue_ticket-1',
      ]);
    });
  });

  group('quality monitoring strict reader', () {
    test('derives exact legacy visibility without accepting partial shape', () {
      final active = QualityMonitoringRequest.fromMap(
        _legacyMonitoring(),
        'monitoring-1',
      );
      final closedAt = DateTime.utc(2026, 8, 14, 10);
      final closed = QualityMonitoringRequest.fromMap(
        _legacyMonitoring()
          ..['status'] = 'closed'
          ..['closedAt'] = closedAt
          ..['closedByUid'] = 'si-2'
          ..['closedByName'] = 'SI Two'
          ..['closeReason'] = 'Legacy monitoring evidence was reviewed.'
          ..['updatedAt'] = closedAt
          ..['updatedByUid'] = 'si-2'
          ..['updatedByName'] = 'SI Two'
          ..['version'] = 2,
        'monitoring-1',
      );

      expect(active.visibilityState, QualityMonitoringVisibilityState.active);
      expect(active.visibleUntil, isNull);
      expect(closed.visibilityState, QualityMonitoringVisibilityState.recent);
      expect(closed.visibleUntil, closedAt.add(const Duration(days: 7)));
      expect(
        () => QualityMonitoringRequest.fromMap(
          _legacyMonitoring()..['visibilityState'] = 'active',
          'monitoring-1',
        ),
        throwsFormatException,
      );
    });

    test('rejects duplicate charge numbers', () {
      final monitoring = _monitoring()..['chargeNumbers'] = <int>[12001, 12001];

      expect(
        () => QualityMonitoringRequest.fromMap(monitoring, 'monitoring-1'),
        throwsFormatException,
      );
    });

    test('rejects malformed charge numbers and reversed lifecycle time', () {
      expect(
        () => QualityMonitoringRequest.fromMap(
          _monitoring()..['chargeNumbers'] = <int>[123],
          'monitoring-1',
        ),
        throwsFormatException,
      );
      expect(
        () => QualityMonitoringRequest.fromMap(
          _monitoring()..['updatedAt'] = DateTime.utc(2026, 8, 14, 7, 59, 59),
          'monitoring-1',
        ),
        throwsFormatException,
      );
    });

    test('rejects closed status without complete closure evidence', () {
      final monitoring = _monitoring()..['status'] = 'closed';

      expect(
        () => QualityMonitoringRequest.fromMap(monitoring, 'monitoring-1'),
        throwsFormatException,
      );
    });

    test('operational ordering retains more than 250 server-visible rows', () {
      final requests = List<QualityMonitoringRequest>.generate(300, (index) {
        final id = 'monitoring-$index';
        return QualityMonitoringRequest.fromMap(
          _monitoring()
            ..['requestId'] = id
            ..['createdAt'] = DateTime.utc(2026, 8, 15, 0, index)
            ..['updatedAt'] = DateTime.utc(2026, 8, 15, 0, index),
          id,
        );
      });

      expect(sortQualityMonitoringRequests(requests), hasLength(300));
    });

    test('server-governed recent and archived states are strict', () {
      final closedAt = DateTime.utc(2026, 8, 14, 8);
      final recent = QualityMonitoringRequest.fromMap(
        _monitoring()
          ..['status'] = 'closed'
          ..['visibilityState'] = 'recent'
          ..['visibleUntil'] = closedAt.add(const Duration(days: 7))
          ..['closedAt'] = closedAt
          ..['closedByUid'] = 'si-2'
          ..['closedByName'] = 'SI Two'
          ..['closeReason'] = 'The monitored campaign is complete.'
          ..['updatedAt'] = closedAt
          ..['updatedByUid'] = 'si-2'
          ..['updatedByName'] = 'SI Two'
          ..['version'] = 2,
        'monitoring-1',
      );
      final archived = QualityMonitoringRequest.fromMap(
        _monitoring()
          ..['requestId'] = 'monitoring-archived'
          ..['status'] = 'closed'
          ..['visibilityState'] = 'archived'
          ..['visibleUntil'] = null
          ..['archivedAt'] = closedAt.add(const Duration(days: 7))
          ..['closedAt'] = closedAt
          ..['closedByUid'] = 'si-2'
          ..['closedByName'] = 'SI Two'
          ..['closeReason'] = 'The monitored campaign is complete.'
          ..['updatedAt'] = closedAt
          ..['updatedByUid'] = 'si-2'
          ..['updatedByName'] = 'SI Two'
          ..['version'] = 2,
        'monitoring-archived',
      );

      expect(recent.visibilityState, QualityMonitoringVisibilityState.recent);
      expect(
        archived.visibilityState,
        QualityMonitoringVisibilityState.archived,
      );
      expect(
        () => QualityMonitoringRequest.fromMap(
          _monitoring()
            ..['status'] = 'closed'
            ..['visibilityState'] = 'recent'
            ..['visibleUntil'] = closedAt.add(
              const Duration(days: 6, hours: 23),
            )
            ..['closedAt'] = closedAt
            ..['closedByUid'] = 'si-2'
            ..['closedByName'] = 'SI Two'
            ..['closeReason'] = 'The monitored campaign is complete.',
          'monitoring-1',
        ),
        throwsFormatException,
      );
    });

    test(
      'operational windows include legacy rows and remove expired closure',
      () {
        final now = DateTime.utc(2026, 8, 22, 12);
        final active = QualityMonitoringRequest.fromMap(
          _legacyMonitoring(),
          'monitoring-1',
        );
        const expiredId = 'monitoring-expired';
        final expiredClosedAt = DateTime.utc(2026, 8, 14, 8);
        final expired = QualityMonitoringRequest.fromMap(
          _legacyMonitoring()
            ..['requestId'] = expiredId
            ..['status'] = 'closed'
            ..['closedAt'] = expiredClosedAt
            ..['closedByUid'] = 'si-2'
            ..['closedByName'] = 'SI Two'
            ..['closeReason'] = 'Legacy campaign is complete.'
            ..['updatedAt'] = expiredClosedAt
            ..['updatedByUid'] = 'si-2'
            ..['updatedByName'] = 'SI Two'
            ..['version'] = 2,
          expiredId,
        );

        final merged = mergeQualityMonitoringWindows(
          [active],
          [active, expired],
          now: now,
        );

        expect(merged.map((request) => request.requestId), ['monitoring-1']);
      },
    );

    test(
      'operational stream expires legacy closure without a new snapshot',
      () async {
        const requestId = 'monitoring-expiring';
        final closedAt = DateTime.now().toUtc().subtract(
          const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
        );
        final legacyClosed = QualityMonitoringRequest.fromMap(
          _legacyMonitoring()
            ..['requestId'] = requestId
            ..['status'] = 'closed'
            ..['closedAt'] = closedAt
            ..['closedByUid'] = 'si-2'
            ..['closedByName'] = 'SI Two'
            ..['closeReason'] = 'Legacy campaign is complete.'
            ..['updatedAt'] = closedAt
            ..['updatedByUid'] = 'si-2'
            ..['updatedByName'] = 'SI Two'
            ..['version'] = 2,
          requestId,
        );
        final current = StreamController<List<QualityMonitoringRequest>>();
        final legacy = StreamController<List<QualityMonitoringRequest>>();
        final observed = <List<QualityMonitoringRequest>>[];
        final expired = Completer<void>();
        final subscription = combineQualityMonitoringWindows(
          current.stream,
          legacy.stream,
        ).listen((requests) {
          observed.add(requests);
          if (observed.length >= 2 &&
              requests.isEmpty &&
              !expired.isCompleted) {
            expired.complete();
          }
        });
        addTearDown(() async {
          await subscription.cancel();
          await current.close();
          await legacy.close();
        });

        current.add(const <QualityMonitoringRequest>[]);
        legacy.add([legacyClosed]);
        await expired.future.timeout(const Duration(seconds: 3));

        expect(observed.first.map((request) => request.requestId), [requestId]);
        expect(observed.last, isEmpty);
      },
    );
  });

  testWidgets(
    'quality tabs expose separate live counts and open warnings first',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final review = QualityWarning.fromMap(
        _warning()
          ..['status'] = 'closureRequested'
          ..['closureRequestReason'] =
              'Operations found the affected material satisfactory.'
          ..['closureRequestedAt'] = DateTime.utc(2026, 8, 14, 11)
          ..['closureRequestedByUid'] = 'operations-1'
          ..['closureRequestedByName'] = 'Operations One'
          ..['updatedAt'] = DateTime.utc(2026, 8, 14, 11)
          ..['updatedByUid'] = 'operations-1'
          ..['updatedByName'] = 'Operations One',
        'issue_ticket-1',
      );
      final active = QualityMonitoringRequest.fromMap(
        _monitoring(),
        'monitoring-1',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream.value(_qualityViewer()),
            ),
            qualityWarningsProvider.overrideWith(
              (ref) => Stream.value(<QualityWarning>[review]),
            ),
            qualityMonitoringRequestsProvider.overrideWith(
              (ref) => Stream.value(<QualityMonitoringRequest>[active]),
            ),
          ],
          child: MaterialApp(
            theme: BafAppTheme.light,
            home: const QualityHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Warnings (1)'), findsOneWidget);
      expect(find.text('Monitoring (1)'), findsOneWidget);
      expect(find.text('No warnings in this view'), findsOneWidget);

      await tester.tap(find.text('Monitoring (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Base 12 · CRGO M4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('monitoring routes open directly on active cycle surveillance', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final active = QualityMonitoringRequest.fromMap(
      _monitoring(),
      'monitoring-1',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream.value(_qualityViewer()),
          ),
          qualityWarningsProvider.overrideWith(
            (ref) => Stream.value(const <QualityWarning>[]),
          ),
          qualityMonitoringRequestsProvider.overrideWith(
            (ref) => Stream.value(<QualityMonitoringRequest>[active]),
          ),
        ],
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: const QualityHomeScreen.monitoring(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Warnings (0)'), findsOneWidget);
    expect(find.text('Monitoring (1)'), findsOneWidget);
    expect(find.text('Base 12 · CRGO M4'), findsOneWidget);
    expect(find.text('No warnings in this view'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closed monitoring cards show accountable closure evidence', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final closedAt = DateTime.utc(2026, 8, 15, 9, 30);
    final closed = QualityMonitoringRequest.fromMap(
      _monitoring()
        ..['status'] = 'closed'
        ..['visibilityState'] = 'recent'
        ..['visibleUntil'] = closedAt.add(const Duration(days: 7))
        ..['closedAt'] = closedAt
        ..['closedByUid'] = 'si-2'
        ..['closedByName'] = 'SI Two'
        ..['closeReason'] = 'Campaign evidence reviewed and accepted.'
        ..['updatedAt'] = closedAt
        ..['updatedByUid'] = 'si-2'
        ..['updatedByName'] = 'SI Two'
        ..['version'] = 2,
      'monitoring-1',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream.value(_qualityViewer()),
          ),
          qualityWarningsProvider.overrideWith(
            (ref) => Stream.value(const <QualityWarning>[]),
          ),
          qualityMonitoringRequestsProvider.overrideWith(
            (ref) => Stream.value(<QualityMonitoringRequest>[closed]),
          ),
        ],
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: const QualityHomeScreen.monitoring(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Campaign evidence reviewed and accepted.'),
      findsOneWidget,
    );
    expect(find.text('Closed by SI Two'), findsOneWidget);
    expect(find.text('15 Aug 2026, 09:30'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'warning cards create only visible charge listeners and dispose them',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final activeCases = <String>{};
      final warnings = List<QualityWarning>.generate(80, (index) {
        final id = 'issue_ticket-$index';
        return QualityWarning.fromMap(
          _warning()
            ..['warningId'] = id
            ..['sourceId'] = 'ticket-$index'
            ..['sourceChargeNo'] = 12000 + index
            ..['sourceSummary'] = 'Warning summary $index',
          id,
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream.value(_qualityViewer()),
            ),
            qualityWarningsProvider.overrideWith(
              (ref) => Stream.value(warnings),
            ),
            qualityMonitoringRequestsProvider.overrideWith(
              (ref) => Stream.value(const <QualityMonitoringRequest>[]),
            ),
            linkedQualityAbnormalityProvider.overrideWith((ref, abnormalityId) {
              activeCases.add(abnormalityId);
              ref.onDispose(() => activeCases.remove(abnormalityId));
              return Stream<ChargeAbnormality?>.value(null);
            }),
          ],
          child: MaterialApp(
            theme: BafAppTheme.light,
            home: const QualityHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(activeCases, isNotEmpty);
      expect(activeCases.length, lessThan(warnings.length));
      expect(find.text('Warning summary 79'), findsNothing);

      await tester.tap(find.text('Review').last);
      await tester.pumpAndSettle();

      expect(find.text('No warnings in this view'), findsOneWidget);
      expect(activeCases, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('long warning facts wrap without overflowing at phone width', (
    tester,
  ) async {
    final warning =
        _warning()
          ..['component'] =
              'Atmosphere control instrumentation and combustion supervision'
          ..['affectedAssets'] = <Map<String, dynamic>>[
            <String, dynamic>{'assetType': 'furnace', 'assetNumber': 7},
            <String, dynamic>{'assetType': 'base', 'assetNumber': 223},
            <String, dynamic>{'assetType': 'forceCooler', 'assetNumber': 25},
          ];

    await _pumpQualityWarningScreen(
      tester,
      abnormalities: const <ChargeAbnormality>[],
      screenSize: const Size(320, 720),
      warningData: warning,
    );

    expect(find.textContaining('FURNACE 7, BASE 223'), findsOneWidget);
    expect(
      find.text(
        'Atmosphere control instrumentation and combustion supervision',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('connected warning hides RA completion until RA is required', (
    tester,
  ) async {
    await _pumpQualityWarningScreen(
      tester,
      abnormalities: <ChargeAbnormality>[
        _linkedIssueAbnormality(ReannealingStatus.pendingDecision),
      ],
    );

    await tester.ensureVisible(find.text('Adjudicate'));
    await tester.tap(find.text('Adjudicate'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byType(DropdownButtonFormField<QualityWarningClosureDisposition>),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coil found acceptable'), findsWidgets);
    expect(find.text('Quality adjudication'), findsOneWidget);
    expect(find.text('Re-annealing completed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connected RA completion accepts exactly one target charge', (
    tester,
  ) async {
    await _pumpQualityWarningScreen(
      tester,
      abnormalities: <ChargeAbnormality>[
        _linkedIssueAbnormality(ReannealingStatus.required),
      ],
    );

    await tester.ensureVisible(find.text('Adjudicate'));
    await tester.tap(find.text('Adjudicate'));
    await tester.pumpAndSettle();

    expect(find.text('Re-annealing completed'), findsOneWidget);
    expect(find.text('Coil found acceptable'), findsNothing);
    expect(find.text('Quality adjudication'), findsNothing);
    expect(_textFieldWithLabel('RA charge number'), findsOneWidget);
    expect(find.text('13001'), findsOneWidget);
    expect(find.text('RA charge numbers'), findsNothing);
    await tester.enterText(
      _textFieldWithLabel('RA charge number'),
      '13001, 13002',
    );
    await tester.enterText(
      _textFieldWithLabel('Decision evidence'),
      'The approved re-annealing cycle is complete.',
    );
    await tester.tap(find.text('Close warning'));
    await tester.pumpAndSettle();

    expect(find.text('Enter one five-digit RA charge number.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'recorded RA completion and operational opinion carry into adjudication',
    (tester) async {
      await _pumpQualityWarningScreen(
        tester,
        abnormalities: <ChargeAbnormality>[
          _linkedIssueAbnormality(ReannealingStatus.completed),
        ],
      );

      expect(
        find.text('Old charge 12001  →  New charge 13001'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Adjudicate'));
      await tester.tap(find.text('Adjudicate'));
      await tester.pumpAndSettle();

      expect(find.text('Recorded operational opinion'), findsWidgets);
      expect(
        tester
            .widget<TextField>(_textFieldWithLabel('Decision evidence'))
            .controller!
            .text,
        'Atmosphere interruption may affect coil quality.',
      );
      expect(
        tester
            .widget<TextField>(_textFieldWithLabel('RA charge number'))
            .controller!
            .text,
        '13001',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'operations see the old charge while the new RA charge is pending',
    (tester) async {
      await _pumpQualityWarningScreen(
        tester,
        actor: _qualityViewer(),
        abnormalities: <ChargeAbnormality>[
          _linkedIssueAbnormality(ReannealingStatus.required),
        ],
      );

      expect(find.text('RA required · awaiting new charge'), findsOneWidget);
      expect(
        find.text('Old charge 12001  →  New RA charge awaiting entry'),
        findsOneWidget,
      );
      expect(find.text('Record RA completion'), findsOneWidget);
      expect(find.text('Adjudicate'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'operations can enter a new RA charge while the original opinion stays visible',
    (tester) async {
      await _pumpQualityWarningScreen(
        tester,
        actor: _qualityViewer(),
        abnormalities: <ChargeAbnormality>[
          _linkedIssueAbnormality(ReannealingStatus.required),
        ],
      );

      await tester.ensureVisible(find.text('Record RA completion'));
      await tester.tap(find.text('Record RA completion'));
      await tester.pumpAndSettle();

      expect(find.text('Record re-annealing completion'), findsOneWidget);
      expect(
        find.text('Old charge 12001  →  New RA charge awaiting entry'),
        findsWidgets,
      );
      expect(find.text('Recorded operational opinion'), findsWidgets);
      expect(
        find.text('Atmosphere interruption may affect coil quality.'),
        findsWidgets,
      );
      expect(_textFieldWithLabel('New RA charge number'), findsOneWidget);

      await tester.enterText(
        _textFieldWithLabel('New RA charge number'),
        '12001',
      );
      await tester.enterText(
        _textFieldWithLabel('Completion evidence'),
        'The re-annealing cycle has completed.',
      );
      await tester.tap(find.text('Record completion'));
      await tester.pumpAndSettle();
      expect(
        find.text('The new RA charge must differ from the old charge.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unlinked legacy warning retains multi-charge adjudication', (
    tester,
  ) async {
    await _pumpQualityWarningScreen(
      tester,
      abnormalities: const <ChargeAbnormality>[],
    );

    await tester.ensureVisible(find.text('Adjudicate'));
    await tester.tap(find.text('Adjudicate'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byType(DropdownButtonFormField<QualityWarningClosureDisposition>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Re-annealing completed').last);
    await tester.pumpAndSettle();

    expect(_textFieldWithLabel('RA charge numbers'), findsOneWidget);
    expect(find.text('13001, 13002'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'standalone warning blocks decisions when its mandatory case is missing',
    (tester) async {
      final warning =
          _warning()
            ..['warningId'] = 'abnormality_abn-1'
            ..['sourceType'] = 'abnormality'
            ..['sourceId'] = 'abn-1';

      await _pumpQualityWarningScreen(
        tester,
        abnormalities: const <ChargeAbnormality>[],
        warningData: warning,
      );

      expect(
        find.text(
          'This warning is missing its mandatory abnormality record. Quality decisions are blocked pending repair.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Request closure'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'RA required'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Adjudicate'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'governed issue warning blocks decisions when its linked case is missing',
    (tester) async {
      final warning =
          _warning()
            ..['affectedAssets'] = <Map<String, dynamic>>[
              <String, dynamic>{
                'assetType': 'furnace',
                'assetNumber': 7,
                'assetHierarchyRef': _qualityHierarchyReference.toMap(),
              },
            ];

      await _pumpQualityWarningScreen(
        tester,
        abnormalities: const <ChargeAbnormality>[],
        warningData: warning,
      );

      expect(
        find.text(
          'This warning is missing its mandatory abnormality record. Quality decisions are blocked pending repair.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Request closure'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Adjudicate'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpQualityWarningScreen(
  WidgetTester tester, {
  required List<ChargeAbnormality> abnormalities,
  AppUser? actor,
  Size screenSize = const Size(480, 1000),
  Map<String, dynamic>? warningData,
}) async {
  await tester.binding.setSurfaceSize(screenSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final warningMap = warningData ?? _warning();
  final warning = QualityWarning.fromMap(
    warningMap,
    warningMap['warningId']! as String,
  );
  final currentActor =
      actor ??
      AppUser(
        uid: 'si-1',
        name: 'SI One',
        email: 'si-1@example.com',
        roles: const <AppRole>[AppRole.si],
        isApproved: true,
        createdAt: DateTime.utc(2026, 8, 14),
      );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith(
          (ref) => Stream.value(currentActor),
        ),
        qualityWarningsProvider.overrideWith(
          (ref) => Stream.value(<QualityWarning>[warning]),
        ),
        qualityMonitoringRequestsProvider.overrideWith(
          (ref) => Stream.value(const <QualityMonitoringRequest>[]),
        ),
        linkedQualityAbnormalityProvider.overrideWith((ref, abnormalityId) {
          ChargeAbnormality? linked;
          for (final abnormality in abnormalities) {
            if (abnormality.firestoreId == abnormalityId) {
              linked = abnormality;
              break;
            }
          }
          return Stream<ChargeAbnormality?>.value(linked);
        }),
      ],
      child: MaterialApp(
        theme: BafAppTheme.light,
        home: const QualityHomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AppUser _qualityViewer() => AppUser(
  uid: 'quality-viewer',
  name: 'Quality Viewer',
  email: 'quality.viewer@example.com',
  roles: const <AppRole>[AppRole.operations],
  isApproved: true,
  createdAt: DateTime.utc(2026, 8, 14),
);

ChargeAbnormality _linkedIssueAbnormality(ReannealingStatus status) {
  return ChargeAbnormality()
    ..firestoreId = 'issue_quality_ticket-1'
    ..sourceChargeNo = 12001
    ..linkedTicketFirestoreId = 'ticket-1'
    ..reannealingStatus = status
    ..reannealedToChargeNo =
        status == ReannealingStatus.completed ? 13001 : null;
}

const _qualityHierarchyReference = AssetHierarchyReference(
  scope: AssetHierarchyReferenceScope.componentDefinitionOnAsset,
  assetClassId: 'furnace-class',
  assetClassCode: 'FURNACE',
  assetClassName: 'Furnace',
  nodeId: 'burner-block',
  nodeVersion: 2,
  nodeName: 'Burner block',
  assetInstanceId: 'furnace-7',
  assetInstanceVersion: 3,
  assetNumber: 7,
  assetInstanceName: 'Furnace 7',
  hierarchyPath: <String>['Furnace', 'Combustion system', 'Burner block'],
  ownershipStatus: AssetOwnershipStatus.confirmed,
  ownerDiscipline: 'Mechanical',
  accountableRoleKeys: <String>['contractSupervisor'],
);

Finder _textFieldWithLabel(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Map<String, dynamic> _warning() {
  final createdAt = DateTime.utc(2026, 8, 14, 8);
  return <String, dynamic>{
    'schemaVersion': 1,
    'warningId': 'issue_ticket-1',
    'sourceType': 'issue',
    'sourceId': 'ticket-1',
    'sourceVersion': 1,
    'sourceChargeNo': 12001,
    'sourceSummary': 'Atmosphere interruption during cycle',
    'sourceSeverity': 'critical',
    'warningReason': 'Atmosphere interruption may affect coil quality.',
    'affectedAssets': <Map<String, dynamic>>[
      <String, dynamic>{'assetType': 'furnace', 'assetNumber': 7},
    ],
    'component': 'Atmosphere control',
    'status': 'open',
    'closureRequestReason': null,
    'closureRequestedAt': null,
    'closureRequestedByUid': null,
    'closureRequestedByName': null,
    'closedAt': null,
    'closedByUid': null,
    'closedByName': null,
    'closureDisposition': null,
    'linkedReannealingChargeNos': <int>[],
    'decisionReason': null,
    'createdAt': createdAt,
    'createdByUid': 'ops-1',
    'createdByName': 'Operations One',
    'updatedAt': createdAt,
    'updatedByUid': 'ops-1',
    'updatedByName': 'Operations One',
    'version': 1,
  };
}

Map<String, dynamic> _monitoring() {
  final createdAt = DateTime.utc(2026, 8, 14, 8);
  return <String, dynamic>{
    'schemaVersion': 2,
    'requestId': 'monitoring-1',
    'baseNumber': 12,
    'grade': 'CRGO M4',
    'cycleReference': 'Cycle family 7A',
    'chargeNumbers': <int>[12001, 12002],
    'reason': 'Monitor atmosphere stability during the campaign.',
    'status': 'active',
    'visibilityState': 'active',
    'visibleUntil': null,
    'archivedAt': null,
    'createdAt': createdAt,
    'createdByUid': 'si-1',
    'createdByName': 'SI One',
    'closedAt': null,
    'closedByUid': null,
    'closedByName': null,
    'closeReason': null,
    'updatedAt': createdAt,
    'updatedByUid': 'si-1',
    'updatedByName': 'SI One',
    'version': 1,
  };
}

Map<String, dynamic> _legacyMonitoring() {
  final value = _monitoring()..['schemaVersion'] = 1;
  value.remove('visibilityState');
  value.remove('visibleUntil');
  value.remove('archivedAt');
  return value;
}
