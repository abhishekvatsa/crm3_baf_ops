import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/durable_submission_repository.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../auth/domain/current_actor_access.dart';
import '../../auth/presentation/current_actor_gate.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/maintenance_model.dart';
import '../domain/maintenance_creation_successor_review.dart';
import '../providers/maintenance_creation_successor_provider.dart';
import 'maintenance_ticket_correction_dialog.dart';

/// A pending device row is not authority to change the accepted issue.
class MaintenanceCreationSuccessorReviewPanel extends ConsumerWidget {
  const MaintenanceCreationSuccessorReviewPanel({
    super.key,
    required this.ticket,
  });

  final MaintenanceRecord ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketId = ticket.firestoreId?.trim();
    if (ticket.isSynced || ticketId == null || ticketId.isEmpty) {
      return const SizedBox.shrink();
    }
    final actor = CurrentActorAccess.resolve(
      ref.watch(currentAppUserProvider),
    ).actor;
    if (actor == null ||
        (!actor.canCorrectMaintenanceTicket &&
            actor.uid != ticket.loggedByUid)) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.all(BafSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pending device changes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: BafSpacing.sm),
            const Text(
              'Saved device changes remain pending. Admin or SI can compare them with the accepted issue and current server record. If the original submission is uncertain, its original reporter must recover it first.',
            ),
            if (actor.canCorrectMaintenanceTicket) ...[
              const SizedBox(height: BafSpacing.sm),
              OutlinedButton.icon(
                key: const ValueKey('maintenance-successor-open'),
                icon: const Icon(Icons.compare_arrows),
                label: const Text('Review saved changes'),
                onPressed: () async {
                  final current = CurrentActorAccess.resolve(
                    ref.read(currentAppUserProvider),
                  ).actor;
                  if (current?.uid != actor.uid ||
                      current?.canCorrectMaintenanceTicket != true) {
                    return;
                  }
                  final completed = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => CurrentActorDialogGuard(
                      originUid: actor.uid,
                      permission: (user) => user.canCorrectMaintenanceTicket,
                      child: _SuccessorReviewDialog(
                        ticketId: ticketId,
                        originUid: actor.uid,
                      ),
                    ),
                  );
                  if (completed == true && context.mounted) {
                    await Navigator.of(context).maybePop();
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuccessorReviewDialog extends ConsumerStatefulWidget {
  const _SuccessorReviewDialog({
    required this.ticketId,
    required this.originUid,
  });

  final String ticketId;
  final String originUid;

  @override
  ConsumerState<_SuccessorReviewDialog> createState() =>
      _SuccessorReviewDialogState();
}

class _SuccessorReviewDialogState
    extends ConsumerState<_SuccessorReviewDialog> {
  final _selected = <String>{};
  final _reason = TextEditingController();
  MaintenanceCreationSuccessorReview? _review;
  DurableSubmission? _pending;
  bool _busy = true;
  bool _retainAcknowledged = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _requireActor() {
    final actor = CurrentActorAccess.resolve(
      ref.read(currentAppUserProvider),
    ).actor;
    if (actor?.uid != widget.originUid ||
        actor?.canCorrectMaintenanceTicket != true) {
      throw StateError(
        'Return to the approved account that opened this review. Your entries are retained.',
      );
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _requireActor();
      final pending = await ref
          .read(maintenanceCreationSuccessorServiceProvider)
          .pending(widget.ticketId);
      if (!mounted) return;
      _requireActor();
      if (pending != null) {
        setState(() {
          _pending = pending;
        });
        return;
      }
      ref.invalidate(
        maintenanceCreationSuccessorReviewProvider(widget.ticketId),
      );
      final review = await ref.read(
        maintenanceCreationSuccessorReviewProvider(widget.ticketId).future,
      );
      if (!mounted) return;
      _requireActor();
      setState(() {
        _review = review;
        _pending = null;
        _retainAcknowledged = false;
        _selected.removeWhere((field) => !review.changedFields.contains(field));
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _findPending() async {
    try {
      _requireActor();
      final pending = await ref
          .read(maintenanceCreationSuccessorServiceProvider)
          .pending(widget.ticketId);
      if (!mounted) return;
      _requireActor();
      setState(() => _pending = pending);
    } catch (_) {
      // Preserve the original failure and draft when recovery cannot be read.
    }
  }

  bool get _retentionReady => _retainAcknowledged;

  Future<void> _correct() async {
    final review = _review;
    if (review == null || _busy || !_retentionReady || _pending != null) return;
    try {
      _requireActor();
    } catch (error) {
      setState(() => _error = '$error');
      return;
    }
    final draft = await showDialog<Object>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CurrentActorDialogGuard(
        originUid: widget.originUid,
        permission: (user) => user.canCorrectMaintenanceTicket,
        child: MaintenanceTicketCorrectionDialog(
          ticket: review.server,
          initialValues: {
            for (final field in _selected)
              if (!_requiresFreshTarget(review, field))
                field: review.localValues[field],
          },
          onSubmit: (draft) async {
            _requireActor();
            if (_pending != null) {
              throw StateError(
                'A saved correction needs confirmation. Close this form and check the saved correction. Your entries remain here until you close it.',
              );
            }
            try {
              await ref
                  .read(maintenanceCreationSuccessorServiceProvider)
                  .submit(
                    review: review,
                    draft: draft,
                    acknowledgeRetainedDifferences: _retainAcknowledged,
                  );
              if (mounted) _requireActor();
            } catch (_) {
              await _findPending();
              rethrow;
            }
          },
        ),
      ),
    );
    if (draft != null && mounted) {
      _complete(
        'Reviewed correction confirmed. Retained device evidence is preserved.',
      );
    }
  }

  Future<void> _keepServer() async {
    final review = _review;
    if (review == null || _busy || !_retentionReady || _pending != null) return;
    if (_reason.text.trim().isEmpty) {
      setState(
        () => _error = 'Explain why the current server values should be kept.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _requireActor();
      await ref
          .read(maintenanceCreationSuccessorServiceProvider)
          .keepServer(
            review: review,
            reason: _reason.text.trim(),
            acknowledgeRetainedDifferences: _retainAcknowledged,
          );
      if (!mounted) return;
      _requireActor();
      _complete(
        'Server values kept. The device review and retained evidence were recorded.',
      );
    } catch (error) {
      await _findPending();
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resume() async {
    final pending = _pending;
    if (pending == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _requireActor();
      await ref
          .read(maintenanceCreationSuccessorServiceProvider)
          .resume(pending.submissionId);
      if (!mounted) return;
      _requireActor();
      _complete(
        'Saved correction confirmed. Retained device evidence is preserved.',
      );
    } catch (error) {
      await _findPending();
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _complete(String message) {
    ref.invalidate(maintenanceCreationSuccessorReviewProvider(widget.ticketId));
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final review = _review;
    final fields = review == null
        ? <String>[]
        : {
            ...review.changedFields,
            for (final field in review.serverValues.keys)
              if (review.originalValues[field] != review.serverValues[field])
                field,
          }.toList();
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('Compare saved issue changes'),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_busy) const LinearProgressIndicator(),
                if (_pending != null) ...[
                  const Text(
                    'A saved correction is awaiting confirmation. Check that request before starting another review.',
                  ),
                  const SizedBox(height: BafSpacing.md),
                  FilledButton(
                    key: const ValueKey('maintenance-successor-resume'),
                    onPressed: _busy ? null : _resume,
                    child: const Text('Check saved correction'),
                  ),
                ] else if (review != null) ...[
                  const Text(
                    'A · Original accepted submission\nB · Retained device changes\nC · Current server record',
                  ),
                  const SizedBox(height: BafSpacing.sm),
                  const Text(
                    'Server values are kept unless you explicitly choose a device value or edit it in the correction form.',
                  ),
                  for (final field in fields) _comparison(review, field),
                  if (review.localValues.entries.every(
                    (entry) => entry.value == review.serverValues[entry.key],
                  ))
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: BafSpacing.md),
                      child: Text(
                        'The supported issue fields already match the server. Confirming this review records local reconciliation; it does not create a server correction.',
                      ),
                    ),
                  if (review.unsupportedChanges.isNotEmpty) ...[
                    const SizedBox(height: BafSpacing.md),
                    Text(
                      'Changes retained without applying',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Text(
                      'These changes cannot be applied through this correction. They remain in the retained review evidence.',
                    ),
                    for (final change in review.unsupportedChanges)
                      Padding(
                        padding: const EdgeInsets.only(top: BafSpacing.sm),
                        child: Text('• ${_fieldLabel(change)}'),
                      ),
                  ],
                  CheckboxListTile(
                    key: const ValueKey('maintenance-successor-retain'),
                    contentPadding: EdgeInsets.zero,
                    value: _retainAcknowledged,
                    onChanged: _busy
                        ? null
                        : (value) => setState(
                            () => _retainAcknowledged = value == true,
                          ),
                    title: const Text(
                      'I have reviewed the differences. Unselected or unsupported device changes will be retained without being applied.',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: BafSpacing.md),
                  FilledButton.icon(
                    key: const ValueKey('maintenance-successor-correct'),
                    onPressed: _busy || !_retentionReady ? null : _correct,
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Review correction'),
                  ),
                  const SizedBox(height: BafSpacing.md),
                  TextField(
                    key: const ValueKey('maintenance-successor-keep-reason'),
                    controller: _reason,
                    enabled: !_busy,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Reason for keeping server values',
                    ),
                  ),
                  OutlinedButton(
                    key: const ValueKey('maintenance-successor-keep'),
                    onPressed: _busy || !_retentionReady ? null : _keepServer,
                    child: const Text(
                      'Keep server values and retain this review',
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: BafSpacing.md),
                  Text(
                    _error!,
                    key: const ValueKey('maintenance-successor-error'),
                    style: const TextStyle(color: BafColors.danger),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (_pending == null)
            TextButton(
              onPressed: _busy ? null : _load,
              child: const Text('Reload comparison'),
            ),
        ],
      ),
    );
  }

  Widget _comparison(MaintenanceCreationSuccessorReview review, String field) {
    final deviceChanged = review.changedFields.contains(field);
    final matchesServer =
        review.localValues[field] == review.serverValues[field];
    final needsTarget = _requiresFreshTarget(review, field);
    return Card(
      margin: const EdgeInsets.only(top: BafSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _fieldLabel(field),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text('A · ${_value(review.originalValues[field])}'),
            Text('B · ${_value(review.localValues[field])}'),
            Text('C · ${_value(review.serverValues[field])}'),
            if (deviceChanged && !matchesServer && needsTarget)
              const Text(
                'Choose a fresh registered target in the correction form to change this field. Device labels are retained without being copied.',
              )
            else if (deviceChanged && !matchesServer)
              CheckboxListTile(
                key: ValueKey('maintenance-successor-select-$field'),
                contentPadding: EdgeInsets.zero,
                value: _selected.contains(field),
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        if (value == true) {
                          _selected.add(field);
                        } else {
                          _selected.remove(field);
                        }
                      }),
                title: const Text('Use retained device value in correction'),
                controlAffinity: ListTileControlAffinity.leading,
              )
            else
              Text(
                matchesServer
                    ? 'Device value already matches the server.'
                    : 'Changed on the server; current value will be kept.',
              ),
          ],
        ),
      ),
    );
  }

  bool _requiresFreshTarget(
    MaintenanceCreationSuccessorReview review,
    String field,
  ) =>
      review.server.assetHierarchyRefJson != null &&
      const {'component', 'subsystem', 'tag'}.contains(field);
}

String _value(Object? value) => value == null || value == ''
    ? 'Not recorded'
    : value is bool
    ? (value ? 'Yes' : 'No')
    : '$value';

String _fieldLabel(String field) =>
    const {
      'description': 'Description',
      'routedTo': 'Primary accountable team',
      'maintenanceType': 'Maintenance type',
      'isCritical': 'Critical issue',
      'plantConditionEffect': 'Plant condition',
      'component': 'Component',
      'subsystem': 'Subsystem',
      'tag': 'Tag',
      'classification': 'Classification',
      'otherDepartment': 'Other accountable team',
      'remarks': 'Remarks',
      'assetType': 'Physical asset type',
      'assetNumber': 'Physical asset number',
      'assetHierarchyRefJson': 'Registered equipment target',
      'status': 'Issue status',
      'isResolved': 'Resolution state',
      'startDate': 'Issue start time',
      'endDate': 'Issue end time',
      'actionsJson': 'Recorded work',
      'resolutionHistoryJson': 'Resolution history',
      'metadataJson': 'Saved issue evidence',
    }[field] ??
    field;
