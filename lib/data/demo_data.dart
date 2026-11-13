import '../domain/app_models.dart';

/// The sample plan used by tests, demos, and the "try a sample plan" button.
class DemoData {
  const DemoData._();

  static CareProfile get profile => const CareProfile(
    name: 'Omar',
    conditions: ['Digestive health'],
    allergies: ['No allergies recorded'],
    wakeTimeLabel: '7:00 AM',
    sleepTimeLabel: '11:00 PM',
    weightLabel: 'Not added',
  );

  static SafetyContext get safetyContext => const SafetyContext(
    foodAndDrinkFactors: ['Tea or coffee', 'Milk or calcium-rich foods'],
    foodAndDrinkReviewed: true,
  );

  /// Three daily supplements whose reminders begin on [startDate].
  static List<Medication> medicationsStarting(DateTime startDate) => [
    Medication(
      id: 'vitamin-d3',
      name: 'Vitamin D3',
      strength: '1000 IU',
      form: MedicationForm.tablet,
      doseLabel: '1 tablet',
      instructions: 'Take with your morning routine',
      colorSeed: 0,
      activeIngredients: const ['Cholecalciferol'],
      schedule: MedicationSchedule(
        times: const [10 * 60],
        startDate: startDate,
      ),
    ),
    Medication(
      id: 'omega-3',
      name: 'Omega 3',
      strength: '1000 mg',
      form: MedicationForm.capsule,
      doseLabel: '1 capsule',
      instructions: 'Take with food',
      colorSeed: 1,
      activeIngredients: const [
        'Eicosapentaenoic acid (EPA)',
        'Docosahexaenoic acid (DHA)',
      ],
      schedule: MedicationSchedule(
        times: const [13 * 60],
        startDate: startDate,
      ),
    ),
    Medication(
      id: 'magnesium',
      name: 'Magnesium',
      strength: '200 mg',
      form: MedicationForm.tablet,
      doseLabel: '1 tablet',
      instructions: 'Evening reminder',
      colorSeed: 2,
      activeIngredients: const ['Magnesium'],
      schedule: MedicationSchedule(
        times: const [20 * 60],
        startDate: startDate,
      ),
    ),
  ];
}
