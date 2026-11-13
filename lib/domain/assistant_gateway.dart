import 'app_models.dart';
import 'app_store.dart';
import 'assistant_engine.dart';
import 'assistant_provenance.dart';

export 'assistant_provenance.dart';

abstract final class AssistantRequestLimits {
  static const int messageCharacters = 2000;
}

class AssistantGatewayResponse {
  const AssistantGatewayResponse({
    required this.reply,
    required this.source,
    this.model,
    this.requestId,
    this.providerSource,
    this.fallbackReason,
    this.degraded = false,
    this.notice,
    this.safetyGate,
    this.memoryUpdates = const [],
    this.doseEvent,
    this.scheduleProposal,
  });

  final AssistantReply reply;
  final AssistantResponseSource source;

  /// Model and tracing data are supplied by the PillAI backend, never trusted
  /// as clinical verification.
  final String? model;
  final String? requestId;
  final String? providerSource;
  final AssistantFallbackReason? fallbackReason;
  final bool degraded;
  final String? notice;
  final AssistantSafetyGate? safetyGate;
  final List<MedicationMemoryFact> memoryUpdates;
  final AssistantDoseEvent? doseEvent;
  final RescheduleProposal? scheduleProposal;

  bool get isLive => source == AssistantResponseSource.liveModel;

  AssistantAnswerProvenance get provenance => AssistantAnswerProvenance(
    source: source,
    model: model,
    requestId: requestId,
    providerSource: providerSource,
    fallbackReason: fallbackReason,
    degraded: degraded,
    notice: notice,
    safetyGate: safetyGate,
  );
}

/// The interface consumed by the Flutter presentation layer.
///
/// Implementations receive structured app state instead of a pre-rendered
/// prompt so the transport can minimize and version the payload explicitly.
abstract interface class AssistantGateway {
  Future<AssistantGatewayResponse> replyTo(
    String message,
    AppStore store, {
    List<ChatMessage> history = const [],
  });
}

/// Allows the UI to request informed consent only when a gateway can send
/// medication context off-device.
abstract interface class RemoteAwareAssistantGateway {
  bool get maySendRemotely;
}

/// Optional lifecycle contract for gateways that own resources such as an
/// HTTP client.
abstract interface class DisposableAssistantGateway {
  void dispose();
}

/// Typed failures from a remote assistant transport.
///
/// User-visible code should surface only [reason], not [message], because the
/// latter may contain server or networking details.
class AssistantGatewayException implements Exception {
  const AssistantGatewayException(this.reason, this.message);

  final AssistantFallbackReason reason;
  final String message;

  @override
  String toString() => 'AssistantGatewayException($reason, $message)';
}

/// Applies local emergency routing and a deterministic fallback around an
/// optional remote assistant.
class ResilientAssistantGateway
    implements
        AssistantGateway,
        DisposableAssistantGateway,
        RemoteAwareAssistantGateway {
  ResilientAssistantGateway({
    this.remote,
    this.fallback = const DemoAssistantEngine(),
  });

  final AssistantGateway? remote;
  final DemoAssistantEngine fallback;

  @override
  bool get maySendRemotely => remote != null;

  @override
  Future<AssistantGatewayResponse> replyTo(
    String message,
    AppStore store, {
    List<ChatMessage> history = const [],
  }) async {
    // The deterministic engine is deliberately evaluated first. Emergency
    // prompts must receive immediate local guidance and are never sent to the
    // remote model before that guidance is produced.
    final localReply = fallback.replyTo(message, store);
    if (localReply.level == SafetyLevel.urgent) {
      return AssistantGatewayResponse(
        reply: localReply,
        source: AssistantResponseSource.emergencyLocal,
      );
    }

    final remoteGateway = remote;
    if (remoteGateway == null) {
      return AssistantGatewayResponse(
        reply: localReply,
        source: AssistantResponseSource.demoFallback,
        fallbackReason: AssistantFallbackReason.notConfigured,
      );
    }

    try {
      return await remoteGateway.replyTo(message, store, history: history);
    } on AssistantGatewayException catch (error) {
      return AssistantGatewayResponse(
        reply: localReply,
        source: AssistantResponseSource.demoFallback,
        fallbackReason: error.reason,
      );
    }
  }

  @override
  void dispose() {
    final remoteGateway = remote;
    if (remoteGateway is DisposableAssistantGateway) {
      (remoteGateway as DisposableAssistantGateway).dispose();
    }
  }
}
