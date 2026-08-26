import 'package:flutter/material.dart';

import '../../../core/theme/baf_design_system.dart';

class CriticalAlarmFeedState extends StatelessWidget {
  const CriticalAlarmFeedState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(BafSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: BafColors.danger),
          const SizedBox(height: BafSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: BafColors.textSecondary),
          ),
          if (action != null) ...[
            const SizedBox(height: BafSpacing.md),
            action!,
          ],
        ],
      ),
    ),
  );
}
