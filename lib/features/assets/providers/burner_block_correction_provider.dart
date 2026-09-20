import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers/durable_submission_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance_workflow/providers/workflow_providers.dart';
import '../services/burner_block_correction_command_service.dart';
import '../repositories/burner_block_correction_repository.dart';

final burnerBlockCorrectionRepositoryProvider =
    Provider<BurnerBlockCorrectionRepository>(
      (ref) => BurnerBlockCorrectionRepository(
        firestore: FirebaseFirestore.instance,
      ),
    );

final burnerBlockCorrectionCommandServiceProvider =
    Provider<BurnerBlockCorrectionCommandService>((ref) {
      return BurnerBlockCorrectionCommandService(
        gateway: ref.read(originBoundWorkflowCommandGatewayProvider),
        durableStore: ref.watch(durableSubmissionRepositoryProvider),
        confirmReadback: ref
            .read(burnerBlockCorrectionRepositoryProvider)
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
