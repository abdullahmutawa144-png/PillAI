import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pill_ai/app.dart';
import 'package:pill_ai/domain/app_models.dart';
import 'package:pill_ai/domain/app_store.dart';
import 'package:pill_ai/domain/assistant_engine.dart';

void main() {
  group('AppStore', () {
    test('records doses without inventing a missed-dose reschedule', () {
      final store = AppStore.demo(clock: DateTime(2026, 7, 20, 9));
      final first = store.nextDose!;

      store.markTaken(first.id, at: DateTime(2026, 7, 20, 10, 2));
      expect(store.doseFor(first.id).status, DoseStatus.taken);
      expect(store.completedToday, 1);

      final second = store.nextDose!;
      final proposal = store.markMissed(second.id, 'I was asleep');
      expect(store.doseFor(second.id).status, DoseStatus.missed);
      expect(proposal.canApply, isFalse);
      expect(proposal.doseId, second.id);
      expect(proposal.to, proposal.from);
      expect(proposal.safetyNote, contains('No reminder was moved'));

      store.confirmReschedule();
      expect(store.doseFor(proposal.doseId).status, DoseStatus.missed);
    });

    test('adds a medication and a first reminder', () {
      final store = AppStore.demo(clock: DateTime(2026, 7, 20, 9));
      store.addMedication(
        name: 'Sample medicine',
        strength: '5 mg',
        form: MedicationForm.tablet,
        doseLabel: '1 tablet',
        instructions: 'Follow the label',
        firstDoseAt: DateTime(2026, 7, 20, 16),
      );

      expect(
        store.medications.any((item) => item.name == 'Sample medicine'),
        isTrue,
      );
      expect(store.todayDoses.length, 4);
    });

    test('undo returns a mistaken tap to the plan', () {
      final store = AppStore.demo(clock: DateTime(2026, 7, 20, 9));
      final dose = store.nextDose!;
      store.markTaken(dose.id);
      store.undoDose(dose.id);
      expect(store.doseFor(dose.id).status, DoseStatus.scheduled);
      expect(store.completedToday, 0);
    });
  });

  test('assistant keeps medicine-specific interaction boundaries', () {
    final store = AppStore.demo(clock: DateTime(2026, 7, 20, 9));
    final reply = const DemoAssistantEngine().replyTo(
      'Can I take iron, milk, and an antibiotic together?',
      store,
    );

    expect(reply.level, SafetyLevel.caution);
    expect(reply.message, contains('medicine-specific'));
    expect(reply.message, contains('cannot verify a safe interval'));
  });

  testWidgets('home renders the next dose and marks it taken', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = AppStore.demo(clock: DateTime(2026, 7, 20, 9));
    addTearDown(store.dispose);
    await tester.pumpWidget(PillAiApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Tell PillAI what happened…'), findsOneWidget);
    expect(find.text('Next dose'), findsOneWidget);
    expect(find.text('Vitamin D3'), findsWidgets);
    expect(find.text('Assistant'), findsOneWidget);
    expect(find.text('0 of 3'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Taken'));
    await tester.pumpAndSettle();

    expect(find.text('1 of 3'), findsOneWidget);
    expect(find.text('Omega 3'), findsWidgets);
    expect(find.text('Undo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
