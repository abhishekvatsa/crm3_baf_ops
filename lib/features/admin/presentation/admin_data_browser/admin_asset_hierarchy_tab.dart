import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../../core/widgets/baf_ui.dart';
import '../../providers/admin_stream_providers.dart';
import '../../../assets/data/asset_hierarchy_model.dart';
import '../../../assets/data/asset_registry_model.dart';
import '../../../assets/providers/asset_hierarchy_provider.dart';
import '../../../assets/repositories/asset_hierarchy_repository.dart';
import '../../../auth/data/user_model.dart';
import '../../../maintenance/data/maintenance_model.dart';
import '../../../planned_maintenance/data/job_template_model.dart';

part 'admin_asset_hierarchy_tab.class_dialogs.dart';
part 'admin_asset_hierarchy_tab.asset_registry.dart';
part 'admin_asset_hierarchy_tab.component_registry.dart';
part 'admin_asset_hierarchy_tab.asset_dialog.dart';
part 'admin_asset_hierarchy_tab.component_dialog.dart';
part 'admin_asset_hierarchy_tab.reason_dialog.dart';
part 'admin_asset_hierarchy_tab.toolbar.dart';

class AssetHierarchyAdminTab extends ConsumerStatefulWidget {
  final AppUser actor;
  final Widget? compactHeader;

  const AssetHierarchyAdminTab({
    super.key,
    required this.actor,
    this.compactHeader,
  });

  @override
  ConsumerState<AssetHierarchyAdminTab> createState() =>
      _AssetHierarchyAdminTabState();
}

class _AssetHierarchyAdminTabState
    extends ConsumerState<AssetHierarchyAdminTab> {
  final _searchController = TextEditingController();
  String? _selectedClassId;
  String _search = '';
  bool _showRetired = false;
  bool _busy = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(assetClassesProvider);
    return ColoredBox(
      color: BafColors.background,
      child: classesAsync.when(
        loading:
            () => _buildNonDataState(
              const BafLoadingPanel(
                label: 'Loading asset hierarchy',
                color: BafColors.admin,
              ),
            ),
        error:
            (error, _) => _buildNonDataState(
              _LoadFailure(
                message: 'Asset hierarchy could not be loaded: $error',
                onRetry: () => ref.invalidate(assetClassesProvider),
              ),
            ),
        data: (classes) => _buildLoaded(context, classes),
      ),
    );
  }

  Widget _buildNonDataState(Widget state) {
    final compactHeader = widget.compactHeader;
    if (compactHeader == null) return state;
    return Column(children: [compactHeader, Expanded(child: state)]);
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
    final selected = visible.cast<AssetClassRecord?>().firstWhere(
      (item) => item?.id == _selectedClassId,
      orElse: () => visible.isEmpty ? null : visible.first,
    );
    if (selected != null && selected.id != _selectedClassId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedClassId = selected.id);
      });
    }

    final toolbar = _HierarchyToolbar(
      total: classes.length,
      active: classes.where((item) => item.isActive).length,
      showRetired: _showRetired,
      busy: _busy,
      searchController: _searchController,
      onShowRetiredChanged: (value) => setState(() => _showRetired = value),
      onSearchChanged: (value) => setState(() => _search = value),
      onAddClass: _busy ? null : () => _createClass(context),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 860) {
          final selector = Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: DropdownButtonFormField<String>(
              key: const ValueKey('asset-hierarchy-class-selector'),
              initialValue: selected?.id,
              decoration: const InputDecoration(
                labelText: 'Asset class',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.precision_manufacturing_rounded),
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
              onChanged: (value) => setState(() => _selectedClassId = value),
            ),
          );
          if (selected == null) {
            return Column(
              children: [
                if (widget.compactHeader != null) widget.compactHeader!,
                toolbar,
                selector,
                Expanded(child: _classDetail(null)),
              ],
            );
          }
          return _classDetail(
            selected,
            compactHeaders: [
              if (widget.compactHeader != null) widget.compactHeader!,
              toolbar,
              selector,
            ],
          );
        }

        return Column(
          children: [
            toolbar,
            Expanded(
              child: Row(
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
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _classDetail(
    AssetClassRecord? assetClass, {
    List<Widget> compactHeaders = const <Widget>[],
  }) {
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
      compactHeaders: compactHeaders,
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
  final List<Widget> compactHeaders;

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
    this.compactHeaders = const <Widget>[],
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
    final compact = MediaQuery.sizeOf(context).width < 560;
    final summary = _ClassSummary(
      assetClass: widget.assetClass,
      busy: widget.busy,
      onEdit: widget.onEditClass,
      onToggleStatus: widget.onToggleClassStatus,
      onAddRoot:
          widget.assetClass.isActive ? () => widget.onAddNode(null) : null,
    );
    final tabs = _hierarchyTabs(compact);
    final tabView = TabBarView(
      children: [
        _definitionTab(nodesAsync),
        _PhysicalAssetRegistry(
          assetClass: widget.assetClass,
          actor: widget.actor,
        ),
      ],
    );
    return DefaultTabController(
      length: 2,
      child:
          widget.compactHeaders.isNotEmpty
              ? NestedScrollView(
                key: const ValueKey('asset-hierarchy-mobile-scroll'),
                headerSliverBuilder:
                    (context, innerBoxIsScrolled) => [
                      for (final header in widget.compactHeaders)
                        SliverToBoxAdapter(child: header),
                      SliverToBoxAdapter(child: summary),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _HierarchyTabHeaderDelegate(child: tabs),
                      ),
                    ],
                body: tabView,
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [summary, tabs, Expanded(child: tabView)],
              ),
    );
  }

  Widget _hierarchyTabs(bool compact) {
    return Material(
      color: Colors.white,
      child: TabBar(
        tabs: [
          Tab(
            icon: compact ? null : const Icon(Icons.account_tree_outlined),
            text: 'Definition',
          ),
          Tab(
            icon: compact ? null : const Icon(Icons.factory_outlined),
            text: 'Physical assets',
          ),
        ],
      ),
    );
  }

  Widget _definitionTab(AsyncValue<List<AssetHierarchyNode>> nodesAsync) {
    return nodesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
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
                vertical: BafSpacing.xs,
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
                        (value) => setState(() => _showRetiredNodes = value),
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
                        key: const ValueKey('asset-hierarchy-definition-list'),
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        children: [
                          for (final root in visibleTree.roots)
                            _HierarchyBranch(
                              node: root,
                              tree: visibleTree,
                              level: 0,
                              busy: widget.busy,
                              onAddChild: widget.onAddNode,
                              onEdit: widget.onEditNode,
                              onToggleStatus: widget.onToggleNodeStatus,
                            ),
                        ],
                      ),
            ),
          ],
        );
      },
    );
  }
}

class _HierarchyTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  const _HierarchyTabHeaderDelegate({required this.child});

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox.expand(child: child);

  @override
  bool shouldRebuild(covariant _HierarchyTabHeaderDelegate oldDelegate) =>
      oldDelegate.child != child;
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
      padding:
          MediaQuery.sizeOf(context).width < 560
              ? const EdgeInsets.fromLTRB(12, 8, 8, 8)
              : const EdgeInsets.all(BafSpacing.md),
      child: LayoutBuilder(
        builder:
            (context, constraints) => Row(
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
                      if (constraints.maxWidth >= 560 &&
                          assetClass.shortDescription != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          assetClass.shortDescription!,
                          style: const TextStyle(
                            color: BafColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (constraints.maxWidth < 560)
                  PopupMenuButton<String>(
                    tooltip: 'Asset class actions',
                    enabled: !busy,
                    onSelected: (action) {
                      switch (action) {
                        case 'edit':
                          onEdit();
                          break;
                        case 'toggle':
                          onToggleStatus();
                          break;
                        case 'add':
                          onAddRoot?.call();
                          break;
                      }
                    },
                    itemBuilder:
                        (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit_rounded),
                              title: Text('Edit asset class'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'toggle',
                            child: ListTile(
                              leading: Icon(
                                assetClass.isActive
                                    ? Icons.archive_outlined
                                    : Icons.restore_rounded,
                              ),
                              title: Text(
                                assetClass.isActive
                                    ? 'Retire asset class'
                                    : 'Restore asset class',
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          if (onAddRoot != null)
                            const PopupMenuItem(
                              value: 'add',
                              child: ListTile(
                                leading: Icon(Icons.add_rounded),
                                title: Text('Add root item'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                        ],
                    icon: const Icon(Icons.more_vert_rounded),
                  )
                else ...[
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
              ],
            ),
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
