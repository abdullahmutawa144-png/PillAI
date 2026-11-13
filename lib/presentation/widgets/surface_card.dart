import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A consistently styled app surface with optional ink interaction.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    required this.child,
    super.key,
    this.padding = AppSpacing.card,
    this.margin,
    this.color = AppColors.surface,
    this.gradient,
    this.borderRadius = AppRadii.lg,
    this.border,
    this.boxShadow = AppShadows.card,
    this.onTap,
    this.semanticLabel,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Gradient? gradient;
  final double borderRadius;
  final BorderSide? border;
  final List<BoxShadow> boxShadow;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(borderRadius);
    final BoxBorder resolvedBorder = Border.fromBorderSide(
      border ?? const BorderSide(color: AppColors.border),
    );

    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: content,
        ),
      );
    }

    return Semantics(
      container: true,
      label: semanticLabel,
      button: onTap != null,
      child: Container(
        margin: margin,
        decoration: BoxDecoration(borderRadius: radius, boxShadow: boxShadow),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: clipBehavior,
          child: Ink(
            decoration: BoxDecoration(
              color: gradient == null ? color : null,
              gradient: gradient,
              borderRadius: radius,
              border: resolvedBorder,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
