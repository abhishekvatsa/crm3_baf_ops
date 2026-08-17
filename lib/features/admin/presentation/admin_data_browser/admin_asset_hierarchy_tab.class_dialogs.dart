part of 'admin_asset_hierarchy_tab.dart';

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
