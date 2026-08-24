import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../../core/widgets/baf_ui.dart';
import '../../../../core/widgets/brand/brand_widgets.dart';
import '../../../../core/widgets/dashboard/status_badge.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/equipment_status_record.dart';
import '../../domain/equipment_command_identity.dart';
import '../../domain/workflow_types.dart';
import '../../providers/workflow_providers.dart';
import '../../services/workflow_command_factory.dart';

class EquipmentStatusBoard extends ConsumerWidget {
  const EquipmentStatusBoard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading && !actorAsync.hasValue) {
      return BafScreenStateScaffold.loading(
        appBarTitle: 'Equipment availability',
        appBarSubtitle: 'Verifying your approved workflow scope',
        appBarIcon: Icons.precision_manufacturing_outlined,
        accent: BafColors.assets,
        label: 'Checking equipment-state access',
      );
    }
    if (actorAsync.hasError) {
      return BafScreenStateScaffold.error(
        appBarTitle: 'Equipment availability',
        appBarSubtitle: 'Verifying your approved workflow scope',
        appBarIcon: Icons.precision_manufacturing_outlined,
        accent: BafColors.assets,
        message: 'Equipment-state access could not be verified.',
      );
    }
    final actor = actorAsync.value;
    if (actor == null || !actor.isApproved) {
      return BafScreenStateScaffold.access(
        appBarTitle: 'Equipment availability',
        appBarSubtitle: 'Derived workflow state and service readiness',
        appBarIcon: Icons.precision_manufacturing_outlined,
        accent: BafColors.assets,
        title: 'Equipment-state access required',
        message: 'An approved account is required to view equipment state.',
      );
    }
    final rows = ref.watch(equipmentStatusProvider(null));
    final commandState = ref.watch(workflowCommandControllerProvider);
    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const BafAppBarTitle(
          title: 'Equipment availability',
          subtitle: 'Derived workflow state and service readiness',
          icon: Icons.precision_manufacturing_outlined,
          accent: BafColors.assets,
        ),
      ),
      body: BafContentFrame(
        maxWidth: 960,
        child: rows.when(
          loading:
              () => const BafLoadingPanel(
                label: 'Loading equipment state',
                color: BafColors.assets,
              ),
          error:
              (error, _) => BafStatePanel.error(
                title: 'Equipment state is unavailable',
                message: '$error',
                onPrimary: () => ref.invalidate(equipmentStatusProvider(null)),
              ),
          data: (items) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BafScreenIntro(
                  title: 'Plant equipment state',
                  subtitle:
                      'Availability is calculated from governed workflow facts.',
                  icon: Icons.settings_input_component_outlined,
                  accent: BafColors.assets,
                  trailing: StatusBadge(
                    label: '${items.length} assets',
                    color: BafColors.assets,
                  ),
                ),
                const SizedBox(height: BafSpacing.lg),
                Expanded(
                  child:
                      items.isEmpty
                          ? BafStatePanel.empty(
                            title: 'No equipment projections',
                            message:
                                'Equipment will appear after the governed asset projection is available.',
                            icon: Icons.precision_manufacturing_outlined,
                            color: BafColors.assets,
                          )
                          : RefreshIndicator(
                            onRefresh: () async {
                              ref.invalidate(equipmentStatusProvider(null));
                            },
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: items.length,
                              separatorBuilder:
                                  (_, __) =>
                                      const SizedBox(height: BafSpacing.sm),
                              itemBuilder:
                                  (_, index) => _tile(
                                    context,
                                    ref,
                                    items[index],
                                    busy: commandState.isLoading,
                                    canDeploy:
                                        actor.canDeployMaintenanceEquipment,
                                    canReconcile:
                                        actor.canReconcileMaintenanceEquipment,
                                  ),
                            ),
                          ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    WidgetRef ref,
    EquipmentStatusRecord row, {
    required bool busy,
    required bool canDeploy,
    required bool canReconcile,
  }) {
    final color = _stateColor(row.stateKey);
    return BafRecordSurface(
      accent: color,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final identity = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(BafRadius.small),
                ),
                child: Icon(_icon(row.stateKey), color: color),
              ),
              const SizedBox(width: BafSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${row.assetTypeKey} ${row.assetNumber}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: BafSpacing.xs),
                    Wrap(
                      spacing: BafSpacing.sm,
                      runSpacing: BafSpacing.xs,
                      children: [
                        StatusBadge(
                          label: _stateLabel(row.stateKey),
                          color: color,
                        ),
                        StatusBadge(
                          label: '${row.openMaintenanceCount} maintenance',
                          color: BafColors.maintenance,
                        ),
                        StatusBadge(
                          label: '${row.openRedCount} RED',
                          color: BafColors.danger,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: BafSpacing.sm,
            runSpacing: BafSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (row.stateKey == 'available' && canDeploy)
                FilledButton.icon(
                  onPressed: busy ? null : () => _deploy(context, ref, row),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Put in service'),
                  style: FilledButton.styleFrom(
                    backgroundColor: BafColors.assets,
                    foregroundColor: Colors.white,
                  ),
                )
              else if (row.awaitingPreparationCount > 0)
                const StatusBadge(
                  label: 'Preparation pending',
                  color: BafColors.warning,
                  icon: Icons.hourglass_bottom_rounded,
                ),
              if (canReconcile)
                IconButton.outlined(
                  tooltip: 'Reconcile derived equipment state',
                  onPressed: busy ? null : () => _reconcile(context, ref, row),
                  icon: const Icon(Icons.sync_outlined),
                ),
            ],
          );
          if (constraints.maxWidth < 640) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                if (actions.children.isNotEmpty) ...[
                  const SizedBox(height: BafSpacing.md),
                  Align(alignment: Alignment.centerLeft, child: actions),
                ],
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: BafSpacing.md),
              actions,
            ],
          );
        },
      ),
    );
  }

  String _stateLabel(String state) {
    switch (state) {
      case 'inService':
        return 'In service';
      case 'underMaintenance':
        return 'Under maintenance';
      case 'awaitingPreparation':
        return 'Awaiting preparation';
      case 'underRED':
        return 'Under RED';
      case 'available':
        return 'Available';
      default:
        return state;
    }
  }

  Color _stateColor(String state) {
    switch (state) {
      case 'inService':
        return BafColors.cobalt;
      case 'underMaintenance':
        return BafColors.maintenance;
      case 'awaitingPreparation':
        return BafColors.warning;
      case 'underRED':
        return BafColors.danger;
      case 'available':
        return BafColors.success;
      default:
        return BafColors.steel;
    }
  }

  Future<void> _reconcile(
    BuildContext context,
    WidgetRef ref,
    EquipmentStatusRecord row,
  ) async {
    final approved = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
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
      final identity = EquipmentCommandIdentity.fromRecord(row);
      await ref
          .read(workflowCommandControllerProvider.notifier)
          .execute(
            WorkflowCommandFactory.create(
              type: WorkflowCommandType.reconcileEquipment,
              aggregateId: identity.aggregateId,
              expectedVersion: row.version,
              payload: identity.payload,
            ),
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Equipment state reconciled.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _deploy(
    BuildContext context,
    WidgetRef ref,
    EquipmentStatusRecord row,
  ) async {
    final approved = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Deploy equipment to service?'),
            content: Text(
              '${row.assetTypeKey} ${row.assetNumber} will be marked In Service.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Deploy'),
              ),
            ],
          ),
    );
    if (approved != true || !context.mounted) return;
    try {
      final identity = EquipmentCommandIdentity.fromRecord(row);
      await ref
          .read(workflowCommandControllerProvider.notifier)
          .execute(
            WorkflowCommandFactory.create(
              type: WorkflowCommandType.deployEquipment,
              aggregateId: identity.aggregateId,
              expectedVersion: row.version,
              payload: identity.payload,
            ),
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Equipment deployed to service.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  IconData _icon(String state) {
    switch (state) {
      case 'inService':
        return Icons.play_circle_outline;
      case 'underMaintenance':
        return Icons.build_outlined;
      case 'awaitingPreparation':
        return Icons.hourglass_bottom;
      case 'underRED':
        return Icons.local_fire_department_outlined;
      case 'available':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }
}
