import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../assets/data/asset_hierarchy_model.dart';
import '../../../assets/data/asset_registry_model.dart';
import '../../../assets/providers/asset_hierarchy_provider.dart';
import '../../../assets/repositories/asset_hierarchy_repository.dart';
import '../../../auth/data/user_model.dart';
import '../../../maintenance/data/maintenance_model.dart';

class AssetHierarchyAdminTab extends ConsumerStatefulWidget {
  final AppUser actor;

  const AssetHierarchyAdminTab({super.key, required this.actor});

  @override
  ConsumerState<AssetHierarchyAdminTab> createState() =>
      _AssetHierarchyAdminTabState();
}

class _AssetHierarchyAdminTabState
    extends ConsumerState<AssetHierarchyAdminTab> {
  String? _selectedClassId;
  String _search = '';
  bool _showRetired = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(assetClassesProvider);
    return ColoredBox(
      color: BafColors.background,
      child: classesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => _LoadFailure(
              message: 'Asset hierarchy could not be loaded: $error',
              onRetry: () => ref.invalidate(assetClassesProvider),
            ),
        data: (classes) => _buildLoaded(context, classes),
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, List<AssetClassRecord> classes) {
    final visible =
        classes.where((assetClass) {
          if (!_showRetired && !assetClass.isActive) return false;
          final needle = _search.trim().toLowerCase();
          if (needle.isEmpty) return true;
          return assetClass.name.toLowerCase().contains(needle) ||
              assetClass.code.toLowerCase().contains(needle) ||
              assetClass.majorArea.toLowerCase().contains(needle);
        }).toList();
    final selected = classes.cast<AssetClassRecord?>().firstWhere(
      (item) => item?.id == _selectedClassId,
      orElse: () => visible.isEmpty ? null : visible.first,
    );
    if (selected != null && selected.id != _selectedClassId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedClassId = selected.id);
      });
    }

    return Column(
      children: [
        _HierarchyToolbar(
          total: classes.length,
          active: classes.where((item) => item.isActive).length,
          showRetired: _showRetired,
          busy: _busy,
          onShowRetiredChanged: (value) => setState(() => _showRetired = value),
          onSearchChanged: (value) => setState(() => _search = value),
          onAddClass: _busy ? null : () => _createClass(context),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 860) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: DropdownButtonFormField<String>(
                        initialValue: selected?.id,
                        decoration: const InputDecoration(
                          labelText: 'Asset class',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(
                            Icons.precision_manufacturing_rounded,
                          ),
                        ),
                        isExpanded: true,
                        items:
                            visible
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item.id,
                                    child: Text(
                                      '${item.code}  ${item.name}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (value) => setState(() => _selectedClassId = value),
                      ),
                    ),
                    Expanded(child: _classDetail(selected)),
                  ],
                );
              }
              return Row(
                children: [
                  SizedBox(
                    width: 310,
                    child: _AssetClassList(
                      classes: visible,
                      selectedId: selected?.id,
                      onSelected:
                          (item) => setState(() => _selectedClassId = item.id),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: _classDetail(selected)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _classDetail(AssetClassRecord? assetClass) {
    if (assetClass == null) {
      return const _EmptyHierarchy(
        icon: Icons.account_tree_outlined,
        title: 'No asset class selected',
        message: 'Add an asset class or adjust the current filters.',
      );
    }
    return _AssetClassDetail(
      key: ValueKey(assetClass.id),
      assetClass: assetClass,
      actor: widget.actor,
      busy: _busy,
      onEditClass: () => _editClass(context, assetClass),
      onToggleClassStatus: () => _toggleClassStatus(context, assetClass),
      onAddNode: (parent) => _createNode(context, assetClass, parent),
      onEditNode: (node) => _editNode(context, node),
      onToggleNodeStatus: (node) => _toggleNodeStatus(context, node),
    );
  }

  AssetHierarchyRepository get _repository =>
      ref.read(assetHierarchyRepositoryProvider);

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success), backgroundColor: BafColors.success),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: BafColors.danger),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createClass(BuildContext context) async {
    final input = await showDialog<_ClassDialogResult>(
      context: context,
      builder: (_) => const _AssetClassDialog(),
    );
    if (input == null) return;
    String? createdId;
    await _run(() async {
      createdId = await _repository.createAssetClass(
        draft: input.draft,
        actor: widget.actor,
        reason: input.reason,
      );
    }, 'Asset class added.');
    if (createdId != null && mounted) {
      setState(() => _selectedClassId = createdId);
    }
  }

  Future<void> _editClass(BuildContext context, AssetClassRecord before) async {
    final input = await showDialog<_ClassDialogResult>(
      context: context,
      builder: (_) => _AssetClassDialog(existing: before),
    );
    if (input == null) return;
    await _run(
      () => _repository.updateAssetClass(
        before: before,
        draft: input.draft,
        actor: widget.actor,
        reason: input.reason,
      ),
      'Asset class updated.',
    );
  }

  Future<void> _toggleClassStatus(
    BuildContext context,
    AssetClassRecord before,
  ) async {
    final next =
        before.isActive
            ? AssetHierarchyStatus.retired
            : AssetHierarchyStatus.active;
    final reason = await _reasonDialog(
      context,
      title: before.isActive ? 'Retire asset class' : 'Restore asset class',
      message:
          before.isActive
              ? 'Retiring hides this class from new operational selection. Historical records remain unchanged.'
              : 'Restoring makes this class available for hierarchy maintenance and future operational use.',
    );
    if (reason == null) return;
    await _run(
      () => _repository.setAssetClassStatus(
        before: before,
        status: next,
        actor: widget.actor,
        reason: reason,
      ),
      before.isActive ? 'Asset class retired.' : 'Asset class restored.',
    );
  }

  Future<void> _createNode(
    BuildContext context,
    AssetClassRecord assetClass,
    AssetHierarchyNode? parent,
  ) async {
    final nodes =
        ref.read(assetHierarchyNodesProvider(assetClass.id)).value ??
        const <AssetHierarchyNode>[];
    final input = await showDialog<_NodeDialogResult>(
      context: context,
      builder:
          (_) => _HierarchyNodeDialog(
            availableParents: nodes,
            initialParent: parent,
          ),
    );
    if (input == null) return;
    await _runTagAware((allowTagTransfer) async {
      await _repository.createNode(
        assetClass: assetClass,
        draft: input.draft,
        actor: widget.actor,
        reason: input.reason,
        allowTagTransfer: allowTagTransfer,
      );
    }, 'Hierarchy item added.');
  }

  Future<void> _editNode(
    BuildContext context,
    AssetHierarchyNode before,
  ) async {
    final nodes =
        ref.read(assetHierarchyNodesProvider(before.assetClassId)).value ??
        const <AssetHierarchyNode>[];
    final input = await showDialog<_NodeDialogResult>(
      context: context,
      builder:
          (_) => _HierarchyNodeDialog(
            existing: before,
            availableParents:
                nodes.where((node) => node.id != before.id).toList(),
          ),
    );
    if (input == null) return;
    await _runTagAware(
      (allowTagTransfer) => _repository.updateNode(
        before: before,
        draft: input.draft,
        actor: widget.actor,
        reason: input.reason,
        allowTagTransfer: allowTagTransfer,
      ),
      'Hierarchy item updated.',
    );
  }

  Future<void> _toggleNodeStatus(
    BuildContext context,
    AssetHierarchyNode before,
  ) async {
    final reason = await _reasonDialog(
      context,
      title:
          before.isActive ? 'Retire hierarchy item' : 'Restore hierarchy item',
      message:
          before.isActive
              ? 'The item will remain in history and audit records but will not be available for new work.'
              : 'The item and its existing parent must both be active.',
    );
    if (reason == null) return;
    await _runTagAware(
      (allowTagTransfer) => _repository.setNodeStatus(
        before: before,
        status:
            before.isActive
                ? AssetHierarchyStatus.retired
                : AssetHierarchyStatus.active,
        actor: widget.actor,
        reason: reason,
        allowTagTransfer: allowTagTransfer,
      ),
      before.isActive ? 'Hierarchy item retired.' : 'Hierarchy item restored.',
    );
  }

  Future<void> _runTagAware(
    Future<void> Function(bool allowTagTransfer) action,
    String success,
  ) async {
    setState(() => _busy = true);
    try {
      await action(false);
    } on AssetTagCollisionException catch (collision) {
      if (!mounted) return;
      setState(() => _busy = false);
      final transfer = await _confirmTagTransfer(context, collision);
      if (!transfer || !mounted) return;
      setState(() => _busy = true);
      try {
        await action(true);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: BafColors.danger),
        );
        return;
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: BafColors.danger),
      );
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success), backgroundColor: BafColors.success),
    );
  }
}

class _HierarchyToolbar extends StatelessWidget {
  final int total;
  final int active;
  final bool showRetired;
  final bool busy;
  final ValueChanged<bool> onShowRetiredChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onAddClass;

  const _HierarchyToolbar({
    required this.total,
    required this.active,
    required this.showRetired,
    required this.busy,
    required this.onShowRetiredChanged,
    required this.onSearchChanged,
    required this.onAddClass,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.md),
        child: Column(
          children: [
            Row(
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
                Expanded(
                  child: TextField(
                    onChanged: onSearchChanged,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Search class, code or area',
                      prefixIcon: Icon(Icons.search_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: BafSpacing.md),
                FilterChip(
                  selected: showRetired,
                  onSelected: onShowRetiredChanged,
                  avatar: const Icon(Icons.history_rounded, size: 18),
                  label: Text('Retired ${total - active}'),
                ),
                const SizedBox(width: BafSpacing.sm),
                Chip(label: Text('$active active')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetClassList extends StatelessWidget {
  final List<AssetClassRecord> classes;
  final String? selectedId;
  final ValueChanged<AssetClassRecord> onSelected;

  const _AssetClassList({
    required this.classes,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (classes.isEmpty) {
      return const _EmptyHierarchy(
        icon: Icons.inventory_2_outlined,
        title: 'No matching classes',
        message: 'Change the filter or add an asset class.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(BafSpacing.sm),
      itemCount: classes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final item = classes[index];
        final selected = item.id == selectedId;
        return ListTile(
          selected: selected,
          selectedTileColor: BafColors.assets.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BafRadius.small),
          ),
          leading: Icon(
            item.isActive
                ? Icons.precision_manufacturing_rounded
                : Icons.inventory_2_outlined,
            color: item.isActive ? BafColors.assets : BafColors.textSecondary,
          ),
          title: Text(
            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${item.code} · ${item.majorArea}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing:
              item.isActive
                  ? null
                  : const Icon(Icons.history_rounded, size: 18),
          onTap: () => onSelected(item),
        );
      },
    );
  }
}

class _AssetClassDetail extends ConsumerStatefulWidget {
  final AssetClassRecord assetClass;
  final AppUser actor;
  final bool busy;
  final VoidCallback onEditClass;
  final VoidCallback onToggleClassStatus;
  final ValueChanged<AssetHierarchyNode?> onAddNode;
  final ValueChanged<AssetHierarchyNode> onEditNode;
  final ValueChanged<AssetHierarchyNode> onToggleNodeStatus;

  const _AssetClassDetail({
    super.key,
    required this.assetClass,
    required this.actor,
    required this.busy,
    required this.onEditClass,
    required this.onToggleClassStatus,
    required this.onAddNode,
    required this.onEditNode,
    required this.onToggleNodeStatus,
  });

  @override
  ConsumerState<_AssetClassDetail> createState() => _AssetClassDetailState();
}

class _AssetClassDetailState extends ConsumerState<_AssetClassDetail> {
  bool _showRetiredNodes = false;

  @override
  Widget build(BuildContext context) {
    final nodesAsync = ref.watch(
      assetHierarchyNodesProvider(widget.assetClass.id),
    );
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ClassSummary(
            assetClass: widget.assetClass,
            busy: widget.busy,
            onEdit: widget.onEditClass,
            onToggleStatus: widget.onToggleClassStatus,
            onAddRoot:
                widget.assetClass.isActive
                    ? () => widget.onAddNode(null)
                    : null,
          ),
          const Material(
            color: Colors.white,
            child: TabBar(
              tabs: [
                Tab(
                  icon: Icon(Icons.account_tree_outlined),
                  text: 'Definition',
                ),
                Tab(
                  icon: Icon(Icons.factory_outlined),
                  text: 'Physical assets',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                nodesAsync.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error:
                      (error, _) => _LoadFailure(
                        message: 'Hierarchy nodes could not be loaded: $error',
                        onRetry:
                            () => ref.invalidate(
                              assetHierarchyNodesProvider(widget.assetClass.id),
                            ),
                      ),
                  data: (nodes) {
                    final tree = AssetHierarchyTree.build(nodes);
                    final visibleNodes =
                        _showRetiredNodes
                            ? nodes
                            : nodes.where((node) => node.isActive).toList();
                    final visibleTree = AssetHierarchyTree.build(visibleNodes);
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: BafSpacing.md,
                            vertical: BafSpacing.sm,
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${visibleNodes.length} items',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: BafColors.textSecondary,
                                ),
                              ),
                              const Spacer(),
                              FilterChip(
                                selected: _showRetiredNodes,
                                onSelected:
                                    (value) => setState(
                                      () => _showRetiredNodes = value,
                                    ),
                                label: Text(
                                  'Retired ${nodes.where((node) => !node.isActive).length}',
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (tree.integrityErrors.isNotEmpty)
                          _IntegrityBanner(errors: tree.integrityErrors),
                        Expanded(
                          child:
                              visibleNodes.isEmpty
                                  ? const _EmptyHierarchy(
                                    icon: Icons.account_tree_outlined,
                                    title: 'No hierarchy items',
                                    message:
                                        'Add a grouping, assembly, component or subcomponent.',
                                  )
                                  : ListView(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      0,
                                      12,
                                      24,
                                    ),
                                    children: [
                                      for (final root in visibleTree.roots)
                                        _HierarchyBranch(
                                          node: root,
                                          tree: visibleTree,
                                          level: 0,
                                          busy: widget.busy,
                                          onAddChild: widget.onAddNode,
                                          onEdit: widget.onEditNode,
                                          onToggleStatus:
                                              widget.onToggleNodeStatus,
                                        ),
                                    ],
                                  ),
                        ),
                      ],
                    );
                  },
                ),
                _PhysicalAssetRegistry(
                  assetClass: widget.assetClass,
                  actor: widget.actor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassSummary extends StatelessWidget {
  final AssetClassRecord assetClass;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback? onAddRoot;

  const _ClassSummary({
    required this.assetClass,
    required this.busy,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onAddRoot,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(BafSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        assetClass.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: BafColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusPill(active: assetClass.isActive),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${assetClass.code} · ${assetClass.majorArea} · v${assetClass.version}',
                  style: const TextStyle(color: BafColors.textSecondary),
                ),
                if (assetClass.shortDescription != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    assetClass.shortDescription!,
                    style: const TextStyle(color: BafColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit asset class',
            onPressed: busy ? null : onEdit,
            icon: const Icon(Icons.edit_rounded),
          ),
          IconButton(
            tooltip:
                assetClass.isActive
                    ? 'Retire asset class'
                    : 'Restore asset class',
            onPressed: busy ? null : onToggleStatus,
            icon: Icon(
              assetClass.isActive
                  ? Icons.archive_outlined
                  : Icons.restore_rounded,
            ),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: busy ? null : onAddRoot,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Root item'),
          ),
        ],
      ),
    );
  }
}

class _HierarchyBranch extends StatelessWidget {
  final AssetHierarchyNode node;
  final AssetHierarchyTree tree;
  final int level;
  final bool busy;
  final ValueChanged<AssetHierarchyNode> onAddChild;
  final ValueChanged<AssetHierarchyNode> onEdit;
  final ValueChanged<AssetHierarchyNode> onToggleStatus;

  const _HierarchyBranch({
    required this.node,
    required this.tree,
    required this.level,
    required this.busy,
    required this.onAddChild,
    required this.onEdit,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final children = tree.childrenOf(node.id);
    return Padding(
      padding: EdgeInsets.only(left: level * 18.0, top: 6),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: node.isActive ? Colors.white : const Color(0xFFF2F4F7),
              border: Border.all(color: BafColors.border),
              borderRadius: BorderRadius.circular(BafRadius.small),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _nodeIcon(node.nodeType),
                  size: 20,
                  color:
                      node.isActive
                          ? BafColors.assets
                          : BafColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              node.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: BafColors.textPrimary,
                              ),
                            ),
                          ),
                          if (node.componentTag != null) ...[
                            const SizedBox(width: 8),
                            _TagPill(label: node.componentTag!),
                          ],
                          if (!node.isActive) ...[
                            const SizedBox(width: 8),
                            const _StatusPill(active: false),
                          ],
                          const SizedBox(width: 8),
                          _OwnershipPill(status: node.ownershipStatus),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          node.nodeType.label,
                          if (node.discipline != null) node.discipline!,
                          if (node.operatingType != null) node.operatingType!,
                          if (node.contactArrangement !=
                              ElectricalContactArrangement.notStated)
                            node.contactArrangement.label,
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: BafColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      if (node.shortDescription != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          node.shortDescription!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: BafColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Add child',
                  onPressed:
                      busy || !node.isActive ? null : () => onAddChild(node),
                  icon: const Icon(Icons.add_rounded),
                ),
                IconButton(
                  tooltip: 'Edit item',
                  onPressed: busy || !node.isActive ? null : () => onEdit(node),
                  icon: const Icon(Icons.edit_rounded),
                ),
                IconButton(
                  tooltip: node.isActive ? 'Retire item' : 'Restore item',
                  onPressed:
                      busy || (node.isActive && node.activeChildCount > 0)
                          ? null
                          : () => onToggleStatus(node),
                  icon: Icon(
                    node.isActive
                        ? Icons.archive_outlined
                        : Icons.restore_rounded,
                  ),
                ),
              ],
            ),
          ),
          for (final child in children)
            _HierarchyBranch(
              node: child,
              tree: tree,
              level: level + 1,
              busy: busy,
              onAddChild: onAddChild,
              onEdit: onEdit,
              onToggleStatus: onToggleStatus,
            ),
        ],
      ),
    );
  }
}

IconData _nodeIcon(AssetHierarchyNodeType type) => switch (type) {
  AssetHierarchyNodeType.grouping => Icons.folder_open_rounded,
  AssetHierarchyNodeType.assembly => Icons.hub_rounded,
  AssetHierarchyNodeType.component => Icons.settings_rounded,
  AssetHierarchyNodeType.subcomponent => Icons.tune_rounded,
};

class _StatusPill extends StatelessWidget {
  final bool active;
  const _StatusPill({required this.active});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: (active ? BafColors.success : BafColors.textSecondary).withValues(
        alpha: 0.1,
      ),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      active ? 'Active' : 'Retired',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: active ? BafColors.success : BafColors.textSecondary,
      ),
    ),
  );
}

class _TagPill extends StatelessWidget {
  final String label;
  const _TagPill({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: BafColors.warning.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: Color(0xFF8A5700),
      ),
    ),
  );
}

class _IntegrityBanner extends StatelessWidget {
  final List<String> errors;
  const _IntegrityBanner({required this.errors});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: BafColors.danger.withValues(alpha: 0.08),
      border: Border.all(color: BafColors.danger.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.circular(BafRadius.small),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: BafColors.danger),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            errors.join('\n'),
            style: const TextStyle(
              color: BafColors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _EmptyHierarchy extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _EmptyHierarchy({
    required this.icon,
    required this.title,
    required this.message,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: BafColors.textSecondary),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: BafColors.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: BafColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}

class _LoadFailure extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _LoadFailure({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: BafColors.danger,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

class _ClassDialogResult {
  final AssetClassDraft draft;
  final String reason;
  const _ClassDialogResult(this.draft, this.reason);
}

class _AssetClassDialog extends StatefulWidget {
  final AssetClassRecord? existing;
  const _AssetClassDialog({this.existing});
  @override
  State<_AssetClassDialog> createState() => _AssetClassDialogState();
}

class _AssetClassDialogState extends State<_AssetClassDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _area;
  late final TextEditingController _short;
  late final TextEditingController _long;
  final _reason = TextEditingController();
  String? _legacyAssetTypeKey;

  @override
  void initState() {
    super.initState();
    final value = widget.existing;
    _legacyAssetTypeKey = value?.legacyAssetTypeKey;
    _code = TextEditingController(text: value?.code);
    _name = TextEditingController(text: value?.name);
    _area = TextEditingController(text: value?.majorArea);
    _short = TextEditingController(text: value?.shortDescription);
    _long = TextEditingController(text: value?.longDescription);
  }

  @override
  void dispose() {
    for (final controller in [_code, _name, _area, _short, _long, _reason]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.existing == null ? 'Add asset class' : 'Edit asset class',
    ),
    content: SizedBox(
      width: 620,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextFormField(
                controller: _code,
                enabled: widget.existing == null,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Class code',
                  hintText: 'FURNACE',
                  border: OutlineInputBorder(),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Asset class name',
                  border: OutlineInputBorder(),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _area,
                decoration: const InputDecoration(
                  labelText: 'Major area / system',
                  border: OutlineInputBorder(),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _legacyAssetTypeKey,
                decoration: const InputDecoration(
                  labelText: 'Current app asset type',
                  helperText: 'Optional migration link for existing screens',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('New dynamic class'),
                  ),
                  DropdownMenuItem(value: 'base', child: Text('Base')),
                  DropdownMenuItem(value: 'furnace', child: Text('Furnace')),
                  DropdownMenuItem(
                    value: 'forceCooler',
                    child: Text('Forced Cooler'),
                  ),
                  DropdownMenuItem(
                    value: 'innerCover',
                    child: Text('Inner Cover'),
                  ),
                ],
                onChanged:
                    (value) => setState(() => _legacyAssetTypeKey = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _short,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Short description',
                  border: OutlineInputBorder(),
                ),
              ),
              TextFormField(
                controller: _long,
                maxLength: 4000,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Long functional description',
                  border: OutlineInputBorder(),
                ),
              ),
              TextFormField(
                controller: _reason,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Change reason',
                  border: OutlineInputBorder(),
                ),
                validator: _reasonValidator,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(widget.existing == null ? 'Add' : 'Save'),
      ),
    ],
  );

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final draft =
        AssetClassDraft(
          code: _code.text,
          name: _name.text,
          majorArea: _area.text,
          shortDescription: _short.text,
          longDescription: _long.text,
          legacyAssetTypeKey: _legacyAssetTypeKey,
        ).normalized();
    final errors = draft.validate();
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errors.join(' ')),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }
    Navigator.pop(context, _ClassDialogResult(draft, _reason.text.trim()));
  }
}

class _NodeDialogResult {
  final AssetHierarchyNodeDraft draft;
  final String reason;
  const _NodeDialogResult(this.draft, this.reason);
}

class _HierarchyNodeDialog extends StatefulWidget {
  final AssetHierarchyNode? existing;
  final AssetHierarchyNode? initialParent;
  final List<AssetHierarchyNode> availableParents;

  const _HierarchyNodeDialog({
    this.existing,
    this.initialParent,
    required this.availableParents,
  });
  @override
  State<_HierarchyNodeDialog> createState() => _HierarchyNodeDialogState();
}

class _HierarchyNodeDialogState extends State<_HierarchyNodeDialog> {
  final _formKey = GlobalKey<FormState>();
  late String? _parentId;
  late AssetHierarchyNodeType _type;
  late ElectricalContactArrangement _contact;
  late AssetOwnershipStatus _ownershipStatus;
  late Set<AppRole> _accountableRoles;
  late final TextEditingController _name;
  late final TextEditingController _tag;
  late final TextEditingController _short;
  late final TextEditingController _long;
  late final TextEditingController _discipline;
  late final TextEditingController _operating;
  late final TextEditingController _normal;
  late final TextEditingController _fail;
  late final TextEditingController _manufacturer;
  late final TextEditingController _model;
  late final TextEditingController _applicability;
  late final TextEditingController _source;
  late final TextEditingController _ownerDiscipline;
  late final TextEditingController _sort;
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    final value = widget.existing;
    _parentId = value?.parentNodeId ?? widget.initialParent?.id;
    _type =
        value?.nodeType ??
        (widget.initialParent == null
            ? AssetHierarchyNodeType.grouping
            : AssetHierarchyNodeType.component);
    _contact =
        value?.contactArrangement ?? ElectricalContactArrangement.notStated;
    _ownershipStatus =
        value?.ownershipStatus ?? AssetOwnershipStatus.unassigned;
    _accountableRoles =
        value?.accountableRoleKeys
            .map(
              (name) =>
                  AppRole.values.where((role) => role.name == name).firstOrNull,
            )
            .whereType<AppRole>()
            .toSet() ??
        <AppRole>{};
    _name = TextEditingController(text: value?.name);
    _tag = TextEditingController(text: value?.componentTag);
    _short = TextEditingController(text: value?.shortDescription);
    _long = TextEditingController(text: value?.longDescription);
    _discipline = TextEditingController(text: value?.discipline);
    _operating = TextEditingController(text: value?.operatingType);
    _normal = TextEditingController(text: value?.normalState);
    _fail = TextEditingController(text: value?.failState);
    _manufacturer = TextEditingController(text: value?.manufacturer);
    _model = TextEditingController(text: value?.model);
    _applicability = TextEditingController(text: value?.applicability);
    _source = TextEditingController(text: value?.sourceReference);
    _ownerDiscipline = TextEditingController(text: value?.ownerDiscipline);
    _sort = TextEditingController(text: '${value?.sortOrder ?? 0}');
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _tag,
      _short,
      _long,
      _discipline,
      _operating,
      _normal,
      _fail,
      _manufacturer,
      _model,
      _applicability,
      _source,
      _ownerDiscipline,
      _sort,
      _reason,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parents =
        widget.availableParents.where((item) => item.isActive).toList();
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Add hierarchy item' : 'Edit hierarchy item',
      ),
      content: SizedBox(
        width: 720,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: _parentId,
                  decoration: const InputDecoration(
                    labelText: 'Parent',
                    border: OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Root of asset class'),
                    ),
                    ...parents.map(
                      (item) => DropdownMenuItem<String?>(
                        value: item.id,
                        child: Text(
                          '${item.nodeType.label} · ${item.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _parentId = value),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<AssetHierarchyNodeType>(
                        initialValue: _type,
                        decoration: const InputDecoration(
                          labelText: 'Record level',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            AssetHierarchyNodeType.values
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(item.label),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) => setState(() => _type = value!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: _required,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _tag,
                        decoration: const InputDecoration(
                          labelText: 'Definition reference / typical tag',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 150,
                      child: TextFormField(
                        controller: _sort,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Sort order',
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (value) =>
                                int.tryParse(value ?? '') == null
                                    ? 'Enter a whole number'
                                    : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _short,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Short description',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextFormField(
                  controller: _long,
                  maxLength: 4000,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Long functional description',
                    border: OutlineInputBorder(),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _discipline,
                        decoration: const InputDecoration(
                          labelText: 'Discipline / technology',
                          hintText: 'Mechanical, electrical, instrumentation',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _operating,
                        decoration: const InputDecoration(
                          labelText: 'Operating method',
                          hintText: 'Pneumatic, electrical, hydraulic, passive',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _normal,
                        decoration: const InputDecoration(
                          labelText: 'Normal process position / state',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _fail,
                        decoration: const InputDecoration(
                          labelText: 'Fail position / state',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ElectricalContactArrangement>(
                  initialValue: _contact,
                  decoration: const InputDecoration(
                    labelText: 'Electrical contact arrangement',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      ElectricalContactArrangement.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => _contact = value!),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<AssetOwnershipStatus>(
                        initialValue: _ownershipStatus,
                        decoration: const InputDecoration(
                          labelText: 'Ownership status',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            AssetOwnershipStatus.values
                                .map(
                                  (status) => DropdownMenuItem(
                                    value: status,
                                    child: Text(status.label),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (value) =>
                                setState(() => _ownershipStatus = value!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _ownerDiscipline,
                        decoration: const InputDecoration(
                          labelText: 'Owning discipline',
                          hintText: 'Mechanical, electrical, instrumentation',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Accountable roles',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children:
                        AppRole.values
                            .map(
                              (role) => FilterChip(
                                label: Text(_assetOwnerRoleLabel(role)),
                                selected: _accountableRoles.contains(role),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _accountableRoles.add(role);
                                    } else {
                                      _accountableRoles.remove(role);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _manufacturer,
                        decoration: const InputDecoration(
                          labelText: 'Manufacturer',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _model,
                        decoration: const InputDecoration(
                          labelText: 'Model / type',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _applicability,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Applicability',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextFormField(
                  controller: _source,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Source document / drawing reference',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextFormField(
                  controller: _reason,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Change reason',
                    border: OutlineInputBorder(),
                  ),
                  validator: _reasonValidator,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.existing == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final draft =
        AssetHierarchyNodeDraft(
          parentNodeId: _parentId,
          nodeType: _type,
          name: _name.text,
          componentTag: _tag.text,
          shortDescription: _short.text,
          longDescription: _long.text,
          discipline: _discipline.text,
          operatingType: _operating.text,
          normalState: _normal.text,
          failState: _fail.text,
          contactArrangement: _contact,
          manufacturer: _manufacturer.text,
          model: _model.text,
          applicability: _applicability.text,
          sourceReference: _source.text,
          ownershipStatus: _ownershipStatus,
          ownerDiscipline: _ownerDiscipline.text,
          accountableRoleKeys:
              _accountableRoles.map((role) => role.name).toList()..sort(),
          sortOrder: int.parse(_sort.text),
        ).normalized();
    final errors = draft.validate();
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errors.join(' ')),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }
    Navigator.pop(context, _NodeDialogResult(draft, _reason.text.trim()));
  }
}

class _PhysicalAssetRegistry extends ConsumerStatefulWidget {
  final AssetClassRecord assetClass;
  final AppUser actor;

  const _PhysicalAssetRegistry({required this.assetClass, required this.actor});

  @override
  ConsumerState<_PhysicalAssetRegistry> createState() =>
      _PhysicalAssetRegistryState();
}

class _PhysicalAssetRegistryState
    extends ConsumerState<_PhysicalAssetRegistry> {
  String? _selectedAssetId;
  bool _showRetired = false;
  bool _busy = false;

  AssetHierarchyRepository get _repository =>
      ref.read(assetHierarchyRepositoryProvider);

  @override
  Widget build(BuildContext context) {
    final assetsAsync = ref.watch(assetInstancesProvider(widget.assetClass.id));
    return assetsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, _) => _LoadFailure(
            message: 'Physical assets could not be loaded: $error',
            onRetry:
                () => ref.invalidate(
                  assetInstancesProvider(widget.assetClass.id),
                ),
          ),
      data: (assets) {
        final visible =
            _showRetired
                ? assets
                : assets.where((asset) => asset.isActive).toList();
        final selected = assets.cast<AssetInstanceRecord?>().firstWhere(
          (asset) => asset?.id == _selectedAssetId,
          orElse: () => visible.isEmpty ? null : visible.first,
        );
        if (selected != null && selected.id != _selectedAssetId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedAssetId = selected.id);
          });
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(BafSpacing.md),
              child: Row(
                children: [
                  Text(
                    '${visible.length} physical assets',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: BafColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  FilterChip(
                    selected: _showRetired,
                    onSelected: (value) => setState(() => _showRetired = value),
                    label: Text(
                      'Retired ${assets.where((asset) => !asset.isActive).length}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed:
                        _busy || !widget.assetClass.isActive
                            ? null
                            : _createAsset,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Physical asset'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 760) {
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButtonFormField<String>(
                            initialValue: selected?.id,
                            decoration: const InputDecoration(
                              labelText: 'Physical asset',
                              border: OutlineInputBorder(),
                            ),
                            isExpanded: true,
                            items:
                                visible
                                    .map(
                                      (asset) => DropdownMenuItem(
                                        value: asset.id,
                                        child: Text(
                                          '${asset.name} · ${asset.assetNumber}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (value) =>
                                    setState(() => _selectedAssetId = value),
                          ),
                        ),
                        Expanded(child: _assetDetail(selected)),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      SizedBox(
                        width: 265,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 8, 16),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final asset = visible[index];
                            return ListTile(
                              selected: asset.id == selected?.id,
                              leading: Icon(
                                Icons.factory_outlined,
                                color:
                                    asset.isActive
                                        ? BafColors.assets
                                        : BafColors.textSecondary,
                              ),
                              title: Text(
                                asset.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '#${asset.assetNumber} · ${asset.serviceState.label}',
                              ),
                              onTap:
                                  () => setState(
                                    () => _selectedAssetId = asset.id,
                                  ),
                            );
                          },
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: _assetDetail(selected)),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _assetDetail(AssetInstanceRecord? asset) {
    if (asset == null) {
      return const _EmptyHierarchy(
        icon: Icons.factory_outlined,
        title: 'No physical asset selected',
        message: 'Add an installed furnace, base, inner cover or cooler.',
      );
    }
    return _InstalledComponentList(
      asset: asset,
      busy: _busy,
      onEditAsset: () => _editAsset(asset),
      onToggleAsset: () => _toggleAsset(asset),
      onAddComponent: () => _createComponent(asset),
      onEditComponent: _editComponent,
      onToggleComponent: _toggleComponent,
    );
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success), backgroundColor: BafColors.success),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: BafColors.danger),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runTagAware(
    Future<void> Function(String? reviewedOwnerComponentId) action,
    String success,
  ) async {
    setState(() => _busy = true);
    try {
      await action(null);
    } on AssetTagCollisionException catch (collision) {
      if (!mounted) return;
      setState(() => _busy = false);
      final transfer = await _confirmTagTransfer(context, collision);
      if (!transfer || !mounted) return;
      setState(() => _busy = true);
      await action(collision.existingComponentInstanceId);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: BafColors.danger),
      );
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success), backgroundColor: BafColors.success),
    );
  }

  Future<void> _createAsset() async {
    final result = await showDialog<_AssetInstanceDialogResult>(
      context: context,
      builder: (_) => _AssetInstanceDialog(assetClass: widget.assetClass),
    );
    if (result == null) return;
    String? createdId;
    await _run(() async {
      createdId = await _repository.createAssetInstance(
        assetClass: widget.assetClass,
        draft: result.draft,
        actor: widget.actor,
        reason: result.reason,
      );
    }, 'Physical asset added.');
    if (createdId != null && mounted) {
      setState(() => _selectedAssetId = createdId);
    }
  }

  Future<void> _editAsset(AssetInstanceRecord before) async {
    final result = await showDialog<_AssetInstanceDialogResult>(
      context: context,
      builder:
          (_) => _AssetInstanceDialog(
            assetClass: widget.assetClass,
            existing: before,
          ),
    );
    if (result == null) return;
    await _run(
      () => _repository.updateAssetInstance(
        before: before,
        draft: result.draft,
        actor: widget.actor,
        reason: result.reason,
      ),
      'Physical asset updated.',
    );
  }

  Future<void> _toggleAsset(AssetInstanceRecord before) async {
    final reason = await _reasonDialog(
      context,
      title:
          before.isActive ? 'Retire physical asset' : 'Restore physical asset',
      message:
          before.isActive
              ? 'Installed components must be retired first. Historical work remains linked.'
              : 'Restoring makes this physical asset available for new work.',
    );
    if (reason == null) return;
    await _run(
      () => _repository.setAssetInstanceStatus(
        before: before,
        status:
            before.isActive
                ? AssetHierarchyStatus.retired
                : AssetHierarchyStatus.active,
        actor: widget.actor,
        reason: reason,
      ),
      before.isActive ? 'Physical asset retired.' : 'Physical asset restored.',
    );
  }

  Future<void> _createComponent(AssetInstanceRecord asset) async {
    final nodes =
        ref.read(assetHierarchyNodesProvider(asset.assetClassId)).value ??
        const <AssetHierarchyNode>[];
    final result = await showDialog<_InstalledComponentDialogResult>(
      context: context,
      builder:
          (_) => _InstalledComponentDialog(
            definitions:
                nodes
                    .where(
                      (node) =>
                          node.isActive &&
                          (node.nodeType == AssetHierarchyNodeType.component ||
                              node.nodeType ==
                                  AssetHierarchyNodeType.subcomponent),
                    )
                    .toList(),
          ),
    );
    if (result == null) return;
    await _runTagAware(
      (reviewedOwnerComponentId) => _repository.createInstalledComponent(
        asset: asset,
        draft: result.draft,
        actor: widget.actor,
        reason: result.reason,
        allowTagTransfer: reviewedOwnerComponentId != null,
        expectedTagOwnerComponentId: reviewedOwnerComponentId,
      ),
      'Installed component added.',
    );
  }

  Future<void> _editComponent(InstalledComponentRecord before) async {
    final nodes =
        ref.read(assetHierarchyNodesProvider(before.assetClassId)).value ??
        const <AssetHierarchyNode>[];
    final result = await showDialog<_InstalledComponentDialogResult>(
      context: context,
      builder:
          (_) => _InstalledComponentDialog(
            existing: before,
            definitions: nodes.where((node) => node.isActive).toList(),
          ),
    );
    if (result == null) return;
    await _runTagAware(
      (reviewedOwnerComponentId) => _repository.updateInstalledComponent(
        before: before,
        draft: result.draft,
        actor: widget.actor,
        reason: result.reason,
        allowTagTransfer: reviewedOwnerComponentId != null,
        expectedTagOwnerComponentId: reviewedOwnerComponentId,
      ),
      'Installed component updated.',
    );
  }

  Future<void> _toggleComponent(InstalledComponentRecord before) async {
    final reason = await _reasonDialog(
      context,
      title:
          before.isActive
              ? 'Retire installed component'
              : 'Restore installed component',
      message:
          before.isActive
              ? 'The tag is released, while historical work retains its component snapshot.'
              : 'Restoring reclaims its tag; a collision will require explicit transfer.',
    );
    if (reason == null) return;
    await _runTagAware(
      (reviewedOwnerComponentId) => _repository.setInstalledComponentStatus(
        before: before,
        status:
            before.isActive
                ? AssetHierarchyStatus.retired
                : AssetHierarchyStatus.active,
        actor: widget.actor,
        reason: reason,
        allowTagTransfer: reviewedOwnerComponentId != null,
        expectedTagOwnerComponentId: reviewedOwnerComponentId,
      ),
      before.isActive
          ? 'Installed component retired.'
          : 'Installed component restored.',
    );
  }
}

class _InstalledComponentList extends ConsumerWidget {
  final AssetInstanceRecord asset;
  final bool busy;
  final VoidCallback onEditAsset;
  final VoidCallback onToggleAsset;
  final VoidCallback onAddComponent;
  final ValueChanged<InstalledComponentRecord> onEditComponent;
  final ValueChanged<InstalledComponentRecord> onToggleComponent;

  const _InstalledComponentList({
    required this.asset,
    required this.busy,
    required this.onEditAsset,
    required this.onToggleAsset,
    required this.onAddComponent,
    required this.onEditComponent,
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
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            asset.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(active: asset.isActive),
                        const SizedBox(width: 8),
                        _OwnershipPill(status: asset.ownershipStatus),
                      ],
                    ),
                    Text(
                      '#${asset.assetNumber} · ${asset.serviceState.label}'
                      '${asset.location == null ? '' : ' · ${asset.location}'}',
                      style: const TextStyle(color: BafColors.textSecondary),
                    ),
                  ],
                ),
              ),
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
                    busy || (asset.isActive && asset.activeComponentCount > 0)
                        ? null
                        : onToggleAsset,
                icon: Icon(
                  asset.isActive
                      ? Icons.archive_outlined
                      : Icons.restore_rounded,
                ),
              ),
              FilledButton.icon(
                onPressed: busy || !asset.isActive ? null : onAddComponent,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Installed component'),
              ),
            ],
          ),
        ),
        Expanded(
          child: componentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
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
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                component.definitionName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                            if (component.componentTag !=
                                                null) ...[
                                              const SizedBox(width: 8),
                                              _TagPill(
                                                label: component.componentTag!,
                                              ),
                                            ],
                                            const SizedBox(width: 8),
                                            _OwnershipPill(
                                              status: component.ownershipStatus,
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
                                  IconButton(
                                    tooltip: 'Edit installed component',
                                    onPressed:
                                        busy || !component.isActive
                                            ? null
                                            : () => onEditComponent(component),
                                    icon: const Icon(Icons.edit_rounded),
                                  ),
                                  IconButton(
                                    tooltip:
                                        component.isActive
                                            ? 'Retire installed component'
                                            : 'Restore installed component',
                                    onPressed:
                                        busy
                                            ? null
                                            : () =>
                                                onToggleComponent(component),
                                    icon: Icon(
                                      component.isActive
                                          ? Icons.archive_outlined
                                          : Icons.restore_rounded,
                                    ),
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

class _AssetInstanceDialogResult {
  final AssetInstanceDraft draft;
  final String reason;
  const _AssetInstanceDialogResult(this.draft, this.reason);
}

class _AssetInstanceDialog extends StatefulWidget {
  final AssetClassRecord assetClass;
  final AssetInstanceRecord? existing;

  const _AssetInstanceDialog({required this.assetClass, this.existing});

  @override
  State<_AssetInstanceDialog> createState() => _AssetInstanceDialogState();
}

class _AssetInstanceDialogState extends State<_AssetInstanceDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _number;
  late final TextEditingController _name;
  late final TextEditingController _plantTag;
  late final TextEditingController _location;
  late final TextEditingController _manufacturer;
  late final TextEditingController _model;
  late final TextEditingController _serial;
  late final TextEditingController _owner;
  final _reason = TextEditingController();
  late AssetServiceState _serviceState;
  late AssetOwnershipStatus _ownership;
  late Set<AppRole> _roles;

  @override
  void initState() {
    super.initState();
    final value = widget.existing;
    _number = TextEditingController(text: value?.assetNumber.toString());
    _name = TextEditingController(text: value?.name);
    _plantTag = TextEditingController(text: value?.plantTag);
    _location = TextEditingController(text: value?.location);
    _manufacturer = TextEditingController(text: value?.manufacturer);
    _model = TextEditingController(text: value?.model);
    _serial = TextEditingController(text: value?.serialNumber);
    _owner = TextEditingController(text: value?.ownerDiscipline);
    _serviceState = value?.serviceState ?? AssetServiceState.inService;
    _ownership = value?.ownershipStatus ?? AssetOwnershipStatus.unassigned;
    _roles = _rolesFromKeys(value?.accountableRoleKeys ?? const <String>[]);
  }

  @override
  void dispose() {
    for (final controller in [
      _number,
      _name,
      _plantTag,
      _location,
      _manufacturer,
      _model,
      _serial,
      _owner,
      _reason,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.existing == null ? 'Add physical asset' : 'Edit physical asset',
    ),
    content: SizedBox(
      width: 680,
      child: Form(
        key: _key,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: TextFormField(
                      controller: _number,
                      enabled: widget.existing == null,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Asset number',
                        border: OutlineInputBorder(),
                      ),
                      validator:
                          (value) =>
                              int.tryParse(value ?? '') == null
                                  ? 'Required'
                                  : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Asset name',
                        border: OutlineInputBorder(),
                      ),
                      validator: _required,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _plantTag,
                      decoration: const InputDecoration(
                        labelText: 'Equipment tag',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _location,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _manufacturer,
                      decoration: const InputDecoration(
                        labelText: 'Manufacturer',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _model,
                      decoration: const InputDecoration(
                        labelText: 'Model / type',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _serial,
                      decoration: const InputDecoration(
                        labelText: 'Serial number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _OwnershipEditor(
                serviceState: _serviceState,
                ownershipStatus: _ownership,
                ownerController: _owner,
                roles: _roles,
                onServiceChanged:
                    (value) => setState(() => _serviceState = value),
                onOwnershipChanged:
                    (value) => setState(() => _ownership = value),
                onRolesChanged: (value) => setState(() => _roles = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reason,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Change reason',
                  border: OutlineInputBorder(),
                ),
                validator: _reasonValidator,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(widget.existing == null ? 'Add' : 'Save'),
      ),
    ],
  );

  void _submit() {
    if (!_key.currentState!.validate()) return;
    final draft =
        AssetInstanceDraft(
          assetNumber: int.parse(_number.text),
          name: _name.text,
          plantTag: _plantTag.text,
          location: _location.text,
          manufacturer: _manufacturer.text,
          model: _model.text,
          serialNumber: _serial.text,
          serviceState: _serviceState,
          ownershipStatus: _ownership,
          ownerDiscipline: _owner.text,
          accountableRoleKeys: _roles.map((role) => role.name).toList(),
        ).normalized();
    final errors = draft.validate();
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errors.join(' ')),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      _AssetInstanceDialogResult(draft, _reason.text.trim()),
    );
  }
}

class _InstalledComponentDialogResult {
  final InstalledComponentDraft draft;
  final String reason;
  const _InstalledComponentDialogResult(this.draft, this.reason);
}

class _InstalledComponentDialog extends StatefulWidget {
  final InstalledComponentRecord? existing;
  final List<AssetHierarchyNode> definitions;

  const _InstalledComponentDialog({this.existing, required this.definitions});

  @override
  State<_InstalledComponentDialog> createState() =>
      _InstalledComponentDialogState();
}

class _InstalledComponentDialogState extends State<_InstalledComponentDialog> {
  final _key = GlobalKey<FormState>();
  late String? _definitionId;
  late final TextEditingController _tag;
  late final TextEditingController _manufacturer;
  late final TextEditingController _model;
  late final TextEditingController _serial;
  late final TextEditingController _owner;
  final _reason = TextEditingController();
  late AssetServiceState _serviceState;
  late AssetOwnershipStatus _ownership;
  late Set<AppRole> _roles;

  @override
  void initState() {
    super.initState();
    final value = widget.existing;
    _definitionId = value?.definitionNodeId;
    _tag = TextEditingController(text: value?.componentTag);
    _manufacturer = TextEditingController(text: value?.manufacturer);
    _model = TextEditingController(text: value?.model);
    _serial = TextEditingController(text: value?.serialNumber);
    _owner = TextEditingController(text: value?.ownerDiscipline);
    _serviceState = value?.serviceState ?? AssetServiceState.inService;
    _ownership = value?.ownershipStatus ?? AssetOwnershipStatus.unassigned;
    _roles = _rolesFromKeys(value?.accountableRoleKeys ?? const <String>[]);
  }

  @override
  void dispose() {
    for (final controller in [
      _tag,
      _manufacturer,
      _model,
      _serial,
      _owner,
      _reason,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.existing == null
          ? 'Add installed component'
          : 'Edit installed component',
    ),
    content: SizedBox(
      width: 680,
      child: Form(
        key: _key,
        child: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _definitionId,
                decoration: const InputDecoration(
                  labelText: 'Component definition',
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                items:
                    widget.definitions
                        .map(
                          (node) => DropdownMenuItem(
                            value: node.id,
                            child: Text(
                              node.hierarchyPath.join(' › '),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _definitionId = value),
                validator: (value) => value == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tag,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Physical component tag',
                  hintText: 'Must be unique across active installed components',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _manufacturer,
                      decoration: const InputDecoration(
                        labelText: 'Manufacturer',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _model,
                      decoration: const InputDecoration(
                        labelText: 'Model / type',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _serial,
                      decoration: const InputDecoration(
                        labelText: 'Serial number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _OwnershipEditor(
                serviceState: _serviceState,
                ownershipStatus: _ownership,
                ownerController: _owner,
                roles: _roles,
                onServiceChanged:
                    (value) => setState(() => _serviceState = value),
                onOwnershipChanged:
                    (value) => setState(() => _ownership = value),
                onRolesChanged: (value) => setState(() => _roles = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reason,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Change reason',
                  border: OutlineInputBorder(),
                ),
                validator: _reasonValidator,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(widget.existing == null ? 'Add' : 'Save'),
      ),
    ],
  );

  void _submit() {
    if (!_key.currentState!.validate()) return;
    final draft =
        InstalledComponentDraft(
          definitionNodeId: _definitionId!,
          componentTag: _tag.text,
          manufacturer: _manufacturer.text,
          model: _model.text,
          serialNumber: _serial.text,
          serviceState: _serviceState,
          ownershipStatus: _ownership,
          ownerDiscipline: _owner.text,
          accountableRoleKeys: _roles.map((role) => role.name).toList(),
        ).normalized();
    final errors = draft.validate();
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errors.join(' ')),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      _InstalledComponentDialogResult(draft, _reason.text.trim()),
    );
  }
}

class _OwnershipEditor extends StatelessWidget {
  final AssetServiceState serviceState;
  final AssetOwnershipStatus ownershipStatus;
  final TextEditingController ownerController;
  final Set<AppRole> roles;
  final ValueChanged<AssetServiceState> onServiceChanged;
  final ValueChanged<AssetOwnershipStatus> onOwnershipChanged;
  final ValueChanged<Set<AppRole>> onRolesChanged;

  const _OwnershipEditor({
    required this.serviceState,
    required this.ownershipStatus,
    required this.ownerController,
    required this.roles,
    required this.onServiceChanged,
    required this.onOwnershipChanged,
    required this.onRolesChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<AssetServiceState>(
              initialValue: serviceState,
              decoration: const InputDecoration(
                labelText: 'Service state',
                border: OutlineInputBorder(),
              ),
              items:
                  AssetServiceState.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) onServiceChanged(value);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<AssetOwnershipStatus>(
              initialValue: ownershipStatus,
              decoration: const InputDecoration(
                labelText: 'Ownership status',
                border: OutlineInputBorder(),
              ),
              items:
                  AssetOwnershipStatus.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) onOwnershipChanged(value);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: ownerController,
              decoration: const InputDecoration(
                labelText: 'Owning discipline',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 7,
          runSpacing: 7,
          children:
              AppRole.values
                  .map(
                    (role) => FilterChip(
                      label: Text(_assetOwnerRoleLabel(role)),
                      selected: roles.contains(role),
                      onSelected: (selected) {
                        final next = Set<AppRole>.from(roles);
                        selected ? next.add(role) : next.remove(role);
                        onRolesChanged(next);
                      },
                    ),
                  )
                  .toList(),
        ),
      ),
    ],
  );
}

Set<AppRole> _rolesFromKeys(List<String> keys) =>
    keys
        .map(
          (key) => AppRole.values.where((role) => role.name == key).firstOrNull,
        )
        .whereType<AppRole>()
        .toSet();

class _OwnershipPill extends StatelessWidget {
  final AssetOwnershipStatus status;

  const _OwnershipPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      AssetOwnershipStatus.confirmed => (
        BafColors.success,
        Icons.verified_user_outlined,
      ),
      AssetOwnershipStatus.provisional => (
        BafColors.warning,
        Icons.pending_actions_outlined,
      ),
      AssetOwnershipStatus.unassigned => (
        BafColors.danger,
        Icons.person_off_outlined,
      ),
    };
    return Tooltip(
      message: status.label,
      child: Icon(icon, size: 17, color: color),
    );
  }
}

String _assetOwnerRoleLabel(AppRole role) => switch (role) {
  AppRole.admin => 'Admin',
  AppRole.si => 'SI',
  AppRole.contractSupervisor => 'Contract supervisor',
  AppRole.shiftSupervisor => 'Shift supervisor',
  AppRole.seniorElectrical => 'Sr. Electrical',
  AppRole.seniorMechanical => 'Sr. Mechanical',
  AppRole.seniorInstrumentation => 'Sr. I&A',
  AppRole.seniorRefractory => 'Sr. Refractory',
  AppRole.refractory => 'Refractory',
  AppRole.operations => 'Operations',
};

Future<bool> _confirmTagTransfer(
  BuildContext context,
  AssetTagCollisionException collision,
) async {
  return await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              icon: const Icon(
                Icons.warning_amber_rounded,
                color: BafColors.warning,
              ),
              title: Text('Tag ${collision.normalizedTag} is already assigned'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        collision.existingAssetClassName,
                        if (collision.existingAssetInstanceName != null)
                          collision.existingAssetInstanceName!,
                        collision.existingNodeName,
                      ].join(' · '),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    if (collision.existingPath.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(collision.existingPath.join('  ›  ')),
                    ],
                    if (collision.existingOwnershipStatus != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        [
                          'Current ownership: ${collision.existingOwnershipStatus!.label}',
                          if (collision.existingOwnerDiscipline != null)
                            collision.existingOwnerDiscipline!,
                          if (collision.existingAccountableRoleKeys.isNotEmpty)
                            collision.existingAccountableRoleKeys
                                .map(
                                  (key) =>
                                      AppRole.values
                                          .where((role) => role.name == key)
                                          .map(_assetOwnerRoleLabel)
                                          .firstOrNull ??
                                      key,
                                )
                                .join(', '),
                        ].join(' · '),
                        style: const TextStyle(
                          color: BafColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      collision.transferSupported
                          ? 'Transferring makes this installed component the only current owner of the tag. The tag is removed from the existing component; historical tickets and completed work keep their recorded snapshots.'
                          : 'This tag is held by a legacy definition record. Reconcile that record before assigning the tag to an installed component.',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep existing owner'),
                ),
                FilledButton.icon(
                  onPressed:
                      collision.transferSupported
                          ? () => Navigator.pop(context, true)
                          : null,
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Transfer tag'),
                ),
              ],
            ),
      ) ??
      false;
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;
String? _reasonValidator(String? value) {
  final length = value?.trim().length ?? 0;
  return length < 8 || length > 500 ? 'Use 8-500 characters' : null;
}

Future<String?> _reasonDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _ReasonDialog(title: title, message: message),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title, required this.message});

  final String title;
  final String message;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.message),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              autofocus: true,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              validator: _reasonValidator,
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
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _controller.text.trim());
            }
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
