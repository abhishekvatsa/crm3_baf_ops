import 'package:flutter/material.dart';
import '../domain/morning_review_models.dart';
import 'morning_review_editors.dart';

Future<Map<String, String>?> showMorningReviewActionCorrectionEditor(
  BuildContext context, {
  required MorningReviewAction action,
  required Widget Function(Widget) guard,
}) => showDialog<Map<String, String>>(
  context: context,
  builder: (_) => guard(_CorrectionEditor(action: action)),
);

class _CorrectionEditor extends StatefulWidget {
  const _CorrectionEditor({required this.action});
  final MorningReviewAction action;
  @override
  State<_CorrectionEditor> createState() => _CorrectionEditorState();
}

class _CorrectionEditorState extends State<_CorrectionEditor> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  String? _kind;
  String? _role;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final terminal = widget.action.isTerminal;
    return AlertDialog(
      title: const Text('Correct action'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.action.text),
                const SizedBox(height: 12),
                const Text(
                  'The previous state, your reason and your identity will remain in the correction history. Frozen meeting minutes remain unchanged.',
                ),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Correction'),
                  items: [
                    for (final kind
                        in terminal ? ['reopen'] : ['cancel', 'reassign'])
                      DropdownMenuItem(
                        value: kind,
                        child: Text(
                          {
                            'cancel': 'Cancel action',
                            'reassign': 'Reassign to role',
                            'reopen': 'Reopen action',
                          }[kind]!,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _kind = value),
                  validator: (value) =>
                      value == null ? 'Choose a correction' : null,
                ),
                if (_kind == 'reassign')
                  DropdownButtonFormField<String>(
                  isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'New responsible role',
                    ),
                    items: [
                      for (final role in const [
                        'admin',
                        'si',
                        'contractSupervisor',
                        'shiftSupervisor',
                        'seniorElectrical',
                        'seniorMechanical',
                        'seniorInstrumentation',
                        'seniorRefractory',
                        'refractory',
                        'operations',
                      ])
                        DropdownMenuItem(
                          value: role,
                          child: Text(morningReviewRoleLabel(role)),
                        ),
                    ],
                    onChanged: (value) => _role = value,
                    validator: (value) =>
                        value == null ? 'Choose the responsible role' : null,
                  ),
                TextFormField(
                  controller: _reason,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 1600,
                  decoration: const InputDecoration(
                    labelText: 'Reason for correction',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'A reason is required'
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back'),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(context, {
                'kind': _kind!,
                'reason': _reason.text.trim(),
                if (_kind == 'reassign') 'assigneeRole': _role!,
              });
            }
          },
          child: const Text('Save correction'),
        ),
      ],
    );
  }
}
