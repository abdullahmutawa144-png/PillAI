import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pill_ai/app.dart';
import 'package:pill_ai/domain/app_models.dart';
import 'package:pill_ai/domain/app_store.dart';

void main() {
  testWidgets('layout switch keeps medication state and can be reversed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = AppStore.demo(clock: DateTime(2026, 7, 20, 9));
    final firstDose = store.nextDose!;
    store.markTaken(firstDose.id);
    addTearDown(store.dispose);

    await tester.pumpWidget(PillAiApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Large & simple mode'));
    await tester.pumpAndSettle();

    expect(store.displayMode, AppDisplayMode.simple);
    expect(store.doseFor(firstDose.id).status, DoseStatus.taken);

    await tester.tap(find.text('Large & simple mode'));
    await tester.pumpAndSettle();
    expect(store.displayMode, AppDisplayMode.standard);
    expect(store.doseFor(firstDose.id).status, DoseStatus.taken);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Simple layout remains usable at 200 percent text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final store = AppStore.demo(clock: DateTime(2026, 7, 20, 9));
    store.setDisplayMode(AppDisplayMode.simple);
    addTearDown(store.dispose);

    await tester.pumpWidget(PillAiApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('I took it'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Speak'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Speak'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Assistant'));
    await tester.pumpAndSettle();
    expect(find.text('How can I help?'), findsOneWidget);
    expect(find.text('Send message'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Medicines'));
    await tester.pumpAndSettle();
    expect(find.text('Vitamin D3 1000 IU'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Health profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
