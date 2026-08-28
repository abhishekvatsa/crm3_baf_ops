// FILE: lib/features/maintenance/validation/maintenance_input_validator.dart

import '../../../core/validation/field_validators.dart';
import '../../../core/validation/charge_number.dart';
import '../../../core/validation/validation_result.dart';
import '../data/maintenance_model.dart';
import '../utils/asset_validator.dart';

class MaintenanceCreateInput {
  final AssetType assetType;
  final String assetNumberText;
  final String component;
  final String description;
  final String? tag;
  final String? chargeNumberText;
  final DateTime startDate;
  final RoutedTo routedTo;
  final String? otherDepartment;
  final bool hasGovernedAssetIdentity;

  const MaintenanceCreateInput({
    required this.assetType,
    required this.assetNumberText,
    required this.component,
    required this.description,
    required this.startDate,
    required this.routedTo,
    this.tag,
    this.chargeNumberText,
    this.otherDepartment,
    this.hasGovernedAssetIdentity = false,
  });
}

class MaintenanceResolutionInput {
  final MaintenanceRecord ticket;
  final DateTime endDate;
  final String? remarks;
  final Iterable<String> teamsInvolved;
  final DateTime? now;

  const MaintenanceResolutionInput({
    required this.ticket,
    required this.endDate,
    this.remarks,
    this.teamsInvolved = const <String>[],
    this.now,
  });
}

class MaintenanceInputValidator {
  static const int maxDescriptionLength = 2000;
  static const int maxComponentLength = 120;
  static const int maxTagLength = 80;
  static const int maxRemarksLength = 4000;
  static const int maxChargeNumber = maximumChargeNumber;

  static const Set<String> allowedResolutionTeams = <String>{
    'electrical',
    'mechanical',
    'instrumentation',
    'refractory',
    'emd',
    'operations',
    'shiftincharge',
    'others',
  };

  const MaintenanceInputValidator._();

  static ValidationResult validateAssetNumber({
    required AssetType assetType,
    required String? value,
    bool hasGovernedAssetIdentity = false,
  }) {
    final integerResult = FieldValidators.integerText(
      value,
      field: 'assetNumber',
      label: 'Asset number',
      min: 1,
      max: 9999,
    );
    if (integerResult.isInvalid) {
      return integerResult;
    }

    final number = int.parse(FieldValidators.clean(value));
    if (!hasGovernedAssetIdentity &&
        !AssetValidator.isValid(assetType, number)) {
      return ValidationResult.invalid([
        ValidationIssue(
          field: 'assetNumber',
          message:
              AssetValidator.getValidationMessage(assetType, number) ??
              'Invalid asset number for ${assetType.name}.',
        ),
      ]);
    }

    return const ValidationResult.valid();
  }

  static ValidationResult validateComponent(String? value) {
    return FieldValidators.requiredText(
      value,
      field: 'component',
      label: 'Component',
      minLength: 1,
      maxLength: maxComponentLength,
    );
  }

  static ValidationResult validateDescription(String? value) {
    return FieldValidators.requiredText(
      value,
      field: 'description',
      label: 'Fault description',
      minLength: 1,
      maxLength: maxDescriptionLength,
    );
  }

  static ValidationResult validateTag(String? value) {
    return FieldValidators.optionalText(
      value,
      field: 'tag',
      label: 'Equipment tag',
      maxLength: maxTagLength,
    );
  }

  static ValidationResult validateOtherDepartment({
    required RoutedTo routedTo,
    String? value,
  }) {
    return _validateOtherDepartment(routedTo, value);
  }

  static ValidationResult validateChargeNumber(String? value) {
    final message = validateChargeNumberText(value);
    return message == null
        ? const ValidationResult.valid()
        : ValidationResult.invalid(<ValidationIssue>[
          ValidationIssue(field: 'chargeNoAtEvent', message: message),
        ]);
  }

  static ValidationResult validateCreate(MaintenanceCreateInput input) {
    return ValidationResult.combine([
      validateAssetNumber(
        assetType: input.assetType,
        value: input.assetNumberText,
        hasGovernedAssetIdentity: input.hasGovernedAssetIdentity,
      ),
      validateComponent(input.component),
      validateDescription(input.description),
      validateTag(input.tag),
      validateChargeNumber(input.chargeNumberText),
      FieldValidators.dateNotFuture(
        input.startDate,
        field: 'startDate',
        label: 'Start time',
      ),
      _validateOtherDepartment(input.routedTo, input.otherDepartment),
    ]);
  }

  static ValidationResult validateResolution(MaintenanceResolutionInput input) {
    final now = input.now ?? DateTime.now();
    final teamIssues = <ValidationIssue>[];
    for (final rawTeam in input.teamsInvolved) {
      final team = rawTeam.trim().toLowerCase();
      if (team.isEmpty) {
        continue;
      }
      if (!allowedResolutionTeams.contains(team)) {
        teamIssues.add(
          ValidationIssue(
            field: 'teamsInvolved',
            message: 'Team "$rawTeam" is not a recognized maintenance team.',
          ),
        );
      }
    }

    return ValidationResult.combine([
      FieldValidators.dateNotFuture(
        input.endDate,
        field: 'endDate',
        label: 'Resolution time',
        now: now,
      ),
      FieldValidators.dateNotBefore(
        input.endDate,
        field: 'endDate',
        label: 'Resolution time',
        minimum: input.ticket.startDate,
        minimumLabel: 'ticket start time',
      ),
      FieldValidators.requiredText(
        input.remarks,
        field: 'remarks',
        label: 'Resolution remarks',
        maxLength: maxRemarksLength,
      ),
      teamIssues.isEmpty
          ? const ValidationResult.valid()
          : ValidationResult.invalid(teamIssues),
      input.ticket.isDeleted
          ? ValidationResult.invalid([
            const ValidationIssue(
              field: 'ticket',
              message: 'Deleted tickets cannot be resolved.',
            ),
          ])
          : const ValidationResult.valid(),
      input.ticket.isResolved
          ? ValidationResult.invalid([
            const ValidationIssue(
              field: 'ticket',
              message: 'This ticket is already resolved.',
            ),
          ])
          : const ValidationResult.valid(),
    ]);
  }

  static ValidationResult _validateOtherDepartment(
    RoutedTo routedTo,
    String? otherDepartment,
  ) {
    if (routedTo == RoutedTo.others) {
      return FieldValidators.requiredText(
        otherDepartment,
        field: 'otherDepartment',
        label: 'Other department',
        minLength: 1,
        maxLength: 80,
      );
    }

    final cleaned = FieldValidators.clean(otherDepartment);
    if (cleaned.isNotEmpty) {
      return ValidationResult.invalid([
        const ValidationIssue(
          field: 'otherDepartment',
          message: 'Other department must be empty unless Route to is Others.',
        ),
      ]);
    }

    return const ValidationResult.valid();
  }
}
