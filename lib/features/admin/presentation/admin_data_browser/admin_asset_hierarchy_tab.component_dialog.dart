part of 'admin_asset_hierarchy_tab.dart';

class _InstalledComponentDialogResult {
  final InstalledComponentDraft draft;
  final String reason;
  final ComponentReplacementEvidenceReference? evidenceReference;
  const _InstalledComponentDialogResult(
    this.draft,
    this.reason, {
    this.evidenceReference,
  });
}

class _ReplacementEvidenceOption {
  final ComponentReplacementEvidenceReference reference;
  final String title;
  final String subtitle;
  final DateTime completedAt;

  const _ReplacementEvidenceOption({
    required this.reference,
    required this.title,
    required this.subtitle,
    required this.completedAt,
  });

  String get key => '${reference.sourceType.name}:${reference.sourceId}';
}

class _InstalledComponentDialog extends StatefulWidget {
  final InstalledComponentRecord? existing;
  final InstalledComponentRecord? replacementFor;
  final List<AssetHierarchyNode> definitions;
  final List<_ReplacementEvidenceOption> evidenceOptions;

  const _InstalledComponentDialog({
    this.existing,
    this.replacementFor,
    required this.definitions,
    this.evidenceOptions = const <_ReplacementEvidenceOption>[],
  }) : assert(existing == null || replacementFor == null);

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
  late DateTime? _installedOn;
  String? _evidenceKey;

  bool get _isReplacement => widget.replacementFor != null;

  @override
  void initState() {
    super.initState();
    final value = widget.replacementFor ?? widget.existing;
    _definitionId = value?.definitionNodeId;
    _tag = TextEditingController(text: value?.componentTag);
    _manufacturer = TextEditingController(text: value?.manufacturer);
    _model = TextEditingController(text: value?.model);
    _serial = TextEditingController(
      text: _isReplacement ? null : value?.serialNumber,
    );
    _owner = TextEditingController(text: value?.ownerDiscipline);
    _serviceState = value?.serviceState ?? AssetServiceState.inService;
    _ownership = value?.ownershipStatus ?? AssetOwnershipStatus.unassigned;
    _roles = _rolesFromKeys(value?.accountableRoleKeys ?? const <String>[]);
    _installedOn =
        _isReplacement ? DateTime.now() : widget.existing?.installedOn;
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
      _isReplacement
          ? 'Replace installed component'
          : widget.existing == null
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
              if (_isReplacement) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BafColors.assets.withValues(alpha: 0.08),
                    border: Border.all(
                      color: BafColors.assets.withValues(alpha: 0.28),
                    ),
                    borderRadius: BorderRadius.circular(BafRadius.small),
                  ),
                  child: const Text(
                    'The current identity will be retired and the new identity installed in one governed change. Historical work remains linked.',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _evidenceKey,
                  decoration: const InputDecoration(
                    labelText: 'Completed work evidence',
                    helperText:
                        'Optional. Only exact-asset resolved work is eligible.',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.fact_check_outlined),
                  ),
                  isExpanded: true,
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Manual Admin confirmation'),
                    ),
                    ...widget.evidenceOptions.map(
                      (option) => DropdownMenuItem<String>(
                        value: option.key,
                        child: Tooltip(
                          message: option.subtitle,
                          child: Text(
                            option.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _evidenceKey = value),
                ),
                const SizedBox(height: 12),
              ],
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
                onChanged:
                    _isReplacement
                        ? null
                        : (value) => setState(() => _definitionId = value),
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
              InputDecorator(
                decoration: InputDecoration(
                  labelText:
                      _isReplacement
                          ? 'Replacement installed on'
                          : 'Installed on',
                  border: const OutlineInputBorder(),
                  errorText:
                      _isReplacement && _installedOn == null
                          ? 'Required for replacement'
                          : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _installedOn == null
                            ? 'Not recorded'
                            : DateFormat(
                              'dd MMM yyyy, HH:mm',
                            ).format(_installedOn!.toLocal()),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Select installation date and time',
                      onPressed: _pickInstalledOn,
                      icon: const Icon(Icons.event_rounded),
                    ),
                    if (_installedOn != null && !_isReplacement)
                      IconButton(
                        tooltip: 'Clear installation date',
                        onPressed: () => setState(() => _installedOn = null),
                        icon: const Icon(Icons.clear_rounded),
                      ),
                  ],
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
        child: Text(
          _isReplacement
              ? 'Replace'
              : widget.existing == null
              ? 'Add'
              : 'Save',
        ),
      ),
    ],
  );

  void _submit() {
    if (!_key.currentState!.validate()) return;
    if (_isReplacement && _installedOn == null) {
      setState(() {});
      return;
    }
    final draft =
        InstalledComponentDraft(
          definitionNodeId: _definitionId!,
          componentTag: _tag.text,
          manufacturer: _manufacturer.text,
          model: _model.text,
          serialNumber: _serial.text,
          installedOn: _installedOn,
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
      _InstalledComponentDialogResult(
        draft,
        _reason.text.trim(),
        evidenceReference:
            widget.evidenceOptions
                .where((option) => option.key == _evidenceKey)
                .firstOrNull
                ?.reference,
      ),
    );
  }

  Future<void> _pickInstalledOn() async {
    final initial = _installedOn?.toLocal() ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(1980),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDate: initial,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(
      () =>
          _installedOn = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          ),
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final serviceField = DropdownButtonFormField<AssetServiceState>(
        initialValue: serviceState,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Service state',
          border: OutlineInputBorder(),
        ),
        items:
            AssetServiceState.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(),
        onChanged: (value) {
          if (value != null) onServiceChanged(value);
        },
      );
      final ownershipField = DropdownButtonFormField<AssetOwnershipStatus>(
        initialValue: ownershipStatus,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Ownership status',
          border: OutlineInputBorder(),
        ),
        items:
            AssetOwnershipStatus.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(),
        onChanged: (value) {
          if (value != null) onOwnershipChanged(value);
        },
      );
      final disciplineField = TextFormField(
        controller: ownerController,
        decoration: const InputDecoration(
          labelText: 'Owning discipline',
          border: OutlineInputBorder(),
        ),
      );
      final fields = <Widget>[serviceField, ownershipField, disciplineField];
      return Column(
        children: [
          if (constraints.maxWidth < 620)
            ...fields.expand((field) => [field, const SizedBox(height: 10)])
          else
            Row(
              children: [
                for (var index = 0; index < fields.length; index++) ...[
                  Expanded(child: fields[index]),
                  if (index < fields.length - 1) const SizedBox(width: 12),
                ],
              ],
            ),
          if (constraints.maxWidth >= 620) const SizedBox(height: 10),
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
    },
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
