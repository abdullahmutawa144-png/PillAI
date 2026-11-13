import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/app_models.dart';
import '../theme/app_theme.dart';
import 'pill_ai_assistant.dart';
import '../bidi.dart';

/// Opens a rounded bottom sheet with consistent padding and keyboard insets.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool scrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: scrollControlled,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: builder(sheetContext),
    ),
  );
}

/// Title (and optional one-line subtitle) at the top of a sheet.
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    required this.title,
    this.subtitle,
    this.leading,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 14)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                textDirection: directionOf(title),
                style: text.headlineSmall,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: text.bodyMedium),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The "ask or tell PillAI" bar that sits at the top of Today.
class AskBar extends StatelessWidget {
  const AskBar({
    required this.hint,
    required this.onTap,
    required this.onMic,
    required this.micTooltip,
    super.key,
  });

  final String hint;
  final VoidCallback onTap;
  final VoidCallback onMic;
  final String micTooltip;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayoutTokens.of(context);
    final height = layout.isSimple ? 68.0 : 58.0;
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.pill)),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: AppColors.surface,
        shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Row(
              children: [
                const SizedBox(width: 8),
                PillAiMark(size: height - 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppColors.inkSubtle),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: IconButton(
                    tooltip: micTooltip,
                    onPressed: onMic,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.aiSoft,
                      foregroundColor: AppColors.ai,
                    ),
                    icon: const Icon(Icons.mic_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small round avatar for a medicine, tinted with its accent color.
class MedicineAvatar extends StatelessWidget {
  const MedicineAvatar({
    required this.form,
    required this.colorSeed,
    this.size = 44,
    super.key,
  });

  final MedicationForm form;
  final int colorSeed;
  final double size;

  static IconData iconFor(MedicationForm form) => switch (form) {
    MedicationForm.tablet => Icons.medication_rounded,
    MedicationForm.capsule => Icons.medication_outlined,
    MedicationForm.liquid => Icons.medication_liquid_rounded,
    MedicationForm.injection => Icons.vaccines_rounded,
    MedicationForm.other => Icons.healing_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final color = AppColors.medicineColor(colorSeed);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(size * .32),
      ),
      child: Icon(iconFor(form), color: color, size: size * .52),
    );
  }
}

/// A ring that fills as doses are taken, with a label in the middle.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    required this.value,
    required this.size,
    this.strokeWidth = 6,
    this.color = AppColors.primary,
    this.trackColor = AppColors.primarySoft,
    this.child,
    super.key,
  });

  final double value;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color trackColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0, 1).toDouble(),
          strokeWidth: strokeWidth,
          color: color,
          trackColor: trackColor,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  final double value;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final deflated = rect.deflate(strokeWidth / 2);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(deflated, 0, math.pi * 2, false, track);
    if (value <= 0) return;
    final progress = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    canvas.drawArc(
      deflated,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      progress,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}

/// A white rounded group of rows, like iOS settings.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.children, this.title, super.key});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(const Divider(height: 1, indent: 64));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 6, bottom: 8),
            child: Text(
              title!,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppColors.inkSubtle),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            child: Column(children: rows),
          ),
        ),
      ],
    );
  }
}

/// One row inside a [SettingsGroup].
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
    this.trailing,
    this.iconColor = AppColors.primary,
    this.destructive = false,
    this.valueBelow = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color iconColor;
  final bool destructive;

  /// Shows [value] under the title, for long titles on narrow screens.
  final bool valueBelow;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayoutTokens.of(context);
    final text = Theme.of(context).textTheme;
    final color = destructive ? AppColors.danger : iconColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: layout.rowMinHeight - 4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withAlpha(24),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: text.titleMedium?.copyWith(
                          color: destructive ? AppColors.danger : AppColors.ink,
                        ),
                      ),
                      if (valueBelow && value != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          value!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
                if (!valueBelow && value != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 2,
                    child: Text(
                      value!,
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium,
                    ),
                  ),
                ],
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
                if (trailing == null && onTap != null) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.inkSubtle,
                    textDirection: null,
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

/// Friendly empty state with one primary and one optional secondary action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: text.headlineSmall),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: text.bodyMedium),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPrimary,
              icon: const Icon(Icons.add_rounded),
              label: Text(primaryLabel),
            ),
          ),
          if (secondaryLabel != null) ...[
            const SizedBox(height: 4),
            TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
          ],
        ],
      ),
    );
  }
}

/// Wraps a choice in a selectable pill.
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: 18,
              color: selected ? AppColors.primaryDark : AppColors.inkMuted,
            ),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: selected ? AppColors.primaryDark : AppColors.ink,
      ),
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.border,
        width: selected ? 1.4 : 1,
      ),
    );
  }
}
