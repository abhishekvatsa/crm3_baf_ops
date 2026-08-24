import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../../core/widgets/baf_ui.dart';
import '../../../../core/widgets/brand/brand_widgets.dart';
import '../../../../core/widgets/dashboard/status_badge.dart';
import '../../../auth/providers/auth_provider.dart';
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
  ConsumerState<LaneClassificationScreen> createState() =>
      _LaneClassificationScreenState();
}

class _LaneClassificationScreenState
    extends ConsumerState<LaneClassificationScreen> {
  final Set<MaintenanceLaneId> selected = <MaintenanceLaneId>{};

  @override
  Widget build(BuildContext context) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading) {
      return BafScreenStateScaffold.loading(
        appBarTitle: 'Classify maintenance lanes',
        appBarSubtitle: 'Verifying your approved workflow scope',
        appBarIcon: Icons.account_tree_outlined,
        accent: BafColors.maintenance,
        label: 'Checking lane-classification access',
      );
    }
    if (actorAsync.hasError) {
      return BafScreenStateScaffold.error(
        appBarTitle: 'Classify maintenance lanes',
        appBarSubtitle: 'Verifying your approved workflow scope',
        appBarIcon: Icons.account_tree_outlined,
        accent: BafColors.maintenance,
        message: 'Lane-classification access could not be verified.',
      );
    }
    final actor = actorAsync.value;
    if (actor == null || !actor.canFinalizeMaintenanceLaneSet) {
      return BafScreenStateScaffold.access(
        appBarTitle: 'Classify maintenance lanes',
        appBarSubtitle: 'Set independent ownership before work begins',
        appBarIcon: Icons.account_tree_outlined,
        accent: BafColors.maintenance,
        title: 'Lane-classification access required',
        message:
            'Your approved role cannot finalise planned-job lane ownership.',
      );
    }
    final commandState = ref.watch(workflowCommandControllerProvider);
    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const BafAppBarTitle(
          title: 'Classify maintenance lanes',
          subtitle: 'Set independent ownership before work begins',
          icon: Icons.account_tree_outlined,
          accent: BafColors.maintenance,
        ),
      ),
      body: BafContentFrame(
        maxWidth: 760,
        child: ListView(
          children: [
            BafScreenIntro(
              title: 'Required teams',
              subtitle:
                  'Select every department that must independently acknowledge and close its work.',
              icon: Icons.groups_2_outlined,
              accent: BafColors.maintenance,
              trailing: StatusBadge(
                label: '${selected.length} selected',
                color:
                    selected.isEmpty
                        ? BafColors.textSecondary
                        : BafColors.maintenance,
              ),
            ),
            const SizedBox(height: BafSpacing.lg),
            for (final definition in MaintenanceLaneCatalog.crm3.definitions)
              Padding(
                padding: const EdgeInsets.only(bottom: BafSpacing.sm),
                child: BafRecordSurface(
                  accent:
                      selected.contains(definition.id)
                          ? BafColors.maintenance
                          : null,
                  padding: EdgeInsets.zero,
                  onTap:
                      () => _setLane(
                        definition.id,
                        !selected.contains(definition.id),
                      ),
                  child: CheckboxListTile(
                    value: selected.contains(definition.id),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      '${definition.code} - ${definition.displayName}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle:
                        definition.delegated
                            ? const Text(
                              'Digitally coordinated by Admin/SI on behalf of EMD',
                            )
                            : const Text(
                              'Independent acknowledgement and closure',
                            ),
                    onChanged:
                        commandState.isLoading
                            ? null
                            : (value) =>
                                _setLane(definition.id, value ?? false),
                  ),
                ),
              ),
            const SizedBox(height: 84),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: BafColors.card,
            border: Border(top: BorderSide(color: BafColors.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(BafSpacing.md),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 736),
                child: SizedBox(
                  width: double.infinity,
                  child: WorkflowActionGuard(
                    busy: commandState.isLoading,
                    enabled: selected.isNotEmpty,
                    label:
                        selected.isEmpty
                            ? 'Select at least one lane'
                            : 'Finalise ${selected.length} lane${selected.length == 1 ? '' : 's'}',
                    icon: Icons.account_tree_outlined,
                    onPressed: _submit,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _setLane(MaintenanceLaneId lane, bool value) {
    setState(() {
      if (value) {
        selected.add(lane);
      } else {
        selected.remove(lane);
      }
    });
  }

  Future<void> _submit() async {
    final actorAsync = ref.read(currentAppUserProvider);
    final actor =
        actorAsync.isLoading || actorAsync.hasError ? null : actorAsync.value;
    if (actor == null || !actor.canFinalizeMaintenanceLaneSet) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lane-classification authority is no longer valid.'),
        ),
      );
      return;
    }
    final command = WorkflowCommandFactory.create(
      type: WorkflowCommandType.finalizeLaneSet,
      aggregateId: widget.workflowId,
      expectedVersion: widget.expectedVersion,
      payload: <String, Object?>{
        'laneKeys': selected.map((lane) => lane.value).toList(growable: false),
      },
    );
    try {
      await ref
          .read(workflowCommandControllerProvider.notifier)
          .execute(command);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}
