import 'package:crm3_baf_ops/features/maintenance/domain/issue_lane_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IssueLanePlan', () {
    test('supports a strict multi-lane lifecycle', () {
      final instrumentationCompletedAt = DateTime.utc(2026, 8, 30, 8, 15);
      final electricalCompletedAt = DateTime.utc(2026, 8, 30, 8, 45);
      final initial = IssueLanePlan.initial(const <String>[
        'instrumentation',
        'electrical',
      ]);
      final acknowledged = initial
          .acknowledge('instrumentation')
          .acknowledge('electrical');
      final completed = acknowledged
          .complete(
            'instrumentation',
            evidence: IssueLaneCompletionEvidence(
              completedAt: instrumentationCompletedAt,
              completedByUid: 'ia-1',
              completedByName: 'I&A One',
            ),
          )
          .complete(
            'electrical',
            evidence: IssueLaneCompletionEvidence(
              completedAt: electricalCompletedAt,
              completedByUid: 'electrical-1',
              completedByName: 'Electrical One',
            ),
          );

      expect(initial.primaryLane, 'instrumentation');
      expect(initial.isMultiLane, isTrue);
      expect(acknowledged.isFullyAcknowledged, isTrue);
      expect(completed.isFullyCompleted, isTrue);
      final restored = IssueLanePlan.fromSynchronizedFields(
        completed.toSynchronizedFields(),
        source: 'test issue',
      );
      expect(restored.completedLanes, const <String>[
        'instrumentation',
        'electrical',
      ]);
      expect(
        restored.completionEvidence['instrumentation']!.completedAt,
        instrumentationCompletedAt,
      );
      expect(
        restored.completionEvidence['electrical']!.completedByName,
        'Electrical One',
      );
      expect(
        completed.toClientWriteFields(),
        isNot(contains('issueLaneCompletionEvidence')),
      );
    });

    test('reconfiguration retains only progress for surviving lanes', () {
      final current = IssueLanePlan.initial(const <String>[
            'electrical',
            'mechanical',
          ])
          .acknowledge('electrical')
          .complete(
            'electrical',
            evidence: IssueLaneCompletionEvidence(
              completedAt: DateTime.utc(2026, 8, 30, 9),
              completedByUid: 'electrical-1',
              completedByName: 'Electrical One',
            ),
          );

      final changed = current.reconfigure(const <String>[
        'electrical',
        'instrumentation',
      ]);

      expect(changed.revision, 2);
      expect(changed.assignedLanes, const <String>[
        'electrical',
        'instrumentation',
      ]);
      expect(changed.acknowledgedLanes, const <String>['electrical']);
      expect(changed.completedLanes, const <String>['electrical']);
      expect(
        changed.completionEvidence['electrical']!.completedByUid,
        'electrical-1',
      );
    });

    test(
      'final closure preserves earlier lane time and dates remaining lanes',
      () {
        final earlierAt = DateTime.utc(2026, 8, 30, 9);
        final finalAt = DateTime.utc(2026, 8, 30, 10);
        final partiallyCompleted = IssueLanePlan.initial(const <String>[
              'electrical',
              'mechanical',
            ])
            .acknowledge('electrical')
            .acknowledge('mechanical')
            .complete(
              'electrical',
              evidence: IssueLaneCompletionEvidence(
                completedAt: earlierAt,
                completedByUid: 'electrical-1',
                completedByName: 'Electrical One',
              ),
            );

        final completed = partiallyCompleted.completeAll(
          completedAt: finalAt,
          completedByUid: 'supervisor-1',
          completedByName: 'Contract Supervisor',
        );

        expect(
          completed.completionEvidence['electrical']!.completedAt,
          earlierAt,
        );
        expect(
          completed.completionEvidence['mechanical']!.completedAt,
          finalAt,
        );
        expect(
          completed.completionEvidence['mechanical']!.completedByName,
          'Contract Supervisor',
        );
        expect(completed.reopen().completionEvidence, isEmpty);

        final legacyCompleted = IssueLanePlan.fromSynchronizedFields(
          const <String, dynamic>{
            'issueLaneSchemaVersion': 1,
            'issueLaneRevision': 1,
            'issueAssignedLanes': <String>['electrical', 'mechanical'],
            'issueAcknowledgedLanes': <String>['electrical', 'mechanical'],
            'issueCompletedLanes': <String>['electrical'],
          },
          source: 'legacy partially completed issue',
        ).completeAll(
          completedAt: finalAt,
          completedByUid: 'supervisor-1',
          completedByName: 'Contract Supervisor',
        );
        expect(
          legacyCompleted.completionEvidence,
          isNot(contains('electrical')),
        );
        expect(
          legacyCompleted.completionEvidence['mechanical']!.completedAt,
          finalAt,
        );
      },
    );

    test('legacy tickets normalize to one accountable lane', () {
      final open = IssueLanePlan.legacy(
        primaryLane: 'mechanical',
        status: 'open',
      );
      final resolved = IssueLanePlan.legacy(
        primaryLane: 'mechanical',
        status: 'resolved',
      );

      expect(open.assignedLanes, const <String>['mechanical']);
      expect(open.acknowledgedLanes, isEmpty);
      expect(resolved.isFullyCompleted, isTrue);
      expect(resolved.completionEvidence, isEmpty);
    });

    test('partial synchronized projection fails closed', () {
      expect(
        () => IssueLanePlan.readOptionalSynchronizedFields(
          const <String, dynamic>{'issueLaneSchemaVersion': 1},
          source: 'maintenance_records/partial',
        ),
        throwsFormatException,
      );
    });

    test('completion requires prior lane acknowledgement', () {
      final plan = IssueLanePlan.initial(const <String>['electrical']);
      expect(() => plan.complete('electrical'), throwsStateError);
    });

    test('malformed or detached completion evidence fails closed', () {
      const laneFields = <String, dynamic>{
        'issueLaneSchemaVersion': 1,
        'issueLaneRevision': 1,
        'issueAssignedLanes': <String>['electrical'],
        'issueAcknowledgedLanes': <String>[],
        'issueCompletedLanes': <String>[],
      };
      const evidence = <String, dynamic>{
        'electrical': <String, dynamic>{
          'completedAt': '2026-08-30T10:00:00.000Z',
          'completedByUid': 'electrical-1',
          'completedByName': 'Electrical One',
        },
      };

      expect(
        () => IssueLanePlan.fromSynchronizedFields(<String, dynamic>{
          ...laneFields,
          'issueLaneCompletionEvidence': evidence,
        }, source: 'maintenance_records/not-completed'),
        throwsFormatException,
      );
      expect(
        () => IssueLanePlan.readOptionalSynchronizedFields(
          const <String, dynamic>{'issueLaneCompletionEvidence': evidence},
          source: 'maintenance_records/evidence-only',
        ),
        throwsFormatException,
      );
    });
  });
}
