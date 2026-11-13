import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pill_ai/app.dart';
import 'package:pill_ai/domain/app_models.dart';
import 'package:pill_ai/domain/app_store.dart';
import 'package:pill_ai/domain/voice_input.dart';

void main() {
  testWidgets('voice transcript is reviewed and never sent automatically', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = AppStore.demo(clock: DateTime(2026, 7, 20, 9));
    final voice = _FakeVoiceInput();
    addTearDown(store.dispose);
    addTearDown(voice.dispose);

    await tester.pumpWidget(PillAiApp(store: store, voiceInput: voice));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assistant'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Speak'));
    await tester.pumpAndSettle();
    expect(find.text('Use your voice?'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Iron supplement 20 milligrams'), findsOneWidget);
    expect(store.messages, isEmpty);
    expect(store.voiceNoticeAccepted, isTrue);
    expect(voice.isListening, isTrue);
    expect(voice.lastLocale, 'en_US');

    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(store.messages, isEmpty);

    await tester.tap(find.byTooltip('Send message'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(store.messages, hasLength(2));
  });

  testWidgets('Simple Home Speak opens the review-before-send voice flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = AppStore.demo(clock: DateTime(2026, 7, 20, 9))
      ..setDisplayMode(AppDisplayMode.simple)
      ..setLanguage(AppLanguage.arabic);
    final voice = _FakeVoiceInput();
    addTearDown(store.dispose);
    addTearDown(voice.dispose);

    await tester.pumpWidget(PillAiApp(store: store, voiceInput: voice));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'تحدّث'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'تحدّث'));
    await tester.pumpAndSettle();

    expect(find.text('استخدام الصوت؟'), findsOneWidget);
    expect(store.messages, isEmpty);

    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();
    expect(find.text('Iron supplement 20 milligrams'), findsOneWidget);
    expect(voice.lastLocale, 'ar_SA');
    expect(store.messages, isEmpty);
  });
}

class _FakeVoiceInput extends VoiceInputController {
  VoiceInputStatus _status = VoiceInputStatus.idle;
  String? lastLocale;

  @override
  String? get errorMessage => null;

  @override
  double get soundLevel => 0;

  @override
  VoiceInputStatus get status => _status;

  @override
  Future<bool> initialize() async {
    _status = VoiceInputStatus.ready;
    notifyListeners();
    return true;
  }

  @override
  Future<void> start({
    required ValueChanged<VoiceTranscript> onTranscript,
    String? localeId,
  }) async {
    lastLocale = localeId;
    await initialize();
    _status = VoiceInputStatus.listening;
    notifyListeners();
    onTranscript(
      const VoiceTranscript(
        text: 'Iron supplement 20 milligrams',
        isFinal: false,
        confidence: 0.9,
      ),
    );
  }

  @override
  Future<void> stop() async {
    _status = VoiceInputStatus.ready;
    notifyListeners();
  }

  @override
  Future<void> cancel() async {
    _status = VoiceInputStatus.ready;
    notifyListeners();
  }
}
