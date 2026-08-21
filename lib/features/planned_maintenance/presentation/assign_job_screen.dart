// FILE: lib/features/planned_maintenance/presentation/assign_job_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/job_template_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../assets/data/asset_registry_model.dart';
import '../../assets/data/inner_cover_lifecycle.dart';
import '../../assets/providers/asset_hierarchy_provider.dart';
import '../../../core/services/sync_coordinator.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/validation/charge_number.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../maintenance_workflow/domain/workflow_error.dart';
import '../../maintenance_workflow/domain/workflow_policy.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../../maintenance_workflow/providers/workflow_providers.dart';
import '../../maintenance_workflow/services/workflow_command_factory.dart';
import '../domain/governed_planned_work_asset_selection.dart';
import 'governed_planned_work_asset_selector.dart';

class AssignJobScreen extends ConsumerStatefulWidget {
  final JobTemplate template;

  const AssignJobScreen({super.key, required this.template});

  @override
  ConsumerState<AssignJobScreen> createState() => _AssignJobScreenState();
}

class _AssignJobScreenState extends ConsumerState<AssignJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _chargeNoController = TextEditingController();
  final _remarksController = TextEditingController();

  String? _selectedAssetInstanceId;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _chargeNoController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  AssetInstanceRecord? _selectedGovernedAsset() {
    final classes = ref.read(assetClassesProvider).asData?.value;
    if (classes == null) return null;
    final route = resolveGovernedPlannedWorkAssetRoute(
      assetType: widget.template.applicableAssetType,
      templateReference: widget.template.assetHierarchyReference,
      allClasses: classes,
    );
    final physicalClassId = route.physicalAssetClass?.id;
    if (!route.isAvailable || physicalClassId == null) return null;
    final assets =
        ref.read(assetInstancesProvider(physicalClassId)).asData?.value;
    if (assets == null) return null;
    final routeEligible = eligiblePlannedWorkAssets(
      route: route,
      assets: assets,
    );
    final linkedBaseIds =
        route.innerCoverByBase
            ? ref
                .read(innerCoverAssignmentsProvider)
                .asData
                ?.value
                .map((assignment) => assignment.baseAssetInstanceId)
                .toSet()
            : null;
    if (route.innerCoverByBase && linkedBaseIds == null) return null;
    final eligible =
        linkedBaseIds == null
            ? routeEligible
            : routeEligible
                .where((asset) => linkedBaseIds.contains(asset.id))
                .toList(growable: false);
    final selected =
        eligible
            .where((item) => item.id == _selectedAssetInstanceId)
            .firstOrNull;
    if (selected != null) return selected;
    if (route.fixedAssetInstanceId != null && eligible.length == 1) {
      return eligible.single;
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final templateFirestoreId = widget.template.firestoreId?.trim();
    if (templateFirestoreId == null || templateFirestoreId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot assign: template is missing its local sync ID.',
          ),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }

    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser == null || !appUser.canAssignJobExecution) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not authorized to assign planned jobs.'),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }

    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final selectedAsset = _selectedGovernedAsset();
      if (selectedAsset == null) {
        throw const WorkflowException(
          WorkflowErrorCode.invalidArgument,
          'Choose an active physical asset from the governed register.',
        );
      }
      final executionId = const Uuid().v4();
      final syncCoordinator = ref.read(syncCoordinatorProvider);

      await ref
          .read(workflowCommandControllerProvider.notifier)
          .execute(
            WorkflowCommandFactory.create(
              type: WorkflowCommandType.createLegacyWorkflowJob,
              aggregateId: executionId,
              expectedVersion: 0,
              payload: <String, Object?>{
                'assignmentSchemaVersion': 2,
                'executionId': executionId,
                'templateFirestoreId': templateFirestoreId,
                'expectedTemplateVersion': widget.template.version,
                'assetClassId': selectedAsset.assetClassId,
                'assetInstanceId': selectedAsset.id,
                if (_parseOptionalInt(_chargeNoController.text)
                    case final chargeNo?)
                  'chargeNoAtEvent': chargeNo,
                if (_cleanOptionalText(_remarksController.text)
                    case final remarks?)
                  'remarks': remarks,
              },
            ),
          );

      unawaited(
        syncCoordinator.runFullSync(
          reason: 'workflow_job_assigned',
          force: true,
        ),
      );

      if (!mounted) return;

      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.pop(context);
      Navigator.pop(context);

      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'Job assigned to ${widget.template.assignedAgencies.map((a) => a.toUpperCase()).join(', ')}',
          ),
          backgroundColor: BafColors.sync,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final message =
          e is WorkflowException && e.code == WorkflowErrorCode.unavailable
              ? 'Assignment requires an online connection. Nothing was submitted; your entries remain on this screen.'
              : 'Failed to assign job: $e';
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: BafColors.danger),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetClassesAsync = ref.watch(assetClassesProvider);
    final assetClasses = assetClassesAsync.asData?.value;
    final assetRoute =
        assetClasses == null
            ? null
            : resolveGovernedPlannedWorkAssetRoute(
              assetType: widget.template.applicableAssetType,
              templateReference: widget.template.assetHierarchyReference,
              allClasses: assetClasses,
            );
    final physicalClassId = assetRoute?.physicalAssetClass?.id;
    final assetInstancesAsync =
        physicalClassId == null
            ? null
            : ref.watch(assetInstancesProvider(physicalClassId));
    final innerCoverAssignmentsAsync =
        assetRoute?.innerCoverByBase == true
            ? ref.watch(innerCoverAssignmentsProvider)
            : null;
    final linkedInnerCoversByBase = {
      for (final assignment
          in innerCoverAssignmentsAsync?.asData?.value ??
              const <BaseInnerCoverAssignment>[])
        assignment.baseAssetInstanceId: assignment,
    };
    final routeEligibleAssets =
        assetRoute == null || assetInstancesAsync?.asData == null
            ? const <AssetInstanceRecord>[]
            : eligiblePlannedWorkAssets(
              route: assetRoute,
              assets: assetInstancesAsync!.requireValue,
            );
    final eligibleAssets =
        assetRoute?.innerCoverByBase == true
            ? routeEligibleAssets
                .where((asset) => linkedInnerCoversByBase.containsKey(asset.id))
                .toList(growable: false)
            : routeEligibleAssets;

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const Text('Assign Job'),
        backgroundColor: BafColors.card,
        foregroundColor: BafColors.textPrimary,
        elevation: 0,
        surfaceTintColor: BafColors.card,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            BafSpacing.lg,
            BafSpacing.md,
            BafSpacing.lg,
            BafSpacing.xl,
          ),
          children: [
            _TemplateContextCard(template: widget.template),
            if (WorkflowPolicy.onlineOnlyLifecycleCommands) ...[
              const SizedBox(height: BafSpacing.md),
              const _OnlineLifecycleNotice(),
            ],
            const SizedBox(height: BafSpacing.lg),
            _SectionCard(
              title: 'Job details',
              subtitle: 'Choose the exact asset and add assignment context.',
              icon: Icons.assignment_turned_in_rounded,
              children: [
                GovernedPlannedWorkAssetSelector(
                  assetType: widget.template.applicableAssetType,
                  classesValue: assetClassesAsync,
                  route: assetRoute,
                  assetsValue: assetInstancesAsync,
                  innerCoverAssignmentsValue: innerCoverAssignmentsAsync,
                  linkedInnerCoversByBase: linkedInnerCoversByBase,
                  eligibleAssets: eligibleAssets,
                  selectedAssetInstanceId: _selectedAssetInstanceId,
                  onAssetChanged:
                      _isSubmitting
                          ? null
                          : (asset) => setState(
                            () => _selectedAssetInstanceId = asset?.id,
                          ),
                ),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _chargeNoController,
                  keyboardType: TextInputType.number,
                  inputFormatters: chargeNumberInputFormatters,
                  decoration: _inputDecoration(
                    'Active charge number',
                    hint: 'Optional, exactly 5 digits',
                  ),
                  validator: validateChargeNumberText,
                ),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _remarksController,
                  maxLines: 3,
                  decoration: _inputDecoration(
                    'Instructions / remarks',
                    hint: 'Optional notes for attending teams',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: _AssignJobBottomBar(
        isSubmitting: _isSubmitting,
        onSubmit: _isSubmitting ? null : _submit,
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label, {
    String? hint,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: BafColors.card,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: BafSpacing.md,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        borderSide: const BorderSide(color: BafColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        borderSide: const BorderSide(color: BafColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        borderSide: const BorderSide(color: BafColors.planned, width: 1.5),
      ),
    );
  }
}

class _AssignJobBottomBar extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback? onSubmit;

  const _AssignJobBottomBar({
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          BafSpacing.lg,
          BafSpacing.md,
          BafSpacing.lg,
          BafSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: BafColors.card,
          border: Border(top: BorderSide(color: BafColors.border)),
        ),
        child: FilledButton.icon(
          onPressed: onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: BafColors.planned,
            foregroundColor: Colors.white,
            disabledBackgroundColor: BafColors.border,
            disabledForegroundColor: BafColors.textSecondary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BafRadius.medium),
            ),
          ),
          icon:
              isSubmitting
                  ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                  : const Icon(Icons.playlist_add_check_rounded),
          label: Text(
            isSubmitting ? 'Assigning...' : 'Assign Job',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _TemplateContextCard extends StatelessWidget {
  final JobTemplate template;

  const _TemplateContextCard({required this.template});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFF),
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.planned.withValues(alpha: 0.18)),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assign planned job',
            style: TextStyle(
              color: BafColors.planned,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            template.jobName,
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              height: 1.12,
            ),
          ),
          if (template.description != null &&
              template.description!.trim().isNotEmpty) ...[
            const SizedBox(height: BafSpacing.sm),
            Text(
              template.description!.trim(),
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: BafSpacing.md),
          Wrap(
            spacing: BafSpacing.sm,
            runSpacing: BafSpacing.sm,
            children: [
              StatusBadge(
                label: template.applicableAssetType.name.toUpperCase(),
                color: BafColors.assets,
                icon: Icons.precision_manufacturing_rounded,
              ),
              ...template.assignedAgencies.map(
                (agency) => StatusBadge(
                  label: agency.toUpperCase(),
                  color: _agencyColor(agency),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnlineLifecycleNotice extends StatelessWidget {
  const _OnlineLifecycleNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.warning.withValues(alpha: 0.45)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_outlined, color: BafColors.warning),
          SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              'Authoritative assignment requires connectivity. This lifecycle action is not queued offline; if the connection is unavailable, the form remains open and nothing is submitted.',
              style: TextStyle(
                color: BafColors.textPrimary,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: BafColors.planned, size: 22),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

String? _cleanOptionalText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

int? _parseOptionalInt(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return int.tryParse(trimmed);
}

Color _agencyColor(String agency) {
  switch (agency) {
    case 'operations':
      return BafColors.sync;
    case 'electrical':
      return const Color(0xFFF59E0B);
    case 'mechanical':
      return BafColors.planned;
    case 'instrumentation':
      return BafColors.audit;
    case 'refractory':
      return BafColors.directives;
    case 'emd':
      return BafColors.assets;
    case 'shiftInCharge':
      return BafColors.charges;
    case 'others':
      return BafColors.admin;
    default:
      return BafColors.admin;
  }
}
