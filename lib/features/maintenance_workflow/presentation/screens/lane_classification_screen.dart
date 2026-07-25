import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/maintenance_lane.dart';
import '../../domain/workflow_types.dart';
import '../../providers/workflow_providers.dart';
import '../../services/workflow_command_factory.dart';
import '../widgets/workflow_action_guard.dart';

class LaneClassificationScreen extends ConsumerStatefulWidget {
  final String workflowId;
  final int expectedVersion;

  const LaneClassificationScreen({
    super.key,
    required this.workflowId,
    required this.expectedVersion,
  });

  @override
  ConsumerState<LaneClassificationScreen> createState() => _LaneClassificationScreenState();
}

class _LaneClassificationScreenState extends ConsumerState<LaneClassificationScreen> {
  final Set<MaintenanceLaneId> selected = <MaintenanceLaneId>{};

  @override
  Widget build(BuildContext context) {
    final commandState = ref.watch(workflowCommandControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Classify maintenance lanes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Select every department that must independently acknowledge and close its work.',
          ),
          const SizedBox(height: 12),
          for (final definition in MaintenanceLaneCatalog.crm3.definitions)
            CheckboxListTile(
              value: selected.contains(definition.id),
              title: Text('${definition.code} — ${definition.displayName}'),
              subtitle: definition.delegated
                  ? const Text('Digitally coordinated by Admin/SI on behalf of EMD')
                  : null,
              onChanged: (value) => setState(() {
                if (value == true) {
                  selected.add(definition.id);
                } else {
                  selected.remove(definition.id);
                }
              }),
            ),
          const SizedBox(height: 20),
          WorkflowActionGuard(
            busy: commandState.isLoading,
            enabled: selected.isNotEmpty,
            label: 'Finalise lane set',
            icon: Icons.account_tree_outlined,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final command = WorkflowCommandFactory.create(
      type: WorkflowCommandType.finalizeLaneSet,
      aggregateId: widget.workflowId,
      expectedVersion: widget.expectedVersion,
      payload: <String, Object?>{
        'laneKeys': selected.map((lane) => lane.value).toList(growable: false),
      },
    );
    try {
      await ref.read(workflowCommandControllerProvider.notifier).execute(command);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}
