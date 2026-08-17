part of 'admin_asset_hierarchy_tab.dart';

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
              LayoutBuilder(
                builder: (context, constraints) {
                  final fields = <Widget>[
                    TextFormField(
                      controller: _manufacturer,
                      decoration: const InputDecoration(
                        labelText: 'Manufacturer',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    TextFormField(
                      controller: _model,
                      decoration: const InputDecoration(
                        labelText: 'Model / type',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    TextFormField(
                      controller: _serial,
                      decoration: const InputDecoration(
                        labelText: 'Serial number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ];
                  if (constraints.maxWidth < 620) {
                    return Column(
                      children: [
                        for (var index = 0; index < fields.length; index++) ...[
                          fields[index],
                          if (index < fields.length - 1)
                            const SizedBox(height: 10),
                        ],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      for (var index = 0; index < fields.length; index++) ...[
                        Expanded(child: fields[index]),
                        if (index < fields.length - 1)
                          const SizedBox(width: 12),
                      ],
                    ],
                  );
                },
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
