import 'dart:convert';

import '../data/job_module_model.dart';
import 'planned_job_closure_attestation.dart';

/// Pure planned-job closure guard used before marking a JobExecution complete.
///
/// This is deliberately local/app-side. Firestore rules cannot safely query all
/// top-level job_modules for a JobExecution, so true server-side closure truth
/// remains a schema/function-stage issue. Keeping this guard pure makes the
/// current app invariant testable without Isar/Firebase.
class PlannedJobClosureGuard {
  const PlannedJobClosureGuard._();

  static List<PlannedJobClosureIssue> collectIssues(
    List<JobModuleInstance> modules,
  ) {
    final activeModules = modules.where((module) => !module.isDeleted).toList();
    if (activeModules.isEmpty) return const <PlannedJobClosureIssue>[];

    final requiredModules =
        activeModules.where((module) => module.requiredForClosure).toList();
    if (requiredModules.isEmpty) return const <PlannedJobClosureIssue>[];

    final openRequiredModules =
        requiredModules
            .where((module) => _isOpenRequiredClosureStatus(module.status))
            .toList();
    final waitingAcceptanceModules =
        requiredModules
            .where((module) => module.status == JobModuleStatus.submitted)
            .toList();
    final missingResponseModules =
        requiredModules
            .where(
              (module) =>
                  module.status != JobModuleStatus.notApplicable &&
                  _moduleMissingRequiredClosureEvidence(module),
            )
            .toList();
    final attentionModules =
        requiredModules
            .where(
              (module) =>
                  module.requiresFollowUp ||
                  (module.pendingIssue != null &&
                      module.pendingIssue!.trim().isNotEmpty),
            )
            .toList();

    return <PlannedJobClosureIssue>[
      if (openRequiredModules.isNotEmpty)
        PlannedJobClosureIssue(
          type: PlannedJobClosureIssueType.openRequiredModule,
          count: openRequiredModules.length,
          message:
              '${openRequiredModules.length} required module(s) still open',
          moduleFirestoreIds: _moduleFirestoreIds(openRequiredModules),
        ),
      if (waitingAcceptanceModules.isNotEmpty)
        PlannedJobClosureIssue(
          type: PlannedJobClosureIssueType.waitingAcceptance,
          count: waitingAcceptanceModules.length,
          message:
              '${waitingAcceptanceModules.length} required module(s) submitted but not accepted',
          moduleFirestoreIds: _moduleFirestoreIds(waitingAcceptanceModules),
        ),
      if (missingResponseModules.isNotEmpty)
        PlannedJobClosureIssue(
          type: PlannedJobClosureIssueType.missingRequiredEvidence,
          count: missingResponseModules.length,
          message:
              '${missingResponseModules.length} required module(s) missing required evidence',
          moduleFirestoreIds: _moduleFirestoreIds(missingResponseModules),
        ),
      if (attentionModules.isNotEmpty)
        PlannedJobClosureIssue(
          type: PlannedJobClosureIssueType.pendingIssueOrFollowUp,
          count: attentionModules.length,
          message:
              '${attentionModules.length} required module(s) with pending issue/follow-up',
          moduleFirestoreIds: _moduleFirestoreIds(attentionModules),
        ),
    ];
  }

  static void assertReady(List<JobModuleInstance> modules) {
    _throwIfIssues(collectIssues(modules));
  }

  static PlannedJobClosureAttestation assertReadyAndAttest({
    required String? executionFirestoreId,
    required List<JobModuleInstance> modules,
    required String completedByUid,
    required String? completedByName,
    required DateTime completedAt,
    required int executionVersionAtCompletion,
  }) {
    final issues = collectIssues(modules);
    _throwIfIssues(issues);

    return PlannedJobClosureAttestation.build(
      executionFirestoreId: executionFirestoreId,
      modules: modules,
      completedByUid: completedByUid,
      completedByName: completedByName,
      completedAt: completedAt,
      executionVersionAtCompletion: executionVersionAtCompletion,
      guardIssueCounts: _issueCountsByType(issues),
    );
  }

  static void _throwIfIssues(List<PlannedJobClosureIssue> issues) {
    if (issues.isEmpty) return;

    throw StateError(
      'Cannot complete planned job: required closure modules are not ready (${issues.map((issue) => issue.message).join('; ')}).',
    );
  }

  static Map<String, int> _issueCountsByType(
    List<PlannedJobClosureIssue> issues,
  ) {
    final counts = <String, int>{
      for (final type in PlannedJobClosureIssueType.values) type.name: 0,
    };

    for (final issue in issues) {
      counts[issue.type.name] = issue.count;
    }

    return counts;
  }

  static bool isReady(List<JobModuleInstance> modules) {
    return collectIssues(modules).isEmpty;
  }

  static List<String> _moduleFirestoreIds(List<JobModuleInstance> modules) {
    return modules
        .map((module) => module.firestoreId?.trim())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toList(growable: false);
  }

  static bool _isOpenRequiredClosureStatus(JobModuleStatus status) {
    return status == JobModuleStatus.notStarted ||
        status == JobModuleStatus.draftSaved ||
        status == JobModuleStatus.inProgress ||
        status == JobModuleStatus.reopened;
  }

  static bool _moduleMissingRequiredClosureEvidence(JobModuleInstance module) {
    final definitions = _moduleFieldDefinitions(module.fieldDefinitionsJson);
    final ordinaryRequiredKeys =
        definitions
            .where(
              (definition) =>
                  _fieldDefinitionRequired(definition) &&
                  !_isSafetyGateDefinition(definition),
            )
            .map(_fieldDefinitionKey)
            .where((key) => key != null && key.isNotEmpty)
            .cast<String>()
            .toList();

    final responsesByKey = {
      for (final response in module.responses) response.key: response.value,
    };

    if (ordinaryRequiredKeys.isNotEmpty) {
      return ordinaryRequiredKeys.any(
        (key) => !_hasEvidenceValue(responsesByKey[key]),
      );
    }

    final hasAnyOrdinaryField = definitions.any(
      (definition) => !_isSafetyGateDefinition(definition),
    );
    if (hasAnyOrdinaryField) return !module.hasResponses;
    return false;
  }

  static List<Map<String, dynamic>> _moduleFieldDefinitions(String jsonText) {
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static bool _fieldDefinitionRequired(Map<String, dynamic> definition) {
    return definition['required'] == true || definition['isRequired'] == true;
  }

  static String? _fieldDefinitionKey(Map<String, dynamic> definition) {
    for (final key in ['fieldId', 'key', 'id', 'name']) {
      final raw = definition[key];
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    }
    return null;
  }

  static bool _isSafetyGateDefinition(Map<String, dynamic> definition) {
    final raw = definition['type'] ?? definition['fieldType'] ?? '';
    final key = raw.toString().trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '',
    );
    return key == 'safetygate' || key == 'safetyconfirmation';
  }

  static bool _hasEvidenceValue(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    return true;
  }
}

enum PlannedJobClosureIssueType {
  openRequiredModule,
  waitingAcceptance,
  missingRequiredEvidence,
  pendingIssueOrFollowUp,
}

class PlannedJobClosureIssue {
  final PlannedJobClosureIssueType type;
  final int count;
  final String message;
  final List<String> moduleFirestoreIds;

  const PlannedJobClosureIssue({
    required this.type,
    required this.count,
    required this.message,
    this.moduleFirestoreIds = const <String>[],
  });
}
