import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/app_models.dart';
import '../../domain/app_store.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../bidi.dart';

/// Shared dose actions used by Today, Medicines, and the assistant, so every
/// entry point records doses the same way.
abstract final class DoseActions {
  static void markTaken(
    BuildContext context,
    AppStore store,
    DoseOccurrence dose,
  ) {
    final s = AppStrings.of(context);
    final name = store.medicationFor(dose.medicationId).name;
    store.markTaken(dose.id);
    _snack(
      context,
      s.takenSnack(name),
      action: SnackBarAction(
        label: s.undo,
        onPressed: () => store.undoDose(dose.id),
      ),
    );
  }

  static void snooze(
    BuildContext context,
    AppStore store,
    DoseOccurrence dose,
  ) {
    store.snoozeDose(dose.id);
    _snack(context, AppStrings.of(context).snoozedSnack);
  }

  static void undo(BuildContext context, AppStore store, DoseOccurrence dose) {
    store.undoDose(dose.id);
    _snack(context, AppStrings.of(context).undoneSnack);
  }

  /// Asks why the dose was missed, records it, then explains that nothing was
  /// moved automatically.
  static Future<void> markMissed(
    BuildContext context,
    AppStore store,
    DoseOccurrence dose, {
    ValueChanged<String>? onAsk,
  }) async {
    final s = AppStrings.of(context);
    final medication = store.medicationFor(dose.medicationId);
    final reason = await showAppSheet<String>(
      context: context,
      builder: (context) => _MissedReasonSheet(medicationName: medication.name),
    );
    if (reason == null || !context.mounted) return;
    store.markMissed(dose.id, reason);
    store.dismissProposal();
    final ask = await showAppSheet<bool>(
      context: context,
      builder: (context) => _MissedRecordedSheet(canAsk: onAsk != null),
    );
    if (ask == true && onAsk != null) {
      onAsk(s.missedPrompt(medication.name, reason));
    }
  }

  static void _snack(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }
}

/// Details and actions for one dose.
Future<void> showDoseSheet(
  BuildContext context, {
  required AppStore store,
  required DoseOccurrence dose,
  ValueChanged<String>? onAsk,
}) {
  return showAppSheet<void>(
    context: context,
    builder: (sheetContext) => AnimatedBuilder(
      animation: store,
      builder: (sheetContext, _) {
        final current = store.doseFor(dose.id);
        final medication = store.medicationFor(current.medicationId);
        final s = AppStrings.of(sheetContext);
        final timing = store.timingOf(current);
        final isFuture = current.scheduledAt.isAfter(
          store.now.add(const Duration(hours: 2)),
        );
        final recorded =
            timing == DoseTiming.taken || timing == DoseTiming.missed;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetHeader(
                  leading: MedicineAvatar(
                    form: medication.form,
                    colorSeed: medication.colorSeed,
                    size: 52,
                  ),
                  title: medication.displayName,
                  subtitle:
                      '${isolate(medication.doseLabel)} · ${s.time(current.scheduledAt)}',
                ),
                const SizedBox(height: 14),
                _DoseStatusLine(store: store, dose: current),
                if (medication.instructions.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: AppColors.inkSubtle,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          medication.instructions,
                          textDirection: directionOf(medication.instructions),
                          textAlign: ambientStart(sheetContext),
                          style: Theme.of(sheetContext).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                if (recorded)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      DoseActions.undo(context, store, current);
                    },
                    icon: const Icon(Icons.undo_rounded),
                    label: Text(s.undoRecord),
                  )
                else if (isFuture)
                  Text(
                    s.loggableLater,
                    textAlign: TextAlign.center,
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  )
                else ...[
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      DoseActions.markTaken(context, store, current);
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: Text(s.iTookIt),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            DoseActions.snooze(context, store, current);
                          },
                          child: Text(
                            s.remindIn10,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            DoseActions.markMissed(
                              context,
                              store,
                              current,
                              onAsk: onAsk,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                          ),
                          child: Text(s.iMissedIt),
                        ),
                      ),
                    ],
                  ),
                ],
                if (onAsk != null) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      onAsk(s.askAboutPrompt(medication.name));
                    },
                    style: TextButton.styleFrom(foregroundColor: AppColors.ai),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                    label: Text(s.askAboutIt),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _DoseStatusLine extends StatelessWidget {
  const _DoseStatusLine({required this.store, required this.dose});

  final AppStore store;
  final DoseOccurrence dose;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final (label, color, icon) = switch (store.timingOf(dose)) {
      DoseTiming.taken => (
        s.takenAt(dose.actualAt ?? dose.scheduledAt),
        AppColors.primary,
        Icons.check_circle_rounded,
      ),
      DoseTiming.missed => (
        s.statusMissed,
        AppColors.danger,
        Icons.cancel_rounded,
      ),
      DoseTiming.dueNow => (
        s.dueNow,
        AppColors.amber,
        Icons.notifications_active_rounded,
      ),
      DoseTiming.overdue => (
        s.overdue,
        AppColors.amber,
        Icons.schedule_rounded,
      ),
      DoseTiming.upcoming => (
        s.upcoming,
        AppColors.inkMuted,
        Icons.schedule_rounded,
      ),
    };
    final original = dose.originalScheduledAt;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Pill(label: label, color: color, icon: icon),
        if (dose.status == DoseStatus.snoozed)
          _Pill(
            label: s.statusSnoozed,
            color: AppColors.amber,
            icon: Icons.snooze_rounded,
          ),
        if (original != null && dose.status != DoseStatus.snoozed)
          _Pill(
            label: s.originally(original),
            color: AppColors.ai,
            icon: Icons.update_rounded,
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, required this.icon});

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _MissedReasonSheet extends StatefulWidget {
  const _MissedReasonSheet({required this.medicationName});

  final String medicationName;

  @override
  State<_MissedReasonSheet> createState() => _MissedReasonSheetState();
}

class _MissedReasonSheetState extends State<_MissedReasonSheet> {
  String? _reason;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final reasons = [
      s.reasonAsleep,
      s.reasonForgot,
      s.reasonAway,
      s.reasonUnwell,
      s.reasonRanOut,
    ];
    _reason ??= reasons.first;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(title: s.whyMissed, subtitle: widget.medicationName),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final reason in reasons)
                  ChoicePill(
                    label: reason,
                    selected: _reason == reason,
                    onTap: () => setState(() => _reason = reason),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.amberSoft,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.amber,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.noDoubleDose,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pop(context, _reason),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: Text(s.recordMissed),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissedRecordedSheet extends StatelessWidget {
  const _MissedRecordedSheet({required this.canAsk});

  final bool canAsk;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(
              leading: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.primary,
                ),
              ),
              title: s.missedRecordedTitle,
            ),
            const SizedBox(height: 14),
            Text(
              s.missedRecordedBody,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            if (canAsk) ...[
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: AppColors.ai),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(s.askPillAi),
              ),
              const SizedBox(height: 6),
            ],
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.gotIt),
            ),
          ],
        ),
      ),
    );
  }
}

/// Before/after review for AI-proposed reminder changes. Returns true to apply.
Future<bool?> showProposalSheet(
  BuildContext context,
  RescheduleProposal proposal,
) {
  return showAppSheet<bool>(
    context: context,
    builder: (sheetContext) {
      final s = AppStrings.of(sheetContext);
      final text = Theme.of(sheetContext).textTheme;
      final changes = proposal.allChanges;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeader(
                leading: const PillAiMark(size: 44),
                title: s.reviewChanges(changes.length),
              ),
              if (proposal.safetyNote.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(proposal.safetyNote, style: text.bodyMedium),
              ],
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: changes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final change = changes[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.aiSoft,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            change.medicationName,
                            textDirection: directionOf(change.medicationName),
                            style: text.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                s.time(change.from),
                                style: text.bodyLarge?.copyWith(
                                  color: AppColors.inkSubtle,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: AppColors.ai,
                                ),
                              ),
                              Text(
                                s.time(change.to),
                                style: text.titleMedium?.copyWith(
                                  color: AppColors.ai,
                                ),
                              ),
                            ],
                          ),
                          if (change.reason.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              change.reason,
                              textDirection: directionOf(change.reason),
                              style: text.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext, true),
                child: Text(s.applyChanges),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                child: Text(s.keepCurrentTimes),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Saudi emergency numbers with one-tap calling.
Future<void> showEmergencySheet(BuildContext context) {
  return showAppSheet<void>(
    context: context,
    builder: (sheetContext) {
      final s = AppStrings.of(sheetContext);
      final text = Theme.of(sheetContext).textTheme;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeader(
                leading: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: AppColors.dangerSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emergency_rounded,
                    color: AppColors.danger,
                    size: 28,
                  ),
                ),
                title: s.emergencyTitle,
              ),
              const SizedBox(height: 14),
              Text(s.emergencyBody, style: text.bodyLarge),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => callNumber(sheetContext, '997'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                icon: const Icon(Icons.call_rounded),
                label: Text(s.callAmbulance),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => callNumber(sheetContext, '911'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(color: AppColors.danger.withAlpha(110)),
                ),
                icon: const Icon(Icons.call_rounded),
                label: Text(s.callEmergency),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => callNumber(sheetContext, '937'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.inkMuted,
                ),
                icon: const Icon(Icons.support_agent_rounded),
                label: Text(s.callMoh),
              ),
              const SizedBox(height: 6),
              Text(
                s.keepPackages,
                textAlign: TextAlign.center,
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> callNumber(BuildContext context, String number) async {
  final failed = AppStrings.of(context).callFailed(number);
  final messenger = ScaffoldMessenger.maybeOf(context);
  var opened = false;
  try {
    opened = await launchUrl(Uri(scheme: 'tel', path: number));
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    messenger?.showSnackBar(SnackBar(content: Text(failed)));
  }
}
