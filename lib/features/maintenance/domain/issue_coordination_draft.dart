import '../../../core/validation/charge_number.dart';

enum IssueCoordinationPurpose { deferment, operationsSupport }

enum IssueCoordinationCondition { chargeComplete, activityRef }

class IssueCoordinationDraft {
  final IssueCoordinationPurpose purpose;
  final IssueCoordinationCondition? condition;
  final int? conditionChargeNo;
  final String? conditionRef;
  final String? defermentBasisKey;
  final String? operationsSupportTypeKey;
  final String? operationsResourceKey;
  final String? requestedLocation;
  final String title;
  final String description;
  final String priorityKey;

  const IssueCoordinationDraft._({
    required this.purpose,
    required this.condition,
    required this.conditionChargeNo,
    required this.conditionRef,
    required this.defermentBasisKey,
    required this.operationsSupportTypeKey,
    required this.operationsResourceKey,
    required this.requestedLocation,
    required this.title,
    required this.description,
    required this.priorityKey,
  });

  factory IssueCoordinationDraft.validate({
    required IssueCoordinationPurpose purpose,
    IssueCoordinationCondition? condition,
    String? conditionChargeText,
    String? conditionRef,
    String? defermentBasisKey,
    String? operationsSupportTypeKey,
    String? operationsResourceKey,
    String? requestedLocation,
    required String title,
    required String description,
    required String priorityKey,
  }) {
    String? optional(String? value) {
      final cleaned = value?.trim();
      return cleaned == null || cleaned.isEmpty ? null : cleaned;
    }

    final cleanTitle = title.trim();
    final cleanDescription = description.trim();
    final cleanConditionRef = optional(conditionRef);
    final cleanLocation = optional(requestedLocation);
    if (cleanTitle.isEmpty || cleanTitle.length > 160) {
      throw const FormatException(
        'Request title is required and cannot exceed 160 characters.',
      );
    }
    if (cleanDescription.isEmpty || cleanDescription.length > 2000) {
      throw const FormatException(
        'Required action is required and cannot exceed 2000 characters.',
      );
    }
    if (!const <String>{
      'low',
      'medium',
      'high',
      'critical',
    }.contains(priorityKey)) {
      throw const FormatException('Select a valid request priority.');
    }

    int? chargeNo;
    if (purpose == IssueCoordinationPurpose.deferment) {
      if (condition == null ||
          !const <String>{
            'ongoingCycle',
            'equipmentRequired',
            'operationalCompliance',
            'safetyConstraint',
            'qualityConstraint',
            'other',
          }.contains(defermentBasisKey)) {
        throw const FormatException(
          'A deferment reason and release condition are required.',
        );
      }
      if (condition == IssueCoordinationCondition.chargeComplete) {
        chargeNo = parseOptionalChargeNumber(conditionChargeText);
        if (chargeNo == null) {
          throw const FormatException(
            'Charge-complete deferment requires exactly five digits.',
          );
        }
      } else if (cleanConditionRef == null) {
        throw const FormatException(
          'Name the activity that must be completed.',
        );
      }
    } else {
      if (!const <String>{
            'craneMovement',
            'assetRelocation',
            'isolation',
            'processPreparation',
            'utilitySupport',
            'accessOrPermit',
            'other',
          }.contains(operationsSupportTypeKey) ||
          !const <String>{
            'crane',
            'transferCar',
            'operationsCrew',
            'utilities',
            'other',
          }.contains(operationsResourceKey)) {
        throw const FormatException(
          'Select the Operations support and resource required.',
        );
      }
      if (const <String>{
            'craneMovement',
            'assetRelocation',
          }.contains(operationsSupportTypeKey) &&
          cleanLocation == null) {
        throw const FormatException(
          'Movement support requires a destination or work location.',
        );
      }
    }

    return IssueCoordinationDraft._(
      purpose: purpose,
      condition:
          purpose == IssueCoordinationPurpose.deferment ? condition : null,
      conditionChargeNo: chargeNo,
      conditionRef:
          purpose == IssueCoordinationPurpose.deferment &&
                  condition == IssueCoordinationCondition.activityRef
              ? cleanConditionRef
              : null,
      defermentBasisKey:
          purpose == IssueCoordinationPurpose.deferment
              ? defermentBasisKey
              : null,
      operationsSupportTypeKey:
          purpose == IssueCoordinationPurpose.operationsSupport
              ? operationsSupportTypeKey
              : null,
      operationsResourceKey:
          purpose == IssueCoordinationPurpose.operationsSupport
              ? operationsResourceKey
              : null,
      requestedLocation:
          purpose == IssueCoordinationPurpose.operationsSupport
              ? cleanLocation
              : null,
      title: cleanTitle,
      description: cleanDescription,
      priorityKey: priorityKey,
    );
  }

  Map<String, Object?> toCommandPayload({
    required String ticketId,
    required int expectedTicketVersion,
    required String complianceId,
    String? originRoute,
  }) => <String, Object?>{
    'ticketId': ticketId,
    'expectedTicketVersion': expectedTicketVersion,
    'complianceId': complianceId,
    if (originRoute != null) 'originRoute': originRoute,
    'requestPurposeKey': purpose.name,
    'conditionTypeKey':
        purpose == IssueCoordinationPurpose.operationsSupport
            ? 'manual'
            : condition!.name,
    'conditionRef': conditionRef,
    'conditionChargeNo': conditionChargeNo,
    'defermentBasisKey': defermentBasisKey,
    'operationsSupportTypeKey': operationsSupportTypeKey,
    'operationsResourceKey': operationsResourceKey,
    'requestedLocation': requestedLocation,
    'title': title,
    'description': description,
    'priorityKey': priorityKey,
  };
}
