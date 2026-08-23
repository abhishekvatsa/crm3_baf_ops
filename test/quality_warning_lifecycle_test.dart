import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
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
            ..affectedAssets = const <AffectedAssetRef>[
              AffectedAssetRef(assetType: AssetType.base, assetNumber: 12),
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
    });
  });

  group('quality warning strict reader', () {
    test('accepts a complete open warning', () {
      final warning = QualityWarning.fromMap(_warning(), 'issue_ticket-1');

      expect(warning.status, QualityWarningStatus.open);
      expect(warning.sourceChargeNo, 12001);
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
            ..['closureRequestedByName'] = 'Operations One';
      final review = QualityWarning.fromMap(reviewMap, 'issue_ticket-2');
      final merged = mergeQualityWarningWindows([open, review], [open]);
      expect(merged.map((warning) => warning.warningId), [
        'issue_ticket-2',
        'issue_ticket-1',
      ]);
    });
  });

  group('quality monitoring strict reader', () {
    test('rejects duplicate charge numbers', () {
      final monitoring = _monitoring()..['chargeNumbers'] = <int>[12001, 12001];

      expect(
        () => QualityMonitoringRequest.fromMap(monitoring, 'monitoring-1'),
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

    test('live window retains every active request and removes duplicates', () {
      final oldActive = QualityMonitoringRequest.fromMap(
        _monitoring()
          ..['requestId'] = 'monitoring-old-active'
          ..['createdAt'] = DateTime.utc(2025, 1, 1)
          ..['updatedAt'] = DateTime.utc(2025, 1, 1),
        'monitoring-old-active',
      );
      final recentActive = QualityMonitoringRequest.fromMap(
        _monitoring()
          ..['requestId'] = 'monitoring-recent-active'
          ..['createdAt'] = DateTime.utc(2026, 8, 15)
          ..['updatedAt'] = DateTime.utc(2026, 8, 15),
        'monitoring-recent-active',
      );
      final merged = mergeQualityMonitoringWindows(
        <QualityMonitoringRequest>[oldActive, recentActive],
        <QualityMonitoringRequest>[recentActive],
      );

      expect(merged.map((request) => request.requestId), <String>[
        'monitoring-recent-active',
        'monitoring-old-active',
      ]);
    });
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
          ..['closureRequestedByName'] = 'Operations One',
        'issue_ticket-1',
      );
      final active = QualityMonitoringRequest.fromMap(
        _monitoring(),
        'monitoring-1',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((ref) => Stream.value(null)),
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

  testWidgets(
    'warning cards create only visible charge listeners and dispose them',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final activeCharges = <int>{};
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
            currentAppUserProvider.overrideWith((ref) => Stream.value(null)),
            qualityWarningsProvider.overrideWith(
              (ref) => Stream.value(warnings),
            ),
            qualityMonitoringRequestsProvider.overrideWith(
              (ref) => Stream.value(const <QualityMonitoringRequest>[]),
            ),
            abnormalitiesForChargeProvider.overrideWith((
              ref,
              sourceChargeNo,
            ) {
              activeCharges.add(sourceChargeNo);
              ref.onDispose(() => activeCharges.remove(sourceChargeNo));
              return Stream.value(const <ChargeAbnormality>[]);
            }),
          ],
          child: MaterialApp(
            theme: BafAppTheme.light,
            home: const QualityHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(activeCharges, isNotEmpty);
      expect(activeCharges.length, lessThan(warnings.length));
      expect(find.text('Warning summary 79'), findsNothing);

      await tester.tap(find.text('Review').last);
      await tester.pumpAndSettle();

      expect(find.text('No warnings in this view'), findsOneWidget);
      expect(activeCharges, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}

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
    'schemaVersion': 1,
    'requestId': 'monitoring-1',
    'baseNumber': 12,
    'grade': 'CRGO M4',
    'cycleReference': 'Cycle family 7A',
    'chargeNumbers': <int>[12001, 12002],
    'reason': 'Monitor atmosphere stability during the campaign.',
    'status': 'active',
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
