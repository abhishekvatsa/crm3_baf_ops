import 'package:flutter/material.dart';

class RedExitAnswers {
  final bool redRequired;
  final bool? preparationRequired;
  const RedExitAnswers({
    required this.redRequired,
    required this.preparationRequired,
  });
}

Future<RedExitAnswers?> showRedExitDialog(
  BuildContext context, {
  required bool askPreparation,
  Widget Function(Widget)? guard,
}) async {
  bool? redRequired;
  bool? preparationRequired;
  return showDialog<RedExitAnswers>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final dialog = StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Final maintenance check'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ExplicitDecision(
                keyPrefix: 'planned-red-required',
                value: redRequired,
                question: 'Is RED work required?',
                onChanged: (value) => setState(() {
                  redRequired = value;
                  if (!value) preparationRequired = null;
                }),
              ),
              if (askPreparation && redRequired == true)
                _ExplicitDecision(
                  keyPrefix: 'planned-red-preparation',
                  value: preparationRequired,
                  question: 'Does the furnace need to be placed on stand?',
                  onChanged: (value) =>
                      setState(() => preparationRequired = value),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed:
                  redRequired == null ||
                      (askPreparation &&
                          redRequired == true &&
                          preparationRequired == null)
                  ? null
                  : () => Navigator.pop(
                      context,
                      RedExitAnswers(
                        redRequired: redRequired!,
                        preparationRequired: preparationRequired,
                      ),
                    ),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      return guard?.call(dialog) ?? dialog;
    },
  );
}

class _ExplicitDecision extends StatelessWidget {
  const _ExplicitDecision({
    required this.keyPrefix,
    required this.question,
    required this.value,
    required this.onChanged,
  });
  final String keyPrefix;
  final String question;
  final bool? value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            ChoiceChip(
              key: ValueKey('$keyPrefix-yes'),
              label: const Text('Yes'),
              selected: value == true,
              onSelected: (_) => onChanged(true),
            ),
            ChoiceChip(
              key: ValueKey('$keyPrefix-no'),
              label: const Text('No'),
              selected: value == false,
              onSelected: (_) => onChanged(false),
            ),
          ],
        ),
      ],
    ),
  );
}
