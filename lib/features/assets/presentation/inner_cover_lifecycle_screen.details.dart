part of 'inner_cover_lifecycle_screen.dart';

class _CoverDetailsSheet extends ConsumerWidget {
  final InnerCoverProfile cover;
  final _InnerCoverBulgeEvidence? bulgeEvidence;
  final bool canManage;
  final VoidCallback onAccept;
  final VoidCallback onAssign;
  final VoidCallback onDelink;
  final VoidCallback onState;

  const _CoverDetailsSheet({
    required this.cover,
    required this.bulgeEvidence,
    required this.canManage,
    required this.onAccept,
    required this.onAssign,
    required this.onDelink,
    required this.onState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(innerCoverHistoryProvider(cover.id));
    final fabrication = ref.watch(innerCoverFabricationProvider(cover.id));
    final pendingAcceptance = canManage
        ? ref.watch(innerCoverAcceptancePendingProvider(cover.id))
        : const AsyncData<DurableSubmission?>(null);
    final date = DateFormat('dd MMM yyyy, HH:mm');
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BafSpacing.xl,
            BafSpacing.sm,
            BafSpacing.xl,
            BafSpacing.xl,
          ),
          children: [
            Text(
              cover.serialNumber,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: BafColors.textPrimary,
              ),
            ),
            const SizedBox(height: BafSpacing.sm),
            Wrap(
              spacing: BafSpacing.sm,
              runSpacing: BafSpacing.sm,
              children: [
                StatusBadge(
                  label: cover.lifecycleState.label,
                  color: _stateColor(cover.lifecycleState),
                ),
                StatusBadge(
                  label: cover.traceabilityGrade.label,
                  color: BafColors.audit,
                ),
                if (bulgeEvidence?.hasConfirmedRecord == true)
                  const StatusBadge(
                    label: 'Confirmed bulge record',
                    color: BafColors.danger,
                  )
                else if (bulgeEvidence?.hasPendingSuspicion == true)
                  const StatusBadge(
                    label: 'Bulge confirmation pending',
                    color: BafColors.warning,
                  ),
              ],
            ),
            const SizedBox(height: BafSpacing.lg),
            if (const {
              InnerCoverLifecycleState.awaitingInspection,
              InnerCoverLifecycleState.underInspection,
            }.contains(cover.lifecycleState)) ...[
              Text(
                canManage
                    ? 'This cover is registered but cannot be assigned yet. Record the actual inspection and acceptance below.'
                    : 'This cover is registered but cannot be assigned yet. An approved Admin must record its inspection and acceptance.',
              ),
              const SizedBox(height: BafSpacing.md),
            ],
            _DetailRow(
              label: 'Origin',
              value: cover.originClassification.label,
            ),
            if (cover.receivedOrCompletedOn != null)
              _DetailRow(
                label: cover.sourceType.receiptOrCompletionDateLabel,
                value: _formatInnerCoverDate(cover.receivedOrCompletedOn!),
              ),
            if (cover.incorporatedOn != null)
              _DetailRow(
                label: 'Date incorporated',
                value: _formatInnerCoverDate(cover.incorporatedOn!),
              ),
            if (cover.supplierOrFabricator != null)
              _DetailRow(
                label: 'Supplier / fabricator',
                value: cover.supplierOrFabricator!,
              ),
            if (cover.currentBaseAssetNumber != null)
              _DetailRow(
                label: 'Current position',
                value: 'Base ${cover.currentBaseAssetNumber}',
              ),
            if (cover.retirementCondition != null)
              _DetailRow(
                label: 'Retirement condition',
                value: cover.retirementCondition!.label,
              ),
            if (cover.retiredAt != null)
              _DetailRow(
                label: 'Retired',
                value:
                    '${date.format(cover.retiredAt!.toLocal())} by ${cover.retiredByName}',
              ),
            if (cover.retirementReason != null)
              _DetailRow(
                label: 'Retirement reason',
                value: cover.retirementReason!,
              ),
            if (cover.returnedToInspectionAt != null)
              _DetailRow(
                label: 'Returned for inspection',
                value:
                    '${date.format(cover.returnedToInspectionAt!.toLocal())} by ${cover.returnedToInspectionByName}',
              ),
            if (cover.returnToInspectionReason != null)
              _DetailRow(
                label: 'Return reason',
                value: cover.returnToInspectionReason!,
              ),
            if (cover.drawingReference != null)
              _DetailRow(label: 'Drawing', value: cover.drawingReference!),
            if (cover.materialGrade != null)
              _DetailRow(label: 'Material', value: cover.materialGrade!),
            if (cover.acceptanceReference != null)
              _DetailRow(
                label: 'Acceptance',
                value: cover.acceptanceReference!,
              ),
            if (canManage) ...[
              const SizedBox(height: BafSpacing.lg),
              Wrap(
                spacing: BafSpacing.sm,
                runSpacing: BafSpacing.sm,
                children: [
                  if (const {
                    InnerCoverLifecycleState.awaitingInspection,
                    InnerCoverLifecycleState.underInspection,
                  }.contains(cover.lifecycleState))
                    FilledButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(Icons.verified_rounded),
                      label: const Text('Accept'),
                    ),
                  if (!const {
                    InnerCoverLifecycleState.awaitingInspection,
                    InnerCoverLifecycleState.underInspection,
                  }.contains(cover.lifecycleState) &&
                      (pendingAcceptance.valueOrNull != null || pendingAcceptance.hasError))
                    OutlinedButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(Icons.pending_actions_rounded),
                      label: const Text('Check saved acceptance'),
                    ),
                  if (cover.isInstalled)
                    OutlinedButton.icon(
                      onPressed: onDelink,
                      icon: const Icon(Icons.link_off_rounded),
                      label: const Text('Delink from Base'),
                    ),
                  if (cover.isAvailable)
                    FilledButton.icon(
                      onPressed: onAssign,
                      icon: const Icon(Icons.add_link_rounded),
                      label: const Text('Assign to Base'),
                    ),
                  if (!cover.isInstalled &&
                      cover.lifecycleState != InnerCoverLifecycleState.disposed)
                    OutlinedButton.icon(
                      onPressed: onState,
                      icon: const Icon(Icons.sync_alt_rounded),
                      label: Text(
                        cover.lifecycleState ==
                                InnerCoverLifecycleState.retiredForSalvage
                            ? 'Return for inspection'
                            : 'Change state',
                      ),
                    ),
                ],
              ),
            ],
            fabrication.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _InlineError(message: '$error'),
              data: (dossier) => dossier == null
                          ? const SizedBox.shrink()
                          : _FabricationSection(dossier: dossier),
            ),
            if (bulgeEvidence?.hasAnyRecord == true) ...[
              const SizedBox(height: BafSpacing.xl),
              const Text(
                'Bulge observations',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: BafSpacing.sm),
              if (bulgeEvidence?.declaration case final declaration?)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.report_problem_rounded,
                    color: BafColors.danger,
                  ),
                  title: const Text(
                    'Confirmed bulge declaration',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${declaration.evidenceCount} confirmation record${declaration.evidenceCount == 1 ? '' : 's'} · latest ${date.format(declaration.latestEvidenceAt.toLocal())}',
                  ),
                ),
              for (final item
                  in bulgeEvidence?.cases ?? const <FurnaceStuckupRecord>[])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    item.adjudicationStatus ==
                            FurnaceStuckupAdjudicationStatus.confirmed
                        ? Icons.verified_rounded
                        : item.adjudicationStatus ==
                            FurnaceStuckupAdjudicationStatus.inconclusive
                        ? Icons.help_outline_rounded
                        : Icons.schedule_rounded,
                    color:
                        item.adjudicationStatus ==
                                FurnaceStuckupAdjudicationStatus.confirmed
                            ? BafColors.danger
                            : BafColors.warning,
                  ),
                  title: Text(
                    'Furnace ${item.furnaceAssetNumber} on Base ${item.baseAssetNumber}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(_bulgeCaseSummary(item, date)),
                ),
            ],
            const SizedBox(height: BafSpacing.xl),
            const Text(
              'Base history',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: BafSpacing.sm),
            history.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _InlineError(message: '$error'),
              data: (items) => items.isEmpty
                          ? const Text(
                            'This cover has not yet been linked to a Base.',
                            style: TextStyle(color: BafColors.textSecondary),
                          )
                          : Column(
                      children: items
                                    .map(
                                      (item) => ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          item.active
                                              ? Icons.link_rounded
                                              : Icons.history_rounded,
                                color: item.active
                                                  ? BafColors.success
                                                  : BafColors.textSecondary,
                                        ),
                                        title: Text(
                                          'Base ${item.baseAssetNumber}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        subtitle: Text(
                                          item.active
                                              ? 'Paired ${date.format(item.installedAt.toLocal())} by ${item.installedByName}'
                                              : 'Paired ${date.format(item.installedAt.toLocal())} by ${item.installedByName}\nRemoved ${date.format(item.removedAt!.toLocal())} by ${item.removedByName}: ${item.removalReason}',
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BaseHistorySheet extends ConsumerWidget {
  final AssetInstanceRecord base;

  const _BaseHistorySheet({required this.base});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(baseInnerCoverHistoryProvider(base.id));
    final date = DateFormat('dd MMM yyyy, HH:mm');
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            BafSpacing.xl,
            BafSpacing.sm,
            BafSpacing.xl,
            BafSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Base ${base.assetNumber}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: BafSpacing.xs),
              const Text(
                'Inner Cover assignment history',
                style: TextStyle(color: BafColors.textSecondary),
              ),
              const SizedBox(height: BafSpacing.lg),
              Expanded(
                child: history.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => _InlineError(message: '$error'),
                  data: (items) => items.isEmpty
                              ? const _EmptyState(
                                icon: Icons.history_rounded,
                                message:
                                    'No Inner Cover assignment has been recorded for this Base.',
                              )
                              : ListView.separated(
                                itemCount: items.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      item.active
                                          ? Icons.link_rounded
                                          : Icons.history_rounded,
                                color: item.active
                                              ? BafColors.success
                                              : BafColors.textSecondary,
                                    ),
                                    title: Text(
                                      'Inner Cover ${item.innerCoverSerialNumber}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: Text(
                                      item.active
                                          ? 'Paired ${date.format(item.installedAt.toLocal())} by ${item.installedByName}'
                                          : 'Paired ${date.format(item.installedAt.toLocal())} by ${item.installedByName}\nRemoved ${date.format(item.removedAt!.toLocal())} by ${item.removedByName}: ${item.removalReason}',
                                    ),
                                  );
                                },
                              ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: BafSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(color: BafColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _FabricationSection extends StatelessWidget {
  final InnerCoverFabricationDossier dossier;

  const _FabricationSection({required this.dossier});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: BafSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fabrication genealogy',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: BafSpacing.sm),
        ...dossier.sections.map(
          (section) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_tree_outlined),
            title: Text(section.type.label),
            subtitle: Text(
              [
                section.materialSource.label,
                if (section.donorInnerCoverId != null)
                  'Donor ${section.donorInnerCoverId} / ${section.donorSectionKey}',
                if (section.lengthMm != null) '${section.lengthMm} mm',
                '${section.cutCount} cut${section.cutCount == 1 ? '' : 's'}',
              ].join(' · '),
            ),
          ),
        ),
      ],
    ),
  );
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: BafSpacing.md),
    child: Text(message, style: const TextStyle(color: BafColors.danger)),
  );
}
