import 'package:flutter/material.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../abnormalities/presentation/abnormality_reports_screen.dart';
import '../../../abnormalities/presentation/abnormality_types_screen.dart';

// ============================================================================
// ABNORMALITIES ADMIN TAB – links to master data and intelligence
// ============================================================================

class AbnormalitiesAdminTab extends StatelessWidget {
  const AbnormalitiesAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: BafColors.background,
      child: ListView(
        padding: const EdgeInsets.all(BafSpacing.lg),
        children: [
          const _AdminAbnormalityHeader(),
          const SizedBox(height: BafSpacing.lg),
          _AdminAbnormalityActionCard(
            icon: Icons.rule_folder_outlined,
            title: 'Abnormality Types',
            subtitle:
                'Create and maintain the master list used while logging charge abnormalities. Includes RA coil-colour type.',
            color: BafColors.admin,
            actionLabel: 'Manage Types',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AbnormalityTypesScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: BafSpacing.md),
          _AdminAbnormalityActionCard(
            icon: Icons.analytics_rounded,
            title: 'Reports / Intelligence',
            subtitle:
                'Review recurrence, RA pending load, affected assets, severity mix and root-reason patterns.',
            color: BafColors.charges,
            actionLabel: 'Open Reports',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AbnormalityReportsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: BafSpacing.md),
          const _AdminAbnormalityPrincipleCard(),
        ],
      ),
    );
  }
}

class _AdminAbnormalityHeader extends StatelessWidget {
  const _AdminAbnormalityHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.navy,
        borderRadius: BorderRadius.circular(BafRadius.large),
      ),
      child: Row(
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
                  'Abnormality Administration',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: BafSpacing.xs),
                Text(
                  'Master data and intelligence layer for charge abnormalities, RA traceability and recurrence memory.',
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
    );
  }
}

class _AdminAbnormalityActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String actionLabel;
  final VoidCallback onTap;

  const _AdminAbnormalityActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.large),
        side: const BorderSide(color: BafColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(BafRadius.large),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(BafSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                ),
                child: Icon(icon, color: color),
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
                    const SizedBox(height: BafSpacing.xs),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: BafSpacing.md),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                ),
                onPressed: onTap,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminAbnormalityPrincipleCard extends StatelessWidget {
  const _AdminAbnormalityPrincipleCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: BafColors.audit.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.large),
        side: BorderSide(color: BafColors.audit.withValues(alpha: 0.18)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(BafSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Business principle',
              style: TextStyle(
                color: BafColors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            SizedBox(height: BafSpacing.sm),
            Text(
              'An abnormality is operational memory, not merely a fault entry. RA due to coil colour must preserve old charge, new charge, base/assets, reason and possible root reason.',
              style: TextStyle(color: BafColors.textSecondary, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}
