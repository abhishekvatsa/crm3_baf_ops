import 'package:flutter/material.dart';

class WorkflowActionGuard extends StatelessWidget {
  final bool busy;
  final bool enabled;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const WorkflowActionGuard({
    super.key,
    required this.busy,
    required this.enabled,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: busy || !enabled ? null : onPressed,
      icon: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(busy ? 'Working online…' : label),
    );
  }
}
