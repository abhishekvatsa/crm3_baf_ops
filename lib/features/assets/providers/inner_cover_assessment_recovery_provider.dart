import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/release/command_capability_service.dart';
import '../../auth/domain/current_actor_access.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance_workflow/providers/workflow_providers.dart';
import '../services/inner_cover_assessment_recovery.dart';

final innerCoverAssessmentRecoveryProvider = Provider<InnerCoverAssessmentRecovery>((
  ref,
) {
  return InnerCoverAssessmentRecovery(
    repository: ref.watch(workflowRepositoryProvider),
    actor: () {
      final access = CurrentActorAccess.resolve(
        ref.read(currentAppUserProvider),
      );
      if (!access.isReady ||
          ref.read(firebaseAuthProvider).currentUser?.uid !=
              access.actor?.uid) {
        throw const InnerCoverRecoveryException(
          'Your approved account could not be verified. The original request remains saved.',
        );
      }
      return access.actor!;
    },
    requireCapability: (uid) async {
      await const CommandCapabilityService().requireCapabilities(
        callableName: 'executeMaintenanceWorkflowCommandV2',
        originActorUid: uid,
        requiredCapabilities: const {'savedSubmissionReview.v1'},
      );
    },
    invoke: (request) async {
      try {
        return (await FirebaseFunctions.instanceFor(region: 'asia-south1')
                .httpsCallable('executeMaintenanceWorkflowCommandV2')
                .call<Object?>(request))
            .data;
      } on FirebaseFunctionsException catch (error) {
        throw innerCoverRecoveryFailure(error, request);
      }
    },
  );
});

/// A blocked server feature is an explanation, never cancellation authority.
class InnerCoverRecoveryUnavailable extends InnerCoverRecoveryException {
  const InnerCoverRecoveryUnavailable({
    required this.actorUid,
    required this.caseId,
    required this.requestId,
    required this.evidenceSha256,
  }) : super(
         'Saved-assessment recovery is not available in this version. Your original request and assessment restriction remain saved. Ask an Admin to review the original records and contact the release administrator. No replacement has been created.',
       );
  final String actorUid;
  final String caseId;
  final String requestId;
  final String evidenceSha256;

  bool appliesTo(String? actor, String concern) =>
      actor == actorUid && concern == caseId;
}

InnerCoverRecoveryException innerCoverRecoveryFailure(
  FirebaseFunctionsException error,
  Map<String, Object?> request,
) {
  final details = error.details;
  final reason = details is Map ? details['reasonCode'] : null;
  final unavailable =
      (error.code == 'invalid-argument' &&
          reason == 'submission-recovery-request-invalid') ||
      (error.code == 'failed-precondition' &&
          reason == 'submission-recovery-finalization-not-activated');
  final recovery = request['recovery'];
  final evidence = recovery is Map ? recovery['assessmentEvidence'] : null;
  if (unavailable &&
      request['originActorUid'] is String &&
      recovery is Map &&
      recovery['requestId'] is String &&
      recovery['evidenceSha256'] is String &&
      evidence is Map &&
      evidence['aggregateId'] is String) {
    return InnerCoverRecoveryUnavailable(
      actorUid: request['originActorUid']! as String,
      caseId: evidence['aggregateId'] as String,
      requestId: recovery['requestId'] as String,
      evidenceSha256: recovery['evidenceSha256'] as String,
    );
  }
  return const InnerCoverRecoveryException(
    'The saved-request outcome could not be verified. Keep the original request and check again while connected; nothing has been replaced.',
  );
}
