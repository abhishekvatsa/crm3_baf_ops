import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../data/equipment_status_record.dart';
import '../../domain/workflow_types.dart';
import '../../providers/workflow_providers.dart';
import '../../services/workflow_command_factory.dart';

class EquipmentStatusBoard extends ConsumerWidget {
  const EquipmentStatusBoard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(equipmentStatusProvider(null));
    final commandState = ref.watch(workflowCommandControllerProvider);
    final actor = ref.watch(currentAppUserProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Equipment availability')),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) => ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, index) => _tile(
            context,
            ref,
            items[index],
            busy: commandState.isLoading,
            canReconcile: actor?.canReconcileMaintenanceEquipment ?? false,
          ),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    WidgetRef ref,
    EquipmentStatusRecord row, {
    required bool busy,
    required bool canReconcile,
  }) {
    return ListTile(
      leading: CircleAvatar(child: Icon(_icon(row.stateKey))),
      title: Text('${row.assetTypeKey} ${row.assetNumber}'),
      subtitle: Text(
        '${row.stateKey} · maintenance ${row.openMaintenanceCount} · RED ${row.openRedCount}',
      ),
      trailing: Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (row.stateKey == 'available')
            FilledButton.tonal(
              onPressed: busy ? null : () => _deploy(context, ref, row),
              child: const Text('In service'),
            )
          else if (row.awaitingPreparationCount > 0)
            const Chip(label: Text('Preparation pending')),
          if (canReconcile)
            IconButton(
              tooltip: 'Reconcile derived equipment state',
              onPressed: busy ? null : () => _reconcile(context, ref, row),
              icon: const Icon(Icons.sync_outlined),
            ),
        ],
      ),
    );
  }

  Future<void> _reconcile(
    BuildContext context,
    WidgetRef ref,
    EquipmentStatusRecord row,
  ) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reconcile equipment state?'),
        content: Text(
          'The server will recompute ${row.assetTypeKey} ${row.assetNumber} from all open workflow facts. No state is selected by the client.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reconcile'),
          ),
        ],
      ),
    );
    if (approved != true || !context.mounted) return;
    try {
      await ref.read(workflowCommandControllerProvider.notifier).execute(
        WorkflowCommandFactory.create(
          type: WorkflowCommandType.reconcileEquipment,
          aggregateId: 'equipment_${row.assetTypeKey}_${row.assetNumber}',
          expectedVersion: row.version,
          payload: <String, Object?>{
            'assetTypeKey': row.assetTypeKey,
            'assetNumber': row.assetNumber,
          },
        ),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Equipment state reconciled.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _deploy(
    BuildContext context,
    WidgetRef ref,
    EquipmentStatusRecord row,
  ) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deploy equipment to service?'),
        content: Text('${row.assetTypeKey} ${row.assetNumber} will be marked In Service.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Deploy')),
        ],
      ),
    );
    if (approved != true) return;
    await ref.read(workflowCommandControllerProvider.notifier).execute(
      WorkflowCommandFactory.create(
        type: WorkflowCommandType.deployEquipment,
        aggregateId: 'equipment_${row.assetTypeKey}_${row.assetNumber}',
        expectedVersion: row.version,
        payload: <String, Object?>{
          'assetTypeKey': row.assetTypeKey,
          'assetNumber': row.assetNumber,
        },
      ),
    );
  }

  IconData _icon(String state) {
    switch (state) {
      case 'inService': return Icons.play_circle_outline;
      case 'underMaintenance': return Icons.build_outlined;
      case 'awaitingPreparation': return Icons.hourglass_bottom;
      case 'underRED': return Icons.local_fire_department_outlined;
      case 'available': return Icons.check_circle_outline;
      default: return Icons.help_outline;
    }
  }
}
