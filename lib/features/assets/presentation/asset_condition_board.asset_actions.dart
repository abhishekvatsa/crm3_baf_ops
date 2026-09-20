part of 'asset_condition_board.dart';

enum _AssetConditionAction { declareDown, declareUnfit, restore, retire }

class _AssetConditionRow extends ConsumerWidget {
  final PlantAssetState state;
  final AssetClassRecord assetClass;
  final AppUser? user;
  final List<MaintenanceRecord> openTickets;

  const _AssetConditionRow({
    required this.state,
    required this.assetClass,
    required this.user,
    required this.openTickets,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canDeclare =
        user?.canDeclareAssetOperationalCondition == true &&
        state.permitsManualChange &&
        !state.isAdministrativelyOutOfService;
    final canRestore =
        user?.canRestoreAssetOperationalCondition == true &&
        state.permitsManualChange &&
        (state.isDown || state.isManuallyUnfit);
    final canRetire =
        state.permitsManualChange &&
        user?.isApproved == true &&
        (user!.isAdmin || user!.isSI);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BafSpacing.md,
        BafSpacing.md,
        BafSpacing.sm,
        BafSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _primaryColor(state).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(BafRadius.small),
            ),
            child: Icon(
              _primaryIcon(state),
              color: _primaryColor(state),
              size: 20,
            ),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.asset.name,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: BafSpacing.xs),
                Wrap(
                  spacing: BafSpacing.xs,
                  runSpacing: BafSpacing.xs,
                  children: _stateBadges(state),
                ),
                PendingAssetCondition(assetId: state.asset.id),
                if (state.operationalCondition?.active == true) ...[
                  const SizedBox(height: BafSpacing.sm),
                  Text(
                    state.operationalCondition!.reason,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BafColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (state.operationalCondition!.basis case final basis?) ...[
                    const SizedBox(height: BafSpacing.xs),
                    Text(
                      <String>[
                        basis.label,
                        if (state.operationalCondition!.componentReference
                            case final reference?)
                          reference.hierarchyPath.join(' › '),
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: BafSpacing.xs),
                  Text(
                    'Declared ${DateFormat('dd MMM, HH:mm').format(state.operationalCondition!.declaredAt!.toLocal())} by ${state.operationalCondition!.declaredByName}',
                    style: const TextStyle(
                      color: BafColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
                if (state.issueConditionContributions.isNotEmpty) ...[
                  const SizedBox(height: BafSpacing.sm),
                  for (final contribution
                      in state.issueConditionContributions) ...[
                    Text(
                      contribution.comment,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            contribution.effect ==
                                MaintenanceIssuePlantConditionEffect.unavailable
                            ? BafColors.cobalt
                            : BafColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: BafSpacing.xs),
                    Text(
                      <String>[
                        'Raised ${DateFormat('dd MMM, HH:mm').format(contribution.startedAt.toLocal())}',
                        if (contribution.raisedByName case final name?)
                          'by $name',
                      ].join(' '),
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (canDeclare || canRestore || canRetire)
            PopupMenuButton<_AssetConditionAction>(
              tooltip: 'Asset condition actions',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (action) => _runAction(context, ref, action),
              itemBuilder: (context) => [
                if (canDeclare)
                  const PopupMenuItem(
                    value: _AssetConditionAction.declareDown,
                    child: Text('Declare down'),
                  ),
                if (canDeclare)
                  const PopupMenuItem(
                    value: _AssetConditionAction.declareUnfit,
                    child: Text('Declare unfit'),
                  ),
                if (canRestore)
                  const PopupMenuItem(
                    value: _AssetConditionAction.restore,
                    child: Text('Clear manual restriction'),
                  ),
                if (canRetire)
                  const PopupMenuItem(
                    value: _AssetConditionAction.retire,
                    child: Text('Retire physical asset'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _runAction(
    BuildContext context,
    WidgetRef ref,
    _AssetConditionAction action,
  ) async {
    final actor = user;
    if (actor == null) return;
    if (action == _AssetConditionAction.retire) {
      final reason = await _showReasonDialog(
        context,
        title: 'Retire ${state.asset.name}',
        actionLabel: 'Retire',
        hint:
            'Give the permanent retirement reason. Manual restrictions remain unresolved in history; this does not record a repair. Installed components and relevant issues must be handled first.',
      );
      if (reason == null || !context.mounted) return;
      await _perform(context, () async {
        final current = ref.read(currentAppUserProvider).asData?.value;
        if (current?.uid != actor.uid ||
            current?.isApproved != true ||
            !(current!.isAdmin || current.isSI)) {
          throw StateError(
            'Return to the original authorized account before retiring this asset.',
          );
        }
        await ref
            .read(assetHierarchyRepositoryProvider)
            .setAssetInstanceStatus(
              before: state.asset,
              status: AssetHierarchyStatus.retired,
              actor: current,
              reason: reason,
            );
      }, 'Asset retired. Existing manual restrictions remain in history.');
      return;
    }
    if (action == _AssetConditionAction.restore) {
      final reason = await _showReasonDialog(
        context,
        title: 'Restore ${state.asset.name}',
        actionLabel: 'Restore',
        hint: 'State the evidence that clears this manual condition.',
      );
      if (reason == null || !context.mounted) return;
      await _perform(context, () async {
        await ref
            .read(assetConditionSubmissionControllerProvider)
            .submitRestore(
              asset: state.asset,
              current: state.operationalCondition!,
              reason: reason,
              originActorUid: actor.uid,
            );
      }, 'Manual condition cleared; remaining restrictions still apply.');
      ref.invalidate(assetConditionPendingProvider(state.asset.id));
      return;
    }
    if (state.operationalCondition?.active == true) {
      if (!actor.canRestoreAssetOperationalCondition) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Replacing an active assessment requires Shift Supervisor, SI or Admin review.',
            ),
          ),
        );
        return;
      }
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace the complete manual assessment?'),
          content: Text(
            'Current assessment: ${state.operationalCondition!.condition.label}\n${state.operationalCondition!.reason}\n\nThe new assessment replaces all current manual causes and linked issues. Include every restriction that still applies. The previous assessment remains in history; independent workflow and issue restrictions remain.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep current'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reviewed — replace assessment'),
            ),
          ],
        ),
      );
      if (!context.mounted || replace != true) return;
    }
    final condition = action == _AssetConditionAction.declareDown
        ? AssetOperationalCondition.down
        : AssetOperationalCondition.unfit;
    final List<MaintenanceRecord> linkedTickets;
    try {
      linkedTickets = _ticketsForAsset(openTickets, state.asset.id);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Open issue data could not be verified: $error'),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }
    final draft = await showModalBottomSheet<_ConditionDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _DeclareConditionSheet(
        asset: state.asset,
        isBase: assetClass.legacyAssetTypeKey == 'base',
        condition: condition,
        tickets: linkedTickets,
      ),
    );
    if (draft == null || !context.mounted) return;
    await _perform(context, () async {
      await ref
          .read(assetConditionSubmissionControllerProvider)
          .submitDeclare(
            asset: state.asset,
            condition: condition,
            causes: draft.causes,
            basis: draft.basis,
            componentReference: draft.componentReference,
            reason: draft.reason,
            linkedIssueIds: draft.linkedIssueIds,
            expectedVersion: state.operationalCondition?.version ?? 0,
            replacesRequestId: state.operationalCondition?.active == true
                ? state.operationalCondition!.lastMutationId
                : null,
            originActorUid: actor.uid,
          );
    }, '${condition.label} condition recorded.');
    ref.invalidate(assetConditionPendingProvider(state.asset.id));
  }
}
