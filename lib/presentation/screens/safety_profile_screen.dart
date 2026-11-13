import 'package:flutter/material.dart';

import '../../data/safety_options.dart';
import '../../domain/app_models.dart';
import '../../domain/app_store.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

Future<void> openHealthProfile(BuildContext context, AppStore store) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (context) => SafetyProfileScreen(store: store)),
  );
}

/// The structured health record the assistant reads instead of chat history.
class SafetyProfileScreen extends StatelessWidget {
  const SafetyProfileScreen({required this.store, super.key});

  final AppStore store;

  static const _ageOptions = [
    'Under 12',
    '12-17',
    '18-39',
    '40-64',
    '65-74',
    '75 or older',
    'Prefer not to answer',
  ];
  static const _sexOptions = [
    'Not added',
    'Female',
    'Male',
    'Prefer not to answer',
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final s = AppStrings.of(context);
        final safety = store.safetyContext;
        final profile = store.profile;

        return Scaffold(
          appBar: AppBar(title: Text(s.healthProfile)),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _ProgressHeader(
                  safety: safety,
                  onContinue: () => _openNextMissing(context),
                ),
                const SizedBox(height: 22),
                SettingsGroup(
                  title: s.groupBody,
                  children: [
                    _row(
                      icon: Icons.cake_rounded,
                      title: s.ageAndWeight,
                      value: _ageSummary(s),
                      done: safety.ageRange != 'Not added',
                      onTap: () => _editAgeAndBody(context),
                    ),
                    _row(
                      icon: Icons.pregnant_woman_rounded,
                      title: s.pregnancy,
                      value: s.reproductiveLabel(safety.reproductiveStatus),
                      done:
                          safety.reproductiveStatus !=
                          ReproductiveStatus.notAnswered,
                      onTap: () => _editReproductive(context),
                    ),
                    _row(
                      icon: Icons.water_drop_rounded,
                      title: s.kidneys,
                      value: s.organLabel(safety.kidneyStatus, kidney: true),
                      done: safety.kidneyStatus != ProfileAnswer.notAnswered,
                      onTap: () => _editOrgan(context, kidney: true),
                    ),
                    _row(
                      icon: Icons.monitor_heart_rounded,
                      title: s.liver,
                      value: s.organLabel(safety.liverStatus, kidney: false),
                      done: safety.liverStatus != ProfileAnswer.notAnswered,
                      onTap: () => _editOrgan(context, kidney: false),
                    ),
                    _row(
                      icon: Icons.medical_information_rounded,
                      title: s.conditions,
                      value: _listSummary(s, profile.conditions),
                      done: !_isPlaceholder(profile.conditions),
                      onTap: () => _editList(context, allergies: false),
                    ),
                    _row(
                      icon: Icons.warning_amber_rounded,
                      title: s.allergies,
                      value: _listSummary(s, profile.allergies),
                      done: !_isPlaceholder(profile.allergies),
                      onTap: () => _editList(context, allergies: true),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SettingsGroup(
                  title: s.groupDaily,
                  children: [
                    _row(
                      icon: Icons.restaurant_rounded,
                      title: s.foodAndDrinks,
                      value: _selectionSummary(
                        s,
                        safety.foodAndDrinkFactors,
                        safety.foodAndDrinkReviewed,
                      ),
                      done: safety.foodAndDrinkReviewed,
                      onTap: () => _editSelection(context, _Selection.food),
                    ),
                    _row(
                      icon: Icons.medication_liquid_rounded,
                      title: s.supplements,
                      value: _selectionSummary(
                        s,
                        safety.supplementsAndOtc,
                        safety.supplementsReviewed,
                      ),
                      done: safety.supplementsReviewed,
                      onTap: () =>
                          _editSelection(context, _Selection.supplements),
                    ),
                    _row(
                      icon: Icons.self_improvement_rounded,
                      title: s.lifestyle,
                      value: _selectionSummary(
                        s,
                        safety.lifestyleFactors,
                        safety.lifestyleReviewed,
                      ),
                      done: safety.lifestyleReviewed,
                      onTap: () =>
                          _editSelection(context, _Selection.lifestyle),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SettingsGroup(
                  title: s.groupSupport,
                  children: [
                    _row(
                      icon: Icons.accessibility_new_rounded,
                      title: s.accessibility,
                      value: _selectionSummary(
                        s,
                        safety.accessibilityNeeds,
                        safety.accessibilityReviewed,
                      ),
                      done: safety.accessibilityReviewed,
                      onTap: () =>
                          _editSelection(context, _Selection.accessibility),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row({
    required IconData icon,
    required String title,
    required String value,
    required bool done,
    required VoidCallback onTap,
  }) {
    return SettingsTile(
      icon: icon,
      iconColor: done ? AppColors.primary : AppColors.inkSubtle,
      title: title,
      value: value,
      valueBelow: true,
      onTap: onTap,
      trailing: done
          ? const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primary,
              size: 22,
            )
          : const Icon(Icons.chevron_right_rounded, color: AppColors.inkSubtle),
    );
  }

  String _ageSummary(AppStrings s) {
    final age = store.safetyContext.ageRange;
    final weight = store.profile.weightLabel;
    if (age == 'Not added') return s.notSet;
    return [s.storedValue(age), if (weight != 'Not added') weight].join(' · ');
  }

  bool _isPlaceholder(List<String> values) {
    if (values.isEmpty) return true;
    return values.every((value) {
      final lower = value.toLowerCase();
      return lower.startsWith('no ') && lower.endsWith(' recorded');
    });
  }

  String _listSummary(AppStrings s, List<String> values) {
    if (_isPlaceholder(values)) return s.noneRecorded;
    return values.join(s.isArabic ? '، ' : ', ');
  }

  String _selectionSummary(AppStrings s, List<String> values, bool reviewed) {
    if (!reviewed) return s.notSet;
    if (values.isEmpty) return s.noneSelected;
    final first = s.storedValue(values.first);
    return values.length == 1 ? first : s.andMore(first, values.length - 1);
  }

  Future<void> _openNextMissing(BuildContext context) async {
    final safety = store.safetyContext;
    if (safety.ageRange == 'Not added') {
      await _editAgeAndBody(context);
    } else if (safety.reproductiveStatus == ReproductiveStatus.notAnswered) {
      await _editReproductive(context);
    } else if (safety.kidneyStatus == ProfileAnswer.notAnswered) {
      await _editOrgan(context, kidney: true);
    } else if (safety.liverStatus == ProfileAnswer.notAnswered) {
      await _editOrgan(context, kidney: false);
    } else if (!safety.foodAndDrinkReviewed) {
      await _editSelection(context, _Selection.food);
    } else if (!safety.supplementsReviewed) {
      await _editSelection(context, _Selection.supplements);
    } else if (!safety.lifestyleReviewed) {
      await _editSelection(context, _Selection.lifestyle);
    } else if (!safety.accessibilityReviewed) {
      await _editSelection(context, _Selection.accessibility);
    }
  }

  Future<void> _editAgeAndBody(BuildContext context) async {
    final result = await showAppSheet<(String, String, String)>(
      context: context,
      builder: (context) => _AgeSheet(
        ageRange: store.safetyContext.ageRange,
        sex: store.safetyContext.sexForMedicationSafety,
        weight: store.profile.weightLabel,
        ageOptions: _ageOptions,
        sexOptions: _sexOptions,
      ),
    );
    if (result == null) return;
    final (age, sex, weight) = result;
    store.updateSafetyContext(
      store.safetyContext.copyWith(ageRange: age, sexForMedicationSafety: sex),
    );
    store.updateProfile(store.profile.copyWith(weightLabel: weight));
  }

  Future<void> _editReproductive(BuildContext context) async {
    final s = AppStrings.of(context);
    final value = await showAppSheet<ReproductiveStatus>(
      context: context,
      builder: (context) => _ChoiceSheet<ReproductiveStatus>(
        title: s.pregnancy,
        current: store.safetyContext.reproductiveStatus,
        choices: [
          for (final status in const [
            ReproductiveStatus.pregnant,
            ReproductiveStatus.breastfeeding,
            ReproductiveStatus.tryingToConceive,
            ReproductiveStatus.postpartum,
            ReproductiveStatus.none,
            ReproductiveStatus.notApplicable,
            ReproductiveStatus.preferNotToAnswer,
          ])
            (status, s.reproductiveLabel(status)),
        ],
      ),
    );
    if (value != null) {
      store.updateSafetyContext(
        store.safetyContext.copyWith(reproductiveStatus: value),
      );
    }
  }

  Future<void> _editOrgan(BuildContext context, {required bool kidney}) async {
    final s = AppStrings.of(context);
    final value = await showAppSheet<ProfileAnswer>(
      context: context,
      builder: (context) => _ChoiceSheet<ProfileAnswer>(
        title: kidney ? s.kidneys : s.liver,
        current: kidney
            ? store.safetyContext.kidneyStatus
            : store.safetyContext.liverStatus,
        choices: [
          for (final answer in const [
            ProfileAnswer.no,
            ProfileAnswer.yes,
            ProfileAnswer.unsure,
          ])
            (answer, s.organLabel(answer, kidney: kidney)),
        ],
      ),
    );
    if (value == null) return;
    store.updateSafetyContext(
      kidney
          ? store.safetyContext.copyWith(kidneyStatus: value)
          : store.safetyContext.copyWith(liverStatus: value),
    );
  }

  Future<void> _editList(
    BuildContext context, {
    required bool allergies,
  }) async {
    final s = AppStrings.of(context);
    final profile = store.profile;
    final source = allergies ? profile.allergies : profile.conditions;
    final values = await showAppSheet<List<String>>(
      context: context,
      builder: (context) => _ListSheet(
        title: allergies ? s.allergies : s.conditions,
        hint: allergies ? s.allergiesHint : s.conditionsHint,
        initial: _isPlaceholder(source) ? const [] : source,
      ),
    );
    if (values == null) return;
    final fallback = allergies
        ? 'No allergies recorded'
        : 'No conditions recorded';
    final cleaned = values.isEmpty ? [fallback] : values;
    store.updateProfile(
      allergies
          ? profile.copyWith(allergies: cleaned)
          : profile.copyWith(conditions: cleaned),
    );
  }

  Future<void> _editSelection(BuildContext context, _Selection kind) async {
    final s = AppStrings.of(context);
    final safety = store.safetyContext;
    final (title, options, current) = switch (kind) {
      _Selection.food => (
        s.foodAndDrinks,
        SafetyOptions.foodAndDrink,
        safety.foodAndDrinkFactors,
      ),
      _Selection.supplements => (
        s.supplements,
        SafetyOptions.supplementsAndOtc,
        safety.supplementsAndOtc,
      ),
      _Selection.lifestyle => (
        s.lifestyle,
        SafetyOptions.lifestyle,
        safety.lifestyleFactors,
      ),
      _Selection.accessibility => (
        s.accessibility,
        SafetyOptions.accessibility,
        safety.accessibilityNeeds,
      ),
    };
    final values = await showAppSheet<List<String>>(
      context: context,
      builder: (context) => _MultiSelectSheet(
        title: title,
        options: [for (final option in options) option.label],
        initial: current,
      ),
    );
    if (values == null) return;
    final latest = store.safetyContext;
    store.updateSafetyContext(switch (kind) {
      _Selection.food => latest.copyWith(
        foodAndDrinkFactors: values,
        foodAndDrinkReviewed: true,
      ),
      _Selection.supplements => latest.copyWith(
        supplementsAndOtc: values,
        supplementsReviewed: true,
      ),
      _Selection.lifestyle => latest.copyWith(
        lifestyleFactors: values,
        lifestyleReviewed: true,
      ),
      _Selection.accessibility => latest.copyWith(
        accessibilityNeeds: values,
        accessibilityReviewed: true,
      ),
    });
  }
}

enum _Selection { food, supplements, lifestyle, accessibility }

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.safety, required this.onContinue});

  final SafetyContext safety;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final text = Theme.of(context).textTheme;
    final complete = safety.reviewedAreaCount == safety.totalAreaCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ProgressRing(
            value: safety.completion,
            size: 58,
            strokeWidth: 6,
            child: Text(
              '${safety.reviewedAreaCount}/${safety.totalAreaCount}',
              style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.healthProgress(
                    safety.reviewedAreaCount,
                    safety.totalAreaCount,
                  ),
                  style: text.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(s.healthWhy, style: text.bodyMedium),
              ],
            ),
          ),
          if (!complete) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Text(s.continueSetup),
            ),
          ],
        ],
      ),
    );
  }
}

class _AgeSheet extends StatefulWidget {
  const _AgeSheet({
    required this.ageRange,
    required this.sex,
    required this.weight,
    required this.ageOptions,
    required this.sexOptions,
  });

  final String ageRange;
  final String sex;
  final String weight;
  final List<String> ageOptions;
  final List<String> sexOptions;

  @override
  State<_AgeSheet> createState() => _AgeSheetState();
}

class _AgeSheetState extends State<_AgeSheet> {
  late String? _age = widget.ageOptions.contains(widget.ageRange)
      ? widget.ageRange
      : null;
  late String _sex = widget.sexOptions.contains(widget.sex)
      ? widget.sex
      : 'Not added';
  late final TextEditingController _weight = TextEditingController(
    text: widget.weight == 'Not added' ? '' : widget.weight,
  );

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(title: s.ageAndWeight),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _age,
              isExpanded: true,
              decoration: InputDecoration(labelText: s.ageRange),
              items: [
                for (final value in widget.ageOptions)
                  DropdownMenuItem(
                    value: value,
                    child: Text(s.storedValue(value)),
                  ),
              ],
              onChanged: (value) => setState(() => _age = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _weight,
              decoration: InputDecoration(
                labelText: s.weightOptional,
                hintText: s.weightHint,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _sex,
              isExpanded: true,
              decoration: InputDecoration(labelText: s.sexOptional),
              items: [
                for (final value in widget.sexOptions)
                  DropdownMenuItem(
                    value: value,
                    child: Text(s.storedValue(value)),
                  ),
              ],
              onChanged: (value) => setState(() => _sex = value ?? 'Not added'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _age == null
                  ? null
                  : () => Navigator.pop(context, (
                      _age!,
                      _sex,
                      _weight.text.trim().isEmpty
                          ? 'Not added'
                          : _weight.text.trim(),
                    )),
              child: Text(s.save),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceSheet<T> extends StatelessWidget {
  const _ChoiceSheet({
    required this.title,
    required this.current,
    required this.choices,
  });

  final String title;
  final T current;
  final List<(T, String)> choices;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(title: title),
            const SizedBox(height: 8),
            RadioGroup<T>(
              groupValue: current,
              onChanged: (value) {
                if (value != null) Navigator.pop(context, value);
              },
              child: Column(
                children: [
                  for (final (value, label) in choices)
                    RadioListTile<T>(
                      value: value,
                      contentPadding: EdgeInsets.zero,
                      title: Text(label),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListSheet extends StatefulWidget {
  const _ListSheet({
    required this.title,
    required this.hint,
    required this.initial,
  });

  final String title;
  final String hint;
  final List<String> initial;

  @override
  State<_ListSheet> createState() => _ListSheetState();
}

class _ListSheetState extends State<_ListSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial.join(', '),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
            SheetHeader(title: widget.title),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              minLines: 2,
              maxLines: 5,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.hint,
                helperText: s.separateWithCommas,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                _controller.text
                    .split(RegExp(r'[,،]'))
                    .map((value) => value.trim())
                    .where((value) => value.isNotEmpty)
                    .toList(growable: false),
              ),
              child: Text(s.save),
            ),
          ],
        ),
      ),
    );
  }
}

class _MultiSelectSheet extends StatefulWidget {
  const _MultiSelectSheet({
    required this.title,
    required this.options,
    required this.initial,
  });

  final String title;
  final List<String> options;
  final List<String> initial;

  @override
  State<_MultiSelectSheet> createState() => _MultiSelectSheetState();
}

class _MultiSelectSheetState extends State<_MultiSelectSheet> {
  late final Set<String> _selected = widget.initial.toSet();

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: SheetHeader(title: widget.title),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final option in widget.options)
                  CheckboxListTile(
                    value: _selected.contains(option),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(s.storedValue(option)),
                    onChanged: (value) => setState(() {
                      if (value ?? false) {
                        _selected.add(option);
                      } else {
                        _selected.remove(option);
                      }
                    }),
                  ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, const <String>[]),
                      child: Text(s.noneApply),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, [
                        for (final option in widget.options)
                          if (_selected.contains(option)) option,
                      ]),
                      child: Text(s.saveSelected(_selected.length)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
