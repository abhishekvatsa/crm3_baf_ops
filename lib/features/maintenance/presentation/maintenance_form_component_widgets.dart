part of 'maintenance_form.dart';

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: BafColors.maintenance, size: 22),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: BafSpacing.xs),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.lg),
          ...children,
        ],
      ),
    );
  }
}

class _ResolvedTagPanel extends StatelessWidget {
  final String? system;
  final String? subsystem;
  final List<String>? path;
  final String? ownership;
  final bool governed;

  const _ResolvedTagPanel({
    this.system,
    this.subsystem,
    this.path,
    this.ownership,
    this.governed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.sync.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.sync.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                governed ? Icons.verified_outlined : Icons.auto_awesome_rounded,
                size: 17,
                color: BafColors.sync,
              ),
              const SizedBox(width: 6),
              Text(
                governed ? 'Governed component resolved' : 'Tag resolved',
                style: const TextStyle(
                  color: BafColors.sync,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.sm),
          if (system != null && system!.trim().isNotEmpty)
            _ResolvedLine(label: 'System', value: system!),
          if (subsystem != null && subsystem!.trim().isNotEmpty)
            _ResolvedLine(label: 'Subsystem', value: subsystem!),
          if (path != null && path!.isNotEmpty)
            _ResolvedLine(label: 'Path', value: path!.join(' › ')),
          if (ownership != null && ownership!.trim().isNotEmpty)
            _ResolvedLine(label: 'Ownership', value: ownership!),
        ],
      ),
    );
  }
}

String _roleLabelForReference(String role) => switch (role) {
  'admin' => 'Admin',
  'si' => 'SI',
  'contractSupervisor' => 'Contract supervisor',
  'shiftSupervisor' => 'Shift supervisor',
  'seniorElectrical' => 'Sr. Electrical',
  'seniorMechanical' => 'Sr. Mechanical',
  'seniorInstrumentation' => 'Sr. I&A',
  'seniorRefractory' => 'Sr. Refractory',
  'refractory' => 'Refractory',
  'operations' => 'Operations',
  _ => role,
};

class _ResolvedLine extends StatelessWidget {
  final String label;
  final String value;

  const _ResolvedLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: BafColors.textSecondary,
            fontSize: 12,
            height: 1.25,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
