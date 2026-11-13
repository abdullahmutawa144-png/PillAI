import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum StatusTone { info, success, warning, danger, neutral, accent }

class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    super.key,
    this.tone = StatusTone.neutral,
    this.icon,
    this.onTap,
    this.compact = false,
    this.semanticLabel,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool compact;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final _StatusPalette palette = _paletteFor(tone);
    final layout = AppLayoutTokens.of(context);
    final double visualHeight = layout.isSimple
        ? (compact ? 38 : 44)
        : (compact ? 28 : 32);

    final Widget chip = Container(
      constraints: BoxConstraints(minHeight: visualHeight),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: layout.isSimple ? 8 : 4,
      ),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: compact ? 14 : 16, color: palette.foreground),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: layout.isSimple ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: palette.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      label: semanticLabel ?? label,
      button: onTap != null,
      child: onTap == null
          ? chip
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Center(child: chip),
                ),
              ),
            ),
    );
  }
}

class _StatusPalette {
  const _StatusPalette(this.background, this.foreground, this.border);

  final Color background;
  final Color foreground;
  final Color border;
}

_StatusPalette _paletteFor(StatusTone tone) {
  return switch (tone) {
    StatusTone.info => const _StatusPalette(
      AppColors.primarySoft,
      AppColors.primaryDark,
      Color(0xFFD5E1FF),
    ),
    StatusTone.success => const _StatusPalette(
      AppColors.mintSoft,
      AppColors.mint,
      Color(0xFFC6EAE1),
    ),
    StatusTone.warning => const _StatusPalette(
      AppColors.warningSoft,
      AppColors.warning,
      Color(0xFFF5D9AC),
    ),
    StatusTone.danger => const _StatusPalette(
      AppColors.dangerSoft,
      AppColors.danger,
      Color(0xFFF4CBD1),
    ),
    StatusTone.accent => const _StatusPalette(
      AppColors.lavenderSoft,
      AppColors.lavender,
      Color(0xFFDED1FF),
    ),
    StatusTone.neutral => const _StatusPalette(
      AppColors.surfaceMuted,
      AppColors.navyMuted,
      AppColors.border,
    ),
  };
}
