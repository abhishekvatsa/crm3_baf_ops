import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/user_model.dart';
import '../../../auth/domain/current_actor_access.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../auth/presentation/current_actor_gate.dart';
import '../../data/template_governance_model.dart';
import '../../domain/template_closure_review.dart';
import '../../domain/template_version_snapshot_contract.dart';

Future<bool> reviewTemplateClosureBeforePublication(
  BuildContext context,
  TemplateVersion version,
  AppUser actor,
) async {
  requireCurrentTemplateReviewer(context, actor.uid);
  version.refreshClosureReviewStateFromSnapshots();
  if (version.closureCriticalModuleCount == 0 ||
      version.closureReviewConfirmed) {
    return true;
  }
  if (!actor.canPublishTemplateVersion) {
    throw StateError('Approved template review authority is required.');
  }
  final bundle = TemplateVersionSnapshotBundle.fromRawJson(
    jobTemplateSnapshotJson: version.jobTemplateSnapshotJson,
    moduleSnapshotsJson: version.moduleSnapshotsJson,
    fieldDefinitionsJson: version.fieldDefinitionsJson,
    checklistJson: version.checklistJson,
  );
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => CurrentActorDialogGuard(
      originUid: actor.uid,
      permission: (current) => current.canPublishTemplateVersion,
      child: AlertDialog(
        title: const Text('Review closure requirements'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Review the required work for version ${version.versionNumber}. Your confirmation records a new review; the earlier version keeps its original review.',
              ),
              const SizedBox(height: 12),
              for (final module in bundle.moduleSnapshots.where(
                TemplateVersionSnapshotBundle.moduleRequiredForClosure,
              )) ...[
                Text(
                  TemplateVersionSnapshotBundle.moduleTitle(
                    module,
                    bundle.moduleSnapshots.indexOf(module),
                  ),
                ),
                for (final field in bundle.fieldsForModule(module))
                  Text(
                    '• ${field['label'] ?? field['key']}${field['isRequired'] == true ? ' (required)' : ''}',
                  ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-template-closure-review'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm review and publish'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || confirmed != true) return false;
  final reviewer = requireCurrentTemplateReviewer(context, actor.uid);
  confirmTemplateClosureReview(
    version,
    actorUid: reviewer.uid,
    actorName: reviewer.name,
    confirmedAt: DateTime.now(),
  );
  return true;
}

AppUser requireCurrentTemplateReviewer(BuildContext context, String originUid) {
  final current = CurrentActorAccess.resolve(
    ProviderScope.containerOf(
      context,
      listen: false,
    ).read(currentAppUserProvider),
  ).actor;
  if (current?.uid != originUid || current?.canPublishTemplateVersion != true) {
    throw StateError(
      'Verify the original approved reviewer before publishing.',
    );
  }
  return current!;
}
