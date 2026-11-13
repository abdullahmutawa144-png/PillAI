import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pill_ai/data/http_assistant_gateway.dart';
import 'package:pill_ai/domain/app_models.dart';
import 'package:pill_ai/domain/app_store.dart';
import 'package:pill_ai/domain/assistant_gateway.dart';

void main() {
  const requestUuid = '123e4567-e89b-42d3-a456-426614174000';
  late AppStore store;

  setUp(() {
    store = AppStore.demo(clock: DateTime(2026, 7, 20, 9));
  });

  tearDown(() => store.dispose());

  test(
    'posts minimized structured context and parses strict metadata',
    () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(_validResponse()),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final gateway = HttpAssistantGateway(
        baseUri: Uri.parse('https://api.example.test/pillai'),
        client: client,
        clientIdProvider: () async => 'install_test_client',
        nowProvider: () => DateTime.utc(2026, 7, 20, 20, 55),
        timeZoneProvider: () => 'Asia/Riyadh',
        timeZoneOffsetProvider: (_) => const Duration(hours: 3),
        requestIdProvider: () => requestUuid,
      );
      final adjustedDose = store.todayDoses.first;
      store.snoozeDose(
        adjustedDose.id,
        duration: const Duration(hours: 13, minutes: 30),
      );
      final history = <ChatMessage>[
        for (var index = 0; index < 10; index++)
          ChatMessage(
            text: 'message $index',
            isUser: index.isEven,
            sentAt: DateTime(2026, 7, 20, 8, index),
          ),
      ];

      final response = await gateway.replyTo(
        'Can I take these together?',
        store,
        history: history,
      );

      expect(captured.url.path, '/pillai/v1/assistant/messages');
      expect(captured.headers, isNot(contains('authorization')));
      expect(captured.headers['x-request-id'], requestUuid);
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['clientId'], 'install_test_client');
      expect(body['message'], 'Can I take these together?');
      final context = body['context'] as Map<String, dynamic>;
      expect(context['now'], '2026-07-20T20:55:00.000Z');
      expect(context['timeZone'], 'Asia/Riyadh');
      final profile = context['profile'] as Map<String, dynamic>;
      expect(profile, isNot(contains('name')));
      expect(profile['allergies'], isEmpty);
      expect(context['medications'], hasLength(3));
      expect(context['todayDoses'], hasLength(3));
      final sentAdjustedDose = (context['todayDoses'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .singleWhere((dose) => dose['id'] == adjustedDose.id);
      final storedAdjustedDose = store.doseFor(adjustedDose.id);
      expect(
        sentAdjustedDose['scheduledAt'],
        storedAdjustedDose.scheduledAt.toUtc().toIso8601String(),
      );
      expect(
        sentAdjustedDose['originalScheduledAt'],
        storedAdjustedDose.originalScheduledAt!.toUtc().toIso8601String(),
      );
      final safety = context['safetyContext'] as Map<String, dynamic>;
      expect(safety, isNot(contains('accessibilityNeeds')));
      final sentHistory = body['history'] as List<dynamic>;
      expect(sentHistory, hasLength(HttpAssistantGateway.maxHistoryMessages));
      expect(
        (sentHistory.first as Map<String, dynamic>)['content'],
        'message 2',
      );
      final clientMetadata = body['client'] as Map<String, dynamic>;
      expect(clientMetadata['timezoneOffsetMinutes'], 180);

      expect(response.source, AssistantResponseSource.liveModel);
      expect(response.model, 'gpt-5.6-terra');
      expect(response.requestId, 'req_123');
      expect(response.degraded, isFalse);
      expect(response.notice, contains('server-owned template'));
      expect(response.reply.level, SafetyLevel.caution);
      expect(response.reply.coverage, SafetyCoverage.notChecked);
    },
  );

  test(
    'parses durable memory, dose events, sources, and a schedule proposal',
    () async {
      final dose = store.todayDoses.first;
      final responseBody = _validResponse();
      responseBody['memoryUpdates'] = [
        {
          'kind': 'routine',
          'value': 'Usually works a night shift',
          'status': 'reported',
          'occurredAt': null,
          'medicationIds': [dose.medicationId],
        },
      ];
      responseBody['doseEvent'] = {
        'action': 'missed',
        'doseId': dose.id,
        'occurredAt': '2026-07-20T09:10:00Z',
        'note': 'User reported sleeping through the reminder',
        'confidence': 'high',
      };
      responseBody['sources'] = [
        {
          'title': 'Official product label',
          'url': 'https://dailymed.nlm.nih.gov/example',
          'support': 'Contains the product timing instruction.',
        },
      ];
      responseBody['scheduleProposal'] = {
        'summary': 'Review this new reminder time.',
        'changes': [
          {
            'doseId': dose.id,
            'from': dose.scheduledAt.toUtc().toIso8601String(),
            'to': dose.scheduledAt
                .add(const Duration(hours: 2))
                .toUtc()
                .toIso8601String(),
            'reason': 'Source-backed timing constraint',
            'sourceUrl': 'https://dailymed.nlm.nih.gov/example',
          },
        ],
      };
      final gateway = HttpAssistantGateway(
        baseUri: Uri.parse('https://api.example.test'),
        client: MockClient(
          (_) async => http.Response(jsonEncode(responseBody), 200),
        ),
        clientIdProvider: () async => 'install_test_client',
        nowProvider: () => DateTime.utc(2026, 7, 20, 9, 20),
      );

      final response = await gateway.replyTo('I overslept', store);

      expect(response.memoryUpdates.single.kind, MedicationMemoryKind.routine);
      expect(response.doseEvent?.action, AssistantDoseAction.missed);
      expect(response.scheduleProposal?.changes, hasLength(1));
      expect(response.reply.sources.single.title, 'Official product label');
    },
  );

  test('rejects a response with an unsupported safety enum', () async {
    final invalid = _validResponse();
    (invalid['reply'] as Map<String, Object?>)['coverage'] = 'probablySafe';
    final gateway = HttpAssistantGateway(
      baseUri: Uri.parse('https://api.example.test'),
      client: MockClient((_) async => http.Response(jsonEncode(invalid), 200)),
      clientIdProvider: () async => 'install_test_client',
    );

    await expectLater(
      gateway.replyTo('Question', store),
      throwsA(
        isA<AssistantGatewayException>().having(
          (error) => error.reason,
          'reason',
          AssistantFallbackReason.invalidResponse,
        ),
      ),
    );
  });

  test('omits an unstable time-zone abbreviation', () async {
    late Map<String, dynamic> capturedBody;
    final gateway = HttpAssistantGateway(
      baseUri: Uri.parse('https://api.example.test'),
      client: MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_validResponse()), 200);
      }),
      clientIdProvider: () async => 'install_test_client',
      nowProvider: () => DateTime.utc(2026, 7, 20, 23, 59, 59),
      timeZoneProvider: () => 'AST',
      timeZoneOffsetProvider: (_) => const Duration(hours: 3),
    );

    await gateway.replyTo('Question', store);

    final context = capturedBody['context'] as Map<String, dynamic>;
    expect(context['now'], '2026-07-20T23:59:59.000Z');
    expect(context, isNot(contains('timeZone')));
    expect(
      (capturedBody['client'] as Map<String, dynamic>)['timezoneOffsetMinutes'],
      180,
    );
  });

  test('uses a fresh UUID v4 correlation header for every request', () async {
    final ids = <String>[];
    final gateway = HttpAssistantGateway(
      baseUri: Uri.parse('https://api.example.test'),
      client: MockClient((request) async {
        ids.add(request.headers['x-request-id']!);
        return http.Response(jsonEncode(_validResponse()), 200);
      }),
      clientIdProvider: () async => 'install_test_client',
    );

    await gateway.replyTo('First', store);
    await gateway.replyTo('Second', store);

    final uuidV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    expect(ids, hasLength(2));
    expect(ids, everyElement(matches(uuidV4)));
    expect(ids.first, isNot(ids.last));
  });

  test('defaults to a timeout longer than the backend budget', () {
    final gateway = HttpAssistantGateway(
      baseUri: Uri.parse('https://api.example.test'),
      client: MockClient((_) async => http.Response('', 500)),
    );

    expect(gateway.timeout, const Duration(seconds: 45));
  });

  test('strictly distinguishes every backend fallback subtype', () async {
    final demo = _validResponse();
    final demoMeta = demo['meta'] as Map<String, Object?>;
    demoMeta['source'] = 'demo';
    demoMeta['fallbackReason'] = 'no_key';
    final demoGateway = HttpAssistantGateway(
      baseUri: Uri.parse('https://api.example.test'),
      client: MockClient((_) async => http.Response(jsonEncode(demo), 200)),
      clientIdProvider: () async => 'install_test_client',
    );

    final demoResponse = await demoGateway.replyTo('Question', store);
    expect(demoResponse.source, AssistantResponseSource.demoFallback);
    expect(demoResponse.degraded, isFalse);
    expect(demoResponse.fallbackReason, AssistantFallbackReason.noApiKey);

    for (final (wireValue, expected) in [
      ('upstream_unavailable', AssistantFallbackReason.upstreamUnavailable),
      ('invalid_output', AssistantFallbackReason.invalidModelOutput),
    ]) {
      final degraded = _validResponse();
      final meta = degraded['meta'] as Map<String, Object?>;
      meta['source'] = 'demo';
      meta['degraded'] = true;
      meta['fallbackReason'] = wireValue;
      final gateway = HttpAssistantGateway(
        baseUri: Uri.parse('https://api.example.test'),
        client: MockClient(
          (_) async => http.Response(jsonEncode(degraded), 200),
        ),
        clientIdProvider: () async => 'install_test_client',
      );

      final response = await gateway.replyTo('Question', store);
      expect(response.source, AssistantResponseSource.demoFallback);
      expect(response.degraded, isTrue);
      expect(response.fallbackReason, expected);
    }
  });

  test(
    'strictly distinguishes both deterministic backend safety gates',
    () async {
      for (final (wireValue, expected) in [
        ('emergency_phrase', AssistantSafetyGate.emergencyPhrase),
        ('composed_output_guard', AssistantSafetyGate.composedOutputGuard),
        (
          'model_possible_emergency',
          AssistantSafetyGate.modelPossibleEmergency,
        ),
      ]) {
        final guarded = _validResponse();
        final meta = guarded['meta'] as Map<String, Object?>;
        meta['source'] = 'safety_gate';
        meta['safetyGate'] = wireValue;
        final gateway = HttpAssistantGateway(
          baseUri: Uri.parse('https://api.example.test'),
          client: MockClient(
            (_) async => http.Response(jsonEncode(guarded), 200),
          ),
          clientIdProvider: () async => 'install_test_client',
        );

        final response = await gateway.replyTo('Question', store);
        expect(response.source, AssistantResponseSource.safetyGuard);
        expect(response.safetyGate, expected);
        expect(response.degraded, isFalse);
      }
    },
  );

  test('rejects an unknown server source', () async {
    final invalid = _validResponse();
    (invalid['meta'] as Map<String, Object?>)['source'] = 'untrusted';
    final gateway = HttpAssistantGateway(
      baseUri: Uri.parse('https://api.example.test'),
      client: MockClient((_) async => http.Response(jsonEncode(invalid), 200)),
      clientIdProvider: () async => 'install_test_client',
    );

    await expectLater(
      gateway.replyTo('Question', store),
      throwsA(
        isA<AssistantGatewayException>().having(
          (error) => error.reason,
          'reason',
          AssistantFallbackReason.invalidResponse,
        ),
      ),
    );
  });

  test(
    'rejects unknown, mistyped, or inconsistent provenance metadata',
    () async {
      final invalidCases = <Map<String, Object?>>[
        {'source': 'demo', 'degraded': true, 'fallbackReason': 'future_reason'},
        {
          'source': 'demo',
          'degraded': false,
          'fallbackReason': 'upstream_unavailable',
        },
        {'degraded': 'false'},
        {'source': 'safety_gate', 'safetyGate': 'future_gate'},
        {'unexpected': 'field'},
      ];

      for (final overrides in invalidCases) {
        final invalid = _validResponse();
        (invalid['meta'] as Map<String, Object?>).addAll(overrides);
        final gateway = HttpAssistantGateway(
          baseUri: Uri.parse('https://api.example.test'),
          client: MockClient(
            (_) async => http.Response(jsonEncode(invalid), 200),
          ),
          clientIdProvider: () async => 'install_test_client',
        );

        await expectLater(
          gateway.replyTo('Question', store),
          throwsA(
            isA<AssistantGatewayException>().having(
              (error) => error.reason,
              'reason',
              AssistantFallbackReason.invalidResponse,
            ),
          ),
          reason: '$overrides should be rejected',
        );
      }
    },
  );

  test('classifies request timeout without leaking a raw exception', () async {
    final gateway = HttpAssistantGateway(
      baseUri: Uri.parse('https://api.example.test'),
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(jsonEncode(_validResponse()), 200);
      }),
      clientIdProvider: () async => 'install_test_client',
    );

    await expectLater(
      gateway.replyTo('Question', store),
      throwsA(
        isA<AssistantGatewayException>().having(
          (error) => error.reason,
          'reason',
          AssistantFallbackReason.timeout,
        ),
      ),
    );
  });

  test('invalid base URL is a configuration fallback reason', () async {
    final gateway = HttpAssistantGateway(
      baseUri: Uri(),
      client: MockClient((_) async => throw StateError('must not be called')),
      clientIdProvider: () async => 'install_test_client',
    );

    await expectLater(
      gateway.replyTo('Question', store),
      throwsA(
        isA<AssistantGatewayException>().having(
          (error) => error.reason,
          'reason',
          AssistantFallbackReason.notConfigured,
        ),
      ),
    );
  });

  test('plain HTTP is limited to local and Android-emulator hosts', () {
    for (final url in [
      'http://127.0.0.1:8787',
      'http://localhost:8787',
      'http://[::1]:8787',
      'http://10.0.2.2:8787',
      'https://api.example.test',
    ]) {
      final gateway = HttpAssistantGateway(
        baseUri: Uri.parse(url),
        client: MockClient((_) async => http.Response('', 500)),
      );
      expect(gateway.maySendRemotely, isTrue, reason: url);
    }

    for (final url in ['http://192.168.1.20:8787', 'http://api.example.test']) {
      final gateway = HttpAssistantGateway(
        baseUri: Uri.parse(url),
        client: MockClient((_) async => http.Response('', 500)),
      );
      expect(gateway.maySendRemotely, isFalse, reason: url);
    }
  });

  test('rejects remote plain HTTP before sending health context', () async {
    var calls = 0;
    final gateway = HttpAssistantGateway(
      baseUri: Uri.parse('http://192.168.1.20:8787'),
      client: MockClient((_) async {
        calls++;
        return http.Response(jsonEncode(_validResponse()), 200);
      }),
      clientIdProvider: () async => 'install_test_client',
    );

    await expectLater(
      gateway.replyTo('Question', store),
      throwsA(
        isA<AssistantGatewayException>().having(
          (error) => error.reason,
          'reason',
          AssistantFallbackReason.notConfigured,
        ),
      ),
    );
    expect(calls, 0);
  });

  test('fails closed when secure request randomness is unavailable', () async {
    var calls = 0;
    final gateway = HttpAssistantGateway(
      baseUri: Uri.parse('https://api.example.test'),
      client: MockClient((_) async {
        calls++;
        return http.Response(jsonEncode(_validResponse()), 200);
      }),
      clientIdProvider: () async => 'install_test_client',
      secureRandomProvider: () => throw UnsupportedError('unavailable'),
    );

    await expectLater(
      gateway.replyTo('Question', store),
      throwsA(
        isA<AssistantGatewayException>().having(
          (error) => error.reason,
          'reason',
          AssistantFallbackReason.notConfigured,
        ),
      ),
    );
    expect(calls, 0);
  });
}

Map<String, Object?> _validResponse() {
  return {
    'reply': {
      'title': 'Needs a medicine-specific check',
      'message': 'I can explain the factors, but this is not verification.',
      'level': 'caution',
      'actionLabel': 'Review safety profile',
      'suggestedPrompt': null,
      'coverage': 'notChecked',
      'contextNote': 'Saved details were considered.',
    },
    'meta': {
      'source': 'model',
      'model': 'gpt-5.6-terra',
      'requestId': 'req_123',
      'degraded': false,
      'notice':
          'The model classified intent; wording came from a server-owned template.',
      'fallbackReason': null,
      'safetyGate': null,
    },
  };
}
