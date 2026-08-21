part of 'admin_asset_hierarchy_tab.dart';

class _InstalledComponentList extends ConsumerWidget {
  final AssetInstanceRecord asset;
  final bool busy;
  final VoidCallback onEditAsset;
  final VoidCallback onToggleAsset;
  final VoidCallback onAddComponent;
  final ValueChanged<InstalledComponentRecord> onEditComponent;
  final ValueChanged<InstalledComponentRecord> onReplaceComponent;
  final ValueChanged<InstalledComponentRecord> onHistoryComponent;
  final ValueChanged<InstalledComponentRecord> onToggleComponent;

  const _InstalledComponentList({
    required this.asset,
    required this.busy,
    required this.onEditAsset,
    required this.onToggleAsset,
    required this.onAddComponent,
    required this.onEditComponent,
    required this.onReplaceComponent,
    required this.onHistoryComponent,
    required this.onToggleComponent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final componentsAsync = ref.watch(installedComponentsProvider(asset.id));
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder:
                (context, constraints) => Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                asset.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              _StatusPill(active: asset.isActive),
                              _OwnershipPill(status: asset.ownershipStatus),
                            ],
                          ),
                          Text(
                            '#${asset.assetNumber} · ${asset.serviceState.label}'
                            '${asset.location == null ? '' : ' · ${asset.location}'}',
                            style: const TextStyle(
                              color: BafColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (constraints.maxWidth < 560)
                      PopupMenuButton<String>(
                        tooltip: 'Physical asset actions',
                        enabled: !busy,
                        onSelected: (action) {
                          switch (action) {
                            case 'edit':
                              onEditAsset();
                              break;
                            case 'toggle':
                              onToggleAsset();
                              break;
                            case 'add':
                              onAddComponent();
                              break;
                          }
                        },
                        itemBuilder:
                            (_) => [
                              if (asset.isActive)
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                    leading: Icon(Icons.edit_rounded),
                                    title: Text('Edit physical asset'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              if (!asset.isActive ||
                                  asset.activeComponentCount == 0)
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: ListTile(
                                    leading: Icon(
                                      asset.isActive
                                          ? Icons.archive_outlined
                                          : Icons.restore_rounded,
                                    ),
                                    title: Text(
                                      asset.isActive
                                          ? 'Retire physical asset'
                                          : 'Restore physical asset',
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              if (asset.isActive)
                                const PopupMenuItem(
                                  value: 'add',
                                  child: ListTile(
                                    leading: Icon(Icons.add_rounded),
                                    title: Text('Add installed component'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                            ],
                        icon: const Icon(Icons.more_vert_rounded),
                      )
                    else ...[
                      IconButton(
                        tooltip: 'Edit physical asset',
                        onPressed: busy || !asset.isActive ? null : onEditAsset,
                        icon: const Icon(Icons.edit_rounded),
                      ),
                      IconButton(
                        tooltip:
                            asset.isActive
                                ? 'Retire physical asset'
                                : 'Restore physical asset',
                        onPressed:
                            busy ||
                                    (asset.isActive &&
                                        asset.activeComponentCount > 0)
                                ? null
                                : onToggleAsset,
                        icon: Icon(
                          asset.isActive
                              ? Icons.archive_outlined
                              : Icons.restore_rounded,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed:
                            busy || !asset.isActive ? null : onAddComponent,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Installed component'),
                      ),
                    ],
                  ],
                ),
          ),
        ),
        Expanded(
          child: componentsAsync.when(
            loading:
                () => const BafLoadingPanel(
                  label: 'Loading installed components',
                  color: BafColors.admin,
                ),
            error:
                (error, _) => _LoadFailure(
                  message: 'Installed components could not be loaded: $error',
                  onRetry:
                      () =>
                          ref.invalidate(installedComponentsProvider(asset.id)),
                ),
            data:
                (components) =>
                    components.isEmpty
                        ? const _EmptyHierarchy(
                          icon: Icons.settings_outlined,
                          title: 'No installed components',
                          message:
                              'Bind physical devices to this class definition.',
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: components.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final component = components[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    component.isActive
                                        ? Colors.white
                                        : const Color(0xFFF2F4F7),
                                border: Border.all(color: BafColors.border),
                                borderRadius: BorderRadius.circular(
                                  BafRadius.small,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.settings_outlined,
                                    color: BafColors.assets,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              component.definitionName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            if (component.componentTag != null)
                                              _TagPill(
                                                label: component.componentTag!,
                                              ),
                                            _OwnershipPill(
                                              status: component.ownershipStatus,
                                            ),
                                            _StatusPill(
                                              active: component.isActive,
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '${component.serviceState.label} · ${component.hierarchyPath.join(' › ')}',
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
                                  PopupMenuButton<_ComponentAction>(
                                    tooltip: 'Component actions',
                                    enabled: !busy,
                                    onSelected: (action) {
                                      switch (action) {
                                        case _ComponentAction.edit:
                                          onEditComponent(component);
                                          break;
                                        case _ComponentAction.replace:
                                          onReplaceComponent(component);
                                          break;
                                        case _ComponentAction.history:
                                          onHistoryComponent(component);
                                          break;
                                        case _ComponentAction.toggleStatus:
                                          onToggleComponent(component);
                                          break;
                                      }
                                    },
                                    itemBuilder:
                                        (
                                          _,
                                        ) => <PopupMenuEntry<_ComponentAction>>[
                                          if (component.isActive)
                                            const PopupMenuItem(
                                              value: _ComponentAction.edit,
                                              child: ListTile(
                                                leading: Icon(
                                                  Icons.edit_rounded,
                                                ),
                                                title: Text('Edit details'),
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                            ),
                                          if (component.isActive)
                                            const PopupMenuItem(
                                              value: _ComponentAction.replace,
                                              child: ListTile(
                                                leading: Icon(
                                                  Icons.swap_horiz_rounded,
                                                ),
                                                title: Text(
                                                  'Replace component',
                                                ),
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                            ),
                                          const PopupMenuItem(
                                            value: _ComponentAction.history,
                                            child: ListTile(
                                              leading: Icon(
                                                Icons.history_rounded,
                                              ),
                                              title: Text('Lifecycle history'),
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                          if (component.isActive ||
                                              !component.isReplacementTerminal)
                                            PopupMenuItem(
                                              value:
                                                  _ComponentAction.toggleStatus,
                                              child: ListTile(
                                                leading: Icon(
                                                  component.isActive
                                                      ? Icons.archive_outlined
                                                      : Icons.restore_rounded,
                                                ),
                                                title: Text(
                                                  component.isActive
                                                      ? 'Retire component'
                                                      : 'Restore component',
                                                ),
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                            ),
                                        ],
                                    icon: const Icon(Icons.more_vert_rounded),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
          ),
        ),
      ],
    );
  }
}

enum _ComponentAction { edit, replace, history, toggleStatus }

class _InstalledComponentHistoryDialog extends ConsumerWidget {
  final AssetInstanceRecord asset;
  final InstalledComponentRecord component;

  const _InstalledComponentHistoryDialog({
    required this.asset,
    required this.component,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audits = ref.watch(installedComponentHistoryProvider(asset.id));
    final components = ref.watch(installedComponentsProvider(asset.id));
    return AlertDialog(
      title: const Text('Component lifecycle history'),
      content: SizedBox(
        width: 680,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              component.definitionName,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              '${asset.name}${component.componentTag == null ? '' : ' · ${component.componentTag}'}',
              style: const TextStyle(color: BafColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: components.when(
                loading:
                    () => const BafLoadingPanel(
                      label: 'Loading component history',
                      color: BafColors.admin,
                    ),
                error:
                    (error, _) => _LoadFailure(
                      message: 'Component lineage could not be loaded: $error',
                      onRetry:
                          () => ref.invalidate(
                            installedComponentsProvider(asset.id),
                          ),
                    ),
                data: (componentRecords) {
                  final memberIds =
                      componentRecords
                          .where(
                            (record) =>
                                record.lifecycleId == component.lifecycleId,
                          )
                          .map((record) => record.id)
                          .toSet()
                        ..add(component.id);
                  return audits.when(
                    loading:
                        () => const Center(child: CircularProgressIndicator()),
                    error:
                        (error, _) => _LoadFailure(
                          message:
                              'Lifecycle history could not be loaded: $error',
                          onRetry:
                              () => ref.invalidate(
                                installedComponentHistoryProvider(asset.id),
                              ),
                        ),
                    data: (records) {
                      final history =
                          records
                              .where(
                                (record) =>
                                    record.componentLineageId ==
                                        component.lifecycleId ||
                                    memberIds.contains(record.entityId) ||
                                    (record.relatedEntityId != null &&
                                        memberIds.contains(
                                          record.relatedEntityId,
                                        )),
                              )
                              .toList();
                      if (history.isEmpty) {
                        return const _EmptyHierarchy(
                          icon: Icons.history_rounded,
                          title: 'No lifecycle entries',
                          message:
                              'Create, edit, replacement and retirement evidence will appear here.',
                        );
                      }
                      final date = DateFormat('dd MMM yyyy, HH:mm');
                      return ListView.separated(
                        itemCount: history.length,
                        separatorBuilder: (_, __) => const Divider(height: 24),
                        itemBuilder: (context, index) {
                          final entry = history[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: BafColors.assets.withValues(
                                alpha: 0.12,
                              ),
                              foregroundColor: BafColors.assets,
                              child: Icon(_componentAuditIcon(entry.action)),
                            ),
                            title: Text(
                              _componentAuditLabel(entry.action),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              _componentAuditSubtitle(entry, date),
                            ),
                            isThreeLine: true,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

String _componentAuditLabel(String action) => switch (action) {
  'create' => 'Installed',
  'update' => 'Details revised',
  'retired' => 'Retired',
  'active' => 'Restored',
  'replacement_installed' => 'Replacement installed',
  'replaced' => 'Replaced and retired',
  'tag_transferred_out' => 'Tag transferred out',
  _ => action.replaceAll('_', ' '),
};

String _componentAuditSubtitle(
  InstalledComponentLifecycleAudit entry,
  DateFormat date,
) {
  final evidenceType = entry.acceptedEvidenceType;
  final evidenceLine =
      evidenceType == null
          ? null
          : '${evidenceType == ComponentReplacementEvidenceSource.maintenanceIssue ? 'Resolved issue' : 'Completed planned work'} · ${entry.acceptedEvidenceId} · v${entry.acceptedEvidenceVersion}';
  return <String>[
    entry.reason,
    if (evidenceLine != null) evidenceLine,
    '${date.format(entry.performedAt.toLocal())} · ${entry.performedByName}',
  ].join('\n');
}

IconData _componentAuditIcon(String action) => switch (action) {
  'create' || 'replacement_installed' => Icons.add_circle_outline_rounded,
  'replaced' || 'retired' => Icons.archive_outlined,
  'active' => Icons.restore_rounded,
  'tag_transferred_out' => Icons.sell_outlined,
  _ => Icons.edit_note_rounded,
};
