import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pill_ai/app.dart';
import 'package:pill_ai/domain/app_models.dart';
import 'package:pill_ai/domain/app_store.dart';
import 'package:pill_ai/domain/assistant_engine.dart';
import 'package:pill_ai/domain/state_storage.dart';
import 'package:pill_ai/presentation/bidi.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('offline assistant in Arabic', () {
    final store = AppStore.demo(clock: DateTime(2026, 7, 20, 9));
    const engine = DemoAssistantEngine();

    test('routes Saudi phrasing and answers in Arabic', () {
      final missed = engine.replyTo('نسيت جرعة الحديد أمس', store);
      expect(missed.title, 'لنتعامل مع الجرعة الفائتة بأمان');
      expect(missed.message, contains('لا تضاعف'));

      final tea = engine.replyTo('شربت شاي الحين، يأثر؟', store);
      expect(tea.level, SafetyLevel.caution);
      expect(tea.title, contains('الأكل والمشروبات'));
      expect(tea.contextNote, contains('الشاي أو القهوة'));
    });

    test('Arabic emergency words reach the urgent route with 997', () {
      final reply = engine.replyTo('ما اقدر اتنفس بعد الدواء', store);
      expect(reply.level, SafetyLevel.urgent);
      expect(reply.message, contains('997'));
    });

    test('English messages stay English in an Arabic app', () {
      final arabicStore = AppStore.demo(clock: DateTime(2026, 7, 20, 9))
        ..setLanguage(AppLanguage.arabic);
      final reply = engine.replyTo('I missed a dose', arabicStore);
      expect(reply.title, "Let's handle the missed dose safely");
    });

    test('common words inside longer Arabic words do not misroute', () {
      // "مشاكل" contains the letters of "اكل" (food) but means "problems".
      final reply = engine.replyTo('عندي مشاكل في النوم', store);
      expect(reply.title, isNot(contains('الأكل')));
    });
  });

  test('isolate keeps mixed-direction data intact', () {
    expect(isolate(''), '');
    expect(isolate('1 tablet'), '\u20681 tablet\u2069');
    expect(directionOf('Vitamin D3'), TextDirection.ltr);
    expect(directionOf('بنادول 500'), TextDirection.rtl);
    expect(directionOf('500 mg'), TextDirection.ltr);
    expect(directionOf('123'), isNull);
  });

  testWidgets('Arabic layout is right-to-left with Arabic navigation', (
    tester,
  ) async {
    _phone(tester);
    final store = AppStore.demo(clock: DateTime(2026, 7, 20, 9))
      ..setLanguage(AppLanguage.arabic);
    addTearDown(store.dispose);

    await tester.pumpWidget(PillAiApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('اليوم'), findsWidgets);
    expect(find.text('المساعد'), findsOneWidget);
    expect(find.text('أدويتي'), findsOneWidget);
    expect(find.text('حسابي'), findsOneWidget);
    final direction = Directionality.of(tester.element(find.text('أدويتي')));
    expect(direction, TextDirection.rtl);
    expect(find.text('الجرعة القادمة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('first launch walks through onboarding and saves the choices', (
    tester,
  ) async {
    _phone(tester);
    final storage = InMemoryStateStorage();
    final store = AppStore.persistent(
      storage: storage,
      clock: () => DateTime(2026, 10, 1, 9),
    );
    addTearDown(store.dispose);

    await tester.pumpWidget(PillAiApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    expect(store.language, AppLanguage.arabic);

    await tester.tap(find.text('ابدأ'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'سارة');
    await tester.tap(find.text('موافق، لنبدأ'));
    await tester.pumpAndSettle();

    expect(store.onboardingComplete, isTrue);
    expect(store.profile.name, 'سارة');
    expect(find.text('لنرتّب أدويتك'), findsOneWidget);

    await tester.tap(find.text('جرّب خطة تجريبية'));
    await tester.pumpAndSettle();
    expect(store.medications, hasLength(3));
    expect(find.text('الجرعة القادمة'), findsOneWidget);

    await store.saved;
    expect(storage.snapshot, contains('"onboarded":true'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('adding a twice-daily medicine creates both reminders', (
    tester,
  ) async {
    _phone(tester);
    final store = AppStore.demo(clock: DateTime(2026, 7, 20, 8));
    addTearDown(store.dispose);

    await tester.pumpWidget(PillAiApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medicines'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Medicine name'),
      'Amoxicillin',
    );
    await tester.tap(find.text('Capsule'));
    await tester.pumpAndSettle();
    final form = find.byType(ListView).last;
    await tester.dragUntilVisible(
      find.text('Twice a day'),
      form,
      const Offset(0, -120),
    );
    await tester.tap(find.text('Twice a day'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('7 days'),
      form,
      const Offset(0, -120),
    );
    expect(find.text('9:00 AM'), findsOneWidget);
    expect(find.text('9:00 PM'), findsOneWidget);
    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to my plan'));
    await tester.pumpAndSettle();

    final added = store.medications.singleWhere(
      (item) => item.name == 'Amoxicillin',
    );
    expect(added.form, MedicationForm.capsule);
    expect(added.doseLabel, '1 capsule');
    expect(added.schedule!.times, [9 * 60, 21 * 60]);
    expect(added.schedule!.durationDays, 7);
    expect(store.todayDoses, hasLength(5));
    expect(find.text('Amoxicillin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
