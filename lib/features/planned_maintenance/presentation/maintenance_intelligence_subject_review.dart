part of 'maintenance_intelligence_screen.dart';

Future<void> _reviewPlanSubject(
  BuildContext context,
  WidgetRef ref,
  MaintenancePlan plan,
) async {
  var accepted = false;
  try {
    final subject = await ref
        .read(assetHierarchyRepositoryProvider)
        .readInnerCoverFromServer(plan.assetInstanceId);
    if (!context.mounted) return;
    if (subject.assetClassId != plan.assetClassId ||
        plan.assetInstanceName != 'Inner Cover ${subject.serialNumber}' ||
        subject.version <= plan.assetInstanceVersion) {
      throw StateError(
        'The plan already uses this cover revision, or its exact identity needs investigation.',
      );
    }
    final reason = await showMaintenancePlanSubjectReview(
      context,
      plan: plan,
      subject: subject,
    );
    if (reason == null || !context.mounted) return;
    final command = WorkflowCommand(
      commandId: 'setMaintenancePlanStatus_${const Uuid().v4()}',
      type: WorkflowCommandType.setMaintenancePlanStatus,
      aggregateId: plan.id,
      expectedVersion: plan.version,
      payload: maintenancePlanSubjectReviewPayload(subject, reason),
    );
    final receipt = await ref
        .read(workflowCommandControllerProvider.notifier)
        .execute(command, refreshProjections: false);
    if (receipt.commandId != command.commandId ||
        receipt.resultKey != 'maintenance-plan-subject-revalidated' ||
        receipt.aggregateVersion != plan.version + 1 ||
        receipt.result['planId'] != plan.id ||
        receipt.result['status'] != 'ready' ||
        receipt.result['assetInstanceVersion'] != subject.version ||
        receipt.result['auditId'] != command.commandId) {
      throw StateError('The plan review receipt could not be verified.');
    }
    accepted = true;
    final current = await ref
        .read(maintenanceIntelligenceRepositoryProvider)
        .readPlanFromServer(plan.id);
    if (current.version < receipt.aggregateVersion ||
        current.assetInstanceId != plan.assetInstanceId ||
        current.assetClassId != plan.assetClassId ||
        current.assetInstanceVersion < subject.version) {
      throw StateError(
        'The reviewed plan revision has not reached this device.',
      );
    }
    ref.invalidate(maintenancePlansProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Plan subject review recorded. Completion remains a separate action.',
        ),
        backgroundColor: BafColors.sync,
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          accepted
              ? 'Review accepted, but the current plan could not be verified: $error'
              : 'Plan review could not be confirmed: $error',
        ),
        backgroundColor: BafColors.danger,
      ),
    );
  }
}

/// The exact snapshot the reviewer saw travels inside the command fingerprint.
Map<String, Object?> maintenancePlanSubjectReviewPayload(
  InnerCoverProfile subject,
  String reason,
) => {
  'status': 'ready',
  'executionId': null,
  'reason': reason.trim(),
  'revalidation': {
    'assetClassId': subject.assetClassId,
    'assetInstanceId': subject.id,
    'assetInstanceVersion': subject.version,
    'serialNumber': subject.serialNumber,
    'lifecycleState': subject.lifecycleState.name,
    'currentBaseAssetInstanceId': subject.currentBaseAssetInstanceId,
    'currentBaseAssetNumber': subject.currentBaseAssetNumber,
  },
};

Future<String?> showMaintenancePlanSubjectReview(
  BuildContext context, {
  required MaintenancePlan plan,
  required InnerCoverProfile subject,
}) async {
  final reason = TextEditingController();
  final form = GlobalKey<FormState>();
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Review current cover for this plan'),
      content: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${plan.assetInstanceName} · ${plan.maintenanceClass.title}',
              ),
              const SizedBox(height: BafSpacing.sm),
              Text(
                'Plan cover revision: ${plan.assetInstanceVersion}\n'
                'Current cover revision: ${subject.version}\n'
                'Serial: ${subject.serialNumber}\nState: ${subject.lifecycleState.label}\n'
                'Current Base: ${subject.currentBaseAssetNumber?.toString() ?? 'Not linked'}',
              ),
              const SizedBox(height: BafSpacing.sm),
              const Text(
                'Confirm that this plan still applies to the same cover in its current condition. '
                'This records your review; it does not complete maintenance or change cover availability.',
              ),
              const SizedBox(height: BafSpacing.sm),
              TextFormField(
                controller: reason,
                decoration: const InputDecoration(labelText: 'Review reason'),
                maxLines: 3,
                maxLength: 500,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Explain why this plan still applies.'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(dialogContext, reason.text.trim());
            }
          },
          child: const Text('Record subject review'),
        ),
      ],
    ),
  );
  // Dialog route animations may still own the controller for this frame.
  WidgetsBinding.instance.addPostFrameCallback((_) => reason.dispose());
  return result;
}
