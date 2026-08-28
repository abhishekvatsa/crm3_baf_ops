import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance_workflow/services/workflow_command_factory.dart';
import '../domain/critical_alarm_models.dart';
import '../providers/critical_alarm_providers.dart';
import 'critical_alarm_feed_state.dart';

class CriticalAlarmContactsPanel extends ConsumerWidget {
  const CriticalAlarmContactsPanel({
    super.key,
    this.administrationMode = false,
    this.alarmTypeKey,
  });

  final bool administrationMode;
  final String? alarmTypeKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAppUserProvider).asData?.value;
    final contacts = ref.watch(criticalAlarmContactsProvider);
    final definitionFeed = ref.watch(criticalAlarmDefinitionsProvider);
    final definitions =
        definitionFeed.asData?.value ?? const <CriticalAlarmDefinition>[];
    final definitionNames = {
      for (final definition in definitions) definition.key: definition.name,
    };
    final canManage = user?.isAdmin == true && definitionFeed.hasValue;
    return contacts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, _) => CriticalAlarmFeedState(
            icon: Icons.cloud_off_outlined,
            title: 'Approved contacts unavailable',
            message:
                'The live server contact directory could not be verified. Follow the plant emergency procedure.',
            action: OutlinedButton.icon(
              onPressed: () => ref.invalidate(criticalAlarmContactsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry live check'),
            ),
          ),
      data: (allContacts) {
        final filtered =
            allContacts.where((contact) {
                if (alarmTypeKey != null &&
                    !contact.alarmTypeKeys.contains(alarmTypeKey)) {
                  return false;
                }
                return administrationMode || contact.isActive;
              }).toList()
              ..sort((left, right) {
                if (left.isActive != right.isActive) {
                  return left.isActive ? -1 : 1;
                }
                return left.priority.compareTo(right.priority);
              });
        if (filtered.isEmpty) {
          return CriticalAlarmFeedState(
            icon: Icons.phone_disabled_outlined,
            title: 'No approved contact configured',
            message:
                'Follow the plant emergency procedure. CRM3 will not substitute a contact from another alarm type.',
            action:
                canManage
                    ? FilledButton.icon(
                      onPressed:
                          () => showCriticalAlarmContactEditor(
                            context,
                            ref,
                            definitions: definitions,
                          ),
                      icon: const Icon(Icons.add_call),
                      label: const Text('Add contact'),
                    )
                    : null,
          );
        }
        return SafeArea(
          top: false,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              BafSpacing.md,
              BafSpacing.md,
              BafSpacing.md,
              BafSpacing.xl,
            ),
            itemCount: filtered.length + (canManage ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: BafSpacing.sm),
            itemBuilder: (context, index) {
              if (canManage && index == 0) {
                return SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        () => showCriticalAlarmContactEditor(
                          context,
                          ref,
                          definitions: definitions,
                        ),
                    icon: const Icon(Icons.add_call),
                    label: const Text('Add approved contact'),
                  ),
                );
              }
              final contact = filtered[index - (canManage ? 1 : 0)];
              return _ContactCard(
                contact: contact,
                definitionNames: definitionNames,
                canManage: canManage,
                onEdit:
                    () => showCriticalAlarmContactEditor(
                      context,
                      ref,
                      contact: contact,
                      definitions: definitions,
                    ),
                onStatus: () => _changeStatus(context, ref, contact),
                onDial: () => _dial(context, ref, contact),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _dial(
    BuildContext context,
    WidgetRef ref,
    CriticalAlarmContact contact,
  ) async {
    try {
      await ref
          .read(criticalAlarmPlatformServiceProvider)
          .openDialer(contact.dialValue);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open the device dialler: $error'),
          backgroundColor: BafColors.danger,
        ),
      );
    }
  }

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    CriticalAlarmContact contact,
  ) async {
    final target =
        contact.isActive
            ? CriticalAlarmContactStatus.retired
            : CriticalAlarmContactStatus.active;
    final reason = await showDialog<String>(
      context: context,
      builder:
          (_) => _ContactStatusReasonDialog(contact: contact, target: target),
    );
    if (reason == null || !context.mounted) return;
    try {
      await ref
          .read(criticalAlarmCommandServiceProvider)
          .setContactStatus(contact: contact, status: target, reason: reason);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: BafColors.danger),
      );
    }
  }
}

class _ContactStatusReasonDialog extends StatefulWidget {
  const _ContactStatusReasonDialog({
    required this.contact,
    required this.target,
  });

  final CriticalAlarmContact contact;
  final CriticalAlarmContactStatus target;

  @override
  State<_ContactStatusReasonDialog> createState() =>
      _ContactStatusReasonDialogState();
}

class _ContactStatusReasonDialogState
    extends State<_ContactStatusReasonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      '${widget.target == CriticalAlarmContactStatus.retired ? 'Retire' : 'Restore'} ${widget.contact.label}?',
    ),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _reason,
        minLines: 2,
        maxLines: 4,
        maxLength: 500,
        decoration: const InputDecoration(
          labelText: 'Audit reason',
          counterText: '',
          border: OutlineInputBorder(),
        ),
        validator:
            (value) => _bounded(
              value,
              minimum: 5,
              maximum: 500,
              missingMessage: 'Enter an audit reason',
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
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(context, _reason.text.trim());
        },
        child: const Text('Confirm'),
      ),
    ],
  );
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.definitionNames,
    required this.canManage,
    required this.onEdit,
    required this.onStatus,
    required this.onDial,
  });

  final CriticalAlarmContact contact;
  final Map<String, String> definitionNames;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onStatus;
  final VoidCallback onDial;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(BafSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: BafColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(BafRadius.small),
                ),
                child: const Icon(Icons.phone_in_talk, color: BafColors.danger),
              ),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${contact.dialValue} - ${_kindLabel(contact.kind)}',
                      style: const TextStyle(color: BafColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (!contact.isActive)
                const Chip(label: Text('Retired'))
              else
                IconButton(
                  tooltip: 'Open device dialler',
                  onPressed: onDial,
                  icon: const Icon(Icons.call_outlined),
                ),
              if (canManage)
                PopupMenuButton<String>(
                  tooltip: 'Contact actions',
                  onSelected:
                      (value) => value == 'edit' ? onEdit() : onStatus(),
                  itemBuilder:
                      (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(
                          value: 'status',
                          child: Text(contact.isActive ? 'Retire' : 'Restore'),
                        ),
                      ],
                ),
            ],
          ),
          const SizedBox(height: BafSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children:
                contact.alarmTypeKeys
                    .map(
                      (key) => Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          definitionNames[key] ??
                              CriticalAlarmDefinition.byKey[key]?.name ??
                              key,
                        ),
                      ),
                    )
                    .toList(),
          ),
          if (contact.notes != null) ...[
            const SizedBox(height: BafSpacing.sm),
            Text(contact.notes!),
          ],
        ],
      ),
    ),
  );
}

Future<void> showCriticalAlarmContactEditor(
  BuildContext context,
  WidgetRef ref, {
  CriticalAlarmContact? contact,
  required List<CriticalAlarmDefinition> definitions,
}) async {
  final draft = await showDialog<_ContactDraft>(
    context: context,
    builder: (_) => _ContactEditor(contact: contact, definitions: definitions),
  );
  if (draft == null || !context.mounted) return;
  try {
    await ref
        .read(criticalAlarmCommandServiceProvider)
        .upsertContact(
          contactId:
              contact?.id ??
              WorkflowCommandFactory.uniqueId('critical_contact'),
          expectedVersion: contact?.version ?? 0,
          label: draft.label,
          kind: draft.kind,
          dialValue: draft.dialValue,
          alarmTypeKeys: draft.alarmTypeKeys,
          priority: draft.priority,
          notes: draft.notes,
          reason: draft.reason,
        );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$error'), backgroundColor: BafColors.danger),
    );
  }
}

class _ContactEditor extends StatefulWidget {
  const _ContactEditor({this.contact, required this.definitions});

  final CriticalAlarmContact? contact;
  final List<CriticalAlarmDefinition> definitions;

  @override
  State<_ContactEditor> createState() => _ContactEditorState();
}

class _ContactEditorState extends State<_ContactEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _dial;
  late final TextEditingController _priority;
  late final TextEditingController _notes;
  late final TextEditingController _reason;
  late CriticalAlarmContactKind _kind;
  late Set<String> _alarmTypes;

  @override
  void initState() {
    super.initState();
    final contact = widget.contact;
    _label = TextEditingController(text: contact?.label);
    _dial = TextEditingController(text: contact?.dialValue);
    _priority = TextEditingController(text: '${contact?.priority ?? 10}');
    _notes = TextEditingController(text: contact?.notes);
    _reason = TextEditingController();
    _kind = contact?.kind ?? CriticalAlarmContactKind.mobile;
    final activeKeys =
        widget.definitions
            .where((definition) => definition.isActive)
            .map((definition) => definition.key)
            .toSet();
    _alarmTypes =
        contact?.alarmTypeKeys.where(activeKeys.contains).toSet() ?? <String>{};
  }

  @override
  void dispose() {
    _label.dispose();
    _dial.dispose();
    _priority.dispose();
    _notes.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.contact == null ? 'Add approved contact' : 'Edit approved contact',
    ),
    content: SizedBox(
      width: 560,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _label,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Contact label',
                  counterText: '',
                ),
                validator:
                    (value) => _bounded(
                      value,
                      minimum: 2,
                      maximum: 120,
                      missingMessage: 'Enter a contact label',
                    ),
              ),
              const SizedBox(height: BafSpacing.sm),
              DropdownButtonFormField<CriticalAlarmContactKind>(
                initialValue: _kind,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Contact type'),
                items:
                    CriticalAlarmContactKind.values
                        .map(
                          (kind) => DropdownMenuItem(
                            value: kind,
                            child: Text(_kindLabel(kind)),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _kind = value ?? _kind),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextFormField(
                controller: _dial,
                keyboardType: TextInputType.phone,
                maxLength: 16,
                decoration: const InputDecoration(
                  labelText: 'Dial number or plant extension',
                  counterText: '',
                ),
                validator: (value) => _dialError(value, _kind),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextFormField(
                controller: _priority,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Priority (1-99)'),
                validator: (value) {
                  final parsed = int.tryParse(value ?? '');
                  return parsed == null || parsed < 1 || parsed > 99
                      ? 'Enter a priority from 1 to 99'
                      : null;
                },
              ),
              const SizedBox(height: BafSpacing.md),
              const Text(
                'Exact alarm types',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              ...widget.definitions
                  .where((definition) => definition.isActive)
                  .map(
                    (definition) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _alarmTypes.contains(definition.key),
                      title: Text(definition.name),
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _alarmTypes.add(definition.key);
                          } else {
                            _alarmTypes.remove(definition.key);
                          }
                        });
                      },
                    ),
                  ),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  counterText: '',
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextFormField(
                controller: _reason,
                maxLines: 2,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Audit reason',
                  counterText: '',
                ),
                validator:
                    (value) => _bounded(
                      value,
                      minimum: 5,
                      maximum: 500,
                      missingMessage: 'Enter an audit reason',
                    ),
              ),
              if (_alarmTypes.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Select at least one exact alarm type.',
                    style: TextStyle(color: BafColors.danger),
                  ),
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
          if (!_formKey.currentState!.validate() || _alarmTypes.isEmpty) {
            setState(() {});
            return;
          }
          Navigator.pop(
            context,
            _ContactDraft(
              label: _label.text.trim(),
              kind: _kind,
              dialValue: _dial.text.trim(),
              alarmTypeKeys: _alarmTypes.toList(),
              priority: int.parse(_priority.text),
              notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
              reason: _reason.text.trim(),
            ),
          );
        },
        child: const Text('Save contact'),
      ),
    ],
  );
}

class _ContactDraft {
  const _ContactDraft({
    required this.label,
    required this.kind,
    required this.dialValue,
    required this.alarmTypeKeys,
    required this.priority,
    required this.notes,
    required this.reason,
  });

  final String label;
  final CriticalAlarmContactKind kind;
  final String dialValue;
  final List<String> alarmTypeKeys;
  final int priority;
  final String? notes;
  final String reason;
}

String? _bounded(
  String? value, {
  required int minimum,
  required int maximum,
  required String missingMessage,
}) {
  final length = value?.trim().length ?? 0;
  if (length < minimum) return missingMessage;
  if (length > maximum) return 'Keep this within $maximum characters';
  return null;
}

String? _dialError(String? value, CriticalAlarmContactKind kind) {
  final dialValue = value?.trim() ?? '';
  final valid = switch (kind) {
    CriticalAlarmContactKind.plantExtension => RegExp(
      r'^\d{2,8}$',
    ).hasMatch(dialValue),
    CriticalAlarmContactKind.mobile || CriticalAlarmContactKind.landline =>
      RegExp(r'^\+?\d{5,15}$').hasMatch(dialValue),
  };
  return valid
      ? null
      : kind == CriticalAlarmContactKind.plantExtension
      ? 'Enter a 2-8 digit plant extension'
      : 'Enter 5-15 digits, optionally beginning with +';
}

String _kindLabel(CriticalAlarmContactKind kind) => switch (kind) {
  CriticalAlarmContactKind.mobile => 'Mobile',
  CriticalAlarmContactKind.landline => 'Landline',
  CriticalAlarmContactKind.plantExtension => 'Plant extension',
};
