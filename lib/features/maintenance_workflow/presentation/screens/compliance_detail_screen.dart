import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final workflowId =
        record.linkedWorkflowId ?? record.linkedExecutionFirestoreId ?? '';
    final aggregate =
        workflowId.isEmpty
            ? const AsyncValue.data(null)
            : ref.watch(workflowAggregateProvider(workflowId));
    final commandState = ref.watch(workflowCommandControllerProvider);
    final actor = ref.watch(currentAppUserProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(record.title)),
      body: aggregate.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) =>
                Center(child: Text('Workflow state unavailable: $error')),
        data: (snapshot) {
          final version = snapshot?.workflow.version;
          final workflowFinal = snapshot?.workflow.isFinal ?? false;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                record.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Text('Request type: ${record.requestPurposeLabel}'),
              Text('Target lane: ${record.targetLaneKey.toUpperCase()}'),
              Text('Status: ${record.statusKey}'),
              if (record.raisedUnderCoordination)
                const Text('Raised under supervisory workflow coordination'),
              if (record.defermentBasisKey != null)
                Text(
                  'Deferment basis: ${_businessLabel(record.defermentBasisKey!)}',
                ),
              if (record.operationsSupportTypeKey != null)
                Text(
                  'Support: ${_businessLabel(record.operationsSupportTypeKey!)}',
                ),
              if (record.operationsResourceKey != null)
                Text(
                  'Resource: ${_businessLabel(record.operationsResourceKey!)}',
                ),
              if (record.requestedLocation != null)
                Text('Location: ${record.requestedLocation}'),
              if (record.linkedMaintenanceFirestoreId != null)
                Text(
                  'Linked maintenance ticket: '
                  '${record.linkedMaintenanceFirestoreId}',
                ),
              if (record.conditionTypeKey != 'manual')
                Text(
                  'Condition: ${record.conditionTypeKey}'
                  '${record.conditionRef == null ? '' : ' — ${record.conditionRef}'}',
                ),
              if (record.becameDueAt != null)
                Text('Became due: ${record.becameDueAt}'),
              if (record.currentAttemptId != null)
                Text('Current compliance attempt: ${record.currentAttemptId}'),
              if (record.counterRevisedDescription != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'One revised condition proposed',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(record.counterRevisedDescription!),
                        if (record.counterProposedByName != null)
                          Text('Proposed by ${record.counterProposedByName}'),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (version == null)
                const Text(
                  'Actions are disabled until the authoritative workflow version is available.',
                )
              else if (workflowFinal)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'This workflow is completed or cancelled. Compliance evidence remains readable, but no further lifecycle action is permitted.',
                    ),
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
            ],
          );
        },
      ),
    );
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
