import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../domain/critical_alarm_models.dart';
import '../providers/critical_alarm_providers.dart';
import 'critical_alarm_feed_state.dart';

class CriticalAlarmDefinitionsPanel extends ConsumerWidget {
  const CriticalAlarmDefinitionsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAppUserProvider).asData?.value;
    if (user?.isAdmin != true) {
      return const CriticalAlarmFeedState(
        icon: Icons.lock_outline,
        title: 'Admin access required',
        message: 'Only Admin may change the governed alarm-reason catalogue.',
      );
    }
    final definitions = ref.watch(criticalAlarmDefinitionsProvider);
    return definitions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, _) => CriticalAlarmFeedState(
            icon: Icons.cloud_off_outlined,
            title: 'Alarm reasons unavailable',
            message:
                'The live governed catalogue could not be verified. No catalogue change is available.',
            action: OutlinedButton.icon(
              onPressed: () => ref.invalidate(criticalAlarmDefinitionsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry live check'),
            ),
          ),
      data:
          (rows) => SafeArea(
            top: false,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                BafSpacing.md,
                BafSpacing.md,
                BafSpacing.md,
                BafSpacing.xl,
              ),
              itemCount: rows.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: BafSpacing.sm),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          () => showCriticalAlarmDefinitionEditor(context, ref),
                      icon: const Icon(Icons.add_alert_outlined),
                      label: const Text('Add alarm reason'),
                    ),
                  );
                }
                final definition = rows[index - 1];
                return _DefinitionCard(
                  definition: definition,
                  onEdit:
                      () => showCriticalAlarmDefinitionEditor(
                        context,
                        ref,
                        definition: definition,
                      ),
                  onStatus:
                      () => _changeDefinitionStatus(context, ref, definition),
                );
              },
            ),
          ),
    );
  }

  Future<void> _changeDefinitionStatus(
    BuildContext context,
    WidgetRef ref,
    CriticalAlarmDefinition definition,
  ) async {
    final target =
        definition.isActive
            ? CriticalAlarmDefinitionStatus.retired
            : CriticalAlarmDefinitionStatus.active;
    final reason = await showDialog<String>(
      context: context,
      builder:
          (_) =>
              _DefinitionStatusDialog(definition: definition, target: target),
    );
    if (reason == null || !context.mounted) return;
    try {
      await ref
          .read(criticalAlarmCommandServiceProvider)
          .setDefinitionStatus(
            definition: definition,
            status: target,
            reason: reason,
          );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: BafColors.danger),
      );
    }
  }
}

class _DefinitionCard extends StatelessWidget {
  const _DefinitionCard({
    required this.definition,
    required this.onEdit,
    required this.onStatus,
  });

  final CriticalAlarmDefinition definition;
  final VoidCallback onEdit;
  final VoidCallback onStatus;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(BafSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: BafColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(BafRadius.small),
            ),
            child: const Icon(
              Icons.notification_important_outlined,
              color: BafColors.danger,
            ),
          ),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  definition.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(definition.criticalityLabel),
                    ),
                    if (definition.isBootstrapDefault)
                      const Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('Built-in default'),
                      ),
                    if (!definition.isActive)
                      const Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('Retired'),
                      ),
                  ],
                ),
                if (definition.updatedByName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Last changed by ${definition.updatedByName}',
                    style: const TextStyle(color: BafColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Alarm reason actions',
            onSelected: (value) => value == 'edit' ? onEdit() : onStatus(),
            itemBuilder:
                (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'status',
                    child: Text(definition.isActive ? 'Retire' : 'Restore'),
                  ),
                ],
          ),
        ],
      ),
    ),
  );
}

Future<void> showCriticalAlarmDefinitionEditor(
  BuildContext context,
  WidgetRef ref, {
  CriticalAlarmDefinition? definition,
}) async {
  final draft = await showDialog<_DefinitionDraft>(
    context: context,
    builder: (_) => _DefinitionEditor(definition: definition),
  );
  if (draft == null || !context.mounted) return;
  try {
    await ref
        .read(criticalAlarmCommandServiceProvider)
        .upsertDefinition(
          definition: definition,
          name: draft.name,
          criticalityKey: draft.criticalityKey,
          criticalityRank: draft.criticalityRank,
          reason: draft.reason,
        );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$error'), backgroundColor: BafColors.danger),
    );
  }
}

class _DefinitionEditor extends StatefulWidget {
  const _DefinitionEditor({this.definition});

  final CriticalAlarmDefinition? definition;

  @override
  State<_DefinitionEditor> createState() => _DefinitionEditorState();
}

class _DefinitionEditorState extends State<_DefinitionEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  final _reason = TextEditingController();
  late String _criticalityKey;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.definition?.name);
    _criticalityKey = widget.definition?.criticalityKey ?? 'critical';
  }

  @override
  void dispose() {
    _name.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.definition == null ? 'Add alarm reason' : 'Edit alarm reason',
    ),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _name,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Alarm reason',
                  counterText: '',
                ),
                validator: (value) {
                  final length = value?.trim().length ?? 0;
                  if (length == 0) return 'Enter the alarm reason';
                  return length > 120
                      ? 'Keep this within 120 characters'
                      : null;
                },
              ),
              const SizedBox(height: BafSpacing.md),
              const Text(
                'Criticality grade',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: BafSpacing.xs),
              BafHorizontalControlRail(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'highest',
                      icon: Icon(Icons.local_fire_department_outlined),
                      label: Text('Highest'),
                    ),
                    ButtonSegment(
                      value: 'critical',
                      icon: Icon(Icons.warning_amber_outlined),
                      label: Text('Critical'),
                    ),
                  ],
                  selected: {_criticalityKey},
                  onSelectionChanged:
                      (selection) =>
                          setState(() => _criticalityKey = selection.single),
                ),
              ),
              const SizedBox(height: BafSpacing.md),
              TextFormField(
                controller: _reason,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Audit reason',
                  counterText: '',
                ),
                validator: (value) {
                  final length = value?.trim().length ?? 0;
                  if (length == 0) return 'Enter an audit reason';
                  return length > 500
                      ? 'Keep this within 500 characters'
                      : null;
                },
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
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            _DefinitionDraft(
              name: _name.text.trim(),
              criticalityKey: _criticalityKey,
              criticalityRank: _criticalityKey == 'highest' ? 1 : 2,
              reason: _reason.text.trim(),
            ),
          );
        },
        child: const Text('Save reason'),
      ),
    ],
  );
}

class _DefinitionStatusDialog extends StatefulWidget {
  const _DefinitionStatusDialog({
    required this.definition,
    required this.target,
  });

  final CriticalAlarmDefinition definition;
  final CriticalAlarmDefinitionStatus target;

  @override
  State<_DefinitionStatusDialog> createState() =>
      _DefinitionStatusDialogState();
}

class _DefinitionStatusDialogState extends State<_DefinitionStatusDialog> {
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
      '${widget.target == CriticalAlarmDefinitionStatus.retired ? 'Retire' : 'Restore'} ${widget.definition.name}?',
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
        ),
        validator:
            (value) =>
                (value?.trim().isEmpty ?? true)
                    ? 'Enter an audit reason'
                    : null,
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

class _DefinitionDraft {
  const _DefinitionDraft({
    required this.name,
    required this.criticalityKey,
    required this.criticalityRank,
    required this.reason,
  });

  final String name;
  final String criticalityKey;
  final int criticalityRank;
  final String reason;
}
