import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';

void main() {
  Map<String, dynamic> baseUser({dynamic roles, dynamic approved = true}) =>
      <String, dynamic>{
        'name': 'Test User',
        'email': 'test@example.com',
        'roles': roles,
        'isApproved': approved,
        'createdAt': DateTime.utc(2026, 7, 21),
      };

  test('canonical approved role list is preserved', () {
    final user = AppUser.fromFirestore(
      baseUser(roles: <String>['seniorMechanical', 'shiftSupervisor']),
      'u1',
    );
    expect(user.isApproved, isTrue);
    expect(user.roles, containsAll(<AppRole>[
      AppRole.seniorMechanical,
      AppRole.shiftSupervisor,
    ]));
  });

  test('unknown roles fail closed instead of becoming Operations', () {
    final user = AppUser.fromFirestore(
      baseUser(roles: <dynamic>['admin', 'futureUnknownRole']),
      'u2',
    );
    expect(user.isApproved, isFalse);
    expect(user.roles, isEmpty);
    expect(user.isOperations, isFalse);
  });

  test('legacy singular role and missing role list fail closed', () {
    final user = AppUser.fromFirestore(<String, dynamic>{
      ...baseUser(roles: null),
      'role': 'admin',
    }, 'u3');
    expect(user.isApproved, isFalse);
    expect(user.roles, isEmpty);
  });

  test('canonical isApproved is the only approval field', () {
    final user = AppUser.fromFirestore(<String, dynamic>{
      ...baseUser(roles: <String>['admin'], approved: false),
      'approved': true,
      'status': 'approved',
    }, 'u4');
    expect(user.isApproved, isFalse);
  });
}
