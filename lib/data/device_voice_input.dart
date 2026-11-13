import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../domain/voice_input.dart';

class DeviceVoiceInput extends VoiceInputController {
  DeviceVoiceInput({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  VoiceInputStatus _status = VoiceInputStatus.idle;
  String? _errorMessage;
  double _soundLevel = 0;
  bool _initialized = false;

  @override
  VoiceInputStatus get status => _status;

  @override
  String? get errorMessage => _errorMessage;

  @override
  double get soundLevel => _soundLevel;

  @override
  Future<bool> initialize() async {
    if (_initialized) return true;
    _setStatus(VoiceInputStatus.initializing);
    _errorMessage = null;
    try {
      final available = await _speech.initialize(
        onStatus: _handlePlatformStatus,
        onError: _handleError,
        options: [SpeechToText.androidNoBluetooth, SpeechToText.iosNoBluetooth],
      );
      _initialized = available;
      _setStatus(
        available ? VoiceInputStatus.ready : VoiceInputStatus.unavailable,
      );
      if (!available) {
        _errorMessage =
            'Voice input is not available on this device. You can keep typing.';
      }
      return available;
    } catch (_) {
      _errorMessage =
          'Voice input could not start. Check microphone permission and try again.';
      _setStatus(VoiceInputStatus.error);
      return false;
    }
  }

  @override
  Future<void> start({
    required ValueChanged<VoiceTranscript> onTranscript,
    String? localeId,
  }) async {
    if (!await initialize()) return;
    _errorMessage = null;
    try {
      await _speech.listen(
        onResult: (result) => _handleResult(result, onTranscript),
        onSoundLevelChange: (level) {
          _soundLevel = level;
          notifyListeners();
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          autoPunctuation: true,
          enableHapticFeedback: true,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          localeId: localeId,
        ),
      );
      if (_speech.isListening) _setStatus(VoiceInputStatus.listening);
    } catch (_) {
      _errorMessage = 'Voice input is busy or unavailable. Please try again.';
      _setStatus(VoiceInputStatus.error);
    }
  }

  @override
  Future<void> stop() async {
    if (!_initialized || !_speech.isListening) return;
    _setStatus(VoiceInputStatus.finalizing);
    await _speech.stop();
  }

  @override
  Future<void> cancel() async {
    if (_initialized && _speech.isListening) await _speech.cancel();
    _soundLevel = 0;
    _setStatus(_initialized ? VoiceInputStatus.ready : VoiceInputStatus.idle);
  }

  void _handleResult(
    SpeechRecognitionResult result,
    ValueChanged<VoiceTranscript> callback,
  ) {
    callback(
      VoiceTranscript(
        text: result.recognizedWords,
        isFinal: result.finalResult,
        confidence: result.confidence,
      ),
    );
    if (result.finalResult) _setStatus(VoiceInputStatus.ready);
  }

  void _handlePlatformStatus(String status) {
    if (status == SpeechToText.listeningStatus) {
      _setStatus(VoiceInputStatus.listening);
    } else if (status == SpeechToText.doneStatus ||
        status == SpeechToText.notListeningStatus) {
      _soundLevel = 0;
      _setStatus(_initialized ? VoiceInputStatus.ready : VoiceInputStatus.idle);
    }
  }

  void _handleError(SpeechRecognitionError error) {
    final code = error.errorMsg.toLowerCase();
    if (code.contains('permission') || code.contains('denied')) {
      _errorMessage =
          'Microphone or speech permission was denied. Enable it in device settings, or type instead.';
      _setStatus(VoiceInputStatus.permissionDenied);
      return;
    }
    if (code.contains('no_match') || code.contains('timeout')) {
      _errorMessage = 'No speech was heard. Tap the microphone and try again.';
    } else if (code.contains('network') || code.contains('server')) {
      _errorMessage =
          'The device speech service could not connect. Check your connection or type instead.';
    } else {
      _errorMessage = 'Voice input stopped unexpectedly. Please try again.';
    }
    _setStatus(
      error.permanent ? VoiceInputStatus.unavailable : VoiceInputStatus.error,
    );
  }

  void _setStatus(VoiceInputStatus value) {
    if (_status == value) return;
    _status = value;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_initialized && _speech.isListening) unawaited(_speech.cancel());
    super.dispose();
  }
}
