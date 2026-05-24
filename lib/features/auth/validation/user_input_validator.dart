// FILE: lib/features/auth/validation/user_input_validator.dart

import '../../../core/validation/field_validators.dart';
import '../../../core/validation/validation_result.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../data/user_model.dart';

class UserInputValidator {
  const UserInputValidator._();

  static ValidationResult validateUserProfile(AppUser user) {
    return ValidationResult.combine([
      FieldValidators.requiredText(
        user.uid,
        field: 'uid',
        label: 'User id',
        minLength: 4,
        maxLength: 160,
      ),
      FieldValidators.requiredText(
        user.name,
        field: 'name',
        label: 'User name',
        minLength: 2,
        maxLength: 120,
      ),
      FieldValidators.email(user.email, field: 'email', label: 'Email'),
      _validateRoles(user.roles),
    ]);
  }

  static ValidationResult validateApprovalTarget(AppUser user) {
    if (user.isApproved) {
      return ValidationResult.combine([
        validateUserProfile(user),
        ValidationResult.invalid([
          const ValidationIssue(
            field: 'isApproved',
            message: 'This user is already approved.',
          ),
        ]),
      ]);
    }

    return validateUserProfile(user);
  }

  static ValidationResult validateRoleAssignment({
    required AppUser currentUser,
    required AppUser targetUser,
    required Iterable<AppRole> selectedRoles,
    required bool lastApprovedAdminWouldBeRemoved,
  }) {
    final roles = selectedRoles.toSet();
    final issues = <ValidationIssue>[];

    issues.addAll(validateUserProfile(targetUser).issues);
    issues.addAll(_validateRoles(roles).issues);

    if (!currentUser.canManageUsers) {
      issues.add(
        const ValidationIssue(
          field: 'currentUser',
          message: 'Admin access is required to manage user roles.',
        ),
      );
    }

    if (currentUser.uid == targetUser.uid &&
        targetUser.roles.contains(AppRole.admin) &&
        !roles.contains(AppRole.admin)) {
      issues.add(
        const ValidationIssue(
          field: 'roles',
          message: 'You cannot remove your own Admin role.',
        ),
      );
    }

    if (lastApprovedAdminWouldBeRemoved) {
      issues.add(
        const ValidationIssue(
          field: 'roles',
          message: 'At least one approved Admin must remain.',
        ),
      );
    }

    return issues.isEmpty
        ? const ValidationResult.valid()
        : ValidationResult.invalid(issues);
  }

  static ValidationResult _validateRoles(Iterable<AppRole> roles) {
    final uniqueRoles = roles.toSet();

    if (uniqueRoles.isEmpty) {
      return ValidationResult.invalid([
        const ValidationIssue(
          field: 'roles',
          message: 'Select at least one role.',
        ),
      ]);
    }

    return const ValidationResult.valid();
  }
}