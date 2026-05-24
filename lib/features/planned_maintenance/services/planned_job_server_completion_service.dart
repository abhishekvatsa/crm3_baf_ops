import 'package:cloud_functions/cloud_functions.dart';

import '../data/job_template_model.dart';
import '../models/component_action_model.dart';

/// Stable callable name used for planned-job completion.
///
/// Issue 63 keeps the callable name stable while moving the callable to the
/// Firestore database region.
const plannedJobCompletionCallableName = 'completePlannedJobExecution';

/// Callable region for planned-job completion.
///
/// Firestore is in asia-south1 and this development build has no old tablets
/// to support, so the app calls the final target region directly.
const plannedJobCompletionCallableRegion = 'asia-south1';

/// Trusted server-side planned-job completion gateway.
///
/// M6 full enforcement deliberately routes final JobExecution completion through
/// a Cloud Function. Firestore rules deny direct client completion because rules
/// cannot query all top-level job_modules for the execution being closed.
///
/// The function validates authority and module readiness on the server, writes
/// the completion with Admin SDK, emits the remote audit log, and returns the
/// canonical updated JobExecution document for local rebase.
class PlannedJobServerCompletionService {
  final FirebaseFunctions? _functions;

  PlannedJobServerCompletionService({FirebaseFunctions? functions})
    : _functions = functions;

  FirebaseFunctions get _client =>
      _functions ??
      FirebaseFunctions.instanceFor(region: plannedJobCompletionCallableRegion);

  Future<JobExecution> completeExecution({
    required String executionFirestoreId,
    String? remarks,
    List<String>? teamsInvolved,
    List<FieldResponse>? responses,
    List<ComponentAction>? actions,
    int? expectedCompletionVersion,
  }) async {
    final callable = _client.httpsCallable(plannedJobCompletionCallableName);

    try {
      final result = await callable.call(<String, dynamic>{
        'executionId': executionFirestoreId,
        if (remarks != null) 'remarks': remarks,
        if (teamsInvolved != null) 'teamsInvolved': teamsInvolved,
        if (responses != null)
          'responses': responses.map((response) => response.toMap()).toList(),
        if (actions != null)
          'actions': actions.map((action) => action.toMap()).toList(),
        if (expectedCompletionVersion != null)
          'expectedCompletionVersion': expectedCompletionVersion,
      });

      final raw = result.data;
      if (raw is! Map) {
        throw StateError('Server completion returned an invalid response.');
      }

      final executionRaw = raw['execution'];
      if (executionRaw is! Map) {
        throw StateError('Server completion did not return an execution.');
      }

      final executionData = Map<String, dynamic>.from(executionRaw);
      final firestoreId =
          executionData['firestoreId'] is String
              ? executionData['firestoreId'] as String
              : executionFirestoreId;

      return JobExecution.fromMap(executionData, firestoreId);
    } on FirebaseFunctionsException catch (error) {
      throw PlannedJobServerCompletionException.fromFirebase(error);
    }
  }
}

/// Base typed wrapper for Cloud Function completion failures.
///
/// The service deliberately converts FirebaseFunctionsException into app-owned
/// exceptions so UI layers can render operator-friendly messages without
/// parsing plugin exception text.
class PlannedJobServerCompletionException implements Exception {
  final String code;
  final String message;
  final Object? details;

  const PlannedJobServerCompletionException({
    required this.code,
    required this.message,
    this.details,
  });

  factory PlannedJobServerCompletionException.fromFirebase(
    FirebaseFunctionsException error,
  ) {
    final message =
        _cleanMessage(error.message) ??
        'Server-side planned-job completion failed.';
    final details = error.details;

    final closureGate = PlannedJobServerClosureGateException.tryParse(
      code: error.code,
      message: message,
      details: details,
    );
    if (closureGate != null) return closureGate;

    return PlannedJobServerCompletionException(
      code: error.code,
      message: message,
      details: details,
    );
  }

  String get operatorMessage {
    switch (code) {
      case 'unauthenticated':
        return 'Sign in again before completing this planned job.';
      case 'permission-denied':
        return 'You are not authorized to complete this planned job.';
      case 'not-found':
        return 'The server could not find this planned job. Pull latest data and try again.';
      case 'failed-precondition':
        return message;
      case 'invalid-argument':
        return message;
      case 'unavailable':
      case 'deadline-exceeded':
        return 'The server could not be reached. Check network connectivity and try again.';
      default:
        return message;
    }
  }

  @override
  String toString() => operatorMessage;
}

/// Typed server-side closure gate rejection.
///
/// The callable returns failed-precondition with `details.issues` when canonical
/// remote modules are not ready. This class preserves those issues so the UI can
/// show the same closure-gate style guidance it uses for local preflight.
class PlannedJobServerClosureGateException
    extends PlannedJobServerCompletionException {
  final List<PlannedJobServerClosureIssue> issues;

  const PlannedJobServerClosureGateException({
    required super.message,
    required this.issues,
    super.details,
  }) : super(code: 'failed-precondition');

  static PlannedJobServerClosureGateException? tryParse({
    required String code,
    required String message,
    Object? details,
  }) {
    if (code != 'failed-precondition') return null;

    final issuesRaw = _detailsMap(details)?['issues'];
    if (issuesRaw is! List) return null;

    final issues = issuesRaw
        .whereType<Map>()
        .map((issue) => PlannedJobServerClosureIssue.fromMap(issue))
        .where((issue) => issue.count > 0 || issue.message.trim().isNotEmpty)
        .toList(growable: false);

    if (issues.isEmpty) return null;

    return PlannedJobServerClosureGateException(
      message: message,
      issues: issues,
      details: details,
    );
  }

  String get blockingMessage {
    final lines = <String>[
      'The server rechecked canonical remote modules and blocked final closure:',
    ];

    for (final issue in issues) {
      final count = issue.count > 0 ? ' (${issue.count})' : '';
      lines.add('• ${issue.message}$count');
      if (issue.moduleFirestoreIds.isNotEmpty) {
        lines.add('  Modules: ${issue.moduleFirestoreIds.take(8).join(', ')}');
        if (issue.moduleFirestoreIds.length > 8) {
          lines.add('  +${issue.moduleFirestoreIds.length - 8} more');
        }
      }
    }

    lines.add('');
    lines.add(
      'Pull latest data, review the listed modules, then try completion again.',
    );
    return lines.join('\n');
  }

  @override
  String get operatorMessage =>
      'Server closure gate blocked final completion. Review required modules.';
}

class PlannedJobServerClosureIssue {
  final String type;
  final int count;
  final String message;
  final List<String> moduleFirestoreIds;

  const PlannedJobServerClosureIssue({
    required this.type,
    required this.count,
    required this.message,
    this.moduleFirestoreIds = const <String>[],
  });

  factory PlannedJobServerClosureIssue.fromMap(Map<dynamic, dynamic> map) {
    final rawIds = map['moduleFirestoreIds'];
    return PlannedJobServerClosureIssue(
      type: _cleanString(map['type']) ?? 'unknown',
      count: _cleanInt(map['count']),
      message: _cleanString(map['message']) ?? 'Server closure issue',
      moduleFirestoreIds:
          rawIds is List
              ? rawIds
                  .map((id) => id.toString().trim())
                  .where((id) => id.isNotEmpty)
                  .toList(growable: false)
              : const <String>[],
    );
  }
}

Map<dynamic, dynamic>? _detailsMap(Object? details) {
  if (details is Map) return details;
  return null;
}

String? _cleanMessage(String? value) => _cleanString(value);

String? _cleanString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int _cleanInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
