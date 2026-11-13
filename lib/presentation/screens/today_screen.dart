import 'package:flutter/material.dart';

import '../../domain/app_models.dart';
import '../../domain/app_store.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'dose_sheets.dart';
import '../bidi.dart';

/// The home screen: what to take now, then the rest of the day.
class TodayScreen extends StatefulWidget {
  const TodayScreen({
    required this.store,
    required this.onOpenAssistant,
    required this.onStartVoice,
    required this.onAddMedicine,
    required this.onOpenProfile,
    super.key,
  });

  final AppStore store;
  final ValueChanged<String?> onOpenAssistant;
  final VoidCallback onStartVoice;
  final VoidCallback onAddMedicine;
  final VoidCallback onOpenProfile;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  DateTime? _selectedDay;

  AppStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final s = AppStrings.of(context);
        final simple = store.isSimpleMode;
        final today = store.today;
        final day = simple ? today : (_selectedDay ?? today);
        final isToday = DateUtils.isSameDay(day, today);
        final hasMedicines = store.medications.isNotEmpty;
        final doses = store.dosesOn(day);
        final next = store.nextDose;

        return SafeArea(
          bottom: false,
          child: CustomScrollView(
            key: const PageStorageKey('today-scroll'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                sliver: SliverList.list(
                  children: [
                    _Header(
                      date: s.dateLong(store.now),
                      greeting: s.greeting(store.now, store.profile.name),
                      name: store.profile.name,
                      onAvatar: widget.onOpenProfile,
                    ),
                    const SizedBox(height: 18),
                    // Standard mode leads with the assistant. Simple mode
                    // leads with the dose to take now: with large text the
                    // first screen must show the one action that matters.
                    if (!simple) ...[
                      AskBar(
                        hint: s.askBarHint,
                        micTooltip: s.speak,
                        onTap: () => widget.onOpenAssistant(null),
                        onMic: widget.onStartVoice,
                      ),
                      const SizedBox(height: 22),
                    ],
                    if (!hasMedicines)
                      EmptyState(
                        icon: Icons.medication_rounded,
                        title: s.setupTitle,
                        body: s.setupBody,
                        primaryLabel: s.addMedicine,
                        onPrimary: widget.onAddMedicine,
                        secondaryLabel: s.trySamplePlan,
                        onSecondary: store.loadSamplePlan,
                      )
                    else ...[
                      if (isToday && next != null)
                        _NextDoseCard(
                          store: store,
                          dose: next,
                          onAsk: widget.onOpenAssistant,
                        )
                      else if (isToday && store.totalToday > 0)
                        _AllDoneCard(store: store),
                      if (isToday && store.totalToday > 0)
                        const SizedBox(height: 22),
                    ],
                    if (simple) ...[
                      _SimpleAskButtons(
                        onSpeak: widget.onStartVoice,
                        onType: () => widget.onOpenAssistant(null),
                      ),
                      const SizedBox(height: 22),
                    ],
                    if (hasMedicines) ...[
                      if (!simple) ...[
                        _DayStrip(
                          store: store,
                          selected: day,
                          onSelected: (value) =>
                              setState(() => _selectedDay = value),
                        ),
                        const SizedBox(height: 18),
                      ],
                      _DayTitle(
                        title: isToday
                            ? s.todayLabel
                            : s.relativeDay(day, today),
                        doses: doses,
                      ),
                      const SizedBox(height: 10),
                      if (doses.isEmpty)
                        _EmptyDay(label: s.noDosesThisDay)
                      else
                        _DoseList(
                          store: store,
                          doses: doses,
                          onAsk: widget.onOpenAssistant,
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.date,
    required this.greeting,
    required this.name,
    required this.onAvatar,
  });

  final String date;
  final String greeting;
  final String name;
  final VoidCallback onAvatar;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final initial = name.trim().isEmpty
        ? null
        : name.trim().characters.first.toUpperCase();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date,
                style: text.labelLarge?.copyWith(color: AppColors.inkSubtle),
              ),
              const SizedBox(height: 4),
              Semantics(
                header: true,
                child: Text(greeting, style: text.headlineMedium),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          label: AppStrings.of(context).tabProfile,
          child: InkWell(
            onTap: onAvatar,
            customBorder: const CircleBorder(),
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: initial == null
                  ? const Icon(Icons.person_rounded, color: AppColors.primary)
                  : Text(
                      initial,
                      style: text.titleLarge?.copyWith(
                        color: AppColors.primaryDark,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SimpleAskButtons extends StatelessWidget {
  const _SimpleAskButtons({required this.onSpeak, required this.onType});

  final VoidCallback onSpeak;
  final VoidCallback onType;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.aiSoft,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const PillAiMark(size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  s.talkToPillAi,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onSpeak,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.ai),
                  icon: const Icon(Icons.mic_rounded),
                  label: Text(s.speak),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onType,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                  ),
                  icon: const Icon(Icons.keyboard_rounded),
                  label: Text(s.typeMessage),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NextDoseCard extends StatelessWidget {
  const _NextDoseCard({
    required this.store,
    required this.dose,
    required this.onAsk,
  });

  final AppStore store;
  final DoseOccurrence dose;
  final ValueChanged<String?> onAsk;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final text = Theme.of(context).textTheme;
    final medication = store.medicationFor(dose.medicationId);
    final timing = store.timingOf(dose);
    final (chipLabel, chipIcon) = switch (timing) {
      DoseTiming.dueNow => (s.dueNow, Icons.notifications_active_rounded),
      DoseTiming.overdue => (s.overdue, Icons.schedule_rounded),
      _ => (s.nextDose, Icons.schedule_rounded),
    };
    final urgent = timing == DoseTiming.dueNow || timing == DoseTiming.overdue;
    final details = [
      isolate(medication.doseLabel),
      if (medication.strength.trim().isNotEmpty) isolate(medication.strength),
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.floating,
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: urgent
                          ? const Color(0xFFFFD58A)
                          : Colors.white.withAlpha(40),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          chipIcon,
                          size: 16,
                          color: urgent
                              ? const Color(0xFF6B3F00)
                              : Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            chipLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelMedium?.copyWith(
                              color: urgent
                                  ? const Color(0xFF6B3F00)
                                  : Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Scales down instead of overflowing at very large text sizes.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    s.time(dose.scheduledAt),
                    style: text.titleLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medication.name,
                      textDirection: directionOf(medication.name),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.headlineMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      details,
                      style: text.bodyLarge?.copyWith(
                        color: Colors.white.withAlpha(215),
                      ),
                    ),
                    if (medication.instructions.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        medication.instructions,
                        textDirection: directionOf(medication.instructions),
                        textAlign: ambientStart(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(
                          color: Colors.white.withAlpha(180),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(36),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(6),
                child: MedicationGlyph(
                  type: switch (medication.form) {
                    MedicationForm.tablet => MedicationGlyphType.tablet,
                    MedicationForm.liquid ||
                    MedicationForm.injection => MedicationGlyphType.bottle,
                    _ => MedicationGlyphType.capsule,
                  },
                  size: 64,
                  primaryColor: AppColors.medicineColor(medication.colorSeed),
                  backgroundColor: Colors.white,
                  semanticLabel: medication.name,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => DoseActions.markTaken(context, store, dose),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryDark,
            ),
            icon: const Icon(Icons.check_rounded),
            label: Text(store.isSimpleMode ? s.iTookIt : s.taken),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _HeroSecondaryButton(
                  icon: Icons.snooze_rounded,
                  label: s.later,
                  onPressed: () => DoseActions.snooze(context, store, dose),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroSecondaryButton(
                  icon: Icons.close_rounded,
                  label: s.missed,
                  onPressed: () => DoseActions.markMissed(
                    context,
                    store,
                    dose,
                    onAsk: onAsk,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroSecondaryButton extends StatelessWidget {
  const _HeroSecondaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final simple = AppLayoutTokens.of(context).isSimple;
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.white.withAlpha(34),
        minimumSize: Size(48, simple ? 58 : 48),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label),
    );
  }
}

class _AllDoneCard extends StatelessWidget {
  const _AllDoneCard({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Row(
        children: [
          ProgressRing(
            value: store.adherenceToday,
            size: 56,
            strokeWidth: 6,
            trackColor: Colors.white,
            child: const Icon(Icons.check_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.allDoneTitle, style: text.titleLarge),
                const SizedBox(height: 2),
                Text(s.allDoneBody, style: text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.store,
    required this.selected,
    required this.onSelected,
  });

  final AppStore store;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final today = store.today;
    final days = [
      for (var offset = -3; offset <= 3; offset++)
        DateTime(today.year, today.month, today.day + offset),
    ];
    return Row(
      children: [
        for (final day in days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: _DayChip(
                weekday: s.weekdayShort(day),
                day: day.day,
                selected: DateUtils.isSameDay(day, selected),
                isToday: DateUtils.isSameDay(day, today),
                marker: _markerFor(day, today),
                semanticLabel: s.dateLong(day),
                onTap: () => onSelected(day),
              ),
            ),
          ),
      ],
    );
  }

  Color? _markerFor(DateTime day, DateTime today) {
    if (!day.isBefore(today)) return null;
    final doses = store.dosesOn(day);
    if (doses.isEmpty) return null;
    final allTaken = doses.every((dose) => dose.status == DoseStatus.taken);
    return allTaken ? AppColors.primary : AppColors.amber;
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.weekday,
    required this.day,
    required this.selected,
    required this.isToday,
    required this.marker,
    required this.semanticLabel,
    required this.onTap,
  });

  final String weekday;
  final int day;
  final bool selected;
  final bool isToday;
  final Color? marker;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final foreground = selected ? Colors.white : AppColors.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(
            color: selected
                ? AppColors.primary
                : isToday
                ? AppColors.primary.withAlpha(120)
                : AppColors.border,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: SizedBox(
            height: 70,
            child: ExcludeSemantics(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    child: Text(
                      weekday,
                      style: text.labelSmall?.copyWith(
                        color: selected
                            ? Colors.white.withAlpha(210)
                            : AppColors.inkSubtle,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$day',
                    style: text.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: marker == null
                          ? Colors.transparent
                          : selected
                          ? Colors.white
                          : marker,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayTitle extends StatelessWidget {
  const _DayTitle({required this.title, required this.doses});

  final String title;
  final List<DoseOccurrence> doses;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final text = Theme.of(context).textTheme;
    final done = doses.where((dose) => dose.status == DoseStatus.taken).length;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: text.titleLarge),
          ),
        ),
        if (doses.isNotEmpty) ...[
          Text(
            s.progress(done, doses.length),
            style: text.labelLarge?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(width: 8),
          ProgressRing(value: done / doses.length, size: 22, strokeWidth: 3.5),
        ],
      ],
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_available_rounded,
            color: AppColors.inkSubtle,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _DoseList extends StatelessWidget {
  const _DoseList({
    required this.store,
    required this.doses,
    required this.onAsk,
  });

  final AppStore store;
  final List<DoseOccurrence> doses;
  final ValueChanged<String?> onAsk;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Column(
          children: [
            for (var i = 0; i < doses.length; i++) ...[
              _DoseRow(store: store, dose: doses[i], onAsk: onAsk),
              if (i < doses.length - 1)
                const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _DoseRow extends StatelessWidget {
  const _DoseRow({
    required this.store,
    required this.dose,
    required this.onAsk,
  });

  final AppStore store;
  final DoseOccurrence dose;
  final ValueChanged<String?> onAsk;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final text = Theme.of(context).textTheme;
    final layout = AppLayoutTokens.of(context);
    final medication = store.medicationFor(dose.medicationId);
    final timing = store.timingOf(dose);
    final (status, statusColor) = switch (timing) {
      DoseTiming.taken => (
        s.takenAt(dose.actualAt ?? dose.scheduledAt),
        AppColors.primary,
      ),
      DoseTiming.missed => (s.statusMissed, AppColors.danger),
      DoseTiming.dueNow => (s.dueNow, AppColors.amber),
      DoseTiming.overdue => (s.overdue, AppColors.amber),
      DoseTiming.upcoming => (null, AppColors.inkMuted),
    };
    final done = timing == DoseTiming.taken || timing == DoseTiming.missed;

    return InkWell(
      onTap: () => showDoseSheet(
        context,
        store: store,
        dose: dose,
        onAsk: (prompt) => onAsk(prompt),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: layout.rowMinHeight + 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: layout.isSimple ? 92 : 74,
                child: Text(
                  s.time(dose.scheduledAt),
                  style: text.labelLarge?.copyWith(
                    color: done ? AppColors.inkSubtle : AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!layout.isSimple) ...[
                MedicineAvatar(
                  form: medication.form,
                  colorSeed: medication.colorSeed,
                  size: 40,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medication.name,
                      textDirection: directionOf(medication.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(
                        color: done ? AppColors.inkMuted : AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          // A status replaces the dose so the line never
                          // truncates on small phones.
                          if (status == null || timing == DoseTiming.missed)
                            TextSpan(text: isolate(medication.doseLabel)),
                          if (timing == DoseTiming.missed)
                            const TextSpan(text: ' · '),
                          if (status != null) ...[
                            TextSpan(
                              text: status,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusButton(store: store, dose: dose, timing: timing),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.store,
    required this.dose,
    required this.timing,
  });

  final AppStore store;
  final DoseOccurrence dose;
  final DoseTiming timing;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final simple = AppLayoutTokens.of(context).isSimple;
    final size = simple ? 50.0 : 40.0;
    final name = store.medicationFor(dose.medicationId).name;
    final tooFarAhead = dose.scheduledAt.isAfter(
      store.now.add(const Duration(hours: 2)),
    );

    final (Color fill, Color border, Widget? icon) = switch (timing) {
      DoseTiming.taken => (
        AppColors.primary,
        AppColors.primary,
        const Icon(Icons.check_rounded, color: Colors.white),
      ),
      DoseTiming.missed => (
        AppColors.dangerSoft,
        AppColors.dangerSoft,
        const Icon(Icons.close_rounded, color: AppColors.danger),
      ),
      DoseTiming.dueNow || DoseTiming.overdue => (
        AppColors.amberSoft,
        AppColors.amber,
        Icon(Icons.check_rounded, color: AppColors.amber.withAlpha(120)),
      ),
      DoseTiming.upcoming => (Colors.transparent, AppColors.disabled, null),
    };

    void onTap() {
      switch (timing) {
        case DoseTiming.taken:
        case DoseTiming.missed:
          DoseActions.undo(context, store, dose);
        case DoseTiming.dueNow:
        case DoseTiming.overdue:
        case DoseTiming.upcoming:
          if (tooFarAhead) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(s.loggableLater)));
          } else {
            DoseActions.markTaken(context, store, dose);
          }
      }
    }

    return Semantics(
      button: true,
      checked: timing == DoseTiming.taken,
      label: timing == DoseTiming.taken
          ? '${s.undo}: $name'
          : '${s.iTookIt}: $name',
      child: InkResponse(
        onTap: onTap,
        radius: size * .75,
        child: AnimatedContainer(
          duration: AppDurations.regular,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 2.2),
          ),
          child: icon,
        ),
      ),
    );
  }
}
