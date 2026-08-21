import 'package:flutter/material.dart';

import '../../theme/baf_design_system.dart';

class ManmithasMark extends StatelessWidget {
  final double size;
  final bool framed;
  final Color backgroundColor;

  const ManmithasMark({
    super.key,
    this.size = 44,
    this.framed = true,
    this.backgroundColor = BafColors.graphite,
  });

  @override
  Widget build(BuildContext context) {
    final mark = Image.asset(
      BafBrand.markAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: BafBrand.makerName,
    );

    if (!framed) return mark;

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(BafRadius.medium),
      ),
      child: mark,
    );
  }
}

class BafBrandLockup extends StatelessWidget {
  final bool onDark;
  final bool compact;

  const BafBrandLockup({super.key, this.onDark = false, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final primary = onDark ? Colors.white : BafColors.textPrimary;
    final secondary =
        onDark ? Colors.white.withValues(alpha: 0.68) : BafColors.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ManmithasMark(
          size: compact ? 36 : 44,
          backgroundColor:
              onDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : BafColors.graphite,
        ),
        const SizedBox(width: BafSpacing.sm),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                BafBrand.productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: primary,
                  fontSize: compact ? 14 : 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                BafBrand.makerLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: secondary,
                  fontSize: compact ? 8 : 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class BafPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget? trailing;

  const BafPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.accent = BafColors.teal,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final identity = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(BafRadius.medium),
            border: Border.all(color: accent.withValues(alpha: 0.16)),
          ),
          child: Icon(icon, color: accent, size: 23),
        ),
        const SizedBox(width: BafSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.lg),
      color: BafColors.card,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (trailing != null &&
              constraints.maxWidth < BafBreakpoints.compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: BafSpacing.md),
                Align(alignment: Alignment.centerLeft, child: trailing!),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: identity),
              if (trailing != null) ...[
                const SizedBox(width: BafSpacing.md),
                trailing!,
              ],
            ],
          );
        },
      ),
    );
  }
}

class BafAppBarTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  const BafAppBarTitle({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.accent = BafColors.teal,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(BafRadius.small),
          ),
          child: Icon(icon, color: accent, size: 19),
        ),
        const SizedBox(width: BafSpacing.sm),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class BafSectionHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  const BafSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, color: BafColors.teal, size: 20),
          const SizedBox(width: BafSpacing.sm),
        ],
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
