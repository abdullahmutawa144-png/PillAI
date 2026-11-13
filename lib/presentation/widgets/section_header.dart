import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.trailing,
  }) : assert(
         trailing == null || actionLabel == null,
         'Use either trailing or actionLabel, not both.',
       );

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final layout = AppLayoutTokens.of(context);

    final Widget? resolvedTrailing =
        trailing ??
        (actionLabel == null
            ? null
            : TextButton(
                onPressed: onAction,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(actionLabel!),
                    const SizedBox(width: AppSpacing.xxs),
                    const Icon(Icons.chevron_right_rounded, size: 20),
                  ],
                ),
              ));

    final titleBlock = Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: textTheme.titleLarge),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xxs),
            Text(subtitle!, style: textTheme.bodyMedium),
          ],
        ],
      ),
    );

    if (layout.isSimple && resolvedTrailing != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleBlock,
          const SizedBox(height: AppSpacing.xs),
          resolvedTrailing,
        ],
      );
    }

    return Row(
      crossAxisAlignment: subtitle == null
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: titleBlock),
        if (resolvedTrailing != null) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          resolvedTrailing,
        ],
      ],
    );
  }
}
