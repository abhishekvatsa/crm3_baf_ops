import 'package:firebase_core/firebase_core.dart';

import '../../features/abnormalities/services/charge_abnormality_command_service.dart';
import '../../features/maintenance_workflow/domain/workflow_error.dart';
import '../../features/maintenance_workflow/services/workflow_outbox_policy.dart';
import '../../features/planned_maintenance/services/runtime_job_module_population_service.dart';

class SyncFailureClassification {
  final String message;
  final String? errorCode;
  final bool isLikelyPermanent;

  const SyncFailureClassification({
    required this.message,
    required this.errorCode,
    required this.isLikelyPermanent,
  });
}

SyncFailureClassification classifySyncFailure(Object error) {
  final populationError =
      error is RuntimeJobModulePopulationException ? error : null;
  final abnormalityError =
      error is ChargeAbnormalityMutationException ? error : null;
  final workflowError = error is WorkflowException ? error : null;
  final firebaseError = error is FirebaseException ? error : null;
  final message =
      populationError?.operatorMessage ??
      abnormalityError?.operatorMessage ??
      workflowError?.message ??
      (firebaseError?.message?.trim().isNotEmpty == true
          ? firebaseError!.message!.trim()
          : error.toString());
  final errorCode =
      populationError?.code ??
      abnormalityError?.code ??
      workflowError?.code.name ??
      firebaseError?.code;
  final isLikelyPermanent =
      workflowError != null
          ? const WorkflowRetryPolicy().classify(workflowError) ==
              WorkflowRetryDisposition.reject
          : populationError?.isDurableRejection ??
              abnormalityError?.isDurableRejection ??
              (firebaseError != null &&
                  (firebaseError.code == 'permission-denied' ||
                      firebaseError.code == 'failed-precondition' ||
                      firebaseError.code == 'invalid-argument'));
  return SyncFailureClassification(
    message: message,
    errorCode: errorCode,
    isLikelyPermanent: isLikelyPermanent,
  );
}
