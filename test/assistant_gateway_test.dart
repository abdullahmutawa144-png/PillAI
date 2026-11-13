import 'package:flutter_test/flutter_test.dart';
import 'package:pill_ai/domain/app_models.dart';
import 'package:pill_ai/domain/app_store.dart';
import 'package:pill_ai/domain/assistant_gateway.dart';

void main() {
  late AppStore store;

  setUp(() {
    store = AppStore.demo(clock: DateTime(2026, 7, 20, 9));
  });

  tearDown(() => store.dispose());

  test('emergency prompts stay local before the remote gateway', () async {
    final remote = _RecordingGateway(_liveResponse());
    final gateway = ResilientAssistantGateway(remote: remote);

    final response = await gateway.replyTo(
      'I took an extra dose and now I cannot breathe',
      store,
    );

    expect(response.source, AssistantResponseSource.emergencyLocal);
    expect(response.reply.level, SafetyLevel.urgent);
    expect(remote.calls, 0);
  });

  test('typed remote failures use deterministic fallback metadata', () async {
    final gateway = ResilientAssistantGateway(
      remote: _ThrowingGateway(
        const AssistantGatewayException(
          AssistantFallbackReason.timeout,
          'private transport detail',
        ),
      ),
    );

    final response = await gateway.replyTo(
      'Can I drink tea with my antibiotic?',
      store,
    );

    expect(response.source, AssistantResponseSource.demoFallback);
    expect(response.fallbackReason, AssistantFallbackReason.timeout);
    expect(response.reply.coverage, SafetyCoverage.notChecked);
    expect(response.reply.message, contains('cannot verify'));
  });

  test('valid remote response and trace metadata pass through', () async {
    final remote = _RecordingGateway(_liveResponse());
    final gateway = ResilientAssistantGateway(remote: remote);
    final history = List<ChatMessage>.of(store.messages);

    final response = await gateway.replyTo(
      'Help me understand today',
      store,
      history: history,
    );

    expect(response.source, AssistantResponseSource.liveModel);
    expect(response.model, 'gpt-5.6-terra');
    expect(response.requestId, 'req_test');
    expect(response.provenance.source, AssistantResponseSource.liveModel);
    expect(response.provenance.model, 'gpt-5.6-terra');
    expect(response.provenance.requestId, 'req_test');
    expect(remote.calls, 1);
    expect(remote.lastHistory, same(history));
  });
}

AssistantGatewayResponse _liveResponse() {
  return const AssistantGatewayResponse(
    reply: AssistantReply(
      title: 'Live answer',
      message: 'A backend-generated explanation.',
      level: SafetyLevel.general,
      coverage: SafetyCoverage.generalGuidance,
    ),
    source: AssistantResponseSource.liveModel,
    model: 'gpt-5.6-terra',
    requestId: 'req_test',
    providerSource: 'openai',
  );
}

class _RecordingGateway implements AssistantGateway {
  _RecordingGateway(this.response);

  final AssistantGatewayResponse response;
  int calls = 0;
  List<ChatMessage>? lastHistory;

  @override
  Future<AssistantGatewayResponse> replyTo(
    String message,
    AppStore store, {
    List<ChatMessage> history = const [],
  }) async {
    calls++;
    lastHistory = history;
    return response;
  }
}

class _ThrowingGateway implements AssistantGateway {
  _ThrowingGateway(this.error);

  final AssistantGatewayException error;

  @override
  Future<AssistantGatewayResponse> replyTo(
    String message,
    AppStore store, {
    List<ChatMessage> history = const [],
  }) {
    throw error;
  }
}
