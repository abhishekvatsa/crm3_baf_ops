import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../../core/widgets/baf_ui.dart';
import '../../../../core/widgets/incremental_list_footer.dart';
import '../../../assets/providers/plant_asset_overview_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../auth/services/auth_service.dart';
import '../../domain/missing_equipment_projection.dart';
import '../../domain/workflow_command_contract.dart';
import '../../providers/workflow_providers.dart';

class MissingEquipmentProjectionScreen extends ConsumerStatefulWidget {
  const MissingEquipmentProjectionScreen({super.key});

  @override
  ConsumerState<MissingEquipmentProjectionScreen> createState() =>
      _MissingEquipmentProjectionScreenState();
}

class _MissingEquipmentProjectionScreenState
    extends ConsumerState<MissingEquipmentProjectionScreen> {
  int _authorityGeneration = 0;
  int _limit = businessListPageSize;
  final _accepted = <String>{};
  final _commands = <String, WorkflowCommand>{};

  @override
  void initState() {
    super.initState();
    // A revoked/replaced session cannot resume an old confirmation even if the
    // same UID is restored before the dialog closes.
    ref.listenManual(currentAppUserProvider, (_, _) {
      _authorityGeneration++;
    });
    ref.listenManual(signOutInProgressProvider, (_, _) {
      _authorityGeneration++;
    });
  }

  List<MissingEquipmentProjection>? _candidates() {
    final classes = ref.read(plantClassEvidenceProvider);
    final assets = ref.read(plantAssetEvidenceProvider);
    final workflow = ref.read(plantWorkflowEvidenceProvider);
    if (classes.isLoading ||
        classes.hasError ||
        assets.isLoading ||
        assets.hasError ||
        workflow.isLoading ||
        workflow.hasError) {
      return null;
    }
    return missingEquipmentProjections(
      classes: classes.asData?.value,
      assets: assets.asData?.value,
      workflow: workflow.asData?.value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authority = ref.watch(currentAppUserProvider);
    final actor = authority.asData?.value;
    final ending = ref.watch(signOutInProgressProvider);
    final allowed =
        !authority.isLoading &&
        !authority.hasError &&
        !ending &&
        actor?.canReconcileMaintenanceEquipment == true;
    if (!allowed) {
      return BafScreenStateScaffold.access(
        appBarTitle: 'Missing equipment states',
        appBarSubtitle: 'Review registered equipment',
        appBarIcon: Icons.fact_check_outlined,
        accent: BafColors.assets,
        title: 'Admin or SI access required',
        message: 'An approved Admin or SI must review this reconciliation.',
      );
    }
    ref.watch(plantClassEvidenceProvider);
    ref.watch(plantAssetEvidenceProvider);
    ref.watch(plantWorkflowEvidenceProvider);
    final candidates = _candidates();
    final busy = ref.watch(workflowCommandControllerProvider).isLoading;
    final visible = candidates?.take(_limit).toList() ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Missing equipment states')),
      body: BafContentFrame(
        maxWidth: 960,
        child: candidates == null
            ? BafStatePanel.error(
                title: 'Current evidence is required',
                message:
                    'The complete registered-asset and workflow records '
                    'must be confirmed by the server. Cached, loading or '
                    'unreadable evidence cannot establish a missing state.',
                onPrimary: _refresh,
              )
            : ListView(
                padding: const EdgeInsets.all(BafSpacing.lg),
                children: [
                  Text(
                    '${candidates.length} registered assets need a workflow state',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: BafSpacing.sm),
                  const Text(
                    'The server recalculates each state from recorded '
                    'workflow facts. Reconciliation does not clear Down, Unfit, '
                    'stuck-up conditions or open issues, and does not record '
                    'repair or deployment dates. Conflicting registry identities '
                    'are excluded and require separate review.',
                  ),
                  const SizedBox(height: BafSpacing.lg),
                  if (candidates.isEmpty)
                    const Text(
                      'No unambiguous missing workflow state was found. '
                      'This is not a plant availability clearance.',
                    ),
                  for (final candidate in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: BafSpacing.md),
                      child: BafRecordSurface(
                        accent: BafColors.warning,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              candidate.asset.displayLabel,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${candidate.assetClass.name} · '
                              '${candidate.asset.serviceState.name}',
                            ),
                            const SizedBox(height: BafSpacing.sm),
                            OutlinedButton.icon(
                              key: ValueKey(
                                'reconcile-missing-${candidate.asset.id}',
                              ),
                              onPressed:
                                  busy || _accepted.contains(candidate.asset.id)
                                  ? null
                                  : () => _review(candidate),
                              icon: const Icon(Icons.sync),
                              label: Text(
                                _accepted.contains(candidate.asset.id)
                                    ? 'Accepted; awaiting current state'
                                    : 'Review reconciliation',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  IncrementalListFooter(
                    visibleCount: visible.length,
                    totalCount: candidates.length,
                    onShowMore: () =>
                        setState(() => _limit += businessListPageSize),
                  ),
                ],
              ),
      ),
    );
  }

  void _refresh() {
    ref.invalidate(plantClassEvidenceProvider);
    ref.invalidate(plantAssetEvidenceProvider);
    ref.invalidate(plantWorkflowEvidenceProvider);
  }

  Future<void> _review(MissingEquipmentProjection candidate) async {
    final actor = ref.read(currentAppUserProvider).asData?.value;
    final generation = _authorityGeneration;
    if (actor?.canReconcileMaintenanceEquipment != true ||
        ref.read(signOutInProgressProvider)) {
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reconcile missing equipment state?'),
        content: SingleChildScrollView(
          child: Text(
            '${candidate.asset.displayLabel}\n'
            'Registered identity: ${candidate.asset.id}\n\n'
            'The server will calculate the workflow counters from actual records. '
            'No available state or zero counts are assumed. Independent '
            'restrictions and unknown physical dates are preserved.',
          ),
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
    if (!mounted || approved != true) return;
    try {
      final authority = ref.read(currentAppUserProvider);
      final latestActor = authority.asData?.value;
      if (generation != _authorityGeneration ||
          authority.isLoading ||
          authority.hasError ||
          ref.read(signOutInProgressProvider) ||
          latestActor?.uid != actor!.uid ||
          latestActor?.authorityRevision != actor.authorityRevision ||
          latestActor?.canReconcileMaintenanceEquipment != true) {
        throw StateError(
          'Account access changed. Review again with the original approved account.',
        );
      }
      final latest = _candidates()
          ?.where((row) => row.reviewBasis == candidate.reviewBasis)
          .toList();
      if (latest?.length != 1) {
        throw StateError(
          'The current registry or workflow evidence changed. Refresh and review again.',
        );
      }
      if (ref.read(workflowCommandControllerProvider).isLoading) {
        throw StateError('Another equipment action is still being confirmed.');
      }
      // Retry the same reviewed action with the same immutable command.
      // The existing executor retains uncertain outcomes across app restarts.
      final command = _commands.putIfAbsent(
        '${actor.uid}:${actor.authorityRevision}:${candidate.reviewBasis}',
        candidate.command,
      );
      final receipt = await ref
          .read(workflowCommandControllerProvider.notifier)
          .execute(command);
      if (!mounted || generation != _authorityGeneration) return;
      if (receipt.commandId != command.commandId ||
          receipt.resultKey != 'equipment-reconciled' ||
          receipt.aggregateVersion != 1) {
        throw StateError(
          'The reconciliation result needs review. Refresh current evidence.',
        );
      }
      setState(() => _accepted.add(candidate.asset.id));
      // The live evidence stream removes the candidate after the server write;
      // keep accepted actions disabled until that confirmation arrives.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Workflow state reconciled. Independent restrictions remain unchanged.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}
