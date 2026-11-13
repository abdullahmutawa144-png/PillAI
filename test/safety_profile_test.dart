import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pill_ai/app.dart';
import 'package:pill_ai/domain/app_store.dart';

void main() {
  testWidgets(
    'food context is structured, reviewable, and saved to the store',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = AppStore.demo(clock: DateTime(2026, 7, 20, 9));
      addTearDown(store.dispose);

      await tester.pumpWidget(PillAiApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Health profile'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 8 done'), findsOneWidget);
      expect(find.text('Pregnancy & breastfeeding'), findsOneWidget);
      expect(find.text('Kidneys'), findsOneWidget);

      await tester.ensureVisible(find.text('Food & drinks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food & drinks'));
      await tester.pumpAndSettle();

      expect(find.text('Tea or coffee'), findsOneWidget);
      expect(find.text('Milk or calcium-rich foods'), findsOneWidget);
      await tester.tap(find.text('Grapefruit or pomelo'));
      await tester.pump();
      await tester.tap(find.text('Save (3)'));
      await tester.pumpAndSettle();

      expect(
        store.safetyContext.foodAndDrinkFactors,
        contains('Grapefruit or pomelo'),
      );
      expect(store.safetyContext.foodAndDrinkReviewed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
