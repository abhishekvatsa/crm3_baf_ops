import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../../core/widgets/baf_ui.dart';
import '../../../../core/widgets/brand/brand_widgets.dart';
import '../../../../core/widgets/dashboard/status_badge.dart';
import '../../../auth/data/user_model.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/compliance_request_record.dart';
import '../../domain/compliance_visibility_policy.dart';
import '../../domain/workflow_types.dart';
import '../../providers/workflow_providers.dart';
import '../../services/workflow_command_factory.dart';
import '../widgets/workflow_action_guard.dart';

class ComplianceDetailScreen extends ConsumerStatefulWidget {
  final ComplianceRequestRecord record;

  const ComplianceDetailScreen({super.key, required this.record});

  @override
  ConsumerState<ComplianceDetailScreen> createState() =>
      _ComplianceDetailScreenState();
}

class _ComplianceDetailScreenState
    extends ConsumerState<ComplianceDetailScreen> {
  String? _receiptWorkflowId;
  int? _receiptAggregateVersion;

  @override
  Widget build(BuildContext context) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading) {
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
    if (actor == null || !canUserSeeComplianceRequest(widget.record, actor)) {
      return BafScreenStateScaffold.access(
        appBarTitle: 'Compliance detail',
        appBarSubtitle: 'Approved compliance access only',
        appBarIcon: Icons.fact_check_outlined,
        accent: BafColors.directives,
        title: 'Compliance access required',
        message:
            'This compliance request is outside your approved operational scope.',
      );
    }

    final complianceId = widget.record.firestoreId?.trim() ?? '';
    if (complianceId.isEmpty) {
      return BafScreenStateScaffold.error(
        appBarTitle: 'Compliance detail',
        appBarSubtitle: 'Verifying the authoritative compliance record',
        appBarIcon: Icons.fact_check_outlined,
        accent: BafColors.directives,
        message: 'This compliance request has no governed server identity.',
      );
    }
    final complianceScope = (actorUid: actor.uid, complianceId: complianceId);
    final recordAsync = ref.watch(
      workflowComplianceRecordProvider(complianceScope),
    );
    if (recordAsync.isLoading) {
      return BafScreenStateScaffold.loading(
        appBarTitle: 'Compliance detail',
        appBarSubtitle: 'Loading current compliance evidence',
        appBarIcon: Icons.fact_check_outlined,
        accent: BafColors.directives,
        label: 'Reading the authoritative compliance request',
      );
    }
    if (recordAsync.hasError) {
      return BafScreenStateScaffold.error(
        appBarTitle: 'Compliance detail',
        appBarSubtitle: 'Loading current compliance evidence',
        appBarIcon: Icons.fact_check_outlined,
        accent: BafColors.directives,
        message: 'The authoritative compliance request is unavailable.',
      );
    }
    final record = recordAsync.value;
    if (record == null) {
      return BafScreenStateScaffold.error(
        appBarTitle: 'Compliance detail',
        appBarSubtitle: 'Loading current compliance evidence',
        appBarIcon: Icons.fact_check_outlined,
        accent: BafColors.directives,
        message: 'This compliance request is no longer available.',
      );
    }
    if (!canUserSeeComplianceRequest(record, actor)) {
      return BafScreenStateScaffold.access(
        appBarTitle: 'Compliance detail',
        appBarSubtitle: 'Approved compliance access only',
        appBarIcon: Icons.fact_check_outlined,
        accent: BafColors.directives,
        title: 'Compliance access required',
        message:
            'This compliance request is outside your approved operational scope.',
      );
    }
    final workflowId =
        record.linkedWorkflowId ?? record.linkedExecutionFirestoreId ?? '';
    if (workflowId.isEmpty) {
      return BafScreenStateScaffold.error(
        appBarTitle: 'Compliance detail',
        appBarSubtitle: 'Loading current workflow evidence',
        appBarIcon: Icons.fact_check_outlined,
        accent: BafColors.directives,
        message: 'This compliance request has no governed workflow identity.',
      );
    }
    final workflowScope = (actorUid: actor.uid, workflowId: workflowId);
    final aggregate = ref.watch(
      workflowAuthoritativeRecordProvider(workflowScope),
    );
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
              () => _detailBody(
                context,
                ref,
                record: record,
                workflowId: workflowId,
                actor: actor,
                busy: commandState.isLoading,
                actionOverride: const BafLoadingPanel(
                  label: 'Loading authoritative workflow state',
                  color: BafColors.directives,
                ),
              ),
          error:
              (error, _) => _detailBody(
                context,
                ref,
                record: record,
                workflowId: workflowId,
                actor: actor,
                busy: commandState.isLoading,
                actionOverride: BafStatePanel.error(
                  title: 'Actions temporarily unavailable',
                  message:
                      'Current workflow state could not be verified. The compliance evidence below remains readable, but lifecycle actions stay disabled.\n\n$error',
                  onPrimary:
                      () => ref.invalidate(
                        workflowAuthoritativeRecordProvider(workflowScope),
                      ),
                ),
              ),
          data: (workflow) {
            final snapshotVersion = workflow?.version;
            final receiptVersion =
                _receiptWorkflowId == workflowId
                    ? _receiptAggregateVersion
                    : null;
            final version =
                snapshotVersion == null
                    ? receiptVersion
                    : receiptVersion == null ||
                        snapshotVersion >= receiptVersion
                    ? snapshotVersion
                    : receiptVersion;
            final workflowFinal =
                workflow?.statusKey == 'completed' ||
                workflow?.statusKey == 'cancelled';
            return _detailBody(
              context,
              ref,
              record: record,
              workflowId: workflowId,
              actor: actor,
              busy: commandState.isLoading,
              version: version,
              workflowFinal: workflowFinal,
            );
          },
        ),
      ),
    );
  }

  Widget _detailBody(
    BuildContext context,
    WidgetRef ref, {
    required ComplianceRequestRecord record,
    required String workflowId,
    required AppUser actor,
    required bool busy,
    int? version,
    bool workflowFinal = false,
    Widget? actionOverride,
  }) {
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
        BafRecordSurface(child: Column(children: _contextRows(record))),
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
        if (actionOverride != null)
          actionOverride
        else if (version == null)
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
            record: record,
            workflowId: workflowId,
            expectedVersion: version,
            busy: busy,
            actor: actor,
          ),
        const SizedBox(height: BafSpacing.xl),
      ],
    );
  }

  List<Widget> _contextRows(ComplianceRequestRecord record) {
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
        return BafColors.success;
      case 'complied':
        return BafColors.warning;
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
    required ComplianceRequestRecord record,
    required String workflowId,
    required int expectedVersion,
    required bool busy,
    required AppUser actor,
  }) {
    final widgets = <Widget>[];
    void add(Widget widget) {
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 12));
      widgets.add(widget);
    }

    final mayWorkTarget = actor.canAcknowledgeOrWorkMaintenanceLane(
      record.targetLaneKey,
    );
    final mayWorkOrigin =
        record.originLaneKey == null
            ? actor.isModuleLifecycleSupervisor
            : (record.raisedUnderCoordination &&
                    actor.canCoordinateMaintenanceCompliance) ||
                actor.canAcknowledgeOrWorkMaintenanceLane(record.originLaneKey);
    final mayMarkCondition = actor.canMarkMaintenanceWorkflowConditionDue;

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
              actorUid: actor.uid,
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
                actorUid: actor.uid,
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
              actorUid: actor.uid,
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
                        actorUid: actor.uid,
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
                      actorUid: actor.uid,
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
                      actorUid: actor.uid,
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
              actorUid: actor.uid,
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
                      actorUid: actor.uid,
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
    required String actorUid,
    Map<String, Object?> extra = const <String, Object?>{},
  }) async {
    final receipt = await ref
        .read(workflowCommandControllerProvider.notifier)
        .execute(
          WorkflowCommandFactory.create(
            type: type,
            aggregateId: workflowId,
            expectedVersion: expectedVersion,
            payload: <String, Object?>{
              'complianceId': widget.record.firestoreId,
              ...extra,
            },
          ),
        );
    if (!mounted) return;
    setState(() {
      final sameWorkflow = _receiptWorkflowId == workflowId;
      final current = sameWorkflow ? _receiptAggregateVersion : null;
      _receiptWorkflowId = workflowId;
      _receiptAggregateVersion =
          current == null || receipt.aggregateVersion > current
              ? receipt.aggregateVersion
              : current;
    });
    final authorizedActorUid = actorUid.trim();
    final complianceId = widget.record.firestoreId?.trim();
    if (authorizedActorUid.isNotEmpty &&
        complianceId != null &&
        complianceId.isNotEmpty) {
      ref.invalidate(
        workflowComplianceRecordProvider((
          actorUid: authorizedActorUid,
          complianceId: complianceId,
        )),
      );
      ref.invalidate(
        workflowAuthoritativeRecordProvider((
          actorUid: authorizedActorUid,
          workflowId: workflowId,
        )),
      );
    }
    ref.invalidate(workflowAggregateProvider(workflowId));
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
