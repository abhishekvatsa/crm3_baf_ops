import 'package:crm3_baf_ops/features/maintenance/domain/issue_lane_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IssueLanePlan', () {
    test('supports a strict multi-lane lifecycle', () {
      final initial = IssueLanePlan.initial(const <String>[
        'instrumentation',
        'electrical',
      ]);
      final acknowledged = initial
          .acknowledge('instrumentation')
          .acknowledge('electrical');
      final completed = acknowledged
          .complete('instrumentation')
          .complete('electrical');

      expect(initial.primaryLane, 'instrumentation');
      expect(initial.isMultiLane, isTrue);
      expect(acknowledged.isFullyAcknowledged, isTrue);
      expect(completed.isFullyCompleted, isTrue);
      expect(
        IssueLanePlan.fromSynchronizedFields(
          completed.toSynchronizedFields(),
          source: 'test issue',
        ).completedLanes,
        const <String>['instrumentation', 'electrical'],
      );
    });

    test('reconfiguration retains only progress for surviving lanes', () {
      final current = IssueLanePlan.initial(const <String>[
        'electrical',
        'mechanical',
      ]).acknowledge('electrical').complete('electrical');

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
    });

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
  });
}
