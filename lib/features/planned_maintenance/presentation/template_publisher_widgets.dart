part of 'template_publisher_screen.dart';

class _Panel extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;

  const _Panel({required this.child, this.title, this.subtitle, this.icon});

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  _IconTile(icon: icon!, color: BafColors.planned, size: 44),
                  const SizedBox(width: BafSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: const TextStyle(
                          color: BafColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: BafSpacing.xs),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: BafColors.textSecondary,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: BafSpacing.lg),
          ],
          child,
        ],
      ),
    );
  }
}

class _ResponsiveTwoColumn extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _ResponsiveTwoColumn({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            children: [left, const SizedBox(height: BafSpacing.md), right],
          );
        }
        return Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: BafSpacing.md),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _IconTile({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(BafRadius.medium),
      ),
      child: Icon(icon, color: color, size: size * 0.55),
    );
  }
}

class _TinyActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _TinyActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: BafSpacing.sm),
      ),
    );
  }
}

class _ValidationLine extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;

  const _ValidationLine({
    required this.text,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BafSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontSize: 13,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessDeniedScaffold extends StatelessWidget {
  const _AccessDeniedScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: BafColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(BafSpacing.xl),
            child: _Panel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, color: BafColors.danger, size: 54),
                  SizedBox(height: BafSpacing.md),
                  Text(
                    'Template governance access denied',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: BafColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: BafSpacing.sm),
                  Text(
                    'Only approved Admin/SI users can create, save or publish governed template versions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: BafColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  final String? title;

  const _ErrorScaffold({required this.message, this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BafColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(BafSpacing.xl),
          child:
              title == null
                  ? _Panel(
                    child: Text(
                      message,
                      style: const TextStyle(color: BafColors.danger),
                    ),
                  )
                  : PersistedDataIntegrityNotice(
                    title: title!,
                    message: message,
                  ),
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration({
  required String label,
  String? hint,
  IconData? icon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon),
    filled: true,
    fillColor: Colors.white,
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
      borderSide: const BorderSide(color: BafColors.planned, width: 1.4),
    ),
  );
}
