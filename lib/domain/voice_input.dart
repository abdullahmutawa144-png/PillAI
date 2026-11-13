import 'package:flutter/foundation.dart';

enum VoiceInputStatus {
  idle,
  initializing,
  ready,
  listening,
  finalizing,
  permissionDenied,
  unavailable,
  error,
}

class VoiceTranscript {
  const VoiceTranscript({
    required this.text,
    required this.isFinal,
    required this.confidence,
  });

  final String text;
  final bool isFinal;
  final double confidence;
}

abstract class VoiceInputController extends ChangeNotifier {
  VoiceInputStatus get status;
  String? get errorMessage;
  double get soundLevel;
  bool get isListening => status == VoiceInputStatus.listening;

  Future<bool> initialize();

  Future<void> start({
    required ValueChanged<VoiceTranscript> onTranscript,
    String? localeId,
  });

  Future<void> stop();

  Future<void> cancel();
}
