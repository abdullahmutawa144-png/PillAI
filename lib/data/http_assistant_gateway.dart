import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_models.dart';
import '../domain/app_store.dart';
import '../domain/assistant_gateway.dart';

/// Sends privacy-minimized, structured medication context to the PillAI
/// backend. OpenAI credentials belong on that backend and are never accepted
/// or stored by this Flutter client.
class HttpAssistantGateway
    implements
        AssistantGateway,
        DisposableAssistantGateway,
        RemoteAwareAssistantGateway {
  HttpAssistantGateway({
    required this.baseUri,
    http.Client? client,
    this.clientIdProvider,
    DateTime Function()? nowProvider,
    this.timeZoneProvider,
    this.timeZoneOffsetProvider,
    this.requestIdProvider,
    Random Function()? secureRandomProvider,
    this.timeout = const Duration(seconds: 45),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _nowProvider = nowProvider ?? DateTime.now,
       _secureRandomProvider = secureRandomProvider ?? Random.secure;

  factory HttpAssistantGateway.fromEnvironment({
    http.Client? client,
    DateTime Function()? nowProvider,
    String? Function()? timeZoneProvider,
    Duration Function(DateTime now)? timeZoneOffsetProvider,
    String Function()? requestIdProvider,
    Random Function()? secureRandomProvider,
    Duration timeout = const Duration(seconds: 45),
  }) {
    const configured = String.fromEnvironment('PILLAI_API_BASE_URL');
    final raw = configured.trim().isEmpty
        ? _platformDefaultBaseUrl()
        : configured.trim();
    final disabled =
        raw.toLowerCase() == 'off' || raw.toLowerCase() == 'disabled';
    return HttpAssistantGateway(
      baseUri: disabled ? Uri() : (Uri.tryParse(raw) ?? Uri()),
      client: client,
      nowProvider: nowProvider,
      timeZoneProvider: timeZoneProvider,
      timeZoneOffsetProvider: timeZoneOffsetProvider,
      requestIdProvider: requestIdProvider,
      secureRandomProvider: secureRandomProvider,
      timeout: timeout,
    );
  }

  static const int maxHistoryMessages = 8;
  static const int maxHistoryCharacters = 1200;
  static const String _clientIdPreferenceKey = 'pillai.install_client_id';

  final Uri baseUri;
  final http.Client _client;
  final bool _ownsClient;
  final Future<String> Function()? clientIdProvider;
  final DateTime Function() _nowProvider;
  final String? Function()? timeZoneProvider;
  final Duration Function(DateTime now)? timeZoneOffsetProvider;
  final String Function()? requestIdProvider;
  final Random Function() _secureRandomProvider;
  final Duration timeout;
  Future<String>? _clientIdFuture;

  @override
  bool get maySendRemotely => _hasValidBaseUri;

  bool get _hasValidBaseUri =>
      baseUri.hasScheme &&
      (baseUri.scheme == 'https' ||
          (baseUri.scheme == 'http' && _plainHttpHostAllowed(baseUri.host))) &&
      baseUri.host.isNotEmpty &&
      baseUri.userInfo.isEmpty &&
      !baseUri.hasQuery &&
      !baseUri.hasFragment;

  @override
  Future<AssistantGatewayResponse> replyTo(
    String message,
    AppStore store, {
    List<ChatMessage> history = const [],
  }) async {
    final endpoint = _endpointOrThrow();
    final clientId = (await _clientId()).trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(clientId)) {
      throw const AssistantGatewayException(
        AssistantFallbackReason.notConfigured,
        'The install client identifier is invalid.',
      );
    }
    final requestId = (requestIdProvider?.call() ?? _newRequestId()).trim();
    if (!_uuidV4Pattern.hasMatch(requestId)) {
      throw const AssistantGatewayException(
        AssistantFallbackReason.notConfigured,
        'The request identifier provider must return a UUID v4.',
      );
    }
    final payload = _requestPayload(message, store, history, clientId);

    late final http.Response response;
    try {
      response = await _client
          .post(
            endpoint,
            headers: {
              'accept': 'application/json',
              'content-type': 'application/json',
              'x-request-id': requestId,
            },
            body: jsonEncode(payload),
          )
          .timeout(timeout);
    } on TimeoutException catch (_) {
      throw const AssistantGatewayException(
        AssistantFallbackReason.timeout,
        'The assistant request timed out.',
      );
    } on http.ClientException catch (error) {
      throw AssistantGatewayException(
        AssistantFallbackReason.network,
        'The assistant request failed: $error',
      );
    } on Object catch (error) {
      // Platform HTTP implementations can surface different network exception
      // types. Keep their details away from the UI and classify them uniformly.
      throw AssistantGatewayException(
        AssistantFallbackReason.network,
        'The assistant request failed: $error',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AssistantGatewayException(
        AssistantFallbackReason.server,
        'The assistant service returned HTTP ${response.statusCode}.',
      );
    }

    try {
      return _parseResponse(utf8.decode(response.bodyBytes), store);
    } on FormatException catch (error) {
      throw AssistantGatewayException(
        AssistantFallbackReason.invalidResponse,
        'The assistant response did not match the contract: $error',
      );
    }
  }

  Uri _endpointOrThrow() {
    if (!_hasValidBaseUri) {
      throw const AssistantGatewayException(
        AssistantFallbackReason.notConfigured,
        'PILLAI_API_BASE_URL must use HTTPS, except for loopback or the Android emulator host.',
      );
    }

    final baseSegments = baseUri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);
    return baseUri.replace(
      pathSegments: [...baseSegments, 'v1', 'assistant', 'messages'],
      query: null,
      fragment: null,
    );
  }

  Map<String, Object?> _requestPayload(
    String message,
    AppStore store,
    List<ChatMessage> history,
    String clientId,
  ) {
    final profile = store.profile;
    final safety = store.safetyContext;
    final now = _nowProvider();
    final timeZone = _stableTimeZone(now);
    final timeZoneOffset =
        timeZoneOffsetProvider?.call(now) ?? now.timeZoneOffset;

    return {
      'clientId': clientId,
      'message': message,
      'context': {
        'now': now.toUtc().toIso8601String(),
        'timeZone': ?timeZone,
        'profile': {
          if (_isAdded(safety.ageRange)) 'ageRange': safety.ageRange,
          if (_isAdded(safety.sexForMedicationSafety))
            'sexForMedicationSafety': safety.sexForMedicationSafety,
          'reproductiveStatus': safety.reproductiveStatus.name,
          'kidneyStatus': safety.kidneyStatus.name,
          'liverStatus': safety.liverStatus.name,
          'conditions': _withoutPlaceholders(profile.conditions),
          'allergies': _withoutPlaceholders(profile.allergies),
          if (_isAdded(profile.weightLabel)) 'weightLabel': profile.weightLabel,
          'wakeTimeLabel': profile.wakeTimeLabel,
          'sleepTimeLabel': profile.sleepTimeLabel,
          'preferredLanguage': profile.preferredLanguage,
        },
        'safetyContext': {
          'foodAndDrink': {
            'reviewed': safety.foodAndDrinkReviewed,
            'factors': safety.foodAndDrinkFactors,
          },
          'supplementsAndOtc': {
            'reviewed': safety.supplementsReviewed,
            'items': safety.supplementsAndOtc,
          },
          'lifestyle': {
            'reviewed': safety.lifestyleReviewed,
            'factors': safety.lifestyleFactors,
          },
        },
        'medications': [
          for (final medication in store.medications)
            {
              'id': medication.id,
              'name': medication.name,
              'strength': medication.strength,
              'form': medication.form.name,
              'doseLabel': medication.doseLabel,
              'instructions': medication.instructions,
              'isPrescription': medication.isPrescription,
              'activeIngredients': medication.activeIngredients,
            },
        ],
        'todayDoses': [
          for (final dose in store.todayDoses)
            {
              'id': dose.id,
              'medicationId': dose.medicationId,
              'medicationName': store.medicationFor(dose.medicationId).name,
              'scheduledAt': dose.scheduledAt.toUtc().toIso8601String(),
              'status': dose.status.name,
              if (dose.actualAt != null)
                'actualAt': dose.actualAt!.toUtc().toIso8601String(),
              if (dose.originalScheduledAt != null)
                'originalScheduledAt': dose.originalScheduledAt!
                    .toUtc()
                    .toIso8601String(),
              if (dose.missedReason?.trim().isNotEmpty == true)
                'missedReason': dose.missedReason!.trim(),
            },
        ],
        'memoryFacts': [
          for (final fact in store.memoryFacts)
            {
              'id': fact.id,
              'kind': fact.kind.name,
              'value': fact.value,
              'status': fact.status.name,
              if (fact.occurredAt != null)
                'occurredAt': fact.occurredAt!.toUtc().toIso8601String(),
              'medicationIds': fact.medicationIds,
            },
        ],
      },
      if (history.isNotEmpty) 'history': _minimizedHistory(history),
      'client': {
        'app': 'PillAI',
        'version': '1.0.0',
        'platform': _platformName(),
        'displayMode': store.displayMode.name,
        'locale': profile.preferredLanguage,
        'timezoneOffsetMinutes': timeZoneOffset.inMinutes,
      },
    };
  }

  List<Map<String, String>> _minimizedHistory(List<ChatMessage> history) {
    final relevant = history
        .where((entry) => entry.text.trim().isNotEmpty)
        .toList(growable: false);
    final start = relevant.length > maxHistoryMessages
        ? relevant.length - maxHistoryMessages
        : 0;
    return [
      for (final entry in relevant.skip(start))
        {
          'role': entry.isUser ? 'user' : 'assistant',
          'content': _truncate(entry.text.trim(), maxHistoryCharacters),
        },
    ];
  }

  AssistantGatewayResponse _parseResponse(String body, AppStore store) {
    final decoded = jsonDecode(body);
    final root = _requiredMap(decoded, 'response');
    final replyJson = _requiredMap(root['reply'], 'reply');
    final metaJson = _requiredMap(root['meta'], 'meta');
    _requireOnlyKeys(metaJson, const {
      'source',
      'requestId',
      'model',
      'degraded',
      'notice',
      'fallbackReason',
      'safetyGate',
    }, 'meta');

    final level = _parseEnum(
      _requiredString(replyJson, 'level'),
      SafetyLevel.values,
      'reply.level',
    );
    final coverage = _parseEnum(
      _requiredString(replyJson, 'coverage'),
      SafetyCoverage.values,
      'reply.coverage',
    );

    final sources = _parseSources(root['sources']);
    final memoryUpdates = _parseMemoryUpdates(root['memoryUpdates']);
    final doseEvent = _parseDoseEvent(root['doseEvent']);
    final scheduleProposal = _parseScheduleProposal(
      root['scheduleProposal'],
      store,
    );

    final reply = AssistantReply(
      title: _requiredString(replyJson, 'title'),
      message: _requiredString(replyJson, 'message'),
      level: level,
      actionLabel: _optionalString(replyJson, 'actionLabel'),
      suggestedPrompt: _optionalString(replyJson, 'suggestedPrompt'),
      coverage: coverage,
      contextNote: _optionalString(replyJson, 'contextNote'),
      sources: sources,
    );

    final providerSource = _requiredString(metaJson, 'source');
    final requestId = _requiredString(metaJson, 'requestId');
    final model = _requiredString(metaJson, 'model');
    final degraded = _requiredBool(metaJson, 'degraded');
    final notice = _requiredString(metaJson, 'notice');
    final fallbackReason =
        _requiredNullableMappedEnum(metaJson, 'fallbackReason', const {
          'no_key': AssistantFallbackReason.noApiKey,
          'upstream_unavailable': AssistantFallbackReason.upstreamUnavailable,
          'invalid_output': AssistantFallbackReason.invalidModelOutput,
        });
    final safetyGate = _requiredNullableMappedEnum(
      metaJson,
      'safetyGate',
      const {
        'emergency_phrase': AssistantSafetyGate.emergencyPhrase,
        'composed_output_guard': AssistantSafetyGate.composedOutputGuard,
        'model_possible_emergency': AssistantSafetyGate.modelPossibleEmergency,
      },
    );
    return switch (providerSource) {
      'model' => _modelResponse(
        reply: reply,
        providerSource: providerSource,
        model: model,
        requestId: requestId,
        degraded: degraded,
        notice: notice,
        fallbackReason: fallbackReason,
        safetyGate: safetyGate,
        memoryUpdates: memoryUpdates,
        doseEvent: doseEvent,
        scheduleProposal: scheduleProposal,
      ),
      'demo' => _demoResponse(
        reply: reply,
        providerSource: providerSource,
        model: model,
        requestId: requestId,
        degraded: degraded,
        notice: notice,
        fallbackReason: fallbackReason,
        safetyGate: safetyGate,
      ),
      'safety_gate' => _safetyGateResponse(
        reply: reply,
        providerSource: providerSource,
        model: model,
        requestId: requestId,
        degraded: degraded,
        notice: notice,
        fallbackReason: fallbackReason,
        safetyGate: safetyGate,
      ),
      _ => throw FormatException(
        'meta.source has unsupported value "$providerSource".',
      ),
    };
  }

  AssistantGatewayResponse _modelResponse({
    required AssistantReply reply,
    required String providerSource,
    required String model,
    required String requestId,
    required bool degraded,
    required String notice,
    required AssistantFallbackReason? fallbackReason,
    required AssistantSafetyGate? safetyGate,
    required List<MedicationMemoryFact> memoryUpdates,
    required AssistantDoseEvent? doseEvent,
    required RescheduleProposal? scheduleProposal,
  }) {
    if (degraded || fallbackReason != null || safetyGate != null) {
      throw const FormatException(
        'Model responses cannot be degraded or include fallback/safety metadata.',
      );
    }
    return AssistantGatewayResponse(
      reply: reply,
      source: AssistantResponseSource.liveModel,
      providerSource: providerSource,
      model: model,
      requestId: requestId,
      degraded: degraded,
      notice: notice,
      memoryUpdates: memoryUpdates,
      doseEvent: doseEvent,
      scheduleProposal: scheduleProposal,
    );
  }

  AssistantGatewayResponse _demoResponse({
    required AssistantReply reply,
    required String providerSource,
    required String model,
    required String requestId,
    required bool degraded,
    required String notice,
    required AssistantFallbackReason? fallbackReason,
    required AssistantSafetyGate? safetyGate,
  }) {
    if (safetyGate != null || fallbackReason == null) {
      throw const FormatException(
        'Demo responses require one fallback reason and no safety gate.',
      );
    }
    final shouldBeDegraded = fallbackReason != AssistantFallbackReason.noApiKey;
    if (degraded != shouldBeDegraded) {
      throw const FormatException(
        'Demo degraded state does not match its fallback reason.',
      );
    }
    return AssistantGatewayResponse(
      reply: reply,
      source: AssistantResponseSource.demoFallback,
      providerSource: providerSource,
      model: model,
      requestId: requestId,
      degraded: degraded,
      notice: notice,
      fallbackReason: fallbackReason,
    );
  }

  AssistantGatewayResponse _safetyGateResponse({
    required AssistantReply reply,
    required String providerSource,
    required String model,
    required String requestId,
    required bool degraded,
    required String notice,
    required AssistantFallbackReason? fallbackReason,
    required AssistantSafetyGate? safetyGate,
  }) {
    if (degraded || fallbackReason != null || safetyGate == null) {
      throw const FormatException(
        'Safety-gate responses require one gate and no fallback metadata.',
      );
    }
    return AssistantGatewayResponse(
      reply: reply,
      source: AssistantResponseSource.safetyGuard,
      providerSource: providerSource,
      model: model,
      requestId: requestId,
      degraded: degraded,
      notice: notice,
      safetyGate: safetyGate,
    );
  }

  List<EvidenceSource> _parseSources(Object? value) {
    if (value == null) return const [];
    if (value is! List || value.length > 8) {
      throw const FormatException('sources must be a bounded array.');
    }
    return [
      for (var index = 0; index < value.length; index++)
        () {
          final source = _requiredMap(value[index], 'sources[$index]');
          final url = _requiredString(source, 'url');
          final parsed = Uri.tryParse(url);
          if (parsed == null ||
              parsed.scheme != 'https' ||
              parsed.host.isEmpty) {
            throw FormatException('sources[$index].url must use HTTPS.');
          }
          return EvidenceSource(
            title: _requiredString(source, 'title'),
            url: url,
            support: _requiredString(source, 'support'),
          );
        }(),
    ];
  }

  List<MedicationMemoryFact> _parseMemoryUpdates(Object? value) {
    if (value == null) return const [];
    if (value is! List || value.length > 8) {
      throw const FormatException('memoryUpdates must be a bounded array.');
    }
    final now = _nowProvider();
    return [
      for (var index = 0; index < value.length; index++)
        () {
          final fact = _requiredMap(value[index], 'memoryUpdates[$index]');
          final kind = _parseEnum(
            _requiredString(fact, 'kind'),
            MedicationMemoryKind.values,
            'memoryUpdates[$index].kind',
          );
          final status = _parseEnum(
            _requiredString(fact, 'status'),
            MemoryFactStatus.values,
            'memoryUpdates[$index].status',
          );
          final text = _requiredString(fact, 'value');
          final medicationIds = fact['medicationIds'];
          if (medicationIds is! List ||
              medicationIds.length > 8 ||
              medicationIds.any((id) => id is! String)) {
            throw FormatException(
              'memoryUpdates[$index].medicationIds must be a string array.',
            );
          }
          final occurredAt = _optionalDateTime(
            fact['occurredAt'],
            'memoryUpdates[$index].occurredAt',
          );
          return MedicationMemoryFact(
            id: 'ai-${now.microsecondsSinceEpoch}-$index',
            kind: kind,
            value: text,
            status: status,
            recordedAt: now,
            occurredAt: occurredAt,
            medicationIds: medicationIds.cast<String>(),
          );
        }(),
    ];
  }

  AssistantDoseEvent? _parseDoseEvent(Object? value) {
    if (value == null) return null;
    final event = _requiredMap(value, 'doseEvent');
    final action = _parseEnum(
      _requiredString(event, 'action'),
      AssistantDoseAction.values,
      'doseEvent.action',
    );
    if (action == AssistantDoseAction.none) return null;
    return AssistantDoseEvent(
      action: action,
      confidence: _parseEnum(
        _requiredString(event, 'confidence'),
        AssistantConfidence.values,
        'doseEvent.confidence',
      ),
      doseId: _optionalString(event, 'doseId'),
      occurredAt: _optionalDateTime(
        event['occurredAt'],
        'doseEvent.occurredAt',
      ),
      note: _optionalString(event, 'note'),
    );
  }

  RescheduleProposal? _parseScheduleProposal(Object? value, AppStore store) {
    if (value == null) return null;
    final proposal = _requiredMap(value, 'scheduleProposal');
    final rawChanges = proposal['changes'];
    if (rawChanges is! List || rawChanges.length > 12) {
      throw const FormatException('scheduleProposal.changes must be bounded.');
    }
    if (rawChanges.isEmpty) return null;
    final changes = <ScheduleChange>[];
    for (var index = 0; index < rawChanges.length; index++) {
      final change = _requiredMap(
        rawChanges[index],
        'scheduleProposal.changes[$index]',
      );
      final doseId = _requiredString(change, 'doseId');
      final dose = store.doseFor(doseId);
      final medication = store.medicationFor(dose.medicationId);
      changes.add(
        ScheduleChange(
          doseId: doseId,
          medicationName: medication.name,
          from: _requiredDateTime(change['from'], 'scheduleProposal.from'),
          to: _requiredDateTime(change['to'], 'scheduleProposal.to'),
          reason: _requiredString(change, 'reason'),
          sourceUrl: _requiredString(change, 'sourceUrl'),
        ),
      );
    }
    final first = changes.first;
    final summary = _optionalString(proposal, 'summary');
    return RescheduleProposal(
      doseId: first.doseId,
      medicationName: first.medicationName,
      from: first.from,
      to: first.to,
      reason: summary ?? first.reason,
      canApply: true,
      safetyNote:
          summary ??
          'Source-backed reminder update ready. Review every time before applying it.',
      changes: changes,
    );
  }

  DateTime _requiredDateTime(Object? value, String field) {
    if (value is! String) throw FormatException('$field must be a date-time.');
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw FormatException('$field must be a date-time.');
    return parsed.toLocal();
  }

  DateTime? _optionalDateTime(Object? value, String field) {
    if (value == null) return null;
    return _requiredDateTime(value, field);
  }

  Future<String> _clientId() {
    final supplied = clientIdProvider;
    if (supplied != null) return supplied();
    return _clientIdFuture ??= _loadOrCreateClientId();
  }

  Future<String> _loadOrCreateClientId() async {
    try {
      final preferences = SharedPreferencesAsync();
      final saved = (await preferences.getString(
        _clientIdPreferenceKey,
      ))?.trim();
      if (saved != null && saved.isNotEmpty) return saved;
      final generated = _newRandomClientId();
      await preferences.setString(_clientIdPreferenceKey, generated);
      return generated;
    } on AssistantGatewayException {
      rethrow;
    } catch (_) {
      // Unsupported platforms and widget tests retain the random ID in memory
      // for this gateway instance. It is never derived from health data.
      return _newRandomClientId();
    }
  }

  String _newRandomClientId() {
    return _encodeRandomId(_secureRandom());
  }

  String _newRequestId() {
    final random = _secureRandom();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  Random _secureRandom() {
    try {
      return _secureRandomProvider();
    } catch (_) {
      throw const AssistantGatewayException(
        AssistantFallbackReason.notConfigured,
        'Secure randomness is unavailable; remote AI has been disabled.',
      );
    }
  }

  String? _stableTimeZone(DateTime now) {
    const configured = String.fromEnvironment('PILLAI_TIME_ZONE');
    final supplied = timeZoneProvider?.call();
    final candidate =
        (supplied?.trim().isNotEmpty == true
                ? supplied!.trim()
                : configured.trim().isNotEmpty
                ? configured.trim()
                : now.timeZoneName.trim())
            .replaceAll('\\', '/');
    if (candidate == 'UTC' || candidate == 'GMT') return 'UTC';
    if (candidate.length > 64 || !_ianaTimeZonePattern.hasMatch(candidate)) {
      return null;
    }
    return candidate;
  }

  String _encodeRandomId(Random random) {
    final bytes = List<int>.generate(18, (_) => random.nextInt(256));
    return 'install_${base64UrlEncode(bytes).replaceAll('=', '')}';
  }

  T _parseEnum<T extends Enum>(String value, List<T> values, String field) {
    for (final candidate in values) {
      if (candidate.name == value) return candidate;
    }
    throw FormatException('$field has unsupported value "$value".');
  }

  Map<String, dynamic> _requiredMap(Object? value, String field) {
    if (value is! Map) throw FormatException('$field must be an object.');
    try {
      return value.cast<String, dynamic>();
    } on TypeError {
      throw FormatException('$field must use string keys.');
    }
  }

  String _requiredString(Map<String, dynamic> map, String field) {
    final value = map[field];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$field must be a non-empty string.');
    }
    return value.trim();
  }

  String? _optionalString(Map<String, dynamic> map, String field) {
    if (!map.containsKey(field) || map[field] == null) return null;
    final value = map[field];
    if (value is! String) {
      throw FormatException('$field must be a string or null.');
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _requiredBool(Map<String, dynamic> map, String field) {
    final value = map[field];
    if (value is! bool) throw FormatException('$field must be a boolean.');
    return value;
  }

  T? _requiredNullableMappedEnum<T>(
    Map<String, dynamic> map,
    String field,
    Map<String, T> values,
  ) {
    if (!map.containsKey(field)) {
      throw FormatException('$field must be present as a string or null.');
    }
    final value = map[field];
    if (value == null) return null;
    if (value is! String || !values.containsKey(value)) {
      throw FormatException('$field has an unsupported value.');
    }
    return values[value];
  }

  void _requireOnlyKeys(
    Map<String, dynamic> map,
    Set<String> allowed,
    String field,
  ) {
    final unexpected = map.keys.where((key) => !allowed.contains(key));
    if (unexpected.isNotEmpty) {
      throw FormatException('$field contains an unsupported field.');
    }
  }

  bool _isAdded(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isNotEmpty &&
        normalized != 'not added' &&
        normalized != 'not reviewed';
  }

  List<String> _withoutPlaceholders(List<String> values) {
    const placeholders = {
      'none recorded',
      'no allergies recorded',
      'no conditions recorded',
      'not added',
    };
    return values
        .map((value) => value.trim())
        .where(
          (value) =>
              value.isNotEmpty && !placeholders.contains(value.toLowerCase()),
        )
        .toList(growable: false);
  }

  String _truncate(String value, int maxCharacters) {
    if (value.length <= maxCharacters) return value;
    return '${value.substring(0, maxCharacters - 1)}…';
  }

  @override
  void dispose() {
    if (_ownsClient) _client.close();
  }
}

final RegExp _uuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

final RegExp _ianaTimeZonePattern = RegExp(
  r'^[A-Za-z0-9._+-]+(?:/[A-Za-z0-9._+-]+)+$',
);

bool _plainHttpHostAllowed(String host) {
  final normalized = host.trim().toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1' ||
      normalized == '10.0.2.2';
}

String _platformDefaultBaseUrl() {
  if (kIsWeb) return 'http://127.0.0.1:8787';
  return defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:8787'
      : 'http://127.0.0.1:8787';
}

String _platformName() {
  if (kIsWeb) return 'web';
  return defaultTargetPlatform.name.toLowerCase();
}
