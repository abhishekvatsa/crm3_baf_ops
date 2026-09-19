import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../maintenance_workflow/providers/workflow_providers.dart';
import '../services/burner_block_correction_command_service.dart';

final burnerBlockCorrectionCommandServiceProvider =
    Provider<BurnerBlockCorrectionCommandService>((ref) {
      return BurnerBlockCorrectionCommandService(
        gateway: ref.read(originBoundWorkflowCommandGatewayProvider),
        currentActorUid: () =>
            ref.read(firebaseAuthProvider).currentUser?.uid ?? '',
      );
    });
