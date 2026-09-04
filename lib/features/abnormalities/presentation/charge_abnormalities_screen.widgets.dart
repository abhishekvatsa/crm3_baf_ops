part of 'charge_abnormalities_screen.dart';

class _DeleteAbnormalityDialog extends StatefulWidget {
  const _DeleteAbnormalityDialog();

  @override
  State<_DeleteAbnormalityDialog> createState() =>
      _DeleteAbnormalityDialogState();
}

class _DeleteAbnormalityDialogState extends State<_DeleteAbnormalityDialog> {
  final TextEditingController _reasonController = TextEditingController();

  AuditReason? _selectedReason;
  String? _validationError;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Charge Abnormality'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This abnormality will be hidden but retained for audit and sync traceability.',
              style: TextStyle(color: BafColors.textSecondary),
            ),
            const SizedBox(height: BafSpacing.md),
            DropdownButtonFormField<AuditReason>(
              initialValue: _selectedReason,
              isExpanded: true,
              decoration: _inputDecoration(label: 'Reason', hint: 'Optional'),
              items:
                  AuditReason.values.map((reason) {
                    return DropdownMenuItem(
                      value: reason,
                      child: Text(
                        _auditReasonLabel(reason),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedReason = value;
                  _validationError = null;
                });
              },
            ),
            const SizedBox(height: BafSpacing.md),
            TextFormField(
              controller: _reasonController,
              maxLines: 2,
              onChanged: (_) => setState(() => _validationError = null),
              decoration: _inputDecoration(
                label: 'Additional notes',
                hint: 'Optional',
                errorText: _validationError,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: BafColors.danger,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            final notes = _emptyToNull(_reasonController.text);
            final combined = <String>[
              if (_selectedReason != null) _auditReasonLabel(_selectedReason!),
              if (notes != null) notes,
            ].join(': ');
            if (combined.isEmpty) {
              setState(() {
                _validationError =
                    'Choose a reason or explain why this record is being deleted.';
              });
              return;
            }
            if (combined.length > 500) {
              setState(() {
                _validationError =
                    'The combined deletion reason must not exceed 500 characters.';
              });
              return;
            }
            Navigator.pop(
              context,
              _DeleteDecision(reason: _selectedReason, notes: notes),
            );
          },
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

class _ChargeAbnormalityDraft {
  final DateTime eventAt;
  final AbnormalityType selectedType;
  final AbnormalitySeverity severity;
  final List<AffectedAssetRef> affectedAssets;
  final String? component;
  final String observedReason;
  final String? description;
  final RootReasonCategory rootReasonCategory;
  final String? rootReasonNotes;
  final ReannealingStatus reannealingStatus;
  final int? reannealedToChargeNo;
  final String? correctionReason;

  const _ChargeAbnormalityDraft({
    required this.eventAt,
    required this.selectedType,
    required this.severity,
    required this.affectedAssets,
    required this.component,
    required this.observedReason,
    required this.description,
    required this.rootReasonCategory,
    required this.rootReasonNotes,
    required this.reannealingStatus,
    required this.reannealedToChargeNo,
    required this.correctionReason,
  });
}

class _SelectedAbnormalityAsset {
  const _SelectedAbnormalityAsset({required this.route, required this.asset});

  final GovernedIssueAssetRoute route;
  final AssetInstanceRecord asset;
}

class _AssetSelectionMessage extends StatelessWidget {
  const _AssetSelectionMessage({
    required this.icon,
    required this.message,
    required this.color,
    this.showProgress = false,
  });

  final IconData icon;
  final String message;
  final Color color;
  final bool showProgress;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(BafSpacing.md),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      border: Border.all(color: color.withValues(alpha: 0.22)),
      borderRadius: BorderRadius.circular(BafRadius.medium),
    ),
    child: Row(
      children: [
        if (showProgress)
          SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          )
        else
          Icon(icon, color: color, size: 20),
        const SizedBox(width: BafSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
      ],
    ),
  );
}

class _FormNotice extends StatelessWidget {
  const _FormNotice({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      horizontal: BafSpacing.md,
      vertical: BafSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      border: Border.all(color: color.withValues(alpha: 0.2)),
      borderRadius: BorderRadius.circular(BafRadius.medium),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: BafSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
      ],
    ),
  );
}

class _PendingHierarchyTarget extends StatelessWidget {
  const _PendingHierarchyTarget({
    required this.reference,
    required this.onClear,
  });

  final AssetHierarchyReference reference;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(
      BafSpacing.md,
      BafSpacing.sm,
      BafSpacing.xs,
      BafSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: BafColors.assets.withValues(alpha: 0.08),
      border: Border.all(color: BafColors.assets.withValues(alpha: 0.25)),
      borderRadius: BorderRadius.circular(BafRadius.medium),
    ),
    child: Row(
      children: [
        const Icon(Icons.account_tree_outlined, color: BafColors.assets),
        const SizedBox(width: BafSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reference.nodeName,
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (reference.hierarchyPath.isNotEmpty)
                Text(
                  reference.hierarchyPath.join(' > '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Use whole asset instead',
          onPressed: onClear,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );
}

class _AffectedAssetTile extends StatelessWidget {
  const _AffectedAssetTile({required this.asset, required this.onRemove});

  final AffectedAssetRef asset;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final reference = asset.assetHierarchyReference;
    final component = asset.componentLabel;
    final detail =
        reference == null
            ? 'Legacy identity - no governed hierarchy snapshot'
            : component == null
            ? 'Whole registered asset'
            : reference.hierarchyPath.join(' > ');
    return Container(
      padding: const EdgeInsets.fromLTRB(
        BafSpacing.md,
        BafSpacing.sm,
        BafSpacing.xs,
        BafSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: BafColors.card,
        border: Border.all(color: BafColors.border),
        borderRadius: BorderRadius.circular(BafRadius.medium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: BafColors.assets.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(BafRadius.small),
            ),
            child: Icon(
              _assetIcon(asset.assetType),
              color: BafColors.assets,
              size: 20,
            ),
          ),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.label,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (component != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    component,
                    style: const TextStyle(
                      color: BafColors.assets,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove affected equipment',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded),
            color: BafColors.danger,
          ),
        ],
      ),
    );
  }
}

class _DeleteDecision {
  final AuditReason? reason;
  final String? notes;

  const _DeleteDecision({required this.reason, required this.notes});
}

// ─────────────────────────────────────────────────────────────
// UI WIDGETS
// ─────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final int sourceChargeNo;
  final String? subtitle;
  final int total;
  final int raCount;
  final int completedRaCount;

  const _HeaderCard({
    required this.sourceChargeNo,
    required this.subtitle,
    required this.total,
    required this.raCount,
    required this.completedRaCount,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      key: const ValueKey('charge-abnormalities-summary'),
      backgroundColor: BafColors.charges,
      borderColor: BafColors.charges.withValues(alpha: 0.28),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final identity = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: BafSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Charge $sourceChargeNo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    if (subtitle?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: BafSpacing.xs),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
          final metrics = Row(
            children: [
              Expanded(child: _MetricPill(label: 'Total', value: total)),
              const SizedBox(width: BafSpacing.sm),
              Expanded(child: _MetricPill(label: 'RA', value: raCount)),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: _MetricPill(label: 'Done', value: completedRaCount),
              ),
            ],
          );
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: BafSpacing.md),
                metrics,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: BafSpacing.lg),
              SizedBox(width: 222, child: metrics),
            ],
          );
        },
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final int value;

  const _MetricPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 58),
      padding: const EdgeInsets.symmetric(
        horizontal: BafSpacing.sm,
        vertical: BafSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _ChargeAbnormalityCard extends StatelessWidget {
  final ChargeAbnormality record;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ChargeAbnormalityCard({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = _categoryColor(record.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: BafSpacing.md),
      child: DashboardCard(
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(BafRadius.large),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    BafSpacing.md,
                    BafSpacing.md,
                    BafSpacing.sm,
                    BafSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: BafSpacing.sm,
                        runSpacing: BafSpacing.sm,
                        children: [
                          StatusBadge(
                            label: record.abnormalityTypeCode,
                            color: BafColors.admin,
                            icon: Icons.tag_rounded,
                          ),
                          StatusBadge(
                            label: _categoryLabel(record.category),
                            color: categoryColor,
                            icon: Icons.category_rounded,
                          ),
                          StatusBadge(
                            label: _severityLabel(record.severity),
                            color: _severityColor(record.severity),
                            icon: Icons.priority_high_rounded,
                          ),
                          StatusBadge(
                            label: _raStatusLabel(record.reannealingStatus),
                            color: _raStatusColor(record.reannealingStatus),
                            icon: Icons.repeat_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: BafSpacing.md),
                      Text(
                        record.abnormalityTypeTitle,
                        style: const TextStyle(
                          color: BafColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: BafSpacing.xs),
                      Text(
                        record.observedReason,
                        style: const TextStyle(
                          color: BafColors.textSecondary,
                          fontSize: 13,
                          height: 1.28,
                        ),
                      ),
                      if ((record.description ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: BafSpacing.xs),
                        Text(
                          record.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: BafColors.textSecondary,
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                      ],
                      const SizedBox(height: BafSpacing.md),
                      Wrap(
                        spacing: BafSpacing.sm,
                        runSpacing: BafSpacing.sm,
                        children: [
                          _SoftChip(
                            icon: Icons.confirmation_number_outlined,
                            label: 'Old charge ${record.sourceChargeNo}',
                          ),
                          if (record.reannealedToChargeNo != null)
                            _SoftChip(
                              icon: Icons.repeat_rounded,
                              label:
                                  'New charge ${record.reannealedToChargeNo}',
                            ),
                          _SoftChip(
                            icon: Icons.precision_manufacturing_rounded,
                            label: record.affectedAssetsLabel,
                          ),
                          _SoftChip(
                            icon: Icons.manage_search_rounded,
                            label: _rootReasonCategoryLabel(
                              record.possibleRootReasonCategory,
                            ),
                          ),
                        ],
                      ),
                      for (final asset in record.affectedAssets.where(
                        (asset) => asset.componentLabel != null,
                      )) ...[
                        const SizedBox(height: BafSpacing.sm),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.account_tree_outlined,
                              size: 16,
                              color: BafColors.assets,
                            ),
                            const SizedBox(width: BafSpacing.xs),
                            Expanded(
                              child: Text(
                                '${asset.label}: ${asset.assetHierarchyReference!.hierarchyPath.join(' > ')}',
                                style: const TextStyle(
                                  color: BafColors.textSecondary,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if ((record.possibleRootReasonNotes ?? '')
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: BafSpacing.sm),
                        Text(
                          'Root note: ${record.possibleRootReasonNotes}',
                          style: const TextStyle(
                            color: BafColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: BafSpacing.md),
                      Text(
                        'Logged ${DateFormat('dd MMM yyyy, HH:mm').format(record.loggedAt)}'
                        '${record.loggedByName == null ? '' : ' by ${record.loggedByName}'}',
                        style: const TextStyle(
                          color: BafColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      if (onEdit != null || onDelete != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (onEdit != null)
                                IconButton(
                                  tooltip: 'Edit',
                                  icon: const Icon(Icons.edit_outlined),
                                  color: BafColors.planned,
                                  onPressed: onEdit,
                                ),
                              if (onDelete != null)
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  color: BafColors.danger,
                                  onPressed: onDelete,
                                ),
                            ],
                          ),
                        ),
                    ],
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

class _ChargeContextStrip extends StatelessWidget {
  final int sourceChargeNo;

  const _ChargeContextStrip({required this.sourceChargeNo});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      backgroundColor: BafColors.charges.withValues(alpha: 0.08),
      borderColor: BafColors.charges.withValues(alpha: 0.18),
      child: Row(
        children: [
          const Icon(
            Icons.confirmation_number_outlined,
            color: BafColors.charges,
          ),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              'Source / old charge no: $sourceChargeNo',
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: BafColors.navySoft, size: 20),
        const SizedBox(width: BafSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: BafColors.textPrimary,
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
    );
  }
}

class _SoftChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SoftChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16, color: BafColors.assets),
      label: Text(label),
      labelStyle: const TextStyle(
        color: BafColors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: BafColors.assets.withValues(alpha: 0.08),
      side: BorderSide(color: BafColors.assets.withValues(alpha: 0.16)),
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color? color;

  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? BafColors.charges;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.xl),
        child: DashboardCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: effectiveColor),
              const SizedBox(height: BafSpacing.md),
              Text(
                title,
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BafSpacing.sm),
              Text(
                message,
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────
