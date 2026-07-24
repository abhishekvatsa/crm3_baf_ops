import 'package:flutter/material.dart';

class RedExitAnswers {
  final bool redRequired;
  final bool? preparationRequired;
  const RedExitAnswers({required this.redRequired, required this.preparationRequired});
}

Future<RedExitAnswers?> showRedExitDialog(
  BuildContext context, {
  required bool askPreparation,
}) async {
  bool? redRequired;
  bool? preparationRequired;
  return showDialog<RedExitAnswers>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Final maintenance check'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              value: redRequired ?? false,
              title: const Text('Is RED work required?'),
              onChanged: (value) => setState(() {
                redRequired = value;
                if (!value) preparationRequired = null;
              }),
            ),
            if (askPreparation && redRequired == true)
              SwitchListTile(
                value: preparationRequired ?? false,
                title: const Text('Does the furnace need to be placed on stand?'),
                onChanged: (value) => setState(() => preparationRequired = value),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: redRequired == null || (askPreparation && redRequired == true && preparationRequired == null)
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
    ),
  );
}
