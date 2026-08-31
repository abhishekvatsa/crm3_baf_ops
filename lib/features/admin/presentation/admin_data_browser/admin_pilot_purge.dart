import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/sync_coordinator.dart';
import '../../../../core/services/local_sync_recovery_service.dart';
import '../../../../core/theme/baf_design_system.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../maintenance_workflow/domain/workflow_types.dart';
import '../../../maintenance_workflow/providers/workflow_providers.dart';
import '../../../maintenance_workflow/services/workflow_command_factory.dart';
import 'admin_data_browser_shared.dart';

class PilotPurgeTarget {
  final String collectionId;
  final String documentId;
  final int expectedVersion;
  final String recordLabel;

  const PilotPurgeTarget({
    required this.collectionId,
    required this.documentId,
    required this.expectedVersion,
    required this.recordLabel,
  });

  String get selectionKey => '$collectionId/$documentId';
}

Future<bool> executePilotBusinessRecordPurge({
  required WidgetRef ref,
  required PilotPurgeTarget target,
  required String reason,
  bool resumeSyncAfterCleanup = true,
}) async {
  final actor = ref.read(currentAppUserProvider).value;
  if (actor == null || !actor.isApproved || !actor.isAdmin) {
    throw StateError('Fresh Admin authority is required for permanent removal.');
  }
  final command = WorkflowCommandFactory.create(
    type: WorkflowCommandType.purgePilotBusinessRecord,
    aggregateId: target.documentId,
    expectedVersion: target.expectedVersion,
    payload: <String, Object?>{
      'collectionId': target.collectionId,
      'documentId': target.documentId,
      'reason': reason,
      'confirmation': 'DELETE ${target.documentId}',
    },
  );
  final receipt = await ref
      .read(workflowCommandControllerProvider.notifier)
      .execute(command);
  return ref
      .read(syncCoordinatorProvider)
      .runWithSyncPaused(
        reason: 'admin_pilot_record_purged',
        resumeSyncAfterRecovery: resumeSyncAfterCleanup,
        operation:
            () => ref
                .read(localSyncRecoveryServiceProvider)
                .removeAuthoritativelyPurgedTombstone(
                  actor: actor,
                  receipt: receipt,
                  collectionId: target.collectionId,
                  documentId: target.documentId,
                ),
      );
}

Future<bool> purgePilotBusinessRecord({
  required BuildContext context,
  required WidgetRef ref,
  required String collectionId,
  required String documentId,
  required int expectedVersion,
  required String recordLabel,
}) async {
  final actor = ref.read(currentAppUserProvider).value;
  if (actor == null || !actor.isApproved || !actor.isAdmin) {
    showAdminDataSnack(
      context,
      'Fresh Admin authority is required for permanent removal.',
      color: BafColors.danger,
    );
    return false;
  }

  final decision = await showDialog<_PilotPurgeDecision>(
    context: context,
    barrierDismissible: false,
    builder:
        (_) => _PilotPurgeDialog(
          recordLabel: recordLabel,
          confirmation: 'DELETE $documentId',
        ),
  );
  if (decision == null || !context.mounted) return false;

  try {
    final removedLocally = await executePilotBusinessRecordPurge(
      ref: ref,
      target: PilotPurgeTarget(
        collectionId: collectionId,
        documentId: documentId,
        expectedVersion: expectedVersion,
        recordLabel: recordLabel,
      ),
      reason: decision.reason,
    );
    if (!context.mounted) return true;
    showAdminDataSnack(
      context,
      removedLocally
          ? '$recordLabel was permanently removed. An immutable purge receipt was retained.'
          : '$recordLabel was removed on the server. Its protected local copy will reconcile on the next sync.',
      color: BafColors.success,
    );
    return true;
  } catch (error) {
    if (!context.mounted) return false;
    showAdminDataSnack(
      context,
      'Permanent removal was refused: $error',
      color: BafColors.danger,
    );
    return false;
  }
}

class _PilotPurgeDecision {
  final String reason;
  final String confirmation;

  const _PilotPurgeDecision({required this.reason, required this.confirmation});
}

class _PilotPurgeDialog extends StatefulWidget {
  final String recordLabel;
  final String confirmation;

  const _PilotPurgeDialog({
    required this.recordLabel,
    required this.confirmation,
  });

  @override
  State<_PilotPurgeDialog> createState() => _PilotPurgeDialogState();
}

class _PilotPurgeDialogState extends State<_PilotPurgeDialog> {
  final _reason = TextEditingController();
  final _confirmation = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Permanently remove pilot record'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.recordLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: BafSpacing.sm),
              const Text(
                'This removes only an already-deleted pilot record. The action cannot be undone, is authority-checked by the server, and leaves an immutable receipt.',
                style: TextStyle(color: BafColors.textSecondary, height: 1.35),
              ),
              const SizedBox(height: BafSpacing.md),
              TextField(
                controller: _reason,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'State why this pilot record must be removed.',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              SelectableText(
                widget.confirmation,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: BafSpacing.xs),
              TextField(
                controller: _confirmation,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Type the confirmation exactly',
                  border: const OutlineInputBorder(),
                  errorText: _error,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: BafColors.danger),
          onPressed: _submit,
          icon: const Icon(Icons.delete_forever_rounded),
          label: const Text('Remove permanently'),
        ),
      ],
    );
  }

  void _submit() {
    final reason = _reason.text.trim();
    final confirmation = _confirmation.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Enter a reason for this purge.');
      return;
    }
    if (confirmation != widget.confirmation) {
      setState(() => _error = 'The confirmation text does not match.');
      return;
    }
    Navigator.pop(
      context,
      _PilotPurgeDecision(reason: reason, confirmation: confirmation),
    );
  }
}
