import 'workflow_error.dart';

class WorkflowActorContext {
  final String uid;
  final String displayName;
  final Set<String> roleKeys;

  WorkflowActorContext({
    required String uid,
    required String displayName,
    Iterable<String> roleKeys = const <String>[],
  }) : uid = uid.trim(),
       displayName = displayName.trim(),
       roleKeys = Set.unmodifiable(
         roleKeys.map((value) => value.trim()).where((value) => value.isNotEmpty),
       ) {
    if (this.uid.isEmpty) {
      throw const WorkflowException(
        WorkflowErrorCode.unauthenticated,
        'Workflow actor UID is required.',
      );
    }
  }

  bool hasAnyRole(Iterable<String> allowed) => allowed.any(roleKeys.contains);
}
