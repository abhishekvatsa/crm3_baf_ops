import 'package:flutter/material.dart';

import '../../../core/theme/baf_design_system.dart';
import '../data/maintenance_model.dart';
import '../domain/issue_administrative_closure.dart';

class IssueAdministrativeClosureDraft {
  const IssueAdministrativeClosureDraft({
    required this.disposition,
    required this.reason,
  });

  final IssueAdministrativeClosureDisposition disposition;
  final String reason;
}

Future<IssueAdministrativeClosureDraft?> showIssueAdministrativeClosureDialog(
  BuildContext context, {
  required MaintenanceRecord ticket,
}) => showDialog<IssueAdministrativeClosureDraft>(
  context: context,
  builder: (_) => _IssueAdministrativeClosureDialog(ticket: ticket),
);

Future<IssueAdministrativeClosureDraft?>
showIssueAdministrativeRelevanceEndDialog(
  BuildContext context, {
  required MaintenanceRecord ticket,
}) => showDialog<IssueAdministrativeClosureDraft>(
  context: context,
  builder:
      (_) => _IssueAdministrativeClosureDialog(
        ticket: ticket,
        endingRetainedRelevance: true,
      ),
);

class _IssueAdministrativeClosureDialog extends StatefulWidget {
  const _IssueAdministrativeClosureDialog({
    required this.ticket,
    this.endingRetainedRelevance = false,
  });

  final MaintenanceRecord ticket;
  final bool endingRetainedRelevance;

  @override
  State<_IssueAdministrativeClosureDialog> createState() =>
      _IssueAdministrativeClosureDialogState();
}

class _IssueAdministrativeClosureDialogState
    extends State<_IssueAdministrativeClosureDialog> {
  final _reasonController = TextEditingController();
  IssueAdministrativeClosureDisposition? _disposition;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.endingRetainedRelevance) {
      _disposition = IssueAdministrativeClosureDisposition.relevanceEnded;
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final disposition = _disposition;
    final reason = _reasonController.text.trim();
    if (disposition == null) {
      setState(() => _error = 'Select why the issue is being closed.');
      return;
    }
    if (reason.isEmpty) {
      setState(() => _error = 'Enter a reason for this closure.');
      return;
    }
    if (reason.length > 2000) {
      setState(
        () => _error = 'The closure reason cannot exceed 2000 characters.',
      );
      return;
    }
    Navigator.pop(
      context,
      IssueAdministrativeClosureDraft(disposition: disposition, reason: reason),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCoordination =
        !widget.endingRetainedRelevance &&
        widget.ticket.workflowQueueState != 'independent' &&
        widget.ticket.workflowQueueState != 'released';
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, color: BafColors.warning),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              widget.endingRetainedRelevance
                  ? 'End retained relevance'
                  : 'Close without resolution',
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.ticket.assetType.name.toUpperCase()} '
                '${widget.ticket.assetNumber} - ${widget.ticket.description}',
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: BafSpacing.lg),
              if (widget.endingRetainedRelevance)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(BafSpacing.md),
                  decoration: BoxDecoration(
                    color: BafColors.warning.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(BafRadius.medium),
                    border: Border.all(
                      color: BafColors.warning.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Text(
                    'The original unresolved closure remains in the record. This audited action only ends its continuing effect on Plant Condition.',
                    style: TextStyle(
                      color: BafColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                )
              else ...[
                _DispositionOption(
                  value: IssueAdministrativeClosureDisposition.stillRelevant,
                  selected: _disposition,
                  icon: Icons.bookmark_added_outlined,
                  title: 'Still relevant',
                  subtitle:
                      'Stop active work, but retain this as an unresolved concern in history and reports.',
                  onChanged:
                      (value) => setState(() {
                        _disposition = value;
                        _error = null;
                      }),
                ),
                const SizedBox(height: BafSpacing.sm),
                _DispositionOption(
                  value: IssueAdministrativeClosureDisposition.relevanceEnded,
                  selected: _disposition,
                  icon: Icons.event_busy_outlined,
                  title: 'No longer relevant',
                  subtitle:
                      'The operating context has ended and no maintenance resolution is now required.',
                  onChanged:
                      (value) => setState(() {
                        _disposition = value;
                        _error = null;
                      }),
                ),
              ],
              if (hasCoordination) ...[
                const SizedBox(height: BafSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(BafSpacing.md),
                  decoration: BoxDecoration(
                    color: BafColors.warning.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(BafRadius.medium),
                    border: Border.all(
                      color: BafColors.warning.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.link_off_rounded,
                        size: 20,
                        color: BafColors.warning,
                      ),
                      SizedBox(width: BafSpacing.sm),
                      Expanded(
                        child: Text(
                          'The linked Operations obligation will be cancelled with this closure.',
                          style: TextStyle(
                            color: BafColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: BafSpacing.lg),
              TextField(
                controller: _reasonController,
                minLines: 3,
                maxLines: 6,
                maxLength: 2000,
                decoration: InputDecoration(
                  labelText:
                      widget.endingRetainedRelevance
                          ? 'Reason relevance has ended'
                          : 'Administrative closure reason',
                  hintText:
                      widget.endingRetainedRelevance
                          ? 'Record what changed and why the concern no longer affects Plant Condition'
                          : 'Record the operating context and decision basis',
                  errorText: _error,
                  alignLabelWithHint: true,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
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
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: BafColors.warning,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.inventory_2_outlined),
          label: Text(
            widget.endingRetainedRelevance ? 'End relevance' : 'Close issue',
          ),
        ),
      ],
    );
  }
}

class _DispositionOption extends StatelessWidget {
  const _DispositionOption({
    required this.value,
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  final IssueAdministrativeClosureDisposition value;
  final IssueAdministrativeClosureDisposition? selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final ValueChanged<IssueAdministrativeClosureDisposition> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return Material(
      color:
          isSelected
              ? BafColors.warning.withValues(alpha: 0.10)
              : BafColors.background,
      borderRadius: BorderRadius.circular(BafRadius.medium),
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        child: Container(
          padding: const EdgeInsets.all(BafSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BafRadius.medium),
            border: Border.all(
              color: isSelected ? BafColors.warning : BafColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: BafColors.warning),
              const SizedBox(width: BafSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: BafSpacing.sm),
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: isSelected ? BafColors.warning : BafColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
