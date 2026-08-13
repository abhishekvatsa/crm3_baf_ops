// FILE: test/input_validation_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/validation/user_input_validator.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/validation/maintenance_input_validator.dart';

AppUser _user({
  String uid = 'user_1',
  String name = 'Test User',
  String email = 'test@example.invalid',
  List<AppRole> roles = const [AppRole.operations],
  bool isApproved = true,
}) {
  return AppUser(
    uid: uid,
    name: name,
    email: email,
    roles: roles,
    isApproved: isApproved,
    createdAt: DateTime.utc(2026, 5, 13),
  );
}

MaintenanceRecord _ticket({bool isResolved = false, bool isDeleted = false}) {
  return MaintenanceRecord()
    ..assetType = AssetType.base
    ..assetNumber = 101
    ..maintenanceType = MaintenanceType.breakdown
    ..description = 'Hydraulic clamp issue observed'
    ..routedTo = RoutedTo.mechanical
    ..startDate = DateTime.utc(2026, 5, 13, 8)
    ..createdAt = DateTime.utc(2026, 5, 13, 8)
    ..updatedAt = DateTime.utc(2026, 5, 13, 8)
    ..isResolved = isResolved
    ..isDeleted = isDeleted;
}

void main() {
  group('MaintenanceInputValidator', () {
    test('accepts a valid maintenance create payload', () {
      final result = MaintenanceInputValidator.validateCreate(
        MaintenanceCreateInput(
          assetType: AssetType.base,
          assetNumberText: '101',
          component: 'Base fan bearing',
          description: 'Abnormal vibration observed at base fan bearing.',
          tag: 'VT-101',
          chargeNumberText: '12345',
          startDate: DateTime.now().subtract(const Duration(minutes: 5)),
          routedTo: RoutedTo.mechanical,
        ),
      );

      expect(result.issues, isEmpty, reason: result.summary);
      expect(result.isValid, isTrue);
    });

    test('accepts governed custom asset numbers only in the bounded range', () {
      final valid = MaintenanceInputValidator.validateCreate(
        MaintenanceCreateInput(
          assetType: AssetType.governedCustom,
          assetNumberText: '9999',
          component: 'Custom component',
          description: 'Condition requiring governed maintenance attention.',
          startDate: DateTime.now().subtract(const Duration(minutes: 5)),
          routedTo: RoutedTo.mechanical,
        ),
      );
      final invalid = MaintenanceInputValidator.validateCreate(
        MaintenanceCreateInput(
          assetType: AssetType.governedCustom,
          assetNumberText: '10000',
          component: 'Custom component',
          description: 'Condition requiring governed maintenance attention.',
          startDate: DateTime.now().subtract(const Duration(minutes: 5)),
          routedTo: RoutedTo.mechanical,
        ),
      );

      expect(valid.messageFor('assetNumber'), isNull);
      expect(invalid.messageFor('assetNumber'), isNotNull);
    });

    test(
      'rejects invalid asset, short description, bad charge and future start',
      () {
        final result = MaintenanceInputValidator.validateCreate(
          MaintenanceCreateInput(
            assetType: AssetType.base,
            assetNumberText: '9999',
            component: 'A',
            description: 'bad',
            chargeNumberText: 'abc',
            startDate: DateTime.now().add(const Duration(hours: 1)),
            routedTo: RoutedTo.mechanical,
          ),
        );

        expect(result.isInvalid, isTrue);
        expect(result.messageFor('assetNumber'), isNotNull);
        expect(result.messageFor('component'), isNotNull);
        expect(result.messageFor('description'), isNotNull);
        expect(result.messageFor('chargeNoAtEvent'), isNotNull);
        expect(result.messageFor('startDate'), isNotNull);
      },
    );

    test('requires other department when Route to is Others', () {
      final result = MaintenanceInputValidator.validateCreate(
        MaintenanceCreateInput(
          assetType: AssetType.base,
          assetNumberText: '101',
          component: 'Base fan bearing',
          description: 'Abnormal vibration observed at base fan bearing.',
          startDate: DateTime.now().subtract(const Duration(minutes: 5)),
          routedTo: RoutedTo.others,
        ),
      );

      expect(result.isInvalid, isTrue);
      expect(result.messageFor('otherDepartment'), isNotNull);
    });

    test('accepts other department when Route to is Others', () {
      final result = MaintenanceInputValidator.validateCreate(
        MaintenanceCreateInput(
          assetType: AssetType.base,
          assetNumberText: '101',
          component: 'Base fan bearing',
          description: 'Abnormal vibration observed at base fan bearing.',
          startDate: DateTime.now().subtract(const Duration(minutes: 5)),
          routedTo: RoutedTo.others,
          otherDepartment: 'Hydraulics contractor',
        ),
      );

      expect(result.issues, isEmpty, reason: result.summary);
      expect(result.isValid, isTrue);
    });

    test('requires resolution remarks before closing a ticket', () {
      final result = MaintenanceInputValidator.validateResolution(
        MaintenanceResolutionInput(
          ticket: _ticket(),
          endDate: DateTime.utc(2026, 5, 13, 9),
          remarks: '   ',
          teamsInvolved: const ['mechanical'],
          now: DateTime.utc(2026, 5, 13, 10),
        ),
      );

      expect(result.isInvalid, isTrue);
      expect(result.messageFor('remarks'), isNotNull);
    });

    test('rejects resolution before start and unknown teams', () {
      final result = MaintenanceInputValidator.validateResolution(
        MaintenanceResolutionInput(
          ticket: _ticket(),
          endDate: DateTime.utc(2026, 5, 13, 7),
          teamsInvolved: const ['mechanical', 'unknown-team'],
          now: DateTime.utc(2026, 5, 13, 10),
        ),
      );

      expect(result.isInvalid, isTrue);
      expect(result.messageFor('endDate'), isNotNull);
      expect(result.messageFor('teamsInvolved'), isNotNull);
    });
  });

  group('UserInputValidator', () {
    test('accepts a sane pending approval target', () {
      final result = UserInputValidator.validateApprovalTarget(
        _user(isApproved: false),
      );

      expect(result.isValid, isTrue);
    });

    test('rejects malformed user profiles', () {
      final result = UserInputValidator.validateUserProfile(
        _user(uid: '', name: '', email: 'not-an-email', roles: const []),
      );

      expect(result.isInvalid, isTrue);
      expect(result.messageFor('uid'), isNotNull);
      expect(result.messageFor('name'), isNotNull);
      expect(result.messageFor('email'), isNotNull);
      expect(result.messageFor('roles'), isNotNull);
    });

    test('leaves quorum decisions to the server transaction', () {
      final admin = _user(uid: 'admin_1', roles: const [AppRole.admin]);

      final result = UserInputValidator.validateRoleAssignment(
        currentUser: admin,
        targetUser: admin,
        selectedRoles: const [AppRole.operations],
      );

      expect(result.isValid, isTrue);
    });

    test('still rejects empty roles and non-admin actors', () {
      final target = _user(uid: 'target_1');
      final nonAdmin = _user(uid: 'ops_1', roles: const [AppRole.operations]);

      final result = UserInputValidator.validateRoleAssignment(
        currentUser: nonAdmin,
        targetUser: target,
        selectedRoles: const [],
      );

      expect(result.isInvalid, isTrue);
      expect(result.messageFor('currentUser'), isNotNull);
      expect(result.messageFor('roles'), isNotNull);
    });
  });
}
