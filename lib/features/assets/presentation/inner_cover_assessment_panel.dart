import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../maintenance_workflow/data/workflow_command_record.dart';
import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../../maintenance_workflow/presentation/screens/workflow_diagnostics_screen.dart';
import '../../maintenance_workflow/providers/workflow_providers.dart';
import '../../maintenance_workflow/repositories/workflow_repository.dart';
import '../../maintenance_workflow/services/workflow_command_factory.dart';
import '../data/furnace_stuckup_record.dart';
import '../providers/furnace_stuckup_provider.dart';
import '../providers/inner_cover_assessment_provider.dart';
import '../providers/inner_cover_assessment_recovery_provider.dart';
import '../services/inner_cover_assessment_recovery.dart';
import 'inner_cover_lifecycle_screen.dart';
import 'inner_cover_assessment_views.dart';

export 'inner_cover_assessment_views.dart'
    show InnerCoverAssessmentDialog, InnerCoverSavedRequestReviewDialog;

export '../providers/inner_cover_assessment_provider.dart'
    show InnerCoverAssessmentEvidence, innerCoverAssessmentEvidenceProvider;

/// Withdrawal retains the physical concern. This panel exposes the separate
/// governed technical decision and its real inspection prerequisites.
class InnerCoverAssessmentPanel extends ConsumerStatefulWidget {
  const InnerCoverAssessmentPanel({required this.record, super.key});
  final FurnaceStuckupRecord record;
  @override
  ConsumerState<InnerCoverAssessmentPanel> createState() =>
      _InnerCoverAssessmentPanelState();
}

class _InnerCoverAssessmentPanelState
    extends ConsumerState<InnerCoverAssessmentPanel> {
  WorkflowCommand? _pending;
  String? _pendingActorUid;
  bool _heldForReview = false;
  bool _busy = false;
  String? _failure;
  InnerCoverRecoveryUnavailable? _unavailableRecovery;

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final evidence = ref.watch(innerCoverAssessmentEvidenceProvider(record));
    return evidence.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: false,
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Checking the retained assessment…'),
      ),
      error: (_, _) => InnerCoverAssessmentEvidenceError(
        onRetry: () =>
            ref.invalidate(innerCoverAssessmentEvidenceProvider(record)),
      ),
      data: (data) {
        final currentRecord = data.currentRecord;
        if (!data.withdrawn) return const SizedBox.shrink();
        final settled = currentRecord.concernDisposition;
        if (settled != null) {
          if (!settled.matches(currentRecord, data.ticketVersion)) {
            return InnerCoverAssessmentMismatchedSummary(
              onCheck: () =>
                  ref.invalidate(innerCoverAssessmentEvidenceProvider(record)),
            );
          }
          return InnerCoverAssessmentSettledSummary(
            caseId: record.id,
            disposition: settled,
          );
        }
        final actor = ref.watch(innerCoverAssessmentActorReaderProvider)();
        final recoveryUnavailable =
            _unavailableRecovery?.appliesTo(actor?.uid, record.id) == true;
        final failure =
            _failure ??
            (recoveryUnavailable ? _unavailableRecovery?.message : null);
        final canSettle = actor?.canAdjudicateFurnaceStuckup == true;
        final sameActor = _pending == null || _pendingActorUid == actor?.uid;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            key: ValueKey('ic-assessment-retained-${record.id}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InnerCoverAssessmentGuidance(
                serialNumber: record.innerCoverSerialNumber,
                sameActor: sameActor,
                failure: failure,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => const InnerCoverLifecycleScreen(),
                            ),
                          ),
                    icon: const Icon(Icons.layers_outlined),
                    label: const Text('Open Inner Cover records'),
                  ),
                  if (canSettle &&
                      sameActor &&
                      !_heldForReview &&
                      (_pending != null ||
                          data.canUseAcceptance(currentRecord)))
                    FilledButton(
                      onPressed: _busy ? null : () => _settle(data),
                      key: ValueKey('ic-assessment-review-${record.id}'),
                      child: Text(
                        _busy
                            ? 'Checking…'
                            : _pending == null
                            ? 'Review assessment'
                            : 'Check saved assessment',
                      ),
                    ),
                  if (_pending != null || _heldForReview)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => ref.invalidate(
                              innerCoverAssessmentEvidenceProvider(record),
                            ),
                      child: const Text('Check current assessment'),
                    ),
                  if (_heldForReview)
                    InnerCoverSavedRequestReviewAction(
                      caseId: record.id,
                      isAdmin: actor?.isAdmin == true,
                      busy: _busy,
                      unavailable: recoveryUnavailable,
                      onInspect: _reviewSaved,
                    ),
                  if (_heldForReview &&
                      sameActor &&
                      actor?.canViewMaintenanceWorkflowDiagnostics == true)
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => WorkflowDiagnosticsScreen(
                                  aggregateId: currentRecord.id,
                                  commandTypeKey: WorkflowCommandType
                                      .settleInnerCoverAssessment
                                      .name,
                                ),
                              ),
                            ),
                      child: const Text('Review saved workflow action'),
                    ),
                ],
              ),
              if (canSettle &&
                  _pending == null &&
                  !data.canUseAcceptance(currentRecord))
                const Text(
                  'A current, unassigned cover with a recorded post-event acceptance is required before review.',
                ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _freshReviewAvailable(
    FurnaceStuckupRecord record,
    String originUid,
  ) async {
    setState(() => _busy = true);
    try {
      final repository = ref.read(workflowRepositoryProvider);
      if (repository is! WorkflowCommandJournalReader) {
        throw StateError('Complete saved assessment journal is unavailable.');
      }
      final saved = await (repository as WorkflowCommandJournalReader)
          .readUnsettledCommands(
            aggregateId: record.id,
            commandTypeKey: WorkflowCommandType.settleInnerCoverAssessment.name,
          );
      if (!mounted) return false;
      final actor = ref.read(innerCoverAssessmentActorReaderProvider)();
      if (actor?.uid != originUid ||
          actor?.canAdjudicateFurnaceStuckup != true) {
        setState(
          () => _failure =
              'The approved account changed during review. Nothing was sent. Open the assessment again from the intended account.',
        );
        return false;
      }
      var unresolved = false;
      for (final request in saved) {
        if (request.aggregateId != record.id ||
            request.commandTypeKey !=
                WorkflowCommandType.settleInnerCoverAssessment.name) {
          continue;
        }
        try {
          final status = await ref
              .read(innerCoverAssessmentRecoveryProvider)
              .status(request);
          if (!mounted) return false;
          if (!status.cancelled) unresolved = true;
          if (status.accepted) {
            ref.invalidate(innerCoverAssessmentEvidenceProvider(record));
          }
        } on InnerCoverRecoveryUnavailable catch (error) {
          if (!mounted) return false;
          setState(() {
            _heldForReview = true;
            _unavailableRecovery = error;
            _failure = null;
          });
          return false;
        } on Object {
          if (!mounted) return false;
          // Unavailable/legacy/malformed evidence proves no cancellation.
          unresolved = true;
        }
      }
      if (!mounted) return false;
      final afterStatusActor = ref.read(
        innerCoverAssessmentActorReaderProvider,
      )();
      if (afterStatusActor?.uid != originUid ||
          afterStatusActor?.canAdjudicateFurnaceStuckup != true) {
        return false;
      }
      if (unresolved) {
        setState(() {
          _heldForReview = true;
          _failure =
              'An earlier assessment request is still saved. Check the current assessment and review the saved workflow action with an Admin or SI. A replacement decision has not been created.';
        });
        return false;
      }
      return true;
    } on Object {
      if (mounted) {
        setState(
          () => _failure =
              'Saved assessment requests could not be checked. Nothing new was sent. Reconnect and try again before starting a new decision.',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reviewSaved() async {
    if (_busy) return;
    final actor = ref.read(innerCoverAssessmentActorReaderProvider)();
    if (actor?.isApproved != true || actor?.isAdmin != true) return;
    final uid = actor!.uid;
    if (_unavailableRecovery?.appliesTo(uid, widget.record.id) == true) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final repository = ref.read(workflowRepositoryProvider);
      if (repository is! WorkflowCommandJournalReader) {
        throw const InnerCoverRecoveryException(
          'Saved assessment records are unavailable. Keep the original request for review.',
        );
      }
      final rows = await (repository as WorkflowCommandJournalReader)
          .readUnsettledCommands(
            aggregateId: widget.record.id,
            commandTypeKey: WorkflowCommandType.settleInnerCoverAssessment.name,
          );
      if (!mounted) return;
      final service = ref.read(innerCoverAssessmentRecoveryProvider);
      WorkflowCommandRecord? saved;
      for (final row in rows) {
        if (row.aggregateId != widget.record.id ||
            row.commandTypeKey !=
                WorkflowCommandType.settleInnerCoverAssessment.name) {
          continue;
        }
        final status = await service.status(row);
        if (!mounted) return;
        if (status.accepted) {
          ref.invalidate(innerCoverAssessmentEvidenceProvider(widget.record));
          if (mounted) {
            setState(
              () => _failure =
                  'The server already accepted this request. Check the current assessment; no replacement was created.',
            );
          }
          return;
        }
        if (!status.cancelled) {
          saved = row;
          break;
        }
      }
      if (!mounted) return;
      if (saved == null) {
        setState(() {
          _heldForReview = false;
          _unavailableRecovery = null;
          _pending = null;
          _pendingActorUid = null;
          _failure =
              'Saved requests have verified closure. Review the current evidence before making a new assessment.';
        });
        ref.invalidate(innerCoverAssessmentEvidenceProvider(widget.record));
        return;
      }
      final reason = await showDialog<String>(
        context: context,
        builder: (_) =>
            InnerCoverSavedRequestReviewDialog(commandId: saved!.commandId),
      );
      if (!mounted || reason == null) return;
      final currentActor = ref.read(innerCoverAssessmentActorReaderProvider)();
      if (currentActor?.uid != uid ||
          currentActor?.isApproved != true ||
          currentActor?.isAdmin != true) {
        throw const InnerCoverRecoveryException(
          'The approved Admin account changed. Open this review again; nothing was replaced.',
        );
      }
      final inspection = await service.inspect(saved, reason);
      if (!mounted) return;
      var resolved = inspection;
      if (!inspection.resolved) {
        final adopt = inspection.receiptPresent;
        final approved = await showDialog<bool>(
          context: context,
          builder: (_) =>
              InnerCoverSavedRequestConfirmationDialog(adopt: adopt),
        );
        if (!mounted || approved != true) return;
        resolved = await service.finalize(inspection);
      }
      if (!mounted) return;
      setState(() {
        _unavailableRecovery = null;
        if (resolved.cancelled) {
          _heldForReview = false;
          _pending = null;
          _pendingActorUid = null;
        }
        _failure = resolved.cancelled
            ? 'The old request is permanently closed and retained. Check the current evidence, then choose Review assessment to make a fresh decision.'
            : 'The server verified the accepted result. Check the current assessment; no replacement was created.';
      });
      ref.invalidate(innerCoverAssessmentEvidenceProvider(widget.record));
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          if (error is InnerCoverRecoveryUnavailable) {
            _unavailableRecovery = error;
          }
          _failure = error is InnerCoverRecoveryUnavailable
              ? null
              : error is InnerCoverRecoveryException
              ? error.message
              : 'The saved request could not be reviewed safely. Keep it and try again while connected; nothing was replaced.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _settle(InnerCoverAssessmentEvidence evidence) async {
    if (_busy || _heldForReview) return;
    final actor = ref.read(innerCoverAssessmentActorReaderProvider)();
    if (actor?.canAdjudicateFurnaceStuckup != true ||
        (_pending != null && _pendingActorUid != actor!.uid)) {
      return;
    }
    final originUid = actor!.uid;
    final record = evidence.currentRecord;
    if (_pending == null) {
      if (!await _freshReviewAvailable(record, originUid)) return;
      if (!mounted) return;
      final reason = await showDialog<String>(
        context: context,
        builder: (_) => InnerCoverAssessmentDialog(
          record: record,
          acceptanceReference:
              evidence.profile.acceptanceReference ?? 'Recorded acceptance',
        ),
      );
      if (!mounted || reason == null) return;
      final currentActor = ref.read(innerCoverAssessmentActorReaderProvider)();
      if (currentActor?.uid != originUid ||
          currentActor?.canAdjudicateFurnaceStuckup != true) {
        setState(
          () => _failure =
              'The approved account changed during review. Nothing was sent. Open the assessment again from the intended account.',
        );
        return;
      }
      if (!await _freshReviewAvailable(record, originUid)) return;
      if (!mounted) return;
      _pendingActorUid = originUid;
      _pending = WorkflowCommandFactory.create(
        type: WorkflowCommandType.settleInnerCoverAssessment,
        aggregateId: record.id,
        expectedVersion: record.version,
        payload: {
          'innerCoverId': record.innerCoverId,
          'innerCoverSerialNumber': record.innerCoverSerialNumber,
          'eventLinkageId': record.innerCoverLinkageId,
          'expectedTicketVersion': evidence.ticketVersion,
          'expectedCoverVersion': evidence.profile.version,
          'acceptanceRequestId': evidence.profile.lastMutationId,
          'assessorConfirmed': true,
          'reason': reason,
        },
      );
    }
    final command = _pending!;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref
          .read(workflowOnlineExecutorProvider)
          .execute(
            command,
            validateReceipt: (receipt) {
              if (receipt.commandId != command.commandId ||
                  receipt.resultKey != 'inner-cover-assessment-settled' ||
                  receipt.aggregateVersion != command.expectedVersion + 1 ||
                  receipt.result['caseId'] != record.id) {
                throw StateError(
                  'The settlement receipt does not match this assessment.',
                );
              }
            },
          );
      if (!mounted) return;
      final savedRecord = await ref.read(innerCoverAssessmentReadbackProvider)(
        record.id,
      );
      if (!mounted) return;
      final disposition = savedRecord.concernDisposition;
      if (disposition?.commandId != command.commandId ||
          disposition?.matches(savedRecord, evidence.ticketVersion) != true) {
        throw StateError(
          'The saved assessment could not yet be verified. Check it again.',
        );
      }
      ref.invalidate(furnaceStuckupCasesProvider);
      ref.invalidate(furnaceStuckupCaseBatchProvider);
      if (!mounted) return;
      setState(() {
        _pending = null;
        _pendingActorUid = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assessment settled. Original history retained.'),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      var heldForReview = false;
      try {
        final retained = await ref
            .read(workflowRepositoryProvider)
            .getRetryCommand(command.commandId);
        heldForReview =
            retained?.stateKey == 'manualReview' ||
            retained?.stateKey == 'rejected';
      } on Object {
        // An unreadable journal cannot establish a terminal outcome.
      }
      debugPrint('Assessment request ${command.commandId} retained: $error');
      if (mounted) {
        setState(() {
          _heldForReview = heldForReview;
          _failure = heldForReview
              ? 'This saved request needs an Admin or SI review. Its outcome has not been replaced. Check the current assessment, then review the saved workflow action and original records before attempting a new decision.'
              : 'The assessment outcome is not yet confirmed. The original request is retained. Check it again while connected using the same approved account.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
