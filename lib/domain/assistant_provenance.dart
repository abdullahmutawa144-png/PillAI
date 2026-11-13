/// Identifies how an assistant answer was produced.
enum AssistantResponseSource {
  /// A response returned by the configured PillAI backend.
  liveModel,

  /// The deterministic on-device engine was used because live AI was
  /// unavailable or the user selected the local demo.
  demoFallback,

  /// Emergency wording was handled on-device before any network request.
  emergencyLocal,

  /// A deterministic backend output guard replaced a model response.
  safetyGuard,
}

/// A stable, non-sensitive reason that can be surfaced in the interface.
enum AssistantFallbackReason {
  notConfigured,
  userChoseLocal,
  timeout,
  network,
  server,
  invalidResponse,
  noApiKey,
  upstreamUnavailable,
  invalidModelOutput,
}

/// Identifies the deterministic backend gate that produced an answer.
enum AssistantSafetyGate {
  emergencyPhrase,
  composedOutputGuard,
  modelPossibleEmergency,
}

/// Immutable production metadata retained with one assistant message.
///
/// This prevents an older answer from appearing to share the source shown by
/// a newer, global status banner.
class AssistantAnswerProvenance {
  const AssistantAnswerProvenance({
    required this.source,
    this.model,
    this.requestId,
    this.providerSource,
    this.fallbackReason,
    this.degraded = false,
    this.notice,
    this.safetyGate,
  });

  final AssistantResponseSource source;
  final String? model;
  final String? requestId;
  final String? providerSource;
  final AssistantFallbackReason? fallbackReason;
  final bool degraded;
  final String? notice;
  final AssistantSafetyGate? safetyGate;
}
