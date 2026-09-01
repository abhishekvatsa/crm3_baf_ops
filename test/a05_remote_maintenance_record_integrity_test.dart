import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/remote_maintenance_reader.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/frequent_issue_selection.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/furnace_stuckup_case.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/issue_administrative_closure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('A-05 remote maintenance record integrity', () {
    test('complete current record decodes without manufactured state', () {
      final record = readRemoteMaintenanceRecord(
        _validRecord(),
        documentId: 'ticket-1',
      );

      expect(record.firestoreId, 'ticket-1');
      expect(record.assetType, AssetType.base);
      expect(record.assetNumber, 101);
      expect(record.status, TicketStatus.open);
      expect(
        record.plantConditionEffect,
        MaintenanceIssuePlantConditionEffect.unfit,
      );
      expect(record.workflowQueueState, 'independent');
      expect(record.actionsJson, '[]');
      expect(record.resolutionHistoryJson, '[]');
    });

    test(
      'Base Inner Cover availability requires verified vacant dependency evidence',
      () {
        final valid =
            _validRecord()
              ..['component'] = baseInnerCoverAvailabilityComponent
              ..['subsystem'] = baseInnerCoverAvailabilitySubsystem
              ..['tag'] = null
              ..['classification'] = baseInnerCoverUnavailableClassification
              ..['plantConditionEffect'] = 'unavailable'
              ..['assetHierarchyRefJson'] = _baseVacancyReference(
                includeAssociation: true,
              );

        final record = readRemoteMaintenanceRecord(
          valid,
          documentId: 'ticket-1',
        );
        expect(
          record.assetHierarchyReference?.innerCoverAssociation?.positionState,
          InnerCoverPositionState.noneLinked,
        );
        expect(record.tag, isNull);

        expect(
          () => readRemoteMaintenanceRecord(
            Map<String, dynamic>.from(valid)
              ..['assetHierarchyRefJson'] = _baseVacancyReference(
                includeAssociation: false,
              ),
            documentId: 'ticket-1',
          ),
          throwsA(isA<PersistedDataFormatException>()),
        );
      },
    );

    test(
      'Plant Condition effect is strict while legacy absence stays neutral',
      () {
        final legacy = _validRecord()..remove('plantConditionEffect');
        expect(
          readRemoteMaintenanceRecord(
            legacy,
            documentId: 'ticket-1',
          ).plantConditionEffect,
          MaintenanceIssuePlantConditionEffect.none,
        );
        for (final value in <Object?>['unknown', 1, true]) {
          expect(
            () => readRemoteMaintenanceRecord(
              _validRecord()..['plantConditionEffect'] = value,
              documentId: 'ticket-1',
            ),
            throwsA(isA<PersistedDataFormatException>()),
          );
        }
        expect(
          () => readRemoteMaintenanceRecord(
            _validRecord()..['plantConditionEffect'] = 'stuckUp',
            documentId: 'ticket-1',
          ),
          throwsA(isA<PersistedDataFormatException>()),
        );
      },
    );

    test('reopening actor, time, and optional reason decode together', () {
      final record = readRemoteMaintenanceRecord(
        _validRecord()
          ..['reopenedByUid'] = 'operations-2'
          ..['reopenedByName'] = 'Operations Two'
          ..['reopenedAt'] = '2026-08-12T10:05:00Z'
          ..['reopenReason'] = 'The condition recurred during operation.',
        documentId: 'ticket-1',
      );

      expect(record.reopenedByUid, 'operations-2');
      expect(record.reopenedByName, 'Operations Two');
      expect(record.reopenedAt, DateTime.utc(2026, 8, 12, 10, 5));
      expect(record.reopenReason, 'The condition recurred during operation.');
    });

    test('partial or impossible reopening evidence fails closed', () {
      final complete =
          _validRecord()
            ..['reopenedByUid'] = 'operations-2'
            ..['reopenedByName'] = 'Operations Two'
            ..['reopenedAt'] = '2026-08-12T10:05:00Z';

      for (final field in <String>[
        'reopenedByUid',
        'reopenedByName',
        'reopenedAt',
      ]) {
        final partial = Map<String, dynamic>.from(complete)..remove(field);
        expect(
          () => readRemoteMaintenanceRecord(partial, documentId: 'ticket-1'),
          throwsA(isA<PersistedDataFormatException>()),
          reason: field,
        );
      }

      expect(
        () => readRemoteMaintenanceRecord(
          Map<String, dynamic>.from(complete)
            ..['reopenedAt'] = '2026-08-12T10:11:00Z',
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });

    test('required business fields never receive defaults', () {
      final mutations = <String, Object?>{
        'version': null,
        'assetType': 'unknown',
        'assetNumber': '101',
        'maintenanceType': null,
        'description': '',
        'routedTo': 'unknown',
        'status': null,
        'isResolved': null,
        'isCritical': 0,
        'loggedByUid': '',
        'isDeleted': null,
      };

      for (final entry in mutations.entries) {
        final data = _validRecord()..[entry.key] = entry.value;
        expect(
          () => readRemoteMaintenanceRecord(data, documentId: 'ticket-1'),
          throwsA(isA<PersistedDataFormatException>()),
          reason: entry.key,
        );
      }
    });

    test('document identity and lifecycle contradictions fail closed', () {
      expect(
        () => readRemoteMaintenanceRecord(
          _validRecord()..['firestoreId'] = 'another-ticket',
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => readRemoteMaintenanceRecord(
          _validRecord()
            ..['status'] = 'resolved'
            ..['isResolved'] = false,
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => readRemoteMaintenanceRecord(
          _validRecord()..['deletedAt'] = '2026-08-12T10:05:00Z',
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );

      final conciseOtherDepartment = readRemoteMaintenanceRecord(
        _validRecord()
          ..['routedTo'] = 'others'
          ..['otherDepartment'] = 'X'
          ..addAll(<String, dynamic>{
            'issueLaneSchemaVersion': 1,
            'issueLaneRevision': 1,
            'issueAssignedLanes': <String>['others'],
            'issueAcknowledgedLanes': <String>[],
            'issueCompletedLanes': <String>[],
          }),
        documentId: 'ticket-1',
      );
      expect(conciseOtherDepartment.issueLanePlanReadResult.isValid, isTrue);

      expect(
        () => readRemoteMaintenanceRecord(
          _validRecord()..['otherDepartment'] = 'X',
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });

    test(
      'administrative closure remains terminal without manufacturing lane completion',
      () {
        final record = readRemoteMaintenanceRecord(
          _validRecord()
            ..['status'] = 'closedWithoutResolution'
            ..['isResolved'] = true
            ..['endDate'] = '2026-08-12T11:00:00Z'
            ..['closedByUid'] = 'admin-1'
            ..['closedByName'] = 'Admin One'
            ..['issueClosureSchemaVersion'] = 1
            ..['issueClosureDisposition'] = 'stillRelevant'
            ..['issueClosureReason'] =
                'The charge ended, but the unresolved condition remains relevant.'
            ..['acknowledgedByUid'] = 'mechanical-1'
            ..['acknowledgedByName'] = 'Mechanical One'
            ..['acknowledgedAt'] = '2026-08-12T10:20:00Z'
            ..addAll(<String, dynamic>{
              'issueLaneSchemaVersion': 1,
              'issueLaneRevision': 2,
              'issueAssignedLanes': <String>['mechanical', 'electrical'],
              'issueAcknowledgedLanes': <String>['mechanical'],
              'issueCompletedLanes': <String>[],
            }),
          documentId: 'ticket-1',
        );

        expect(record.status, TicketStatus.closedWithoutResolution);
        expect(record.isClosed, isTrue);
        expect(record.wasTechnicallyResolved, isFalse);
        expect(
          record.administrativeClosure?.disposition,
          IssueAdministrativeClosureDisposition.stillRelevant,
        );
        expect(record.issueLanePlan.completedLanes, isEmpty);

        final acknowledgedLegacyClosure =
            _validRecord()
              ..['status'] = 'closedWithoutResolution'
              ..['isResolved'] = true
              ..['endDate'] = '2026-08-12T11:00:00Z'
              ..['closedByUid'] = 'admin-1'
              ..['closedByName'] = 'Admin One'
              ..['issueClosureSchemaVersion'] = 1
              ..['issueClosureDisposition'] = 'stillRelevant'
              ..['issueClosureReason'] =
                  'The operating cycle ended while engineering follow-up remained open.'
              ..['acknowledgedByUid'] = 'mechanical-1'
              ..['acknowledgedByName'] = 'Mechanical One'
              ..['acknowledgedAt'] = '2026-08-12T10:20:00Z';

        expect(
          () => readRemoteMaintenanceRecord(
            acknowledgedLegacyClosure,
            documentId: 'ticket-1',
          ),
          throwsA(
            isA<PersistedDataFormatException>().having(
              (error) => error.fieldName,
              'fieldName',
              'acknowledgedByUid',
            ),
          ),
        );

        final repairedClosure = readRemoteMaintenanceRecord(
          acknowledgedLegacyClosure..addAll(<String, dynamic>{
            'issueLaneSchemaVersion': 1,
            'issueLaneRevision': 1,
            'issueAssignedLanes': <String>['mechanical'],
            'issueAcknowledgedLanes': <String>['mechanical'],
            'issueCompletedLanes': <String>[],
          }),
          documentId: 'ticket-1',
        );

        expect(repairedClosure.issueLanePlan.acknowledgedLanes, <String>[
          'mechanical',
        ]);
        expect(repairedClosure.issueLanePlan.completedLanes, isEmpty);

        expect(
          () => readRemoteMaintenanceRecord(
            _validRecord()
              ..['status'] = 'closedWithoutResolution'
              ..['isResolved'] = true
              ..['endDate'] = '2026-08-12T11:00:00Z'
              ..['closedByUid'] = 'admin-1'
              ..['closedByName'] = 'Admin One'
              ..['issueClosureSchemaVersion'] = 1
              ..['issueClosureDisposition'] = 'stillRelevant',
            documentId: 'ticket-1',
          ),
          throwsA(isA<PersistedDataFormatException>()),
        );

        expect(
          () => readRemoteMaintenanceRecord(
            _validRecord()
              ..['status'] = 'closedWithoutResolution'
              ..['isResolved'] = true
              ..['endDate'] = '2026-08-12T11:00:00Z'
              ..['closedByUid'] = 'admin-1'
              ..['issueClosureSchemaVersion'] = 1
              ..['issueClosureDisposition'] = 'stillRelevant'
              ..['issueClosureReason'] =
                  'The charge ended, but engineering relevance remains.',
            documentId: 'ticket-1',
          ),
          throwsA(isA<PersistedDataFormatException>()),
        );
      },
    );

    test('partial or contradictory workflow projection fails closed', () {
      expect(
        () => readRemoteMaintenanceRecord(
          _validRecord()..['workflowDeferred'] = false,
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );

      final linked =
          _validRecord()..addAll(<String, dynamic>{
            'workflowDeferred': false,
            'workflowQueueState': 'actionable',
            'workflowAggregateId': 'workflow-1',
            'workflowComplianceId': 'compliance-1',
            'workflowOriginLaneKey': 'operations',
            'workflowTargetLaneKey': 'mechanical',
            'workflowConditionTypeKey': 'manual',
            'workflowUpdatedAt': '2026-08-12T10:05:00Z',
          });
      expect(
        readRemoteMaintenanceRecord(
          linked,
          documentId: 'ticket-1',
        ).workflowAggregateId,
        'workflow-1',
      );

      expect(
        () => readRemoteMaintenanceRecord(
          Map<String, dynamic>.from(linked)..['workflowDeferred'] = true,
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });

    test(
      'complete multi-lane issue projection decodes without losing progress',
      () {
        final record = readRemoteMaintenanceRecord(
          _validRecord()
            ..['status'] = 'inProgress'
            ..['acknowledgedByUid'] = 'mechanical-1'
            ..['acknowledgedByName'] = 'Senior Mechanical'
            ..['acknowledgedAt'] = '2026-08-12T10:05:00Z'
            ..addAll(<String, dynamic>{
              'issueLaneSchemaVersion': 1,
              'issueLaneRevision': 3,
              'issueAssignedLanes': <String>['mechanical', 'electrical'],
              'issueAcknowledgedLanes': <String>['mechanical', 'electrical'],
              'issueCompletedLanes': <String>['mechanical'],
            }),
          documentId: 'ticket-1',
        );

        expect(record.issueLanePlan.revision, 3);
        expect(record.issueLanePlan.assignedLanes, <String>[
          'mechanical',
          'electrical',
        ]);
        expect(record.issueLanePlan.acknowledgedLanes, <String>[
          'mechanical',
          'electrical',
        ]);
        expect(record.issueLanePlan.completedLanes, <String>['mechanical']);
      },
    );

    test(
      'legacy resolved issue without acknowledgement remains readable while canonical evidence stays strict',
      () {
        final legacy = readRemoteMaintenanceRecord(
          _validRecord()
            ..['status'] = 'resolved'
            ..['isResolved'] = true
            ..['endDate'] = '2026-08-12T11:00:00Z'
            ..['closedByUid'] = 'mechanical-1'
            ..['closedByName'] = 'Senior Mechanical',
          documentId: 'ticket-1',
        );
        expect(legacy.status, TicketStatus.resolved);
        expect(legacy.issueLanePlan.isFullyCompleted, isTrue);
        expect(legacy.acknowledgedByUid, isNull);

        expect(
          () => readRemoteMaintenanceRecord(
            _validRecord()
              ..['status'] = 'resolved'
              ..['isResolved'] = true
              ..['endDate'] = '2026-08-12T11:00:00Z'
              ..['closedByUid'] = 'mechanical-1'
              ..['closedByName'] = 'Senior Mechanical'
              ..addAll(<String, dynamic>{
                'issueLaneSchemaVersion': 1,
                'issueLaneRevision': 1,
                'issueAssignedLanes': <String>['mechanical'],
                'issueAcknowledgedLanes': <String>['mechanical'],
                'issueCompletedLanes': <String>['mechanical'],
              }),
            documentId: 'ticket-1',
          ),
          throwsA(isA<PersistedDataFormatException>()),
        );
      },
    );

    test('partial or lifecycle-invalid issue lane projection fails closed', () {
      expect(
        () => readRemoteMaintenanceRecord(
          _validRecord()..['issueLaneSchemaVersion'] = 1,
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );

      expect(
        () => readRemoteMaintenanceRecord(
          _validRecord()..addAll(<String, dynamic>{
            'issueLaneSchemaVersion': 1,
            'issueLaneRevision': 1,
            'issueAssignedLanes': <String>['mechanical'],
            'issueAcknowledgedLanes': null,
            'issueCompletedLanes': <String>[],
          }),
          documentId: 'null-lane-progress',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );

      expect(
        () => readRemoteMaintenanceRecord(
          _validRecord()..['acknowledgedByUid'] = 'mechanical-1',
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );

      expect(
        () => readRemoteMaintenanceRecord(
          _validRecord()
            ..['status'] = 'resolved'
            ..['isResolved'] = true
            ..addAll(<String, dynamic>{
              'issueLaneSchemaVersion': 1,
              'issueLaneRevision': 2,
              'issueAssignedLanes': <String>['mechanical', 'electrical'],
              'issueAcknowledgedLanes': <String>['mechanical', 'electrical'],
              'issueCompletedLanes': <String>['mechanical'],
            }),
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );

      expect(
        () => readRemoteMaintenanceRecord(
          _validRecord()
            ..['status'] = 'acknowledged'
            ..['acknowledgedByUid'] = 'mechanical-1'
            ..['acknowledgedByName'] = 'Mechanical One'
            ..['acknowledgedAt'] =
                DateTime.utc(2026, 8, 23, 4).toIso8601String()
            ..addAll(<String, dynamic>{
              'issueLaneSchemaVersion': 1,
              'issueLaneRevision': 1,
              'issueAssignedLanes': <String>['mechanical', 'electrical'],
              'issueAcknowledgedLanes': <String>['mechanical'],
              'issueCompletedLanes': <String>[],
            }),
          documentId: 'partial-acknowledgement-label',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });

    test('malformed present optional values are not treated as absent', () {
      for (final entry
          in <String, Object?>{
            'component': 12,
            'hierarchyPath': 'base/101',
            'teamsInvolved': <Object>['operations', 7],
            'downtimeHours': double.nan,
            'chargeNoAtEvent': '42',
          }.entries) {
        expect(
          () => readRemoteMaintenanceRecord(
            _validRecord()..[entry.key] = entry.value,
            documentId: 'ticket-1',
          ),
          throwsA(isA<PersistedDataFormatException>()),
          reason: entry.key,
        );
      }
    });

    test('exact governed identity admits universal asset numbers', () {
      final record = readRemoteMaintenanceRecord(
        _validRecord()
          ..['assetType'] = 'furnace'
          ..['assetNumber'] = 27
          ..['assetHierarchyRefJson'] = _governedAssetReference(27),
        documentId: 'ticket-1',
      );

      expect(record.assetType, AssetType.furnace);
      expect(record.assetNumber, 27);
      expect(record.assetHierarchyReference?.assetInstanceId, 'furnace-27');
    });

    test(
      'exact installed component identity admits universal asset numbers',
      () {
        final record = readRemoteMaintenanceRecord(
          _validRecord()
            ..['assetType'] = 'furnace'
            ..['assetNumber'] = 28
            ..['assetHierarchyRefJson'] = _governedAssetReference(
              28,
              scope: AssetHierarchyReferenceScope.installedComponent,
            ),
          documentId: 'ticket-1',
        );

        expect(record.assetNumber, 28);
        expect(
          record.assetHierarchyReference?.scope,
          AssetHierarchyReferenceScope.installedComponent,
        );
        expect(
          record.assetHierarchyReference?.componentInstanceId,
          'component-28',
        );
      },
    );

    test('legacy or mismatched identity cannot bypass asset number rules', () {
      expect(
        () => readRemoteMaintenanceRecord(
          _validRecord()
            ..['assetType'] = 'furnace'
            ..['assetNumber'] = 27,
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => readRemoteMaintenanceRecord(
          _validRecord()
            ..['assetType'] = 'furnace'
            ..['assetNumber'] = 27
            ..['assetHierarchyRefJson'] = _governedAssetReference(28),
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => readRemoteMaintenanceRecord(
          _validRecord()
            ..['assetType'] = 'furnace'
            ..['assetNumber'] = 10000
            ..['assetHierarchyRefJson'] = _governedAssetReference(10000),
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });

    test('burner-lockout fields are all-or-none and route to I&A', () {
      final valid =
          _validRecord()
            ..['assetType'] = 'furnace'
            ..['assetNumber'] = 1
            ..['component'] = 'Burner system'
            ..['classification'] = 'furnaceBurnerLockout'
            ..['routedTo'] = 'instrumentation'
            ..['isCritical'] = true
            ..addAll(_openBurnerLockoutFields());
      final record = readRemoteMaintenanceRecord(valid, documentId: 'ticket-1');

      expect(record.burnerLockoutCase?.positions, <int>[2, 5]);
      expect(record.burnerLockoutCase?.redHotPositions, <int>[5]);

      expect(
        () => readRemoteMaintenanceRecord(
          Map<String, dynamic>.from(valid)..remove('burnerSparkObservation'),
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => readRemoteMaintenanceRecord(
          Map<String, dynamic>.from(valid)..['routedTo'] = 'mechanical',
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => readRemoteMaintenanceRecord(
          Map<String, dynamic>.from(valid)..['isCritical'] = false,
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });

    test('furnace stuck-up fields are all-or-none and route to Mechanical', () {
      final valid =
          _validRecord()
            ..['assetType'] = 'furnace'
            ..['assetNumber'] = 7
            ..['component'] = 'Furnace / Inner Cover interface'
            ..['classification'] = furnaceStuckupClassification
            ..['plantConditionEffect'] = 'stuckUp'
            ..['routedTo'] = 'mechanical'
            ..addAll(_stuckupCase().toSynchronizedFields());

      expect(
        readRemoteMaintenanceRecord(
          valid,
          documentId: 'ticket-1',
        ).furnaceStuckupCase?.baseNumber,
        117,
      );
      expect(
        () => readRemoteMaintenanceRecord(
          Map<String, dynamic>.from(valid)..['routedTo'] = 'electrical',
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => readRemoteMaintenanceRecord(
          Map<String, dynamic>.from(valid)..remove('stuckupOperatingContext'),
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });

    test('frequent issue selection is strict and preserved locally', () {
      final record = readRemoteMaintenanceRecord(
        _validRecord()
          ..['frequentIssueSelection'] = <String, dynamic>{
            'schemaVersion': 1,
            'selectionType': 'definition',
            'definitionId': 'issue-1',
            'definitionVersion': 3,
            'definitionCode': 'FLAME_UNSTABLE',
            'definitionTitle': 'Unstable flame',
            'codeOwnedWorkflowProfile': null,
            'unlistedReason': null,
          },
        documentId: 'ticket-1',
      );

      expect(
        record.frequentIssueSelection?.type,
        FrequentIssueSelectionType.definition,
      );
      expect(record.frequentIssueSelection?.definitionId, 'issue-1');

      expect(
        () => readRemoteMaintenanceRecord(
          _validRecord()
            ..['frequentIssueSelection'] = <String, dynamic>{
              'schemaVersion': 1,
              'selectionType': 'definition',
              'definitionId': 'issue-1',
              'definitionVersion': 3,
              'definitionCode': null,
              'definitionTitle': 'Unstable flame',
              'codeOwnedWorkflowProfile': null,
              'unlistedReason': null,
            },
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });
  });
}

FurnaceStuckupCase _stuckupCase() => FurnaceStuckupCase(
  baseNumber: 117,
  baseAssetReference: AssetHierarchyReference(
    scope: AssetHierarchyReferenceScope.physicalAsset,
    assetClassId: 'base-class',
    assetClassCode: 'BASE',
    assetClassName: 'Base',
    nodeId: 'base-root',
    nodeVersion: 3,
    nodeName: 'Base',
    assetInstanceId: 'base-117',
    assetInstanceVersion: 8,
    assetNumber: 117,
    assetInstanceName: 'Base 117',
    hierarchyPath: const <String>['Base'],
    ownershipStatus: AssetOwnershipStatus.confirmed,
    ownerDiscipline: 'Operations',
    accountableRoleKeys: const <String>['operations'],
    innerCoverAssociation: InnerCoverEventReference(
      baseAssetInstanceId: 'base-117',
      baseAssetNumber: 117,
      positionState: InnerCoverPositionState.linked,
      innerCoverId: 'inner-cover-gr26',
      innerCoverSerialNumber: 'GR26',
      linkageId: 'link-gr26-base-117',
      assignmentVersion: 4,
      linkedAt: DateTime.utc(2026, 8, 1),
      eventAt: DateTime.utc(2026, 8, 20, 8),
      confirmedAt: DateTime.utc(2026, 8, 20, 8, 1),
      confirmedByUid: 'operations-1',
      confirmedByName: 'Operations One',
    ),
  ),
  suspectedCause: FurnaceStuckupCause.innerCoverBulging,
  operatingContext: FurnaceStuckupOperatingContext.postAnnealingRemoval,
);

Map<String, dynamic> _openBurnerLockoutFields() => <String, dynamic>{
  'burnerLockoutSchemaVersion': 1,
  'burnerPositions': <int>[2, 5],
  'burnerCommonMode': true,
  'burnerCycleStage': 'ignition',
  'burnerHmiAlarm': 'Flame failure',
  'burnerFlameObservation': 'notSeen',
  'burnerSparkObservation': 'seen',
  'burnerRelightAttempts': 2,
  'burnerRemainsLockedOut': true,
  'burnerRedHotPositions': <int>[5],
  'burnerAttendedPositions': <int>[],
  'burnerResolutionEvidence': <String, dynamic>{},
};

String _governedAssetReference(
  int number, {
  AssetHierarchyReferenceScope scope =
      AssetHierarchyReferenceScope.physicalAsset,
}) {
  return AssetHierarchyReference(
    scope: scope,
    assetClassId: 'furnace-class',
    assetClassCode: 'FURNACE',
    assetClassName: 'Furnace',
    nodeId: 'furnace-$number',
    nodeVersion: 4,
    nodeName: 'Furnace $number',
    assetInstanceId: 'furnace-$number',
    assetInstanceVersion: 4,
    assetNumber: number,
    assetInstanceName: 'Furnace $number',
    componentInstanceId:
        scope == AssetHierarchyReferenceScope.installedComponent
            ? 'component-$number'
            : null,
    componentInstanceVersion:
        scope == AssetHierarchyReferenceScope.installedComponent ? 2 : null,
    componentTag:
        scope == AssetHierarchyReferenceScope.installedComponent
            ? 'PT-$number'
            : null,
    hierarchyPath: <String>['Furnace', 'Furnace $number'],
    ownershipStatus: AssetOwnershipStatus.confirmed,
    ownerDiscipline: 'Mechanical',
    accountableRoleKeys: const <String>['seniorMechanical'],
  ).encode();
}

String _baseVacancyReference({required bool includeAssociation}) {
  final eventAt = DateTime.utc(2026, 8, 12, 10);
  return AssetHierarchyReference(
    scope: AssetHierarchyReferenceScope.physicalAsset,
    assetClassId: 'base-class',
    assetClassCode: 'BASE',
    assetClassName: 'Base',
    nodeId: 'base-101',
    nodeVersion: 4,
    nodeName: 'Base 101',
    assetInstanceId: 'base-101',
    assetInstanceVersion: 4,
    assetNumber: 101,
    assetInstanceName: 'Base 101',
    hierarchyPath: const <String>['Base', 'Base 101'],
    ownershipStatus: AssetOwnershipStatus.confirmed,
    ownerDiscipline: 'Operations',
    accountableRoleKeys: const <String>['operations'],
    innerCoverAssociation:
        includeAssociation
            ? InnerCoverEventReference(
              baseAssetInstanceId: 'base-101',
              baseAssetNumber: 101,
              positionState: InnerCoverPositionState.noneLinked,
              eventAt: eventAt,
              confirmedAt: eventAt.add(const Duration(minutes: 1)),
              confirmedByUid: 'operations-1',
              confirmedByName: 'Operations One',
            )
            : null,
  ).encode();
}

Map<String, dynamic> _validRecord() => <String, dynamic>{
  'firestoreId': 'ticket-1',
  'version': 3,
  'assetType': 'base',
  'assetNumber': 101,
  'maintenanceType': 'breakdown',
  'description': 'Inspect furnace base alignment',
  'plantConditionEffect': 'unfit',
  'routedTo': 'mechanical',
  'status': 'open',
  'isResolved': false,
  'isCritical': false,
  'loggedByUid': 'actor-1',
  'startDate': '2026-08-12T10:00:00Z',
  'createdAt': '2026-08-12T10:00:00Z',
  'updatedAt': '2026-08-12T10:10:00Z',
  'actionsJson': '[]',
  'resolutionHistoryJson': '[]',
  'isDeleted': false,
};
