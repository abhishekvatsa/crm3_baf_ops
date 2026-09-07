import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/compliance_request_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/compliance_visibility_policy.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _actor(String uid, AppRole role, {bool approved = true}) => AppUser(
  uid: uid,
  name: uid,
  email: '$uid@example.com',
  roles: [role],
  isApproved: approved,
  createdAt: DateTime.utc(2026),
);

ComplianceRequestRecord _request() => ComplianceRequestRecord()
  ..firestoreId = 'request-1'
  ..title = 'Operations support'
  ..description = 'Move the furnace to the maintenance position.'
  ..targetLaneKey = 'inst'
  ..originLaneKey = 'elec'
  ..raisedByUid = 'operations-raiser'
  ..statusKey = 'raised';

void main() {
  test('completed release waits for maintenance acceptance, never dormant', () {
    final record = _request()
      ..targetLaneKey = 'oprn'
      ..originLaneKey = 'mech'
      ..conditionTypeKey = 'chargeComplete'
      ..conditionRef = '12345'
      ..statusKey = 'complied'
      ..becameDueAt = null;
    expect(
      complianceNextStepLabel(record),
      'Release condition confirmed; awaiting MECH acceptance',
    );
    record.statusKey = 'acknowledged';
    record.lastCorrectionReason = 'Crane movement is still incomplete';
    expect(
      complianceNextStepLabel(record),
      contains('Crane movement is still incomplete'),
    );
    record.statusKey = 'confirmedClosed';
    expect(complianceNextStepLabel(record), 'Request accepted and closed');
  });

  test('report visibility matches the complete compliance audience', () {
    final request = _request();
    final cases = <(AppUser, bool)>[
      (_actor('admin', AppRole.admin), true),
      (_actor('si', AppRole.si), true),
      (_actor('shift', AppRole.shiftSupervisor), true),
      (_actor('contract', AppRole.contractSupervisor), true),
      (_actor('target-worker', AppRole.seniorInstrumentation), true),
      (_actor('origin-worker', AppRole.seniorElectrical), true),
      (_actor('operations-raiser', AppRole.operations), true),
      (_actor('unrelated', AppRole.seniorMechanical), false),
      (_actor('unapproved', AppRole.admin, approved: false), false),
    ];

    for (final (actor, expected) in cases) {
      expect(
        isComplianceRequestRelevantToUser(request, actor),
        expected,
        reason: actor.uid,
      );
    }
  });

  test('inbox views are projections of the same visibility facts', () {
    final request = _request();
    expect(
      complianceRequestMatchesView(
        request,
        actor: _actor('target-worker', AppRole.seniorInstrumentation),
        view: ComplianceRequestView.forMyLane,
      ),
      isTrue,
    );
    expect(
      complianceRequestMatchesView(
        request,
        actor: _actor('origin-worker', AppRole.seniorElectrical),
        view: ComplianceRequestView.raisedByUs,
      ),
      isTrue,
    );
    expect(
      complianceRequestMatchesView(
        request,
        actor: _actor('operations-raiser', AppRole.operations),
        view: ComplianceRequestView.raisedByUs,
      ),
      isTrue,
    );
    expect(
      complianceRequestMatchesView(
        request,
        actor: _actor('shift', AppRole.shiftSupervisor),
        view: ComplianceRequestView.all,
      ),
      isTrue,
    );
  });

  test('personal action counters follow current lifecycle authority', () {
    final request = _request();
    final target = _actor('target-worker', AppRole.seniorInstrumentation);
    final origin = _actor('origin-worker', AppRole.seniorElectrical);

    expect(complianceRequiresActionFrom(request, target), isTrue);
    expect(complianceRequiresActionFrom(request, origin), isFalse);
    expect(complianceRequiresOriginConfirmation(request, origin), isFalse);

    request.statusKey = 'complied';
    expect(complianceRequiresActionFrom(request, target), isFalse);
    expect(complianceRequiresOriginConfirmation(request, origin), isTrue);
    expect(complianceRequiresOriginConfirmation(request, target), isFalse);

    request.statusKey = 'acknowledged';
    request.counterRevisedDescription = 'Use the next available crane';
    expect(complianceRequiresActionFrom(request, target), isFalse);
    expect(complianceRequiresActionFrom(request, origin), isTrue);
    expect(complianceRequiresOriginConfirmation(request, origin), isFalse);
  });

  test('condition action belongs to the condition confirmer', () {
    final request = _request()
      ..originLaneKey = 'oprn'
      ..targetLaneKey = 'inst'
      ..conditionTypeKey = 'chargeComplete'
      ..conditionRef = '51139';
    final target = _actor('target-worker', AppRole.seniorInstrumentation);
    final operations = _actor('operations', AppRole.operations);

    expect(canActAsComplianceTarget(request, target), isTrue);
    expect(complianceRequiresActionFrom(request, target), isFalse);
    expect(complianceRequiresActionFrom(request, operations), isTrue);
    expect(isComplianceRequestRelevantToUser(request, operations), isTrue);
  });
}
