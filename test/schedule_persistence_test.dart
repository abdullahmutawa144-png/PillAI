import 'package:flutter_test/flutter_test.dart';
import 'package:pill_ai/domain/app_models.dart';
import 'package:pill_ai/domain/app_store.dart';
import 'package:pill_ai/domain/state_storage.dart';

void main() {
  final monday = DateTime(2026, 10, 5, 7);

  Medication addTwiceDaily(AppStore store, {int? days}) {
    return store.addMedication(
      name: 'Amoxicillin',
      strength: '500 mg',
      form: MedicationForm.capsule,
      doseLabel: '1 capsule',
      instructions: 'Every 12 hours',
      times: const [9 * 60, 21 * 60],
      durationDays: days,
    );
  }

  group('recurring schedule', () {
    test('a course creates reminders only inside its days', () {
      final store = AppStore.persistent(
        storage: InMemoryStateStorage(),
        clock: () => monday,
      );
      addTwiceDaily(store, days: 3);

      for (var offset = 0; offset < 3; offset++) {
        final day = DateTime(2026, 10, 5 + offset);
        expect(store.dosesOn(day), hasLength(2), reason: '$day');
      }
      expect(store.dosesOn(DateTime(2026, 10, 8)), isEmpty);
      expect(store.dosesOn(DateTime(2026, 10, 4)), isEmpty);

      final schedule = store.medications.single.schedule!;
      expect(schedule.daysLeft(DateTime(2026, 10, 5)), 3);
      expect(schedule.daysLeft(DateTime(2026, 10, 7)), 1);
      expect(schedule.daysLeft(DateTime(2026, 10, 9)), 0);
    });

    test('as-needed medicines stay on record without reminders', () {
      final store = AppStore.persistent(
        storage: InMemoryStateStorage(),
        clock: () => monday,
      );
      store.addMedication(
        name: 'Paracetamol',
        strength: '500 mg',
        form: MedicationForm.tablet,
        doseLabel: '1 tablet',
        instructions: 'When needed for pain',
        times: const [],
      );
      expect(store.medications, hasLength(1));
      expect(store.todayDoses, isEmpty);
    });

    test('editing times rebuilds future reminders and keeps history', () {
      var now = DateTime(2026, 10, 5, 10);
      final store = AppStore.persistent(
        storage: InMemoryStateStorage(),
        clock: () => now,
      );
      final medication = addTwiceDaily(store);
      final morning = store.todayDoses.first;
      store.markTaken(morning.id);

      store.updateMedication(
        medication.copyWith(
          schedule: MedicationSchedule(
            times: const [9 * 60, 22 * 60],
            startDate: medication.schedule!.startDate,
          ),
        ),
      );

      final today = store.todayDoses;
      expect(today.map((dose) => dose.scheduledAt.hour), [9, 22]);
      expect(store.doseFor(morning.id).status, DoseStatus.taken);
      now = DateTime(2026, 10, 6, 8);
      expect(
        store.dosesOn(DateTime(2026, 10, 6)).map((d) => d.scheduledAt.hour),
        [9, 22],
      );
    });

    test('removing a medicine removes its reminders', () {
      final store = AppStore.demo(clock: DateTime(2026, 7, 20, 9));
      store.removeMedication('omega-3');
      expect(store.medicationOrNull('omega-3'), isNull);
      expect(store.todayDoses, hasLength(2));
    });

    test('timing labels follow the clock', () {
      final store = AppStore.demo(clock: DateTime(2026, 7, 20, 13, 30));
      final doses = store.todayDoses;
      expect(store.timingOf(doses[0]), DoseTiming.overdue); // 10:00
      expect(store.timingOf(doses[1]), DoseTiming.dueNow); // 13:00
      expect(store.timingOf(doses[2]), DoseTiming.upcoming); // 20:00
    });
  });

  group('persistence', () {
    test(
      'medicines, doses, consent and onboarding survive a restart',
      () async {
        final storage = InMemoryStateStorage();
        final first = AppStore.persistent(
          storage: storage,
          clock: () => monday,
        );
        await first.ready;
        expect(first.onboardingComplete, isFalse);

        first.completeOnboarding(name: 'Sara', language: AppLanguage.arabic);
        final medication = addTwiceDaily(first, days: 7);
        final dose = first.todayDoses.first;
        first.markTaken(dose.id, at: DateTime(2026, 10, 5, 9, 4));
        first.setRemoteAiConsent(true);
        first.addMessage(
          ChatMessage(text: 'شربت شاي', isUser: true, sentAt: monday),
        );
        await first.saved;
        first.dispose();

        final second = AppStore.persistent(
          storage: storage,
          clock: () => monday,
        );
        await second.ready;
        expect(second.onboardingComplete, isTrue);
        expect(second.profile.name, 'Sara');
        expect(second.language, AppLanguage.arabic);
        expect(second.remoteAiConsent, isTrue);
        expect(second.medications.single.id, medication.id);
        expect(second.medications.single.schedule!.durationDays, 7);
        expect(second.doseFor(dose.id).status, DoseStatus.taken);
        expect(second.doseFor(dose.id).actualAt, DateTime(2026, 10, 5, 9, 4));
        expect(second.todayDoses, hasLength(2));
        expect(second.messages.single.text, 'شربت شاي');
        second.dispose();
      },
    );

    test('a corrupt snapshot starts fresh instead of crashing', () async {
      final store = AppStore.persistent(
        storage: InMemoryStateStorage('{not json'),
        clock: () => monday,
      );
      await store.ready;
      expect(store.isLoaded, isTrue);
      expect(store.onboardingComplete, isFalse);
      expect(store.medications, isEmpty);
    });

    test(
      'delete all my data clears storage and returns to onboarding',
      () async {
        final storage = InMemoryStateStorage();
        final store = AppStore.persistent(
          storage: storage,
          clock: () => monday,
        );
        await store.ready;
        store.completeOnboarding(name: 'Omar', language: AppLanguage.english);
        addTwiceDaily(store);
        await store.saved;
        expect(storage.snapshot, isNotNull);

        await store.resetAll();
        expect(storage.snapshot, isNull);
        expect(store.onboardingComplete, isFalse);
        expect(store.medications, isEmpty);
        expect(store.profile.name, isEmpty);
      },
    );
  });
}
