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

ComplianceRequestRecord _request() =>
    ComplianceRequestRecord()
      ..firestoreId = 'request-1'
      ..title = 'Operations support'
      ..description = 'Move the furnace to the maintenance position.'
      ..targetLaneKey = 'inst'
      ..originLaneKey = 'elec'
      ..raisedByUid = 'operations-raiser'
      ..statusKey = 'raised';

void main() {
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
}
