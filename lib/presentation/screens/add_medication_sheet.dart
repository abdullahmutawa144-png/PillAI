import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/app_models.dart';
import '../../domain/app_store.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

/// Opens the add (or edit) medicine sheet. Returns true when saved.
Future<bool?> showMedicationEditor(
  BuildContext context, {
  required AppStore store,
  Medication? medication,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: AddMedicationSheet(store: store, medication: medication),
    ),
  );
}

/// Name, type, dose, how often, how long — the rest is optional.
class AddMedicationSheet extends StatefulWidget {
  const AddMedicationSheet({required this.store, this.medication, super.key});

  final AppStore store;

  /// When set, the sheet edits this medicine instead of adding a new one.
  final Medication? medication;

  @override
  State<AddMedicationSheet> createState() => _AddMedicationSheetState();
}

class _AddMedicationSheetState extends State<AddMedicationSheet> {
  static const _defaultTimes = <int, List<int>>{
    1: [9 * 60],
    2: [9 * 60, 21 * 60],
    3: [8 * 60, 14 * 60, 20 * 60],
    4: [8 * 60, 12 * 60, 16 * 60, 20 * 60],
  };
  static const _durations = <int?>[null, 3, 5, 7, 10, 14, 30];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _dose;
  late final TextEditingController _strength;
  late final TextEditingController _ingredients;
  late final TextEditingController _instructions;
  late MedicationForm _form;
  late int _frequency;
  late List<int> _times;
  int? _durationDays;
  late bool _isPrescription;
  bool _doseTouched = false;
  bool _showMore = false;

  bool get _editing => widget.medication != null;

  @override
  void initState() {
    super.initState();
    final medication = widget.medication;
    final schedule = medication?.schedule;
    _name = TextEditingController(text: medication?.name ?? '');
    _dose = TextEditingController(text: medication?.doseLabel ?? '');
    _strength = TextEditingController(text: medication?.strength ?? '');
    _ingredients = TextEditingController(
      text: medication?.activeIngredients.join(', ') ?? '',
    );
    _instructions = TextEditingController(text: medication?.instructions ?? '');
    _form = medication?.form ?? MedicationForm.tablet;
    _times = List.of(schedule?.times ?? _defaultTimes[1]!);
    _frequency = schedule == null ? 1 : schedule.times.length.clamp(0, 6);
    _durationDays = schedule?.durationDays;
    _isPrescription = medication?.isPrescription ?? false;
    _doseTouched = medication != null;
    _showMore =
        medication != null &&
        (medication.strength.isNotEmpty ||
            medication.activeIngredients.isNotEmpty);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_doseTouched && _dose.text.isEmpty) {
      _dose.text = AppStrings.of(context).defaultDose(_form);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _strength.dispose();
    _ingredients.dispose();
    _instructions.dispose();
    super.dispose();
  }

  void _setForm(MedicationForm form) {
    setState(() {
      _form = form;
      if (!_doseTouched) _dose.text = AppStrings.of(context).defaultDose(form);
    });
  }

  void _setFrequency(int frequency) {
    setState(() {
      _frequency = frequency;
      if (frequency > 0) {
        _times = List.of(
          _defaultTimes[frequency] ??
              List.generate(
                frequency,
                (i) => 8 * 60 + i * (12 * 60 ~/ frequency),
              ),
        );
      } else {
        _times = [];
      }
    });
  }

  Future<void> _pickTime(int index) async {
    final minutes = _times[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _times[index] = picked.hour * 60 + picked.minute;
      _times.sort();
    });
  }

  List<String> _ingredientList() => _ingredients.text
      .split(RegExp(r'[,،]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final s = AppStrings.of(context);
    final store = widget.store;
    final instructions = _instructions.text.trim().isEmpty
        ? s.defaultInstructions
        : _instructions.text.trim();
    final times = _frequency == 0 ? <int>[] : _times;
    final existing = widget.medication;
    if (existing == null) {
      store.addMedication(
        name: _name.text,
        strength: _strength.text,
        form: _form,
        doseLabel: _dose.text,
        instructions: instructions,
        times: times,
        durationDays: times.isEmpty ? null : _durationDays,
        isPrescription: _isPrescription,
        activeIngredients: _ingredientList(),
      );
    } else {
      store.updateMedication(
        existing.copyWith(
          name: _name.text.trim(),
          strength: _strength.text.trim(),
          form: _form,
          doseLabel: _dose.text.trim(),
          instructions: instructions,
          isPrescription: _isPrescription,
          activeIngredients: _ingredientList(),
          schedule: MedicationSchedule(
            times: times,
            startDate: existing.schedule?.startDate ?? store.today,
            durationDays: times.isEmpty ? null : _durationDays,
          ),
        ),
      );
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final text = Theme.of(context).textTheme;
    final height = MediaQuery.sizeOf(context).height * .9;

    return SizedBox(
      height: height,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _editing ? s.editMedicineTitle : s.addMedicineTitle,
                      style: text.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: s.close,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [LengthLimitingTextInputFormatter(120)],
                    style: text.titleMedium,
                    decoration: InputDecoration(
                      labelText: s.medicineName,
                      hintText: s.medicineNameHint,
                      prefixIcon: const Icon(Icons.medication_rounded),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? s.medicineNameRequired
                        : null,
                  ),
                  const SizedBox(height: 20),
                  _Label(s.type),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final form in MedicationForm.values)
                        ChoicePill(
                          label: s.formLabel(form),
                          icon: MedicineAvatar.iconFor(form),
                          selected: _form == form,
                          onTap: () => _setForm(form),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _dose,
                    inputFormatters: [LengthLimitingTextInputFormatter(80)],
                    onChanged: (_) => _doseTouched = true,
                    decoration: InputDecoration(
                      labelText: s.dose,
                      prefixIcon: const Icon(Icons.straighten_rounded),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? s.doseRequired
                        : null,
                  ),
                  const SizedBox(height: 24),
                  _Label(s.howOften),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final frequency in const [1, 2, 3, 4, 0])
                        ChoicePill(
                          label: s.timesPerDay(frequency),
                          selected: _frequency == frequency,
                          onTap: () => _setFrequency(frequency),
                        ),
                    ],
                  ),
                  if (_frequency > 0) ...[
                    const SizedBox(height: 16),
                    _Label(s.reminderTimes),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < _times.length; i++)
                          ActionChip(
                            avatar: const Icon(
                              Icons.alarm_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            label: Text(s.timeOfMinutes(_times[i])),
                            labelStyle: text.labelLarge?.copyWith(
                              color: AppColors.primaryDark,
                            ),
                            backgroundColor: AppColors.primaryFaint,
                            side: const BorderSide(
                              color: AppColors.primarySoft,
                            ),
                            onPressed: () => _pickTime(i),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _Label(s.forHowLong),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final days in _durations)
                          ChoicePill(
                            label: days == null ? s.ongoing : s.days(days),
                            selected: _durationDays == days,
                            onTap: () => setState(() => _durationDays = days),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    onTap: () => setState(() => _showMore = !_showMore),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.moreDetails,
                              style: text.titleMedium?.copyWith(
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                          Icon(
                            _showMore
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            color: AppColors.primaryDark,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showMore) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _strength,
                      inputFormatters: [LengthLimitingTextInputFormatter(80)],
                      decoration: InputDecoration(
                        labelText: s.strength,
                        hintText: s.strengthHint,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ingredients,
                      decoration: InputDecoration(
                        labelText: s.activeIngredients,
                        hintText: s.ingredientsHint,
                      ),
                      validator: (_) => _ingredientList().length > 12
                          ? s.tooManyIngredients
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _instructions,
                      minLines: 1,
                      maxLines: 3,
                      inputFormatters: [LengthLimitingTextInputFormatter(500)],
                      decoration: InputDecoration(
                        labelText: s.instructions,
                        hintText: s.instructionsHint,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _isPrescription,
                      title: Text(s.prescribedByDoctor),
                      onChanged: (value) =>
                          setState(() => _isPrescription = value),
                    ),
                  ],
                ],
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: Icon(
                      _editing ? Icons.check_rounded : Icons.add_rounded,
                    ),
                    label: Text(_editing ? s.saveChanges : s.addToPlan),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
