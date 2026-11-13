import 'package:flutter/material.dart';

import '../../domain/app_models.dart';
import '../../domain/app_store.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'add_medication_sheet.dart';
import '../bidi.dart';

/// Every medicine on record, with its times and course.
class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({
    required this.store,
    required this.onAddMedicine,
    required this.onAsk,
    super.key,
  });

  final AppStore store;
  final VoidCallback onAddMedicine;
  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final s = AppStrings.of(context);
        final medications = store.medications;
        return SafeArea(
          bottom: false,
          child: CustomScrollView(
            key: const PageStorageKey('medicines-scroll'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                sliver: SliverList.list(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              s.medicinesTitle,
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                          ),
                        ),
                        if (medications.isNotEmpty)
                          FilledButton.tonalIcon(
                            onPressed: onAddMedicine,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primarySoft,
                              foregroundColor: AppColors.primaryDark,
                              minimumSize: const Size(0, 44),
                            ),
                            icon: const Icon(Icons.add_rounded),
                            label: Text(s.add),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (medications.isEmpty)
                      EmptyState(
                        icon: Icons.medication_rounded,
                        title: s.noMedicinesTitle,
                        body: s.setupBody,
                        primaryLabel: s.addMedicine,
                        onPrimary: onAddMedicine,
                        secondaryLabel: s.trySamplePlan,
                        onSecondary: store.loadSamplePlan,
                      )
                    else
                      for (final medication in medications)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _MedicationCard(
                            store: store,
                            medication: medication,
                            onTap: () => _showDetails(context, medication),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDetails(BuildContext context, Medication medication) {
    return showAppSheet<void>(
      context: context,
      builder: (sheetContext) => _MedicationDetails(
        store: store,
        medicationId: medication.id,
        onAsk: onAsk,
        // The sheet closes first, so the editor opens from this screen.
        onEdit: (current) =>
            showMedicationEditor(context, store: store, medication: current),
      ),
    );
  }
}

String _scheduleSummary(AppStrings s, Medication medication) {
  final schedule = medication.schedule;
  final times = schedule?.times ?? const <int>[];
  return [
    isolate(medication.doseLabel),
    s.timesPerDay(times.length),
  ].where((part) => part.trim().isNotEmpty).join(' · ');
}

String? _courseLabel(AppStrings s, Medication medication, DateTime today) {
  final schedule = medication.schedule;
  if (schedule == null || schedule.isAsNeeded) return null;
  final left = schedule.daysLeft(today);
  return left == null ? s.ongoing : s.daysLeft(left);
}

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({
    required this.store,
    required this.medication,
    required this.onTap,
  });

  final AppStore store;
  final Medication medication;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final text = Theme.of(context).textTheme;
    final times = medication.schedule?.times ?? const <int>[];
    final course = _courseLabel(s, medication, store.today);
    final finished = medication.schedule?.daysLeft(store.today) == 0;

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MedicineAvatar(
                form: medication.form,
                colorSeed: medication.colorSeed,
                size: 48,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            medication.displayName,
                            textDirection: directionOf(medication.displayName),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium?.copyWith(
                              color: finished
                                  ? AppColors.inkSubtle
                                  : AppColors.ink,
                            ),
                          ),
                        ),
                        if (medication.isPrescription) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: s.prescription,
                            child: const Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _scheduleSummary(s, medication),
                      style: text.bodyMedium,
                    ),
                    if (times.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final minutes in times)
                            _TimeTag(label: s.timeOfMinutes(minutes)),
                          if (course != null)
                            _TimeTag(label: course, muted: true),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.inkSubtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeTag extends StatelessWidget {
  const _TimeTag({required this.label, this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: muted ? AppColors.surfaceMuted : AppColors.primaryFaint,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: muted ? AppColors.inkMuted : AppColors.primaryDark,
        ),
      ),
    );
  }
}

class _MedicationDetails extends StatelessWidget {
  const _MedicationDetails({
    required this.store,
    required this.medicationId,
    required this.onAsk,
    required this.onEdit,
  });

  final AppStore store;
  final String medicationId;
  final ValueChanged<String> onAsk;
  final ValueChanged<Medication> onEdit;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final medication = store.medicationOrNull(medicationId);
        if (medication == null) return const SizedBox(height: 120);
        final s = AppStrings.of(context);
        final text = Theme.of(context).textTheme;
        final schedule = medication.schedule;
        final course = _courseLabel(s, medication, store.today);
        final end = schedule?.endDate;

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                SheetHeader(
                  leading: MedicineAvatar(
                    form: medication.form,
                    colorSeed: medication.colorSeed,
                    size: 56,
                  ),
                  title: medication.displayName,
                  subtitle: _scheduleSummary(s, medication),
                ),
                const SizedBox(height: 18),
                if (schedule != null && schedule.times.isNotEmpty)
                  _DetailRow(
                    icon: Icons.alarm_rounded,
                    label: s.times,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final minutes in schedule.times)
                          _TimeTag(label: s.timeOfMinutes(minutes)),
                      ],
                    ),
                  ),
                if (course != null)
                  _DetailRow(
                    icon: Icons.event_rounded,
                    label: s.course,
                    child: Text(
                      end == null ? course : '$course · ${s.until(end)}',
                      style: text.bodyLarge,
                    ),
                  ),
                if (medication.instructions.trim().isNotEmpty)
                  _DetailRow(
                    icon: Icons.info_outline_rounded,
                    label: s.instructions,
                    child: Text(
                      medication.instructions,
                      textDirection: directionOf(medication.instructions),
                      textAlign: ambientStart(context),
                      style: text.bodyLarge,
                    ),
                  ),
                if (medication.activeIngredients.isNotEmpty)
                  _DetailRow(
                    icon: Icons.science_outlined,
                    label: s.activeIngredients,
                    child: Text(
                      medication.activeIngredients.join(
                        s.isArabic ? '، ' : ', ',
                      ),
                      textDirection: directionOf(
                        medication.activeIngredients.first,
                      ),
                      style: text.bodyLarge,
                    ),
                  ),
                if (medication.isPrescription)
                  _DetailRow(
                    icon: Icons.verified_rounded,
                    label: s.prescription,
                    child: Text(s.prescribedByDoctor, style: text.bodyLarge),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onEdit(medication);
                  },
                  icon: const Icon(Icons.edit_rounded),
                  label: Text(s.edit),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onAsk(s.askAboutPrompt(medication.name));
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ai,
                  ),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: Text(s.askAboutIt),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () => _confirmDelete(context, medication),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(s.delete),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Medication medication,
  ) async {
    final s = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.deleteMedicineTitle(medication.name)),
        content: Text(s.deleteMedicineBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    Navigator.pop(context);
    store.removeMedication(medication.id);
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.inkSubtle),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
