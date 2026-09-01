part of 'admin_asset_hierarchy_tab.dart';

class _HierarchyToolbar extends StatelessWidget {
  final int total;
  final int active;
  final bool showRetired;
  final bool busy;
  final TextEditingController searchController;
  final ValueChanged<bool> onShowRetiredChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onAddClass;

  const _HierarchyToolbar({
    required this.total,
    required this.active,
    required this.showRetired,
    required this.busy,
    required this.searchController,
    required this.onShowRetiredChanged,
    required this.onSearchChanged,
    required this.onAddClass,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final search = TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Search class, code or area',
              prefixIcon: Icon(Icons.search_rounded),
              border: OutlineInputBorder(),
            ),
          );
          final retired = total - active;
          if (compact) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                key: const ValueKey('asset-hierarchy-mobile-toolbar'),
                children: [
                  Expanded(child: search),
                  const SizedBox(width: BafSpacing.sm),
                  Badge(
                    isLabelVisible: retired > 0,
                    label: Text('$retired'),
                    child: IconButton.filledTonal(
                      key: const ValueKey('asset-hierarchy-retired-toggle'),
                      tooltip:
                          showRetired
                              ? 'Hide retired asset classes'
                              : 'Show retired asset classes',
                      onPressed: () => onShowRetiredChanged(!showRetired),
                      style: IconButton.styleFrom(
                        backgroundColor: BafColors.cobalt,
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white54,
                      ),
                      icon: Icon(
                        showRetired
                            ? Icons.history_toggle_off_rounded
                            : Icons.history_rounded,
                      ),
                    ),
                  ),
                  const SizedBox(width: BafSpacing.sm),
                  IconButton.filled(
                    key: const ValueKey('asset-hierarchy-add-class'),
                    tooltip: 'Add asset class',
                    onPressed: onAddClass,
                    style: IconButton.styleFrom(
                      backgroundColor: BafColors.assets,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: BafColors.surfaceStrong,
                      disabledForegroundColor: BafColors.textTertiary,
                    ),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            );
          }

          final filters = <Widget>[
            FilterChip(
              selected: showRetired,
              onSelected: onShowRetiredChanged,
              avatar: const Icon(Icons.history_rounded, size: 18),
              label: Text('Retired $retired'),
            ),
            Chip(label: Text('$active active')),
          ];
          return Padding(
            padding: const EdgeInsets.all(BafSpacing.md),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: BafColors.assets.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(BafRadius.medium),
                      ),
                      child: const Icon(
                        Icons.account_tree_rounded,
                        color: BafColors.assets,
                      ),
                    ),
                    const SizedBox(width: BafSpacing.md),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Asset hierarchy',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: BafColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Maintain classes, assemblies, components and subcomponents.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: BafColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (busy)
                      const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: onAddClass,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Asset class'),
                    ),
                  ],
                ),
                const SizedBox(height: BafSpacing.md),
                Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: BafSpacing.md),
                    ...filters.expand(
                      (filter) => [
                        filter,
                        const SizedBox(width: BafSpacing.sm),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
