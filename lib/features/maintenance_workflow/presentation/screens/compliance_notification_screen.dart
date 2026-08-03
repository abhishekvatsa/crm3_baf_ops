import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../providers/workflow_providers.dart';
import 'compliance_detail_screen.dart';
import 'compliance_inbox_screen.dart';

/// Resolves a notification's exact compliance record from the local
/// projection, refreshing once from the governed pull path when necessary.
class ComplianceNotificationScreen extends ConsumerWidget {
  final String complianceId;
  final String? laneKey;

  const ComplianceNotificationScreen({
    super.key,
    required this.complianceId,
    this.laneKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordAsync = ref.watch(
      workflowComplianceRecordProvider(complianceId),
    );

    return recordAsync.when(
      loading:
          () => const Scaffold(
            backgroundColor: BafColors.background,
            appBar: _ComplianceNotificationAppBar(),
            body: Center(child: CircularProgressIndicator()),
          ),
      error:
          (error, _) => _ComplianceNotificationFallback(
            title: 'Compliance update unavailable',
            message:
                'The exact obligation could not be refreshed. You can retry or open your compliance inbox.',
            laneKey: laneKey,
            onRetry:
                () => ref.invalidate(
                  workflowComplianceRecordProvider(complianceId),
                ),
          ),
      data:
          (record) =>
              record == null
                  ? _ComplianceNotificationFallback(
                    title: 'Compliance update not found',
                    message:
                        'The obligation is not present in the current projection. It may have been superseded or removed.',
                    laneKey: laneKey,
                    onRetry:
                        () => ref.invalidate(
                          workflowComplianceRecordProvider(complianceId),
                        ),
                  )
                  : ComplianceDetailScreen(record: record),
    );
  }
}

class _ComplianceNotificationAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _ComplianceNotificationAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(title: const Text('Compliance update'));
  }
}

class _ComplianceNotificationFallback extends StatelessWidget {
  final String title;
  final String message;
  final String? laneKey;
  final VoidCallback onRetry;

  const _ComplianceNotificationFallback({
    required this.title,
    required this.message,
    required this.laneKey,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: const _ComplianceNotificationAppBar(),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(BafSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.assignment_late_outlined,
                  size: 46,
                  color: BafColors.warning,
                ),
                const SizedBox(height: BafSpacing.md),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: BafSpacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: BafSpacing.lg),
                Wrap(
                  spacing: BafSpacing.sm,
                  runSpacing: BafSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                    FilledButton.icon(
                      onPressed:
                          () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) =>
                                      ComplianceInboxScreen(laneKey: laneKey),
                            ),
                          ),
                      icon: const Icon(Icons.inbox_outlined),
                      label: const Text('Open inbox'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
