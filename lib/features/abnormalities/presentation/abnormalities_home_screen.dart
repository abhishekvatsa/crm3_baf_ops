// FILE: lib/features/abnormalities/presentation/abnormalities_home_screen.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/sync_coordinator.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/validation/charge_number.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../../core/widgets/dashboard/dashboard_widgets.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/abnormality_provider.dart';
import 'abnormality_reports_screen.dart';
import 'abnormality_types_screen.dart';
import 'charge_abnormalities_screen.dart';

class AbnormalitiesHomeScreen extends ConsumerStatefulWidget {
  const AbnormalitiesHomeScreen({super.key});

  @override
  ConsumerState<AbnormalitiesHomeScreen> createState() =>
      _AbnormalitiesHomeScreenState();
}

class _AbnormalitiesHomeScreenState
    extends ConsumerState<AbnormalitiesHomeScreen> {
  final TextEditingController _chargeController = TextEditingController();

  @override
  void dispose() {
    _chargeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeTypesAsync = ref.watch(activeAbnormalityTypesProvider);
    final allTypesAsync = ref.watch(allAbnormalityTypesProvider);
    final appUser = ref.watch(currentAppUserProvider).value;
    final canManageTypes = appUser?.canManageAbnormalityTypes == true;

    final activeCount = activeTypesAsync.maybeWhen(
      data: (types) => types.length,
      orElse: () => null,
    );

    final totalCount = allTypesAsync.maybeWhen(
      data: (types) => types.length,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const BafAppBarTitle(
          title: 'Abnormalities',
          subtitle: 'Charge events, RA traceability and root causes',
          icon: Icons.memory_outlined,
          accent: BafColors.instrument,
        ),
        actions: [
          if (canManageTypes)
            IconButton(
              tooltip: 'Seed/check default abnormality types',
              icon: const Icon(Icons.auto_fix_high_rounded),
              color: BafColors.audit,
              onPressed: _seedDefaults,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(BafSpacing.lg),
        children: [
          _HeroCard(activeCount: activeCount, totalCount: totalCount),
          const SizedBox(height: BafSpacing.lg),
          _ChargeEntryCard(controller: _chargeController, onOpen: _openCharge),
          const SizedBox(height: BafSpacing.lg),
          _ActionGrid(
            canManageTypes: canManageTypes,
            onOpenMasterData: _openMasterData,
            onSeedDefaults: _seedDefaults,
            onOpenReports: _openReports,
          ),
          const SizedBox(height: BafSpacing.lg),
          const _BusinessPrincipleCard(),
        ],
      ),
    );
  }

  Future<void> _seedDefaults() async {
    final actor = ref.read(currentAppUserProvider).value;
    if (actor == null || !actor.canManageAbnormalityTypes) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Only Admin can seed abnormality type master data.'),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }

    try {
      final repository = ref.read(abnormalityRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);

      await repository.seedDefaultTypes(actor: actor);

      final syncOutcome =
          kIsWeb
              ? SyncRequestOutcome.succeeded
              : await syncCoordinator.runFullSyncWithResult(
                reason: 'abnormality_defaults_seeded',
                force: true,
              );

      if (!mounted) return;

      final message = switch (syncOutcome) {
        SyncRequestOutcome.succeeded =>
          'Default abnormality types checked and synchronized.',
        SyncRequestOutcome.queued || SyncRequestOutcome.throttled =>
          'Default abnormality types checked on this device; synchronization is queued.',
        SyncRequestOutcome.failed =>
          'Default abnormality types were checked locally, but cloud synchronization needs attention.',
      };
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              syncOutcome == SyncRequestOutcome.failed
                  ? BafColors.danger
                  : null,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Seeding failed: $e'),
          backgroundColor: BafColors.danger,
        ),
      );
    }
  }

  void _openMasterData() {
    final actor = ref.read(currentAppUserProvider).value;
    if (actor == null || !actor.canManageAbnormalityTypes) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Only Admin can manage abnormality type master data.'),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AbnormalityTypesScreen()));
  }

  void _openReports() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AbnormalityReportsScreen()));
  }

  void _openCharge() {
    final text = _chargeController.text.trim();
    final chargeNo = parseOptionalChargeNumber(text);

    if (chargeNo == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Enter an exact five-digit charge number'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ChargeAbnormalitiesScreen(
              sourceChargeNo: chargeNo,
              subtitle:
                  'Log abnormalities, RA decision, affected assets and root-reason memory for charge $chargeNo.',
            ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// UI WIDGETS
// ─────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final int? activeCount;
  final int? totalCount;

  const _HeroCard({required this.activeCount, required this.totalCount});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      backgroundColor: BafColors.navy,
      borderColor: BafColors.navySoft.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                ),
                child: const Icon(Icons.memory_rounded, color: Colors.white),
              ),
              const SizedBox(width: BafSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operational abnormality memory',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: BafSpacing.xs),
                    Text(
                      'Capture abnormality events, RA traceability, affected assets and possible root reasons charge-by-charge.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.lg),
          Wrap(
            spacing: BafSpacing.sm,
            runSpacing: BafSpacing.sm,
            children: [
              _MetricPill(
                label: 'Active Types',
                value: activeCount == null ? '—' : '$activeCount',
              ),
              _MetricPill(
                label: 'Total Types',
                value: totalCount == null ? '—' : '$totalCount',
              ),
              const StatusBadge(
                label: 'RA Traceability',
                color: BafColors.audit,
                icon: Icons.repeat_rounded,
              ),
              const StatusBadge(
                label: 'Offline First',
                color: BafColors.sync,
                icon: Icons.sync_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;

  const _MetricPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 88),
      padding: const EdgeInsets.symmetric(
        horizontal: BafSpacing.md,
        vertical: BafSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ChargeEntryCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onOpen;

  const _ChargeEntryCard({required this.controller, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.confirmation_number_outlined,
            title: 'Open charge abnormality log',
            subtitle:
                'Enter the original/source charge number to view or log abnormalities.',
            color: BafColors.charges,
          ),
          const SizedBox(height: BafSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: chargeNumberInputFormatters,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => onOpen(),
                  decoration: _inputDecoration(
                    label: 'Source / old charge no.',
                    hint: 'Example: 12345',
                  ),
                ),
              ),
              const SizedBox(width: BafSpacing.sm),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: BafColors.charges,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: BafSpacing.lg,
                    vertical: 15,
                  ),
                ),
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  final bool canManageTypes;
  final VoidCallback onOpenMasterData;
  final VoidCallback onSeedDefaults;
  final VoidCallback onOpenReports;

  const _ActionGrid({
    required this.canManageTypes,
    required this.onOpenMasterData,
    required this.onSeedDefaults,
    required this.onOpenReports,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 720;

        final cards = <Widget>[
          if (canManageTypes)
            _ActionCard(
              icon: Icons.rule_folder_outlined,
              title: 'Abnormality Types',
              subtitle:
                  'Maintain process, equipment, result-quality and RA abnormality master data.',
              color: BafColors.admin,
              actionLabel: 'Manage',
              onPressed: onOpenMasterData,
            ),
          _ActionCard(
            icon: Icons.analytics_rounded,
            title: 'Reports / Intelligence',
            subtitle:
                'Review recurrence, RA pending load, affected assets and root-reason patterns.',
            color: BafColors.charges,
            actionLabel: 'Open',
            onPressed: onOpenReports,
          ),
          if (canManageTypes)
            _ActionCard(
              icon: Icons.auto_fix_high_rounded,
              title: 'Default RA Type',
              subtitle:
                  'Ensure RA Required – Coil Colour exists for coil colour based re-annealing cases.',
              color: BafColors.audit,
              actionLabel: 'Check / Seed',
              onPressed: onSeedDefaults,
            ),
        ];

        if (!twoColumns || cards.length == 1) {
          return Column(
            children: List<Widget>.generate(cards.length * 2 - 1, (index) {
              return index.isEven
                  ? cards[index ~/ 2]
                  : const SizedBox(height: BafSpacing.md);
            }),
          );
        }

        return Wrap(
          spacing: BafSpacing.md,
          runSpacing: BafSpacing.md,
          children: cards
              .map(
                (card) => SizedBox(
                  width: (constraints.maxWidth - BafSpacing.md) / 2,
                  child: card,
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String actionLabel;
  final VoidCallback onPressed;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: icon,
            title: title,
            subtitle: subtitle,
            color: color,
          ),
          const SizedBox(height: BafSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
              onPressed: onPressed,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessPrincipleCard extends StatelessWidget {
  const _BusinessPrincipleCard();

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      backgroundColor: BafColors.audit.withValues(alpha: 0.08),
      borderColor: BafColors.audit.withValues(alpha: 0.18),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.lightbulb_outline_rounded,
            title: 'Business principle',
            subtitle:
                'An abnormality is not only a fault. It is operational memory.',
            color: BafColors.audit,
          ),
          SizedBox(height: BafSpacing.md),
          _PrincipleRow(
            icon: Icons.confirmation_number_outlined,
            text: 'Always preserve the old/source charge number.',
          ),
          SizedBox(height: BafSpacing.sm),
          _PrincipleRow(
            icon: Icons.repeat_rounded,
            text:
                'If coil colour indicates RA, RA itself is an abnormality and must record the new charge when available.',
          ),
          SizedBox(height: BafSpacing.sm),
          _PrincipleRow(
            icon: Icons.precision_manufacturing_rounded,
            text:
                'Affected base, furnace, force cooler or inner cover should be captured for recurrence analysis.',
          ),
          SizedBox(height: BafSpacing.sm),
          _PrincipleRow(
            icon: Icons.manage_search_rounded,
            text:
                'Possible root reason can start as unknown and improve after investigation.',
          ),
        ],
      ),
    );
  }
}

class _PrincipleRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PrincipleRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: BafColors.audit, size: 18),
        const SizedBox(width: BafSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: BafColors.textPrimary, height: 1.3),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(BafRadius.medium),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: BafSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────

InputDecoration _inputDecoration({required String label, String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: BafColors.card,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(color: BafColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(color: BafColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(color: BafColors.navySoft, width: 1.4),
    ),
  );
}
