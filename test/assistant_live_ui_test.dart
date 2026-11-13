import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pill_ai/app.dart';
import 'package:pill_ai/domain/app_models.dart';
import 'package:pill_ai/domain/app_store.dart';
import 'package:pill_ai/domain/assistant_gateway.dart';
import 'package:pill_ai/domain/voice_input.dart';

void main() {
  testWidgets('asks once before sharing context and remembers the choice', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final store = AppStore.demo(clock: DateTime(2026, 7, 20, 9));
    final voice = _IdleVoiceInput();
    final gateway = _LiveGateway();
    addTearDown(store.dispose);
    addTearDown(voice.dispose);

    await tester.pumpWidget(
      PillAiApp(store: store, voiceInput: voice, assistantGateway: gateway),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assistant'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Help with my medicines');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();

    expect(find.text('Turn on smart answers?'), findsOneWidget);
    expect(find.textContaining('AI provider (OpenAI)'), findsOneWidget);
    expect(gateway.calls, 0);

    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();

    expect(gateway.calls, 1);
    expect(store.remoteAiConsent, isTrue);
    expect(find.text('PillAI · GPT-5.6 Terra'), findsOneWidget);
    expect(find.text('Smart answers on'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'And tomorrow?');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(find.text('Turn on smart answers?'), findsNothing);
    expect(gateway.calls, 2);
  });

  testWidgets('emergency wording bypasses consent and stays local first', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final store = AppStore.demo(clock: DateTime(2026, 7, 20, 9));
    final voice = _IdleVoiceInput();
    final gateway = _LiveGateway();
    addTearDown(store.dispose);
    addTearDown(voice.dispose);

    await tester.pumpWidget(
      PillAiApp(store: store, voiceInput: voice, assistantGateway: gateway),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assistant'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'I took an extra dose and now I cannot breathe',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();

    expect(find.text('Turn on smart answers?'), findsNothing);
    expect(gateway.calls, 0);
    expect(find.text('Get urgent help now'), findsOneWidget);
    expect(find.text('Emergency route'), findsOneWidget);
    expect(find.text('Call 997 · Ambulance'), findsOneWidget);
  });

  testWidgets('Arabic emergency wording is answered in Arabic on device', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final store = AppStore.demo(clock: DateTime(2026, 7, 20, 9))
      ..setLanguage(AppLanguage.arabic);
    final voice = _IdleVoiceInput();
    final gateway = _LiveGateway();
    addTearDown(store.dispose);
    addTearDown(voice.dispose);

    await tester.pumpWidget(
      PillAiApp(store: store, voiceInput: voice, assistantGateway: gateway),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('المساعد'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ولدي بلع حبوب كثيرة');
    await tester.pump();
    await tester.tap(find.byTooltip('إرسال'));
    await tester.pumpAndSettle();

    expect(gateway.calls, 0);
    expect(find.text('اطلب المساعدة الآن'), findsOneWidget);
    expect(find.text('اتصل 997 · الإسعاف'), findsOneWidget);
  });

  testWidgets('offline choice is retained on its answer bubble', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final store = AppStore.demo(clock: DateTime(2026, 7, 20, 9));
    final voice = _IdleVoiceInput();
    final gateway = _LiveGateway();
    addTearDown(store.dispose);
    addTearDown(voice.dispose);

    await tester.pumpWidget(
      PillAiApp(store: store, voiceInput: voice, assistantGateway: gateway),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assistant'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Use local guidance');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use offline mode'));
    await tester.pumpAndSettle();

    expect(gateway.calls, 0);
    expect(store.remoteAiConsent, isFalse);
    expect(
      store.messages.last.provenance?.fallbackReason,
      AssistantFallbackReason.userChoseLocal,
    );
    expect(find.text('Offline · your choice'), findsOneWidget);
  });

  testWidgets('permanent emergency action opens local guidance only', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final store = AppStore.demo(clock: DateTime(2026, 7, 20, 9));
    final voice = _IdleVoiceInput();
    final gateway = _LiveGateway();
    addTearDown(store.dispose);
    addTearDown(voice.dispose);

    await tester.pumpWidget(
      PillAiApp(store: store, voiceInput: voice, assistantGateway: gateway),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assistant'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Emergency'));
    await tester.pumpAndSettle();

    expect(find.text('Is this an emergency?'), findsOneWidget);
    expect(find.text('Call 997 · Ambulance'), findsOneWidget);
    expect(find.text('Call 911 · Emergency'), findsOneWidget);
    expect(find.text('Turn on smart answers?'), findsNothing);
    expect(gateway.calls, 0);
  });

  testWidgets('composer enforces the backend 2,000-character limit', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final store = AppStore.demo(clock: DateTime(2026, 7, 20, 9));
    final voice = _IdleVoiceInput();
    final gateway = _LiveGateway();
    addTearDown(store.dispose);
    addTearDown(voice.dispose);

    await tester.pumpWidget(
      PillAiApp(store: store, voiceInput: voice, assistantGateway: gateway),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assistant'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'x' * 2001);
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, hasLength(2000));
    expect(find.text('2000/2000'), findsOneWidget);
    expect(gateway.calls, 0);
  });
}

void _setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _LiveGateway implements AssistantGateway, RemoteAwareAssistantGateway {
  int calls = 0;

  @override
  bool get maySendRemotely => true;

  @override
  Future<AssistantGatewayResponse> replyTo(
    String message,
    AppStore store, {
    List<ChatMessage> history = const [],
  }) async {
    calls++;
    return const AssistantGatewayResponse(
      reply: AssistantReply(
        title: 'Live explanation',
        message: 'This answer came from the PillAI backend.',
        level: SafetyLevel.general,
        coverage: SafetyCoverage.generalGuidance,
      ),
      source: AssistantResponseSource.liveModel,
      providerSource: 'model',
      model: 'gpt-5.6-terra',
      requestId: 'req_widget',
      notice:
          'The model classified intent; wording came from a server-owned template.',
    );
  }
}

class _IdleVoiceInput extends VoiceInputController {
  @override
  String? get errorMessage => null;

  @override
  double get soundLevel => 0;

  @override
  VoiceInputStatus get status => VoiceInputStatus.idle;

  @override
  Future<void> cancel() async {}

  @override
  Future<bool> initialize() async => true;

  @override
  Future<void> start({
    required ValueChanged<VoiceTranscript> onTranscript,
    String? localeId,
  }) async {}

  @override
  Future<void> stop() async {}
}
