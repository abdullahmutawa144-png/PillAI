import 'package:flutter_test/flutter_test.dart';
import 'package:pill_ai/domain/app_models.dart';
import 'package:pill_ai/domain/app_store.dart';

void main() {
  late AppStore store;

  setUp(() {
    store = AppStore.demo(clock: DateTime(2026, 7, 20, 9));
  });

  tearDown(() => store.dispose());

  test(
    'AI chat saves arbitrary structured memory and an unambiguous dose event',
    () {
      final dose = store.todayDoses.first;
      final recordedAt = DateTime(2026, 7, 20, 9, 17);

      store.applyAssistantEffects(
        memoryUpdates: [
          MedicationMemoryFact(
            id: 'fact-1',
            kind: MedicationMemoryKind.healthStatus,
            value: 'User reported a new pregnancy',
            status: MemoryFactStatus.reported,
            recordedAt: recordedAt,
          ),
          MedicationMemoryFact(
            id: 'fact-2',
            kind: MedicationMemoryKind.routine,
            value: 'Works a changing night shift',
            status: MemoryFactStatus.reported,
            recordedAt: recordedAt,
          ),
        ],
        doseEvent: AssistantDoseEvent(
          action: AssistantDoseAction.taken,
          confidence: AssistantConfidence.high,
          doseId: dose.id,
          occurredAt: recordedAt,
          note: 'Reported in chat',
        ),
      );

      expect(store.memoryFacts, hasLength(2));
      expect(
        store.memoryFacts.map((fact) => fact.kind),
        containsAll([
          MedicationMemoryKind.healthStatus,
          MedicationMemoryKind.routine,
        ]),
      );
      expect(store.doseFor(dose.id).status, DoseStatus.taken);
      expect(store.doseFor(dose.id).actualAt, recordedAt);
    },
  );

  test('one confirmation applies every validated reminder change', () {
    final doses = store.todayDoses.take(2).toList(growable: false);
    final changes = [
      for (final dose in doses)
        ScheduleChange(
          doseId: dose.id,
          medicationName: store.medicationFor(dose.medicationId).name,
          from: dose.scheduledAt,
          to: dose.scheduledAt.add(const Duration(minutes: 45)),
          reason: 'Validated source-backed timing constraint',
          sourceUrl: 'https://dailymed.nlm.nih.gov/example',
        ),
    ];
    final first = changes.first;

    store.applyAssistantEffects(
      scheduleProposal: RescheduleProposal(
        doseId: first.doseId,
        medicationName: first.medicationName,
        from: first.from,
        to: first.to,
        reason: 'Reorganize two reminders',
        canApply: true,
        safetyNote: 'Review before applying.',
        changes: changes,
      ),
    );
    store.confirmReschedule();

    for (final change in changes) {
      final updated = store.doseFor(change.doseId);
      expect(updated.scheduledAt, change.to);
      expect(updated.status, DoseStatus.adjusted);
    }
    expect(store.pendingProposal, isNull);
  });
}
