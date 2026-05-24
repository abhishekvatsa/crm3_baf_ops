import 'package:flutter/material.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../directives/data/operational_directive_model.dart';
import '../../../directives/providers/operational_directive_provider.dart';
import '../../../maintenance/data/maintenance_model.dart';
import '../../../maintenance/utils/asset_validator.dart';
import '../../utils/admin_ticket_helpers.dart';

class AdminEditDirectiveDialog extends StatefulWidget {
  final OperationalDirective directive;

  const AdminEditDirectiveDialog({super.key, required this.directive});

  @override
  State<AdminEditDirectiveDialog> createState() =>
      _AdminEditDirectiveDialogState();
}

class _AdminEditDirectiveDialogState extends State<AdminEditDirectiveDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _remarksController;
  late final TextEditingController _assetNumberController;
  late final TextEditingController _componentController;
  late final TextEditingController _subsystemController;
  late final TextEditingController _tagController;

  late AppRole _selectedRole;
  AssetType? _selectedAssetType;

  @override
  void initState() {
    super.initState();
    final directive = widget.directive;
    _titleController = TextEditingController(text: directive.title);
    _descriptionController = TextEditingController(text: directive.description);
    _remarksController = TextEditingController(text: directive.remarks ?? '');
    _assetNumberController = TextEditingController(
      text: directive.assetNumber?.toString() ?? '',
    );
    _componentController = TextEditingController(
      text: directive.component ?? '',
    );
    _subsystemController = TextEditingController(
      text: directive.subsystem ?? '',
    );
    _tagController = TextEditingController(text: directive.tag ?? '');
    _selectedRole = directive.directedTo;
    _selectedAssetType = directive.assetType;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _remarksController.dispose();
    _assetNumberController.dispose();
    _componentController.dispose();
    _subsystemController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Directive'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator:
                      (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Required'
                              : null,
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                  validator:
                      (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Required'
                              : null,
                ),
                const SizedBox(height: BafSpacing.sm),
                DropdownButtonFormField<AppRole>(
                  initialValue: _selectedRole,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Directed To'),
                  items:
                      AppRole.values.map((role) {
                        return DropdownMenuItem<AppRole>(
                          value: role,
                          child: Text(role.name),
                        );
                      }).toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _selectedRole = value);
                  },
                ),
                const SizedBox(height: BafSpacing.sm),
                DropdownButtonFormField<AssetType?>(
                  initialValue: _selectedAssetType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Asset Type'),
                  items: [
                    const DropdownMenuItem<AssetType?>(
                      value: null,
                      child: Text('None'),
                    ),
                    ...AssetType.values.map(
                      (type) => DropdownMenuItem<AssetType?>(
                        value: type,
                        child: Text(type.name.toUpperCase()),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedAssetType = value;
                      if (value == null) {
                        _assetNumberController.clear();
                      }
                    });
                  },
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _assetNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Asset Number (required if type selected)',
                  ),
                  keyboardType: TextInputType.number,
                  enabled: _selectedAssetType != null,
                  validator: (value) {
                    if (_selectedAssetType == null) {
                      return null;
                    }
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) {
                      return 'Asset number is required when type is selected';
                    }
                    final number = int.tryParse(text);
                    if (number == null) {
                      return 'Invalid number';
                    }
                    if (!AssetValidator.isValid(_selectedAssetType!, number)) {
                      return AssetValidator.getValidationMessage(
                        _selectedAssetType!,
                        number,
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _componentController,
                  decoration: const InputDecoration(
                    labelText: 'Component (optional)',
                  ),
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _subsystemController,
                  decoration: const InputDecoration(
                    labelText: 'Subsystem (optional)',
                  ),
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _tagController,
                  decoration: const InputDecoration(
                    labelText: 'Instrument Tag (optional)',
                  ),
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _remarksController,
                  decoration: const InputDecoration(labelText: 'Remarks'),
                  maxLines: 2,
                  textInputAction: TextInputAction.newline,
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
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) {
              return;
            }
            final updated =
                copyOperationalDirective(widget.directive)
                  ..title = _titleController.text.trim()
                  ..description = _descriptionController.text.trim()
                  ..directedTo = _selectedRole
                  ..assetType = _selectedAssetType
                  ..assetNumber =
                      _selectedAssetType == null
                          ? null
                          : int.parse(_assetNumberController.text.trim())
                  ..component = cleanAdminOptionalText(
                    _componentController.text,
                  )
                  ..subsystem = cleanAdminOptionalText(
                    _subsystemController.text,
                  )
                  ..tag = cleanAdminTagText(_tagController.text)
                  ..remarks = cleanAdminOptionalText(_remarksController.text);
            Navigator.pop(context, updated);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
