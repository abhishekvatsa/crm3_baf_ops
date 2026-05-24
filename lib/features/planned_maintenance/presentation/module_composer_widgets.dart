part of 'module_composer_screen.dart';

class _ComposerCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;

  const _ComposerCard({this.title, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: BafColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.large),
        side: const BorderSide(color: BafColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: BafSpacing.sm),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

enum _ComposerAppBarAction {
  openWorkshop,
  openRegistryAuthoring,
  preparePublish,
  toggleJsonPreview,
  saveToPublisher,
}

enum _ModuleTileAction { openEditor, duplicate, delete }

class _ModuleTile extends StatelessWidget {
  final ComposerModuleDraft module;
  final bool selected;
  final bool selectedForMerge;
  final VoidCallback onTap;
  final VoidCallback onToggleMerge;
  final VoidCallback onOpenEditor;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _ModuleTile({
    required this.module,
    required this.selected,
    required this.selectedForMerge,
    required this.onTap,
    required this.onToggleMerge,
    required this.onOpenEditor,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color:
          selected ? BafColors.planned.withValues(alpha: 0.08) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        side: BorderSide(
          color: selected ? BafColors.planned : BafColors.border,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        onLongPress: () => _showActions(context),
        dense: true,
        leading: Checkbox(
          value: selectedForMerge,
          onChanged: (_) => onToggleMerge(),
        ),
        title: Text(
          module.moduleCode,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          module.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<_ModuleTileAction>(
          tooltip: 'Module actions',
          onSelected: _handleAction,
          itemBuilder:
              (context) => const [
                PopupMenuItem(
                  value: _ModuleTileAction.openEditor,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.open_in_new_rounded),
                    title: Text('Open focused editor'),
                  ),
                ),
                PopupMenuItem(
                  value: _ModuleTileAction.duplicate,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.copy_rounded),
                    title: Text('Duplicate'),
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: _ModuleTileAction.delete,
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: BafColors.danger,
                    ),
                    title: Text(
                      'Delete',
                      style: TextStyle(color: BafColors.danger),
                    ),
                  ),
                ),
              ],
        ),
      ),
    );
  }

  void _handleAction(_ModuleTileAction action) {
    switch (action) {
      case _ModuleTileAction.openEditor:
        onOpenEditor();
        return;
      case _ModuleTileAction.duplicate:
        onDuplicate();
        return;
      case _ModuleTileAction.delete:
        onDelete();
        return;
    }
  }

  Future<void> _showActions(BuildContext context) async {
    final action = await showModalBottomSheet<_ModuleTileAction>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.open_in_new_rounded),
                  title: const Text('Open focused editor'),
                  subtitle: Text(module.moduleCode),
                  onTap:
                      () =>
                          Navigator.pop(context, _ModuleTileAction.openEditor),
                ),
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('Duplicate'),
                  onTap:
                      () => Navigator.pop(context, _ModuleTileAction.duplicate),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: BafColors.danger,
                  ),
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: BafColors.danger),
                  ),
                  onTap: () => Navigator.pop(context, _ModuleTileAction.delete),
                ),
              ],
            ),
          ),
    );
    if (action != null) {
      _handleAction(action);
    }
  }
}

class _KnowledgeTile extends StatelessWidget {
  final BafKnowledgeEntry entry;
  final VoidCallback? onClone;

  const _KnowledgeTile({required this.entry, required this.onClone});

  @override
  Widget build(BuildContext context) {
    final color = _readinessColor(entry.composerReadiness);
    return Container(
      margin: const EdgeInsets.only(bottom: BafSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: ListTile(
        dense: true,
        title: Text(
          entry.moduleCandidateCode,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: BafColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.taskText, maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _MiniBadge(
                  label: _readinessLabel(entry.composerReadiness),
                  color: color,
                ),
                if (entry.deviceTags.isNotEmpty)
                  _MiniBadge(
                    label: entry.deviceTags.join(','),
                    color: BafColors.sync,
                  ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          tooltip:
              onClone == null ? 'Not directly cloneable' : 'Clone into draft',
          onPressed: onClone,
          icon: Icon(
            onClone == null
                ? Icons.info_outline_rounded
                : Icons.add_circle_outline_rounded,
          ),
        ),
      ),
    );
  }
}

class _SeedModuleTile extends StatelessWidget {
  final BafModuleSeed seed;
  final VoidCallback onClone;

  const _SeedModuleTile({required this.seed, required this.onClone});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: BafSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: ListTile(
        dense: true,
        title: Text(
          seed.displayTitle,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${seed.catalogueArea} • ${seed.componentGroup} • '
          '${seed.fields.length} fields • ${seed.standardItems.length} checklist items',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: 'Clone seed module',
          onPressed: onClone,
          icon: const Icon(Icons.copy_all_rounded, color: BafColors.planned),
        ),
      ),
    );
  }
}

class _TagResolutionSummary extends StatelessWidget {
  final BafTagResolution result;

  const _TagResolutionSummary({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.sm),
      decoration: BoxDecoration(
        color: (result.requiresReview ? BafColors.warning : BafColors.success)
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(
          color: (result.requiresReview ? BafColors.warning : BafColors.success)
              .withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${result.normalizedTag} — ${result.displayName ?? 'Unresolved'}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: BafColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Confidence ${(result.confidence * 100).toStringAsFixed(0)}% • ${result.resolutionSource}',
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
            ),
          ),
          if (result.ownerDisciplines.isNotEmpty ||
              result.safetyClasses.isNotEmpty) ...[
            const SizedBox(height: BafSpacing.xs),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final owner in result.ownerDisciplines)
                  _MiniBadge(
                    label: _enumLabel(owner),
                    color: BafColors.planned,
                  ),
                for (final safety in result.safetyClasses.take(4))
                  _MiniBadge(
                    label: _enumLabel(safety),
                    color: BafColors.warning,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  final ComposerFieldDraft field;
  final ValueChanged<bool> onRequiredChanged;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onDelete;

  const _FieldTile({
    required this.field,
    required this.onRequiredChanged,
    required this.onEdit,
    required this.onDuplicate,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: BafSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(
          color:
              field.isSafetyCriticalPreset
                  ? BafColors.warning.withValues(alpha: 0.5)
                  : BafColors.border,
        ),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          field.isSafetyCriticalPreset
              ? Icons.health_and_safety_rounded
              : Icons.edit_note_rounded,
          color:
              field.isSafetyCriticalPreset
                  ? BafColors.warning
                  : BafColors.planned,
        ),
        title: Text(
          field.label,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${field.key} • ${field.type.name}${field.unit == null ? '' : ' • ${field.unit}'}',
        ),
        trailing: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 2,
          children: [
            const Text('Req'),
            Switch(value: field.isRequired, onChanged: onRequiredChanged),
            IconButton(
              tooltip: 'Move up',
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
              onPressed: onMoveUp,
            ),
            IconButton(
              tooltip: 'Move down',
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              onPressed: onMoveDown,
            ),
            IconButton(
              tooltip: 'Edit field',
              icon: const Icon(Icons.edit_rounded, color: BafColors.planned),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Duplicate field',
              icon: const Icon(Icons.copy_rounded, color: BafColors.sync),
              onPressed: onDuplicate,
            ),
            IconButton(
              tooltip: 'Delete field',
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: BafColors.danger,
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  final ComposerChecklistItemDraft item;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onDelete;

  const _ChecklistTile({
    required this.item,
    required this.onEdit,
    required this.onDuplicate,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: BafSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          item.isRequired
              ? Icons.task_alt_rounded
              : Icons.check_circle_outline_rounded,
          color: BafColors.sync,
        ),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          item.description.isEmpty ? 'No description' : item.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Wrap(
          children: [
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
              onPressed: onMoveUp,
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              onPressed: onMoveDown,
            ),
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: BafColors.planned),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, color: BafColors.sync),
              onPressed: onDuplicate,
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: BafColors.danger,
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _ValidationLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _ValidationLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BafSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: BafColors.textPrimary,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KnowledgeSourceBanner extends StatelessWidget {
  final BafKnowledgeMatrixMeta meta;
  final VoidCallback? onSeedCloud;
  final bool isSeeding;

  const _KnowledgeSourceBanner({
    required this.meta,
    required this.onSeedCloud,
    required this.isSeeding,
  });

  @override
  Widget build(BuildContext context) {
    final isFallback = meta.isStaticFallback || meta.source == 'staticFallback';
    final color = isFallback ? BafColors.warning : BafColors.sync;
    return Container(
      padding: const EdgeInsets.all(BafSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFallback ? Icons.shield_rounded : Icons.cloud_done_rounded,
                color: color,
                size: 18,
              ),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Text(
                  '${meta.sourceLabel} • ${meta.matrixVersion}',
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${meta.source} source • ${meta.knowledgeRowCount} rows • ${meta.tagRowCount} tag rows',
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 11.5,
            ),
          ),
          if (meta.note.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              meta.note,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 11.5,
              ),
            ),
          ],
          if (onSeedCloud != null) ...[
            const SizedBox(height: BafSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: isSeeding ? null : onSeedCloud,
                icon:
                    isSeeding
                        ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.cloud_upload_rounded, size: 16),
                label: Text(isSeeding ? 'Seeding...' : 'Seed cloud baseline'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
