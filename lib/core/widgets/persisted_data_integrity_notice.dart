import 'package:flutter/material.dart';

import '../theme/baf_design_system.dart';

class PersistedDataIntegrityNotice extends StatelessWidget {
  final String title;
  final String message;

  const PersistedDataIntegrityNotice({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$title. $message',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(BafSpacing.md),
        decoration: BoxDecoration(
          color: BafColors.danger.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(BafRadius.small),
          border: const Border(
            left: BorderSide(color: BafColors.danger, width: 4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: BafColors.danger,
              size: 22,
            ),
            const SizedBox(width: BafSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: BafColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: const TextStyle(
                      color: BafColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
