import 'package:flutter/material.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../data/asset_hierarchy_model.dart';
import '../../data/asset_registry_model.dart';

final class GovernedAssetTargetSelection {
  const GovernedAssetTargetSelection.target({
    required this.node,
    required this.reference,
  }) : unlisted = false;

  const GovernedAssetTargetSelection.unlisted()
    : node = null,
      reference = null,
      unlisted = true;

  final AssetHierarchyNode? node;
  final AssetHierarchyReference? reference;
  final bool unlisted;
}

AssetHierarchyReference componentDefinitionReferenceForAsset({
  required AssetInstanceRecord asset,
  required AssetHierarchyNode node,
  String? definitionAssetClassId,
}) {
  final expectedDefinitionClassId =
      definitionAssetClassId?.trim().isNotEmpty == true
          ? definitionAssetClassId!.trim()
          : asset.assetClassId;
  if (!asset.isActive ||
      !node.isActive ||
      node.assetClassId != expectedDefinitionClassId) {
    throw StateError('The selected component is outside the active asset.');
  }
  if (node.nodeType != AssetHierarchyNodeType.component &&
      node.nodeType != AssetHierarchyNodeType.subcomponent) {
    throw StateError('Select a component or subcomponent work target.');
  }
  return AssetHierarchyReference(
    scope: AssetHierarchyReferenceScope.componentDefinitionOnAsset,
    assetClassId: asset.assetClassId,
    assetClassCode: asset.assetClassCode,
    assetClassName: asset.assetClassName,
    nodeId: node.id,
    nodeVersion: node.version,
    nodeName: node.name,
    assetInstanceId: asset.id,
    assetInstanceVersion: asset.version,
    assetNumber: asset.assetNumber,
    assetInstanceName: asset.name,
    hierarchyPath: node.hierarchyPath,
    ownershipStatus: node.ownershipStatus,
    ownerDiscipline: node.ownerDiscipline,
    accountableRoleKeys: node.accountableRoleKeys,
  );
}

Future<GovernedAssetTargetSelection?> showGovernedAssetTargetPicker({
  required BuildContext context,
  required AssetInstanceRecord asset,
  required List<AssetHierarchyNode> nodes,
  String? selectedNodeId,
  String? definitionAssetClassId,
  bool allowUnlisted = false,
}) {
  return showModalBottomSheet<GovernedAssetTargetSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: BafColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(BafRadius.medium),
      ),
    ),
    builder:
        (_) => _GovernedAssetTargetPicker(
          asset: asset,
          nodes: nodes,
          selectedNodeId: selectedNodeId,
          definitionAssetClassId: definitionAssetClassId,
          allowUnlisted: allowUnlisted,
        ),
  );
}

class _GovernedAssetTargetPicker extends StatefulWidget {
  const _GovernedAssetTargetPicker({
    required this.asset,
    required this.nodes,
    required this.selectedNodeId,
    required this.definitionAssetClassId,
    required this.allowUnlisted,
  });

  final AssetInstanceRecord asset;
  final List<AssetHierarchyNode> nodes;
  final String? selectedNodeId;
  final String? definitionAssetClassId;
  final bool allowUnlisted;

  @override
  State<_GovernedAssetTargetPicker> createState() =>
      _GovernedAssetTargetPickerState();
}

class _GovernedAssetTargetPickerState
    extends State<_GovernedAssetTargetPicker> {
  final _searchController = TextEditingController();
  String? _parentNodeId;
  String _query = '';

  late final List<AssetHierarchyNode> _activeNodes = widget.nodes
      .where(
        (node) =>
            node.isActive &&
            node.assetClassId ==
                (widget.definitionAssetClassId ?? widget.asset.assetClassId),
      )
      .toList(growable: false);

  late final Map<String, AssetHierarchyNode> _byId =
      <String, AssetHierarchyNode>{
        for (final node in _activeNodes) node.id: node,
      };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _selectable(AssetHierarchyNode node) =>
      node.nodeType == AssetHierarchyNodeType.component ||
      node.nodeType == AssetHierarchyNodeType.subcomponent;

  bool _hasChildren(AssetHierarchyNode node) =>
      _activeNodes.any((candidate) => candidate.parentNodeId == node.id);

  List<AssetHierarchyNode> get _visibleNodes {
    final query = _query.trim().toLowerCase();
    final visible =
        query.isEmpty
            ? _activeNodes
                .where((node) => node.parentNodeId == _parentNodeId)
                .toList()
            : _activeNodes.where((node) {
              if (!_selectable(node)) return false;
              return <String>[
                node.name,
                node.componentTag ?? '',
                node.discipline ?? '',
                node.operatingType ?? '',
                ...node.hierarchyPath,
              ].join(' ').toLowerCase().contains(query);
            }).toList();
    visible.sort((left, right) {
      final order = left.sortOrder.compareTo(right.sortOrder);
      return order != 0
          ? order
          : left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    return visible;
  }

  List<AssetHierarchyNode> get _breadcrumbs {
    final parentId = _parentNodeId;
    if (parentId == null) return const <AssetHierarchyNode>[];
    final parent = _byId[parentId];
    if (parent == null) return const <AssetHierarchyNode>[];
    return <AssetHierarchyNode>[
      for (final id in parent.ancestorNodeIds)
        if (_byId[id] case final ancestor?) ancestor,
      parent,
    ];
  }

  void _select(AssetHierarchyNode node) {
    Navigator.pop(
      context,
      GovernedAssetTargetSelection.target(
        node: node,
        reference: componentDefinitionReferenceForAsset(
          asset: widget.asset,
          node: node,
          definitionAssetClassId: widget.definitionAssetClassId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleNodes;
    final searchActive = _query.trim().isNotEmpty;
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Column(
        children: [
          _PickerHeader(
            assetLabel: widget.asset.name,
            onClose: () => Navigator.pop(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BafSpacing.md,
              BafSpacing.md,
              BafSpacing.md,
              BafSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                labelText: 'Search hierarchy',
                hintText: 'Component, subcomponent, tag or discipline',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon:
                    searchActive
                        ? IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                        : null,
              ),
            ),
          ),
          if (!searchActive)
            _BreadcrumbBar(
              assetClassName: widget.asset.assetClassName,
              nodes: _breadcrumbs,
              onRoot:
                  () => setState(() {
                    _parentNodeId = null;
                  }),
              onNode:
                  (node) => setState(() {
                    _parentNodeId = node.id;
                  }),
            ),
          if (widget.allowUnlisted)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BafSpacing.md,
                BafSpacing.xs,
                BafSpacing.md,
                BafSpacing.xs,
              ),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed:
                      () => Navigator.pop(
                        context,
                        const GovernedAssetTargetSelection.unlisted(),
                      ),
                  icon: const Icon(Icons.add_comment_outlined),
                  label: const Text('Record an unlisted component'),
                ),
              ),
            ),
          Expanded(
            child:
                visible.isEmpty
                    ? const _EmptyHierarchyLevel()
                    : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        BafSpacing.md,
                        BafSpacing.sm,
                        BafSpacing.md,
                        BafSpacing.xl,
                      ),
                      itemCount: visible.length,
                      separatorBuilder:
                          (_, _) =>
                              const Divider(height: 1, color: BafColors.border),
                      itemBuilder: (context, index) {
                        final node = visible[index];
                        final hasChildren = _hasChildren(node);
                        final selectable = _selectable(node);
                        final selected = node.id == widget.selectedNodeId;
                        return ListTile(
                          selected: selected,
                          contentPadding: const EdgeInsets.only(
                            left: BafSpacing.sm,
                            right: 0,
                          ),
                          leading: Icon(
                            _nodeIcon(node.nodeType),
                            color: selected ? BafColors.sync : BafColors.assets,
                          ),
                          title: Text(
                            node.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            <String>[
                              node.nodeType.label,
                              if (searchActive && node.hierarchyPath.isNotEmpty)
                                node.hierarchyPath.join(' › '),
                              if (node.discipline?.trim().isNotEmpty == true)
                                node.discipline!,
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap:
                              hasChildren && !searchActive
                                  ? () => setState(() {
                                    _parentNodeId = node.id;
                                  })
                                  : selectable
                                  ? () => _select(node)
                                  : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (selectable)
                                IconButton(
                                  tooltip: 'Use ${node.name}',
                                  icon: Icon(
                                    selected
                                        ? Icons.check_circle_rounded
                                        : Icons.task_alt_outlined,
                                    color:
                                        selected
                                            ? BafColors.sync
                                            : BafColors.textSecondary,
                                  ),
                                  onPressed: () => _select(node),
                                ),
                              if (hasChildren && !searchActive)
                                const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class _PickerHeader extends StatelessWidget {
  const _PickerHeader({required this.assetLabel, required this.onClose});

  final String assetLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        BafSpacing.lg,
        BafSpacing.md,
        BafSpacing.sm,
        BafSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: BafColors.navy,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BafRadius.medium),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_tree_outlined, color: Colors.white),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose work target',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  assetLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFC6D7DB)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _BreadcrumbBar extends StatelessWidget {
  const _BreadcrumbBar({
    required this.assetClassName,
    required this.nodes,
    required this.onRoot,
    required this.onNode,
  });

  final String assetClassName;
  final List<AssetHierarchyNode> nodes;
  final VoidCallback onRoot;
  final ValueChanged<AssetHierarchyNode> onNode;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: BafSpacing.md),
        children: [
          ActionChip(
            avatar: const Icon(Icons.factory_outlined, size: 16),
            label: Text(assetClassName),
            onPressed: onRoot,
          ),
          for (final node in nodes) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: BafColors.textSecondary,
              ),
            ),
            ActionChip(label: Text(node.name), onPressed: () => onNode(node)),
          ],
        ],
      ),
    );
  }
}

class _EmptyHierarchyLevel extends StatelessWidget {
  const _EmptyHierarchyLevel();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(BafSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 36,
              color: BafColors.textSecondary,
            ),
            SizedBox(height: BafSpacing.sm),
            Text(
              'No matching governed component is available at this level.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

IconData _nodeIcon(AssetHierarchyNodeType type) => switch (type) {
  AssetHierarchyNodeType.grouping => Icons.folder_outlined,
  AssetHierarchyNodeType.assembly => Icons.hub_outlined,
  AssetHierarchyNodeType.component => Icons.settings_outlined,
  AssetHierarchyNodeType.subcomponent => Icons.precision_manufacturing_outlined,
};
