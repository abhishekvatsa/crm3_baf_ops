import 'package:flutter/material.dart';
import '../../domain/module_composer_models.dart';

class KnowledgePresetEditor extends StatelessWidget {
  const KnowledgePresetEditor({
    super.key,
    required this.presets,
    required this.onChanged,
  });
  final List<Map<String, dynamic>> presets;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Suggested response fields',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      for (var i = 0; i < presets.length; i++)
        ListTile(
          title: Text('${presets[i]['label']}'),
          subtitle: Text(
            '${presets[i]['type']} · ${presets[i]['isRequired'] == true ? 'required' : 'optional'}',
          ),
          onTap: () => edit(context, i),
          trailing: IconButton(
            tooltip: 'Remove suggested field',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => onChanged([...presets]..removeAt(i)),
          ),
        ),
      TextButton.icon(
        onPressed: () => edit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Add response field'),
      ),
    ],
  );

  Future<void> edit(BuildContext context, int? index) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PresetDialog(
        before: index == null ? const {} : presets[index],
        otherKeys: {
          for (var i = 0; i < presets.length; i++)
            if (i != index) '${presets[i]['key']}',
        },
      ),
    );
    if (result == null) return;
    final updated = [...presets];
    if (index == null) {
      updated.add(result);
    } else {
      updated[index] = result;
    }
    onChanged(updated);
  }
}

class _PresetDialog extends StatefulWidget {
  const _PresetDialog({required this.before, required this.otherKeys});
  final Map<String, dynamic> before;
  final Set<String> otherKeys;
  @override
  State<_PresetDialog> createState() => _PresetDialogState();
}

class _PresetDialogState extends State<_PresetDialog> {
  late final label = TextEditingController(
    text: widget.before['label'] as String? ?? '',
  );
  late final fieldKey = TextEditingController(
    text: widget.before['key'] as String? ?? '',
  );
  late final unit = TextEditingController(
    text: widget.before['unit'] as String? ?? '',
  );
  late final options = TextEditingController(
    text: (widget.before['options'] as List? ?? []).join('\n'),
  );
  late final source = TextEditingController(
    text: widget.before['sourceText'] as String? ?? '',
  );
  late String type = widget.before['type'] as String? ?? 'text';
  late bool requiredValue = widget.before['isRequired'] == true;
  late bool critical = widget.before['isSafetyCriticalPreset'] == true;
  late ComposerEvidenceRole role = KnowledgeFieldPreset.fromMap(
    widget.before,
    defaultRequired: false,
    defaultSafetyCritical: false,
  ).evidenceRole;
  String? error;
  @override
  void dispose() {
    for (final controller in [label, fieldKey, unit, options, source]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Suggested response field'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: label,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            TextField(
              controller: fieldKey,
              decoration: const InputDecoration(labelText: 'Stable field key'),
            ),
            DropdownButtonFormField<String>(
              initialValue: type,
              isExpanded: true,
              items: ComposerFieldType.values
                  .map(
                    (v) => DropdownMenuItem(value: v.name, child: Text(v.name)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => type = v);
              },
              decoration: const InputDecoration(labelText: 'Response type'),
            ),
            TextField(
              controller: unit,
              decoration: const InputDecoration(
                labelText: 'Unit (if applicable)',
              ),
            ),
            TextField(
              controller: options,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Choices, one per line',
              ),
            ),
            TextField(
              controller: source,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Source instruction',
              ),
            ),
            CheckboxListTile(
              title: const Text('Required response'),
              value: requiredValue,
              onChanged: (v) => setState(() => requiredValue = v!),
            ),
            CheckboxListTile(
              title: const Text('Safety-critical evidence'),
              value: critical,
              onChanged: (v) => setState(() => critical = v!),
            ),
            DropdownButtonFormField<ComposerEvidenceRole>(
              initialValue: role,
              isExpanded: true,
              items: ComposerEvidenceRole.values
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(composerEvidenceRoleLabel(v)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => role = v);
              },
              decoration: const InputDecoration(labelText: 'Evidence meaning'),
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: save, child: const Text('Use field')),
    ],
  );
  void save() {
    final key = fieldKey.text.trim().isEmpty
        ? suggestedComposerFieldKey(label: label.text)
        : fieldKey.text.trim();
    final choices = options.text
        .split('\n')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();
    if (label.text.trim().isEmpty ||
        widget.otherKeys.contains(key) ||
        (const ['dropdown', 'multiSelect'].contains(type) && choices.isEmpty)) {
      setState(
        () => error =
            'Enter a label and a unique key. Choice fields also need choices.',
      );
      return;
    }
    final meta = Map<String, dynamic>.from(widget.before['meta'] as Map? ?? {});
    meta.remove(kComposerEvidenceRoleMetaKey);
    if (role != ComposerEvidenceRole.none) {
      meta[kComposerEvidenceRoleMetaKey] = role.name;
    }
    Navigator.pop(context, <String, dynamic>{
      ...widget.before,
      'key': key,
      'label': label.text.trim(),
      'type': type,
      'isRequired': requiredValue,
      'isSafetyCriticalPreset': critical,
      'unit': unit.text.trim().isEmpty ? null : unit.text.trim(),
      'options': choices,
      'sourceText': source.text.trim().isEmpty
          ? label.text.trim()
          : source.text.trim(),
      'meta': meta,
      'evidenceRole': role.name,
    });
  }
}
