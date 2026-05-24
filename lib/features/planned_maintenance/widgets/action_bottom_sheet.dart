// FILE: lib/features/planned_maintenance/widgets/action_bottom_sheet.dart

import 'package:flutter/material.dart';

import '../domain/baf_tag_resolver_v2.dart';
import '../models/component_action_model.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/dashboard/status_badge.dart';

class ActionBottomSheet extends StatefulWidget {
  const ActionBottomSheet({super.key});

  @override
  State<ActionBottomSheet> createState() => _ActionBottomSheetState();
}

class _ActionBottomSheetState extends State<ActionBottomSheet> {
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _componentController = TextEditingController();
  final TextEditingController _issueController = TextEditingController();

  String? asset;
  String? system;
  String? subsystem;
  List<String>? path;

  bool _isAutoResolved = false;

  ActionType _actionType = ActionType.issue;
  ActionStatus _status = ActionStatus.issue;

  @override
  void dispose() {
    _tagController.dispose();
    _componentController.dispose();
    _issueController.dispose();
    super.dispose();
  }

  void _resolveTag(String rawTag) {
    final tag = rawTag.trim();

    if (tag.isEmpty) {
      _clearAutoFields();
      return;
    }

    final result = BafTagResolverV2.resolveToMap(tag);
    final isResolved = result['isAutoResolved'] == true;

    if (!isResolved) {
      _clearAutoFields();
      return;
    }

    setState(() {
      asset = result['asset'] as String?;
      system = result['system'] as String?;
      subsystem = result['subsystem'] as String?;

      final rawPath = result['hierarchyPath'];
      path = rawPath is List ? List<String>.from(rawPath) : null;

      if (_componentController.text.trim().isEmpty) {
        _componentController.text = (result['component'] as String?) ?? '';
      }

      _isAutoResolved = true;
    });
  }

  void _clearAutoFields() {
    setState(() {
      asset = null;
      system = null;
      subsystem = null;
      path = null;
      _isAutoResolved = false;
    });
  }

  bool _canSave() {
    return _componentController.text.trim().isNotEmpty && asset != null;
  }

  void _save() {
    final component = _componentController.text.trim();
    final tag = _tagController.text.trim();

    if (asset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid tag to resolve asset'),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }

    if (component.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Component is required'),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }

    final action = ComponentAction(
      component: component,
      asset: asset!,
      tag: tag.isEmpty ? null : tag,
      system: system,
      subsystem: subsystem,
      hierarchyPath: path,
      actionType: _actionType,
      status: _status,
      issue: _issueController.text.trim(),
      isAutoResolved: _isAutoResolved,
      createdAt: DateTime.now(),
    );

    Navigator.pop(context, action);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: BafColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: BafColors.planned.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.add_task_rounded,
                      color: BafColors.planned,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add action / observation',
                          style: TextStyle(
                            color: BafColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Record what was found or done during the job.',
                          style: TextStyle(
                            color: BafColors.textSecondary,
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _tagController,
                decoration: _inputDecoration(
                  'Instrument tag',
                  hint: 'Example: FIT45',
                  icon: Icons.sell_rounded,
                ),
                textCapitalization: TextCapitalization.characters,
                onChanged: _resolveTag,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _componentController,
                decoration: _inputDecoration(
                  'Component',
                  icon: Icons.memory_rounded,
                ),
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ActionType>(
                initialValue: _actionType,
                isExpanded: true,
                decoration: _inputDecoration(
                  'Action type',
                  icon: Icons.handyman_rounded,
                ),
                items:
                    ActionType.values.map((type) {
                      return DropdownMenuItem<ActionType>(
                        value: type,
                        child: Text(
                          _actionTypeLabel(type),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _actionType = val);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ActionStatus>(
                initialValue: _status,
                isExpanded: true,
                decoration: _inputDecoration(
                  'Status',
                  icon: Icons.flag_rounded,
                ),
                items:
                    ActionStatus.values.map((status) {
                      return DropdownMenuItem<ActionStatus>(
                        value: status,
                        child: Text(
                          _statusLabel(status),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _status = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _issueController,
                maxLines: 3,
                decoration: _inputDecoration(
                  'Issue / observation',
                  hint: 'What did you notice or do?',
                  icon: Icons.notes_rounded,
                  alignLabelWithHint: true,
                ),
              ),
              if (_isAutoResolved) ...[
                const SizedBox(height: 14),
                _ResolvedTagPanel(
                  asset: asset,
                  system: system,
                  subsystem: subsystem,
                  path: path,
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BafColors.textPrimary,
                        side: const BorderSide(color: BafColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(BafRadius.medium),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _canSave() ? _save : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: BafColors.planned,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(BafRadius.medium),
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text(
                        'Save Action',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label, {
    String? hint,
    IconData? icon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        borderSide: const BorderSide(color: BafColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        borderSide: const BorderSide(color: BafColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        borderSide: const BorderSide(color: BafColors.planned, width: 1.5),
      ),
    );
  }

  String _actionTypeLabel(ActionType type) {
    switch (type) {
      case ActionType.issue:
        return 'Issue / observation';
      case ActionType.repair:
        return 'Repair';
      case ActionType.replacement:
        return 'Replacement';
      case ActionType.inspection:
        return 'Inspection';
    }
  }

  String _statusLabel(ActionStatus status) {
    switch (status) {
      case ActionStatus.issue:
        return 'Issue';
      case ActionStatus.inProgress:
        return 'In progress';
      case ActionStatus.resolved:
        return 'Resolved';
    }
  }
}

class _ResolvedTagPanel extends StatelessWidget {
  final String? asset;
  final String? system;
  final String? subsystem;
  final List<String>? path;

  const _ResolvedTagPanel({this.asset, this.system, this.subsystem, this.path});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BafColors.sync.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.sync.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StatusBadge(
            label: 'Tag resolved',
            color: BafColors.sync,
            icon: Icons.auto_awesome_rounded,
          ),
          const SizedBox(height: 8),
          if (asset != null && asset!.trim().isNotEmpty)
            _ResolvedLine(label: 'Asset', value: asset!),
          if (system != null && system!.trim().isNotEmpty)
            _ResolvedLine(label: 'System', value: system!),
          if (subsystem != null && subsystem!.trim().isNotEmpty)
            _ResolvedLine(label: 'Subsystem', value: subsystem!),
          if (path != null && path!.isNotEmpty)
            _ResolvedLine(label: 'Path', value: path!.join(' › ')),
        ],
      ),
    );
  }
}

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
