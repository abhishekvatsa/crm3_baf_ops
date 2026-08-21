import 'package:flutter/material.dart';

import '../theme/baf_design_system.dart';

/// Shared page geometry for operational screens.
class BafContentFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final bool includeTopSafeArea;
  final bool includeBottomSafeArea;

  const BafContentFrame({
    super.key,
    required this.child,
    this.maxWidth = 1040,
    this.padding = const EdgeInsets.fromLTRB(
      BafSpacing.lg,
      BafSpacing.md,
      BafSpacing.lg,
      BafSpacing.xl,
    ),
    this.includeTopSafeArea = false,
    this.includeBottomSafeArea = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: includeTopSafeArea,
      bottom: includeBottomSafeArea,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Responsive screen introduction. This remains an unframed page section.
class BafScreenIntro extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget? trailing;

  const BafScreenIntro({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.accent = BafColors.teal,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final copy = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _AccentIcon(icon: icon, accent: accent),
        const SizedBox(width: BafSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: BafSpacing.xs),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );

    if (trailing == null) return copy;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              copy,
              const SizedBox(height: BafSpacing.md),
              Align(alignment: Alignment.centerLeft, child: trailing!),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: copy),
            const SizedBox(width: BafSpacing.lg),
            trailing!,
          ],
        );
      },
    );
  }
}

class BafSearchField extends StatelessWidget {
  final Key? fieldKey;
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final bool enabled;

  const BafSearchField({
    super.key,
    this.fieldKey,
    this.controller,
    required this.hintText,
    required this.onChanged,
    this.onClear,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon:
            onClear == null
                ? null
                : IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
      ),
    );
  }
}

class BafStatePanel extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String? primaryLabel;
  final IconData? primaryIcon;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool busy;

  const BafStatePanel({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.primaryLabel,
    this.primaryIcon,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.busy = false,
  });

  factory BafStatePanel.empty({
    Key? key,
    required String title,
    required String message,
    IconData icon = Icons.inbox_outlined,
    Color color = BafColors.teal,
    String? primaryLabel,
    IconData? primaryIcon,
    VoidCallback? onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) => BafStatePanel(
    key: key,
    icon: icon,
    color: color,
    title: title,
    message: message,
    primaryLabel: primaryLabel,
    primaryIcon: primaryIcon,
    onPrimary: onPrimary,
    secondaryLabel: secondaryLabel,
    onSecondary: onSecondary,
  );

  factory BafStatePanel.error({
    Key? key,
    String title = 'Something needs attention',
    required String message,
    String primaryLabel = 'Try again',
    VoidCallback? onPrimary,
  }) => BafStatePanel(
    key: key,
    icon: Icons.error_outline_rounded,
    color: BafColors.danger,
    title: title,
    message: message,
    primaryLabel: onPrimary == null ? null : primaryLabel,
    primaryIcon: Icons.refresh_rounded,
    onPrimary: onPrimary,
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      label: '$title. $message',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BafSpacing.lg,
              vertical: BafSpacing.xxl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AccentIcon(icon: icon, accent: color, size: 54),
                const SizedBox(height: BafSpacing.lg),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: BafSpacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: BafColors.textSecondary,
                  ),
                ),
                if (primaryLabel != null || secondaryLabel != null) ...[
                  const SizedBox(height: BafSpacing.xl),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: BafSpacing.sm,
                    runSpacing: BafSpacing.sm,
                    children: [
                      if (primaryLabel != null)
                        FilledButton.icon(
                          onPressed: busy ? null : onPrimary,
                          icon:
                              busy
                                  ? const SizedBox.square(
                                    dimension: 17,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : Icon(primaryIcon ?? Icons.arrow_forward),
                          label: Text(primaryLabel!),
                          style: FilledButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      if (secondaryLabel != null)
                        OutlinedButton(
                          onPressed: busy ? null : onSecondary,
                          child: Text(secondaryLabel!),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BafLoadingPanel extends StatelessWidget {
  final String label;
  final Color color;

  const BafLoadingPanel({
    super.key,
    this.label = 'Loading',
    this.color = BafColors.teal,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(BafSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 30,
                child: CircularProgressIndicator(color: color, strokeWidth: 3),
              ),
              const SizedBox(height: BafSpacing.md),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: BafColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BafRecordSurface extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? accent;
  final EdgeInsetsGeometry padding;

  const BafRecordSurface({
    super.key,
    required this.child,
    this.onTap,
    this.accent,
    this.padding = const EdgeInsets.all(BafSpacing.md),
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      side: BorderSide(
        color: accent?.withValues(alpha: 0.24) ?? BafColors.border,
      ),
    );
    return Material(
      color: BafColors.card,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: accent ?? Colors.transparent,
                width: accent == null ? 0 : 3,
              ),
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class BafSectionLabel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const BafSectionLabel({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: BafSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}

class _AccentIcon extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final double size;

  const _AccentIcon({required this.icon, required this.accent, this.size = 46});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, color: accent, size: size * 0.5),
    );
  }
}
