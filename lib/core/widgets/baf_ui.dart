import 'package:flutter/material.dart';

import '../theme/baf_design_system.dart';
import 'brand/brand_widgets.dart';

double bafDialogBodyHeight(
  BuildContext context, {
  required double preferred,
  double minimum = 180,
  double reservedChrome = 220,
}) {
  final media = MediaQuery.of(context);
  final available =
      media.size.height - media.viewInsets.bottom - reservedChrome;
  return available.clamp(minimum, preferred).toDouble();
}

/// Keeps mode controls intact on compact screens without compressing labels
/// into unreadable fragments. Short controls still occupy the available width.
class BafHorizontalControlRail extends StatelessWidget {
  const BafHorizontalControlRail({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minimumWidth =
            constraints.hasBoundedWidth ? constraints.maxWidth : 0.0;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minimumWidth),
            child: child,
          ),
        );
      },
    );
  }
}

/// Standard top-level shell for operational and governance screens.
///
/// Keeping page identity and background treatment here prevents nested feature
/// areas from quietly drifting back to unrelated app-bar styles.
class BafScreenScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget body;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final bool resizeToAvoidBottomInset;

  const BafScreenScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.body,
    this.accent = BafColors.teal,
    this.actions,
    this.bottom,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BafColors.background,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: AppBar(
        title: BafAppBarTitle(
          title: title,
          subtitle: subtitle,
          icon: icon,
          accent: accent,
        ),
        actions: actions,
        bottom: bottom,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BafContextRail(color: accent),
          Expanded(child: BafPageCanvas(child: body)),
        ],
      ),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

/// Quiet page depth shared by routed work surfaces.
///
/// The solid top band creates separation from the app chrome without using a
/// decorative gradient or turning the page into a floating card.
class BafPageCanvas extends StatelessWidget {
  final Widget child;

  const BafPageCanvas({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: BafColors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 72,
            child: ColoredBox(color: BafColors.surfaceTint),
          ),
          child,
        ],
      ),
    );
  }
}

class BafContextRail extends StatelessWidget {
  final Color color;

  const BafContextRail({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      excludeSemantics: true,
      child: SizedBox(height: 3, child: ColoredBox(color: color)),
    );
  }
}

/// A complete screen for loading, access, empty, and fatal-error states.
class BafScreenStateScaffold extends StatelessWidget {
  final String appBarTitle;
  final String appBarSubtitle;
  final IconData appBarIcon;
  final Color accent;
  final Widget state;
  final List<Widget>? actions;

  const BafScreenStateScaffold({
    super.key,
    required this.appBarTitle,
    required this.appBarSubtitle,
    required this.appBarIcon,
    required this.state,
    this.accent = BafColors.teal,
    this.actions,
  });

  factory BafScreenStateScaffold.loading({
    Key? key,
    required String appBarTitle,
    required String appBarSubtitle,
    required IconData appBarIcon,
    String label = 'Loading',
    Color accent = BafColors.teal,
  }) => BafScreenStateScaffold(
    key: key,
    appBarTitle: appBarTitle,
    appBarSubtitle: appBarSubtitle,
    appBarIcon: appBarIcon,
    accent: accent,
    state: BafLoadingPanel(label: label, color: accent),
  );

  factory BafScreenStateScaffold.error({
    Key? key,
    required String appBarTitle,
    required String appBarSubtitle,
    required IconData appBarIcon,
    String title = 'This view could not be opened',
    required String message,
    String retryLabel = 'Try again',
    VoidCallback? onRetry,
    Color accent = BafColors.teal,
  }) => BafScreenStateScaffold(
    key: key,
    appBarTitle: appBarTitle,
    appBarSubtitle: appBarSubtitle,
    appBarIcon: appBarIcon,
    accent: accent,
    state: BafStatePanel.error(
      title: title,
      message: message,
      primaryLabel: retryLabel,
      onPrimary: onRetry,
    ),
  );

  factory BafScreenStateScaffold.access({
    Key? key,
    required String appBarTitle,
    required String appBarSubtitle,
    required IconData appBarIcon,
    String title = 'Access required',
    required String message,
    Color accent = BafColors.teal,
  }) => BafScreenStateScaffold(
    key: key,
    appBarTitle: appBarTitle,
    appBarSubtitle: appBarSubtitle,
    appBarIcon: appBarIcon,
    accent: accent,
    state: BafStatePanel(
      icon: Icons.lock_outline_rounded,
      color: BafColors.danger,
      title: title,
      message: message,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return BafScreenScaffold(
      title: appBarTitle,
      subtitle: appBarSubtitle,
      icon: appBarIcon,
      accent: accent,
      actions: actions,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: state,
            ),
          );
        },
      ),
    );
  }
}

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final panel = Center(
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
                                      : Icon(
                                        primaryIcon ?? Icons.arrow_forward,
                                      ),
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
          );
          if (!constraints.hasBoundedHeight) return panel;
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: panel,
            ),
          );
        },
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.hasBoundedHeight && constraints.maxHeight < 120;
          if (compact) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: BafSpacing.md,
                  vertical: BafSpacing.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        color: color,
                        strokeWidth: 2.4,
                      ),
                    ),
                    const SizedBox(width: BafSpacing.sm),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: BafColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(BafSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 30,
                    child: CircularProgressIndicator(
                      color: color,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: BafSpacing.md),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: BafColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class BafRecordSurface extends StatefulWidget {
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
  State<BafRecordSurface> createState() => _BafRecordSurfaceState();
}

class _BafRecordSurfaceState extends State<BafRecordSurface> {
  bool _highlighted = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.onTap != null && _highlighted;
    final borderColor =
        active
            ? (widget.accent ?? BafColors.teal).withValues(alpha: 0.42)
            : widget.accent?.withValues(alpha: 0.22) ?? BafColors.border;
    final radius = BorderRadius.circular(BafRadius.medium);

    return AnimatedContainer(
      duration: BafMotion.quick,
      curve: BafMotion.curve,
      decoration: BoxDecoration(
        color: BafColors.surfaceRaised,
        borderRadius: radius,
        border: Border.all(color: borderColor),
        boxShadow: active ? BafShadows.soft : BafShadows.subtle,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHover:
              widget.onTap == null
                  ? null
                  : (value) => setState(() => _highlighted = value),
          onFocusChange:
              widget.onTap == null
                  ? null
                  : (value) => setState(() => _highlighted = value),
          borderRadius: radius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: widget.accent ?? Colors.transparent,
                  width: widget.accent == null ? 0 : 3,
                ),
              ),
            ),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
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
    final radius = BorderRadius.circular(BafRadius.medium);
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: BafColors.surfaceRaised,
          borderRadius: radius,
          border: Border.all(color: accent.withValues(alpha: 0.24)),
          boxShadow: BafShadows.subtle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.only(
                    topLeft: radius.topLeft,
                    bottomLeft: radius.bottomLeft,
                  ),
                ),
              ),
            ),
            Icon(icon, color: accent, size: size * 0.48),
          ],
        ),
      ),
    );
  }
}
