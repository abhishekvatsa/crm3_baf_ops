import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/release/command_capability_service.dart';
import '../../maintenance_workflow/services/workflow_command_gateway.dart';

/// A fresh server deployment check for each explicit send/retry. No cached
/// capability grants permission to introduce a shape older readers cannot use.
final inspectionTargetContextCapabilityProvider =
    Provider<Future<void> Function(String)>((ref) {
      const service = CommandCapabilityService();
      return (originUid) async {
        await service.requireCapabilities(
          callableName: maintenanceWorkflowV2CallableName,
          originActorUid: originUid,
          requiredCapabilities: const {
            'maintenanceWorkflow.v2',
            'inspectionTargetContextRevalidation.v1',
          },
        );
      };
    });
