part of 'abnormality_types_screen.dart';

class _HeaderCard extends StatelessWidget {
  final int total;
  final int active;
  final int inactive;

  const _HeaderCard({
    required this.total,
    required this.active,
    required this.inactive,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      key: const ValueKey('abnormality-types-summary'),
      padding: const EdgeInsets.all(BafSpacing.md),
      backgroundColor: BafColors.navy,
      borderColor: BafColors.navySoft.withValues(alpha: 0.26),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final introduction = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                ),
                child: const Icon(
                  Icons.rule_folder_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: BafSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operational abnormality master',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    SizedBox(height: BafSpacing.xs),
                    Text(
                      'Govern cycle-event choices and RA routing.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (constraints.maxWidth < 680) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                introduction,
                const SizedBox(height: BafSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _MetricPill(label: 'Total', value: total),
                    ),
                    const SizedBox(width: BafSpacing.sm),
                    Expanded(
                      child: _MetricPill(label: 'Active', value: active),
                    ),
                    const SizedBox(width: BafSpacing.sm),
                    Expanded(
                      child: _MetricPill(label: 'Inactive', value: inactive),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: introduction),
              const SizedBox(width: BafSpacing.xl),
              _MetricPill(label: 'Total', value: total),
              const SizedBox(width: BafSpacing.sm),
              _MetricPill(label: 'Active', value: active),
              const SizedBox(width: BafSpacing.sm),
              _MetricPill(label: 'Inactive', value: inactive),
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

class _AbnormalityTypeCard extends StatelessWidget {
  final AbnormalityType type;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _AbnormalityTypeCard({
    required this.type,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(type.category);

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
                  color: color,
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
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: BafSpacing.sm,
                        runSpacing: BafSpacing.sm,
                        children: [
                          StatusBadge(
                            label: type.code,
                            color: BafColors.admin,
                            icon: Icons.tag_rounded,
                          ),
                          StatusBadge(
                            label: _categoryLabel(type.category),
                            color: color,
                            icon: Icons.category_rounded,
                          ),
                          StatusBadge(
                            label: _severityLabel(type.severity),
                            color: _severityColor(type.severity),
                            icon: Icons.priority_high_rounded,
                          ),
                          if (type.suggestsReannealing)
                            const StatusBadge(
                              label: 'RA',
                              color: BafColors.audit,
                              icon: Icons.repeat_rounded,
                            ),
                          StatusBadge(
                            label: type.isActive ? 'ACTIVE' : 'INACTIVE',
                            color: type.isActive
                                ? BafColors.success
                                : BafColors.textSecondary,
                            icon: type.isActive
                                ? Icons.check_circle_rounded
                                : Icons.pause_circle_outline_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: BafSpacing.md),
                      Text(
                        type.title,
                        style: const TextStyle(
                          color: BafColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if ((type.description ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: BafSpacing.xs),
                        Text(
                          type.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: BafColors.textSecondary,
                            fontSize: 13,
                            height: 1.28,
                          ),
                        ),
                      ],
                      const SizedBox(height: BafSpacing.md),
                      Wrap(
                        spacing: BafSpacing.sm,
                        runSpacing: BafSpacing.sm,
                        children: type.applicableAssetTypes.isEmpty
                            ? const [
                                _SoftChip(
                                  icon: Icons.all_inclusive_rounded,
                                  label: 'All / unspecified assets',
                                ),
                              ]
                            : type.applicableAssetTypes.map((assetType) {
                                return _SoftChip(
                                  icon: _assetIcon(assetType),
                                  label: _assetTypeLabel(assetType),
                                );
                              }).toList(),
                      ),
                      const SizedBox(height: BafSpacing.md),
                      Text(
                        'Updated ${DateFormat('dd MMM yyyy, HH:mm').format(type.updatedAt)}'
                        '${type.lastEditedByName == null ? '' : ' by ${type.lastEditedByName}'}',
                        style: const TextStyle(
                          color: BafColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit_outlined),
                    color: BafColors.planned,
                    onPressed: onEdit,
                  ),
                  IconButton(
                    tooltip: type.isRaCoilColourType
                        ? 'Seeded RA type cannot be deleted'
                        : 'Delete',
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: onDelete == null
                        ? BafColors.textSecondary.withValues(alpha: 0.45)
                        : BafColors.danger,
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(width: BafSpacing.xs),
            ],
          ),
        ),
      ),
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
    final effectiveColor = color ?? BafColors.navy;

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

InputDecoration _inputDecoration({required String label, String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: BafColors.card,
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
      borderSide: const BorderSide(color: BafColors.navySoft, width: 1.4),
    ),
  );
}
