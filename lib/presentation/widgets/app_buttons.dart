import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Widget labelWidget = isLoading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: Colors.white,
            ),
          )
        : Text(label);

    final Widget button = icon == null || isLoading
        ? FilledButton(
            onPressed: isLoading ? null : onPressed,
            child: labelWidget,
          )
        : FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 21),
            label: labelWidget,
          );

    return Semantics(
      label: semanticLabel ?? label,
      button: true,
      child: SizedBox(width: expand ? double.infinity : null, child: button),
    );
  }
}

/// A circular, accessible icon action used for notifications and card actions.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
    this.foregroundColor = AppColors.primaryDark,
    this.backgroundColor = AppColors.surface,
    this.showIndicator = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color foregroundColor;
  final Color backgroundColor;
  final bool showIndicator;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayoutTokens.of(context);
    return SizedBox.square(
      dimension: layout.minTapTarget,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: IconButton(
              onPressed: onPressed,
              tooltip: tooltip,
              style: IconButton.styleFrom(
                foregroundColor: foregroundColor,
                backgroundColor: backgroundColor,
                disabledForegroundColor: AppColors.disabled,
                shape: const CircleBorder(
                  side: BorderSide(color: AppColors.border),
                ),
              ),
              icon: Icon(icon),
            ),
          ),
          if (showIndicator)
            const Positioned(
              right: 2,
              top: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: Colors.white, width: 2),
                  ),
                ),
                child: SizedBox.square(dimension: 11),
              ),
            ),
        ],
      ),
    );
  }
}

/// Large completion control for a dose row.
class CompletionToggle extends StatelessWidget {
  const CompletionToggle({
    required this.isCompleted,
    required this.onPressed,
    super.key,
    this.semanticLabel,
  });

  final bool isCompleted;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final String label =
        semanticLabel ??
        (isCompleted ? 'Mark dose as not taken' : 'Mark dose as taken');

    return Semantics(
      label: label,
      button: true,
      toggled: isCompleted,
      child: IconButton(
        onPressed: onPressed,
        tooltip: label,
        iconSize: 27,
        style: IconButton.styleFrom(
          minimumSize: const Size.square(48),
          foregroundColor: isCompleted ? Colors.white : AppColors.inkSubtle,
          backgroundColor: isCompleted ? AppColors.mint : Colors.transparent,
          side: BorderSide(
            color: isCompleted ? AppColors.mint : AppColors.disabled,
            width: 1.6,
          ),
        ),
        icon: Icon(isCompleted ? Icons.check_rounded : Icons.circle_outlined),
      ),
    );
  }
}
