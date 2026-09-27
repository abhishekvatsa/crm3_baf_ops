import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../assets/data/asset_hierarchy_model.dart';
import '../../assets/providers/asset_hierarchy_provider.dart';
import '../../assets/presentation/widgets/governed_asset_target_picker.dart';
import '../../auth/domain/current_actor_access.dart';
import '../../auth/presentation/current_actor_gate.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance_workflow/providers/workflow_providers.dart';
import '../data/maintenance_model.dart';
import '../domain/maintenance_component_identification.dart';
import '../services/maintenance_component_identification_command.dart';
import '../services/maintenance_issue_command_reconciler.dart';

class MaintenanceComponentIdentificationPanel extends ConsumerStatefulWidget {
  const MaintenanceComponentIdentificationPanel({
    super.key,
    required this.ticket,
  });
  final MaintenanceRecord ticket;
  @override
  ConsumerState<MaintenanceComponentIdentificationPanel> createState() =>
      _IdentificationPanelState();
}

class _IdentificationPanelState
    extends ConsumerState<MaintenanceComponentIdentificationPanel> {
  bool _busy = false;
  String? _message;
  MaintenanceRecord? _refreshed;
  MaintenanceComponentIdentification? _accepted;

  Future<void> _identify() async {
    final ticket = _refreshed ?? widget.ticket;
    final actor = CurrentActorAccess.resolve(
      ref.read(currentAppUserProvider),
    ).actor;
    if (_busy ||
        actor?.canIdentifyMaintenanceComponent != true ||
        ref.read(firebaseAuthProvider).currentUser?.uid != actor!.uid) {
      return;
    }
    final draft =
        await showDialog<({AssetHierarchyReference target, String basis})>(
          context: context,
          barrierDismissible: false,
          builder: (_) => CurrentActorDialogGuard(
            originUid: actor.uid,
            permission: (user) => user.canIdentifyMaintenanceComponent,
            child: _IdentificationDialog(ticket: ticket),
          ),
        );
    if (!mounted || draft == null) return;
    final current = CurrentActorAccess.resolve(
      ref.read(currentAppUserProvider),
    ).actor;
    if (current?.uid != actor.uid ||
        current?.canIdentifyMaintenanceComponent != true ||
        ref.read(firebaseAuthProvider).currentUser?.uid != actor.uid) {
      return;
    }
    final controller = ref.read(workflowCommandControllerProvider.notifier);
    final reconciler = ref.read(maintenanceIssueCommandReconcilerProvider);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final command = buildMaintenanceComponentIdentificationCommand(
        ticket: ticket,
        target: draft.target,
        basis: draft.basis,
      );
      final receipt = await controller.execute(command);
      final accepted = validateMaintenanceComponentIdentificationReceipt(
        command: command,
        receipt: receipt,
        actorUid: actor.uid,
      );
      MaintenanceRecord? refreshed;
      String message =
          'Identification recorded. The original report and linked records are retained.';
      try {
        refreshed = await reconciler.adoptServerMutation(
          firestoreId: command.aggregateId,
          expectedLocalVersion: ticket.version,
          expectedLocalUpdatedAt: ticket.updatedAt.toUtc(),
          minimumServerVersion: receipt.aggregateVersion,
        );
      } on MaintenanceIssueCommandConvergenceException catch (error) {
        message = '$error';
      }
      if (mounted) {
        setState(() {
          _accepted = accepted;
          _refreshed = refreshed;
          _message = message;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Could not record identification: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _refreshed ?? widget.ticket;
    if (ticket.componentIntakeState == null && !ticket.hasLegacyBlankComponent) {
      return const SizedBox.shrink();
    }
    final actor = CurrentActorAccess.resolve(
      ref.watch(currentAppUserProvider),
    ).actor;
    final identified = _accepted ?? ticket.componentIdentification;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Originally reported component: ${ticket.componentIntakeLabel}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (ticket.component?.isNotEmpty == true) Text(ticket.component!),
          if (identified != null) ...[
            const SizedBox(height: 8),
            Text('Later identified component: ${identified.component}'),
            Text(
              'Identified by ${identified.identifiedByName} · ${DateFormat('dd MMM yyyy, HH:mm').format(identified.identifiedAt.toLocal())}',
            ),
            Text('Basis: ${identified.basis}'),
            const Text(
              'This later identification does not change the original report or establish a cause.',
            ),
          ] else if (ticket.awaitsComponentIdentification &&
              actor?.canIdentifyMaintenanceComponent == true)
            OutlinedButton.icon(
              key: const ValueKey('maintenance-identify-component'),
              onPressed: _busy || !ticket.isSynced ? null : _identify,
              icon: const Icon(Icons.search),
              label: Text(
                _busy ? 'Saving identification…' : 'Identify component',
              ),
            ),
          if (_message != null) Text(_message!),
        ],
      ),
    );
  }
}

class _IdentificationDialog extends ConsumerStatefulWidget {
  const _IdentificationDialog({required this.ticket});
  final MaintenanceRecord ticket;
  @override
  ConsumerState<_IdentificationDialog> createState() =>
      _IdentificationDialogState();
}

class _IdentificationDialogState extends ConsumerState<_IdentificationDialog> {
  final _basis = TextEditingController();
  AssetHierarchyReference? _target;
  bool _loading = false;
  String? _error;
  @override
  void dispose() {
    _basis.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final original = widget.ticket.assetHierarchyReference!;
      final repository = ref.read(assetHierarchyRepositoryProvider);
      final assets = await repository
          .watchAssetInstances(original.assetClassId)
          .first;
      final asset = assets.singleWhere(
        (value) => value.id == original.assetInstanceId && value.isActive,
      );
      // Inner Cover definitions belong to their own class; physical identity remains the Base.
      var definitionClass = original.assetClassId;
      if (widget.ticket.assetType == AssetType.innerCover) {
        final classes = await repository.watchAssetClasses().first;
        definitionClass = classes
            .singleWhere(
              (item) =>
                  item.isActive && item.legacyAssetTypeKey == 'innerCover',
            )
            .id;
      }
      final nodes = await repository.watchNodes(definitionClass).first;
      if (!mounted) return;
      final selection = await showGovernedAssetTargetPicker(
        context: context,
        asset: asset,
        nodes: nodes,
        definitionAssetClassId: definitionClass,
      );
      if (mounted && selection?.reference != null) {
        setState(() => _target = selection!.reference);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _error = 'The registered component could not be selected: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _save() {
    final target = _target;
    if (target == null) {
      setState(() => _error = 'Choose a registered component on this asset.');
      return;
    }
    try {
      buildMaintenanceComponentIdentificationCommand(
        ticket: widget.ticket,
        target: target,
        basis: _basis.text,
      );
      Navigator.pop(context, (target: target, basis: _basis.text.trim()));
    } catch (error) {
      setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Identify component'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Original asset: ${widget.ticket.assetType.name} ${widget.ticket.assetNumber}',
            ),
            const Text(
              'Add what was identified and the evidence used. The original report, completed work and linked Quality records remain unchanged.',
            ),
            OutlinedButton(
              key: const ValueKey('maintenance-identification-choose'),
              onPressed: _loading ? null : _choose,
              child: Text(_target?.nodeName ?? 'Choose registered component'),
            ),
            TextField(
              key: const ValueKey('maintenance-identification-basis'),
              controller: _basis,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Identification basis',
                hintText:
                    'What inspection or evidence identified this component?',
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _loading ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('maintenance-identification-save'),
        onPressed: _loading ? null : _save,
        child: const Text('Save identification'),
      ),
    ],
  );
}
