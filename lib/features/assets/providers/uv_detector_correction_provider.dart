import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers/durable_submission_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance_workflow/providers/workflow_providers.dart';
import '../services/uv_detector_correction_command_service.dart';
import '../repositories/uv_detector_correction_repository.dart';

final uvDetectorCorrectionRepositoryProvider =
    Provider<UvDetectorCorrectionRepository>(
      (ref) =>
          UvDetectorCorrectionRepository(firestore: FirebaseFirestore.instance),
    );

final uvDetectorCorrectionCommandServiceProvider =
    Provider<UvDetectorCorrectionCommandService>((ref) {
      return UvDetectorCorrectionCommandService(
        gateway: ref.read(originBoundWorkflowCommandGatewayProvider),
        durableStore: ref.watch(durableSubmissionRepositoryProvider),
        confirmReadback: ref
            .read(uvDetectorCorrectionRepositoryProvider)
            .confirmReadback,
        currentActorUid: () {
          final actor = ref.read(currentAppUserProvider);
          if (actor.isLoading ||
              actor.hasError ||
              actor.valueOrNull?.canAdjudicateFurnaceStuckup != true) {
            throw StateError(
              'An approved Admin or SI account is required for installation correction.',
            );
          }
          return actor.valueOrNull!.uid;
        },
      );
    });
