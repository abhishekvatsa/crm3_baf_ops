part of 'maintenance_form.dart';

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: BafColors.maintenance, size: 22),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: BafSpacing.xs),
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
          ),
          const SizedBox(height: BafSpacing.lg),
          ...children,
        ],
      ),
    );
  }
}

class _ResolvedTagPanel extends StatelessWidget {
  final String? system;
  final String? subsystem;
  final List<String>? path;
  final String? ownership;
  final bool governed;

  const _ResolvedTagPanel({
    this.system,
    this.subsystem,
    this.path,
    this.ownership,
    this.governed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.sync.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.sync.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                governed ? Icons.verified_outlined : Icons.auto_awesome_rounded,
                size: 17,
                color: BafColors.sync,
              ),
              const SizedBox(width: 6),
              Text(
                governed ? 'Governed component resolved' : 'Tag resolved',
                style: const TextStyle(
                  color: BafColors.sync,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.sm),
          if (system != null && system!.trim().isNotEmpty)
            _ResolvedLine(label: 'System', value: system!),
          if (subsystem != null && subsystem!.trim().isNotEmpty)
            _ResolvedLine(label: 'Subsystem', value: subsystem!),
          if (path != null && path!.isNotEmpty)
            _ResolvedLine(label: 'Path', value: path!.join(' › ')),
          if (ownership != null && ownership!.trim().isNotEmpty)
            _ResolvedLine(label: 'Ownership', value: ownership!),
        ],
      ),
    );
  }
}

String _roleLabelForReference(String role) => switch (role) {
  'admin' => 'Admin',
  'si' => 'SI',
  'contractSupervisor' => 'Contract supervisor',
  'shiftSupervisor' => 'Shift supervisor',
  'seniorElectrical' => 'Sr. Electrical',
  'seniorMechanical' => 'Sr. Mechanical',
  'seniorInstrumentation' => 'Sr. I&A',
  'seniorRefractory' => 'Sr. Refractory',
  'refractory' => 'Refractory',
  'operations' => 'Operations',
  _ => role,
};

class _ResolvedLine extends StatelessWidget {
  final String label;
  final String value;

  const _ResolvedLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: BafColors.textSecondary,
            fontSize: 12,
            height: 1.25,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _IssueComponentSelection {
  const _IssueComponentSelection.node(this.node) : unlisted = false;

  const _IssueComponentSelection.unlisted() : node = null, unlisted = true;

  final AssetHierarchyNode? node;
  final bool unlisted;
}

class _IssueComponentPickerSheet extends StatefulWidget {
  const _IssueComponentPickerSheet({
    required this.assetLabel,
    required this.nodes,
    required this.selectedNodeId,
  });

  final String assetLabel;
  final List<AssetHierarchyNode> nodes;
  final String? selectedNodeId;

  @override
  State<_IssueComponentPickerSheet> createState() =>
      _IssueComponentPickerSheetState();
}

class _IssueComponentPickerSheetState
    extends State<_IssueComponentPickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visible =
        widget.nodes.where((node) {
            if (query.isEmpty) return true;
            return <String>[
              node.name,
              node.componentTag ?? '',
              node.discipline ?? '',
              node.operatingType ?? '',
              ...node.hierarchyPath,
            ].join(' ').toLowerCase().contains(query);
          }).toList()
          ..sort((left, right) {
            final path = left.hierarchyPath
                .join('/')
                .compareTo(right.hierarchyPath.join('/'));
            return path != 0 ? path : left.name.compareTo(right.name);
          });

    return FractionallySizedBox(
      heightFactor: 0.90,
      child: Column(
        children: [
          Container(
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
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(BafRadius.small),
                  ),
                  child: const Icon(
                    Icons.account_tree_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: BafSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select affected component',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.assetLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFC6D7DB),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(BafSpacing.md),
            child: TextField(
              controller: _search,
              autofocus: false,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                labelText: 'Search component, tag or discipline',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                BafSpacing.md,
                0,
                BafSpacing.md,
                BafSpacing.xl,
              ),
              itemCount: visible.length + 1,
              separatorBuilder:
                  (_, _) => const Divider(height: 1, color: BafColors.border),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    leading: const Icon(
                      Icons.add_comment_outlined,
                      color: BafColors.warning,
                    ),
                    title: const Text(
                      'Unlisted component',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Enter a description and send it for hierarchy review.',
                    ),
                    onTap:
                        () => Navigator.pop(
                          context,
                          const _IssueComponentSelection.unlisted(),
                        ),
                  );
                }
                final node = visible[index - 1];
                final selected = node.id == widget.selectedNodeId;
                return ListTile(
                  selected: selected,
                  leading: Icon(
                    node.nodeType == AssetHierarchyNodeType.subcomponent
                        ? Icons.subdirectory_arrow_right_rounded
                        : Icons.settings_outlined,
                    color: selected ? BafColors.sync : BafColors.assets,
                  ),
                  title: Text(
                    node.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    <String>[
                      if (node.hierarchyPath.isNotEmpty)
                        node.hierarchyPath.join(' › '),
                      if (node.discipline?.trim().isNotEmpty == true)
                        node.discipline!,
                      if (node.componentTag?.trim().isNotEmpty == true)
                        'Tag ${node.componentTag}',
                    ].join('\n'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing:
                      selected
                          ? const Icon(
                            Icons.check_circle_rounded,
                            color: BafColors.sync,
                          )
                          : const Icon(Icons.chevron_right_rounded),
                  onTap:
                      () => Navigator.pop(
                        context,
                        _IssueComponentSelection.node(node),
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
