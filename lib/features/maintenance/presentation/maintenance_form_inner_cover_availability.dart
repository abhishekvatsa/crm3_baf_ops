part of 'maintenance_form.dart';

enum _BaseIssueTarget { governedComponent, innerCoverAvailability }

extension _BaseInnerCoverAvailabilityFormState on _MaintenanceFormState {
  bool get _isBaseInnerCoverAvailability =>
      !_isFurnaceStuckup &&
      !_isBurnerLockout &&
      _assetType == AssetType.base &&
      _baseIssueTarget == _BaseIssueTarget.innerCoverAvailability;

  bool get _usesGovernedComponentIssueTarget =>
      !_isBurnerLockout && !_isFurnaceStuckup && !_isBaseInnerCoverAvailability;

  void _applyBaseIssueTarget(_BaseIssueTarget target) {
    if (target == _baseIssueTarget) return;
    final asset = _selectedPhysicalAsset();
    _baseIssueTarget = target;
    _resetAssetEvidence();
    _assetHierarchyReference = asset?.toReference();
    _plantConditionEffect =
        target == _BaseIssueTarget.innerCoverAvailability
            ? MaintenanceIssuePlantConditionEffect.unavailable
            : MaintenanceIssuePlantConditionEffect.unfit;
  }

  bool _validateBaseInnerCoverAvailabilitySubmission(AssetInstanceRecord base) {
    if (!_isBaseInnerCoverAvailability) return true;
    final error = _baseInnerCoverAvailabilitySubmissionError(
      ref.read(innerCoverAssignmentsProvider),
      base,
    );
    if (error == null) return true;
    _showMessage(error, BafColors.warning);
    return false;
  }

  List<Widget> get _baseIssueTargetControls {
    final selectedAsset = _selectedPhysicalAsset();
    if (_isFurnaceStuckup ||
        _assetType != AssetType.base ||
        selectedAsset == null) {
      return const <Widget>[];
    }
    return <Widget>[
      const SizedBox(height: BafSpacing.md),
      _BaseIssueTargetSelector(
        selected: _baseIssueTarget,
        onChanged: _setBaseIssueTarget,
      ),
    ];
  }

  List<Widget> get _baseInnerCoverAvailabilityControls {
    final selectedAsset = _selectedPhysicalAsset();
    if (selectedAsset == null) return const <Widget>[];
    return <Widget>[
      const SizedBox(height: BafSpacing.md),
      _BaseInnerCoverAvailabilityIntake(
        baseAssetInstanceId: selectedAsset.id,
        onOpenLifecycle:
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const InnerCoverLifecycleScreen(),
              ),
            ),
      ),
    ];
  }
}

String? _baseInnerCoverAvailabilitySubmissionError(
  AsyncValue<List<BaseInnerCoverAssignment>> assignments,
  AssetInstanceRecord base,
) {
  if (!assignments.hasValue) {
    return 'The current Inner Cover assignment cannot be verified. Sync and retry before raising this issue.';
  }
  final linked =
      assignments.value!
          .where((assignment) => assignment.baseAssetInstanceId == base.id)
          .firstOrNull;
  return linked == null
      ? null
      : 'Inner Cover ${linked.innerCoverSerialNumber} is still linked. Delink or retire it first.';
}

class _BaseIssueTargetSelector extends StatelessWidget {
  const _BaseIssueTargetSelector({
    required this.selected,
    required this.onChanged,
  });

  final _BaseIssueTarget selected;
  final ValueChanged<_BaseIssueTarget> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Issue target',
          style: TextStyle(
            color: BafColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: BafSpacing.sm),
        SegmentedButton<_BaseIssueTarget>(
          showSelectedIcon: false,
          segments: const <ButtonSegment<_BaseIssueTarget>>[
            ButtonSegment<_BaseIssueTarget>(
              value: _BaseIssueTarget.governedComponent,
              icon: Icon(Icons.account_tree_outlined),
              label: Text('Base component'),
            ),
            ButtonSegment<_BaseIssueTarget>(
              value: _BaseIssueTarget.innerCoverAvailability,
              icon: Icon(Icons.layers_clear_outlined),
              label: Text('No Inner Cover'),
            ),
          ],
          selected: <_BaseIssueTarget>{selected},
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
      ],
    );
  }
}

class _BaseInnerCoverAvailabilityIntake extends ConsumerWidget {
  const _BaseInnerCoverAvailabilityIntake({
    required this.baseAssetInstanceId,
    required this.onOpenLifecycle,
  });

  final String baseAssetInstanceId;
  final VoidCallback onOpenLifecycle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignments = ref.watch(innerCoverAssignmentsProvider);
    final linked =
        assignments.value
            ?.where(
              (assignment) =>
                  assignment.baseAssetInstanceId == baseAssetInstanceId,
            )
            .firstOrNull;
    final verifiedVacant = assignments.hasValue && linked == null;
    final color = verifiedVacant ? BafColors.success : BafColors.warning;
    final title = switch ((
      assignments.isLoading,
      assignments.hasError,
      linked,
    )) {
      (true, _, _) => 'Checking the current Inner Cover assignment',
      (_, true, _) => 'Inner Cover assignment could not be verified',
      (_, _, final assignment?) =>
        'Inner Cover ${assignment.innerCoverSerialNumber} is still linked',
      _ => 'No Inner Cover is linked to this Base',
    };
    final message =
        verifiedVacant
            ? 'No Base component or tag is needed. The issue will record the verified Inner Cover dependency and mark the Base unavailable.'
            : linked != null
            ? 'Use the governed lifecycle to delink or retire this Inner Cover before raising an availability issue.'
            : 'Sync the current assignment before submitting this issue.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.38)),
        borderRadius: BorderRadius.circular(BafRadius.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                verifiedVacant
                    ? Icons.verified_outlined
                    : Icons.layers_clear_outlined,
                color: color,
                size: 20,
              ),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.xs),
          Text(
            message,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          if (!verifiedVacant) ...[
            const SizedBox(height: BafSpacing.sm),
            OutlinedButton.icon(
              onPressed: onOpenLifecycle,
              icon: const Icon(Icons.layers_outlined),
              label: const Text('Open Inner Cover lifecycle'),
            ),
          ],
        ],
      ),
    );
  }
}

class _BaseInnerCoverAvailabilityConditionNotice extends StatelessWidget {
  const _BaseInnerCoverAvailabilityConditionNotice();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.block_outlined, color: BafColors.warning, size: 20),
        SizedBox(width: BafSpacing.sm),
        Expanded(
          child: Text(
            'Unavailable is applied automatically because the Base has no Inner Cover. Closing the issue removes only this issue-derived condition.',
            style: TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
