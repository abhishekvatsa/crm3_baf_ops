import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../../core/widgets/baf_ui.dart';
import '../../../../core/widgets/brand/brand_widgets.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/compliance_visibility_policy.dart';
import '../../providers/workflow_providers.dart';
import 'compliance_detail_screen.dart';
import 'compliance_inbox_screen.dart';

/// Resolves a notification's exact compliance record under the current
/// approved actor session.
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
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading) {
      return BafScreenStateScaffold.loading(
        appBarTitle: 'Compliance update',
        appBarSubtitle: 'Verifying your approved compliance scope',
        appBarIcon: Icons.assignment_late_outlined,
        accent: BafColors.directives,
        label: 'Checking compliance access',
      );
    }
    if (actorAsync.hasError) {
      return BafScreenStateScaffold.error(
        appBarTitle: 'Compliance update',
        appBarSubtitle: 'Verifying your approved compliance scope',
        appBarIcon: Icons.assignment_late_outlined,
        accent: BafColors.directives,
        message: 'Compliance access could not be verified.',
      );
    }
    final actor = actorAsync.value;
    if (actor == null || !actor.isApproved) {
      return BafScreenStateScaffold.access(
        appBarTitle: 'Compliance update',
        appBarSubtitle: 'Operational obligation and response status',
        appBarIcon: Icons.assignment_late_outlined,
        accent: BafColors.directives,
        title: 'Compliance access required',
        message: 'An approved account is required to open compliance updates.',
      );
    }
    final recordScope = (actorUid: actor.uid, complianceId: complianceId);
    final recordAsync = ref.watch(
      workflowComplianceRecordProvider(recordScope),
    );

    return recordAsync.when(
      loading:
          () => const Scaffold(
            backgroundColor: BafColors.background,
            appBar: _ComplianceNotificationAppBar(),
            body: BafLoadingPanel(
              label: 'Loading compliance update',
              color: BafColors.directives,
            ),
          ),
      error:
          (error, _) => _ComplianceNotificationFallback(
            title: 'Compliance update unavailable',
            message:
                'The exact obligation could not be refreshed. You can retry or open your compliance inbox.',
            laneKey: laneKey,
            onRetry:
                () => ref.invalidate(
                  workflowComplianceRecordProvider(recordScope),
                ),
          ),
      data: (record) {
        if (record == null) {
          return _ComplianceNotificationFallback(
            title: 'Compliance update not found',
            message:
                'The obligation is not present in the current projection. It may have been superseded or removed.',
            laneKey: laneKey,
            onRetry:
                () => ref.invalidate(
                  workflowComplianceRecordProvider(recordScope),
                ),
          );
        }
        if (!isComplianceRequestRelevantToUser(record, actor)) {
          return BafScreenStateScaffold.access(
            appBarTitle: 'Compliance update',
            appBarSubtitle: 'Operational obligation and response status',
            appBarIcon: Icons.assignment_late_outlined,
            accent: BafColors.directives,
            title: 'Compliance audience required',
            message:
                'This obligation is outside your approved lane and supervisory scope.',
          );
        }
        return ComplianceDetailScreen(record: record);
      },
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
    return AppBar(
      title: const BafAppBarTitle(
        title: 'Compliance update',
        subtitle: 'Operational obligation and response status',
        icon: Icons.assignment_late_outlined,
        accent: BafColors.directives,
      ),
    );
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
        child: BafStatePanel(
          icon: Icons.assignment_late_outlined,
          color: BafColors.warning,
          title: title,
          message: message,
          primaryLabel: 'Open inbox',
          primaryIcon: Icons.inbox_outlined,
          onPrimary:
              () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => ComplianceInboxScreen(laneKey: laneKey),
                ),
              ),
          secondaryLabel: 'Retry',
          onSecondary: onRetry,
        ),
      ),
    );
  }
}
