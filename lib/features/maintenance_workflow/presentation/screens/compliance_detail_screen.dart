import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../../core/widgets/baf_ui.dart';
import '../../../../core/widgets/brand/brand_widgets.dart';
import '../../../../core/widgets/dashboard/status_badge.dart';
import '../../../auth/data/user_model.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/compliance_request_record.dart';
import '../../domain/workflow_types.dart';
import '../../providers/workflow_providers.dart';
import '../../services/workflow_command_factory.dart';
import '../widgets/workflow_action_guard.dart';

class ComplianceDetailScreen extends ConsumerWidget {
  final ComplianceRequestRecord record;

  const ComplianceDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading && !actorAsync.hasValue) {
      return BafScreenStateScaffold.loading(
        appBarTitle: 'Compliance detail',
        appBarSubtitle: 'Verifying your approved compliance scope',
        appBarIcon: Icons.fact_check_outlined,
        accent: BafColors.directives,
        label: 'Checking compliance access',
      );
    }
    if (actorAsync.hasError) {
      return BafScreenStateScaffold.error(
        appBarTitle: 'Compliance detail',
        appBarSubtitle: 'Verifying your approved compliance scope',
        appBarIcon: Icons.fact_check_outlined,
        accent: BafColors.directives,
        message: 'Compliance access could not be verified.',
      );
    }
    final actor = actorAsync.value;
    if (actor == null || !actor.isApproved) {
      return BafScreenStateScaffold.access(
        appBarTitle: 'Compliance detail',
        appBarSubtitle: 'Approved compliance access only',
        appBarIcon: Icons.fact_check_outlined,
        accent: BafColors.directives,
        title: 'Compliance access required',
        message:
            'An approved operational role is required to view compliance evidence.',
      );
    }
    final workflowId =
        record.linkedWorkflowId ?? record.linkedExecutionFirestoreId ?? '';
    final aggregate =
        workflowId.isEmpty
            ? const AsyncValue.data(null)
            : ref.watch(workflowAggregateProvider(workflowId));
    final commandState = ref.watch(workflowCommandControllerProvider);

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: BafAppBarTitle(
          title: record.title,
          subtitle: 'Compliance evidence and lifecycle action',
          icon: Icons.fact_check_outlined,
          accent: BafColors.directives,
        ),
      ),
      body: BafContentFrame(
        maxWidth: 840,
        child: aggregate.when(
          loading:
              () => const BafLoadingPanel(
                label: 'Loading authoritative workflow state',
                color: BafColors.directives,
              ),
          error:
              (error, _) => BafStatePanel.error(
                title: 'Workflow state is unavailable',
                message: '$error',
                onPrimary:
                    workflowId.isEmpty
                        ? null
                        : () => ref.invalidate(
                          workflowAggregateProvider(workflowId),
                        ),
              ),
          data: (snapshot) {
            final version = snapshot?.workflow.version;
            final workflowFinal = snapshot?.workflow.isFinal ?? false;
            return ListView(
              children: [
                BafScreenIntro(
                  title: record.title,
                  subtitle:
                      record.description.trim().isEmpty
                          ? 'No additional description was recorded.'
                          : record.description,
                  icon: Icons.assignment_turned_in_outlined,
                  accent: BafColors.directives,
                  trailing: StatusBadge(
                    label: _businessLabel(record.statusKey),
                    color: _statusColor(record.statusKey),
                  ),
                ),
                const SizedBox(height: BafSpacing.lg),
                const BafSectionLabel(
                  title: 'Request context',
                  subtitle: 'Ownership, purpose and activation evidence',
                ),
                const SizedBox(height: BafSpacing.sm),
                BafRecordSurface(child: Column(children: _contextRows())),
                if (record.counterRevisedDescription != null) ...[
                  const SizedBox(height: BafSpacing.lg),
                  BafRecordSurface(
                    accent: BafColors.warning,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Revised condition proposed',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: BafSpacing.sm),
                        Text(record.counterRevisedDescription!),
                        if (record.counterProposedByName != null) ...[
                          const SizedBox(height: BafSpacing.xs),
                          Text(
                            'Proposed by ${record.counterProposedByName}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: BafSpacing.xl),
                const BafSectionLabel(
                  title: 'Available actions',
                  subtitle: 'Actions follow lane authority and current state',
                ),
                const SizedBox(height: BafSpacing.sm),
                if (version == null)
                  const BafStatePanel(
                    icon: Icons.cloud_off_outlined,
                    color: BafColors.warning,
                    title: 'Actions temporarily unavailable',
                    message:
                        'Actions are disabled until the authoritative workflow version is available.',
                  )
                else if (workflowFinal)
                  const BafRecordSurface(
                    accent: BafColors.audit,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lock_clock_outlined, color: BafColors.audit),
                        SizedBox(width: BafSpacing.md),
                        Expanded(
                          child: Text(
                            'This workflow is completed or cancelled. Compliance evidence remains readable, but no further lifecycle action is permitted.',
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._actions(
                    context,
                    ref,
                    workflowId: workflowId,
                    expectedVersion: version,
                    busy: commandState.isLoading,
                    actor: actor,
                  ),
                const SizedBox(height: BafSpacing.xl),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _contextRows() {
    final values = <(String, String)>[
      ('Request type', record.requestPurposeLabel),
      ('Target lane', record.targetLaneKey.toUpperCase()),
      ('Status', _businessLabel(record.statusKey)),
      if (record.raisedUnderCoordination)
        ('Coordination', 'Supervisory workflow coordination'),
      if (record.defermentBasisKey != null)
        ('Deferment basis', _businessLabel(record.defermentBasisKey!)),
      if (record.operationsSupportTypeKey != null)
        ('Support', _businessLabel(record.operationsSupportTypeKey!)),
      if (record.operationsResourceKey != null)
        ('Resource', _businessLabel(record.operationsResourceKey!)),
      if (record.requestedLocation != null)
        ('Location', record.requestedLocation!),
      if (record.linkedMaintenanceFirestoreId != null)
        ('Linked maintenance ticket', record.linkedMaintenanceFirestoreId!),
      if (record.conditionTypeKey != 'manual')
        (
          'Condition',
          '${_businessLabel(record.conditionTypeKey)}${record.conditionRef == null ? '' : ': ${record.conditionRef}'}',
        ),
      if (record.becameDueAt != null)
        ('Became due', record.becameDueAt!.toLocal().toString()),
      if (record.currentAttemptId != null)
        ('Compliance attempt', record.currentAttemptId!),
    ];
    return List<Widget>.generate(
      values.length,
      (index) => _ComplianceInfoRow(
        label: values[index].$1,
        value: values[index].$2,
        last: index == values.length - 1,
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmedClosed':
      case 'complied':
        return BafColors.success;
      case 'cancelled':
      case 'superseded':
        return BafColors.textSecondary;
      case 'acknowledged':
        return BafColors.cobalt;
      default:
        return BafColors.warning;
    }
  }

  String _businessLabel(String value) =>
      value
          .replaceAllMapped(
            RegExp(r'([a-z])([A-Z])'),
            (match) => '${match.group(1)} ${match.group(2)}',
          )
          .toLowerCase();

  List<Widget> _actions(
    BuildContext context,
    WidgetRef ref, {
    required String workflowId,
    required int expectedVersion,
    required bool busy,
    required AppUser? actor,
  }) {
    final widgets = <Widget>[];
    void add(Widget widget) {
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 12));
      widgets.add(widget);
    }

    final mayWorkTarget =
        actor?.canAcknowledgeOrWorkMaintenanceLane(record.targetLaneKey) ??
        false;
    final mayWorkOrigin =
        record.originLaneKey == null
            ? actor?.isModuleLifecycleSupervisor == true
            : (record.raisedUnderCoordination &&
                    actor?.canCoordinateMaintenanceCompliance == true) ||
                (actor?.canAcknowledgeOrWorkMaintenanceLane(
                      record.originLaneKey,
                    ) ??
                    false);
    final mayMarkCondition =
        actor?.canMarkMaintenanceWorkflowConditionDue ?? false;

    if ((record.statusKey == 'raised' || record.statusKey == 'acknowledged') &&
        record.conditionTypeKey != 'manual') {
      add(
        WorkflowActionGuard(
          busy: busy,
          enabled: mayMarkCondition,
          label: 'Confirm condition and reactivate linked work',
          icon: Icons.playlist_add_check_circle_outlined,
          onPressed: () async {
            final note = await _askText(
              context,
              title: 'Confirm condition',
              label: 'Confirmation note',
              initialValue: 'Condition confirmed; linked work reactivated.',
            );
            if (note == null) return;
            await _send(
              ref,
              workflowId,
              expectedVersion,
              WorkflowCommandType.confirmConditionAndReactivate,
              extra: <String, Object?>{'note': note},
            );
          },
        ),
      );
    }

    if (record.statusKey == 'raised') {
      add(
        WorkflowActionGuard(
          busy: busy,
          enabled: mayWorkTarget,
          label: 'Acknowledge',
          icon: Icons.mark_email_read_outlined,
          onPressed:
              () => _send(
                ref,
                workflowId,
                expectedVersion,
                WorkflowCommandType.acknowledgeCompliance,
              ),
        ),
      );
    }

    if (record.statusKey == 'acknowledged') {
      add(
        WorkflowActionGuard(
          busy: busy,
          enabled: mayWorkTarget,
          label: 'Mark complied',
          icon: Icons.task_alt,
          onPressed: () async {
            final note = await _askText(
              context,
              title: 'Compliance evidence',
              label: 'What was completed?',
            );
            if (note == null) return;
            await _send(
              ref,
              workflowId,
              expectedVersion,
              WorkflowCommandType.markComplianceComplied,
              extra: <String, Object?>{'note': note},
            );
          },
        ),
      );
      if (record.counterRevisedDescription == null &&
          record.counterDepth == 0) {
        add(
          OutlinedButton.icon(
            onPressed:
                busy || !mayWorkTarget
                    ? null
                    : () async {
                      final revised = await _askText(
                        context,
                        title: 'Propose one revised condition',
                        label: 'Complete revised condition',
                      );
                      if (revised == null) return;
                      await _send(
                        ref,
                        workflowId,
                        expectedVersion,
                        WorkflowCommandType.proposeCounterCondition,
                        extra: <String, Object?>{'revisedDescription': revised},
                      );
                    },
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Propose one revised condition'),
          ),
        );
      }
    }

    if (record.counterRevisedDescription != null) {
      add(
        FilledButton.icon(
          onPressed:
              busy || !mayWorkOrigin
                  ? null
                  : () async {
                    final note = await _askText(
                      context,
                      title: 'Accept revised condition',
                      label: 'Decision note (optional)',
                      required: false,
                    );
                    if (note == null) return;
                    await _send(
                      ref,
                      workflowId,
                      expectedVersion,
                      WorkflowCommandType.decideCounterCondition,
                      extra: <String, Object?>{
                        'accepted': true,
                        'note': note,
                        'successorComplianceId':
                            WorkflowCommandFactory.uniqueId('compliance'),
                      },
                    );
                  },
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Accept revised condition'),
        ),
      );
      add(
        OutlinedButton.icon(
          onPressed:
              busy || !mayWorkOrigin
                  ? null
                  : () async {
                    final note = await _askText(
                      context,
                      title: 'Reject and escalate',
                      label: 'Reason for rejection',
                    );
                    if (note == null) return;
                    await _send(
                      ref,
                      workflowId,
                      expectedVersion,
                      WorkflowCommandType.decideCounterCondition,
                      extra: <String, Object?>{'accepted': false, 'note': note},
                    );
                  },
          icon: const Icon(Icons.escalator_warning_outlined),
          label: const Text('Reject and escalate'),
        ),
      );
    }

    if (record.statusKey == 'complied') {
      add(
        WorkflowActionGuard(
          busy: busy,
          enabled: mayWorkOrigin,
          label: 'Confirm closed',
          icon: Icons.verified_outlined,
          onPressed: () async {
            final note = await _askText(
              context,
              title: 'Confirm compliance',
              label: 'Confirmation note (optional)',
              required: false,
            );
            if (note == null) return;
            await _send(
              ref,
              workflowId,
              expectedVersion,
              WorkflowCommandType.confirmComplianceClosed,
              extra: <String, Object?>{'note': note},
            );
          },
        ),
      );
      add(
        OutlinedButton.icon(
          onPressed:
              busy || !mayWorkOrigin
                  ? null
                  : () async {
                    final reason = await _askText(
                      context,
                      title: 'Return for correction',
                      label: 'What remains incomplete?',
                    );
                    if (reason == null) return;
                    await _send(
                      ref,
                      workflowId,
                      expectedVersion,
                      WorkflowCommandType.returnComplianceForCorrection,
                      extra: <String, Object?>{'reason': reason},
                    );
                  },
          icon: const Icon(Icons.replay_outlined),
          label: const Text('Return for correction'),
        ),
      );
    }

    return widgets;
  }

  Future<void> _send(
    WidgetRef ref,
    String workflowId,
    int expectedVersion,
    WorkflowCommandType type, {
    Map<String, Object?> extra = const <String, Object?>{},
  }) async {
    await ref
        .read(workflowCommandControllerProvider.notifier)
        .execute(
          WorkflowCommandFactory.create(
            type: type,
            aggregateId: workflowId,
            expectedVersion: expectedVersion,
            payload: <String, Object?>{
              'complianceId': record.firestoreId,
              ...extra,
            },
          ),
        );
  }

  Future<String?> _askText(
    BuildContext context, {
    required String title,
    required String label,
    String initialValue = '',
    bool required = true,
  }) {
    return showDialog<String>(
      context: context,
      builder:
          (_) => _ComplianceTextPromptDialog(
            title: title,
            label: label,
            initialValue: initialValue,
            isRequired: required,
          ),
    );
  }
}

class _ComplianceInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool last;

  const _ComplianceInfoRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: BafSpacing.sm),
      decoration: BoxDecoration(
        border:
            last
                ? null
                : const Border(bottom: BorderSide(color: BafColors.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelWidget = Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: BafColors.textSecondary),
          );
          final valueWidget = Text(value);
          if (constraints.maxWidth < 420) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget,
                const SizedBox(height: BafSpacing.xs),
                valueWidget,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 148, child: labelWidget),
              const SizedBox(width: BafSpacing.md),
              Expanded(child: valueWidget),
            ],
          );
        },
      ),
    );
  }
}

class _ComplianceTextPromptDialog extends StatefulWidget {
  final String title;
  final String label;
  final String initialValue;
  final bool isRequired;

  const _ComplianceTextPromptDialog({
    required this.title,
    required this.label,
    required this.initialValue,
    required this.isRequired,
  });

  @override
  State<_ComplianceTextPromptDialog> createState() =>
      _ComplianceTextPromptDialogState();
}

class _ComplianceTextPromptDialogState
    extends State<_ComplianceTextPromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 4,
        decoration: InputDecoration(labelText: widget.label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = _controller.text.trim();
            if (widget.isRequired && value.isEmpty) return;
            Navigator.pop(context, value);
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
