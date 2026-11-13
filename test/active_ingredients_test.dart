import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pill_ai/data/http_assistant_gateway.dart';
import 'package:pill_ai/domain/app_models.dart';
import 'package:pill_ai/domain/app_store.dart';

void main() {
  test('medication keeps an empty active-ingredient list by default', () {
    const medication = Medication(
      id: 'sample',
      name: 'Sample',
      strength: '',
      form: MedicationForm.other,
      doseLabel: 'As directed',
      instructions: 'Follow the label',
      colorSeed: 0,
    );

    expect(medication.activeIngredients, isEmpty);
  });

  test(
    'addMedication trims and case-insensitively deduplicates ingredients',
    () {
      final store = AppStore.demo(clock: DateTime(2026, 7, 20, 9));
      addTearDown(store.dispose);

      final medication = store.addMedication(
        name: 'Sample medicine',
        strength: '5 mg',
        form: MedicationForm.tablet,
        doseLabel: '1 tablet',
        instructions: 'Follow the label',
        firstDoseAt: DateTime(2026, 7, 20, 16),
        activeIngredients: const [
          '  Amoxicillin ',
          'amoxicillin',
          '',
          ' Clavulanic acid ',
          'CLAVULANIC ACID',
          '   ',
        ],
      );

      expect(medication.activeIngredients, const [
        'Amoxicillin',
        'Clavulanic acid',
      ]);
    },
  );

  test('assistant request serializes exact active ingredients', () async {
    final store = AppStore.demo(clock: DateTime(2026, 7, 20, 9));
    addTearDown(store.dispose);
    store.addMedication(
      name: 'Combination medicine',
      strength: '500 mg / 125 mg',
      form: MedicationForm.tablet,
      doseLabel: '1 tablet',
      instructions: 'Follow the label',
      firstDoseAt: DateTime(2026, 7, 20, 16),
      activeIngredients: const ['Amoxicillin', 'Clavulanic acid'],
    );

    late Map<String, dynamic> capturedBody;
    final gateway = HttpAssistantGateway(
      baseUri: Uri.parse('https://api.example.test'),
      client: MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_validResponse()), 200);
      }),
      clientIdProvider: () async => 'install_test_client',
    );

    await gateway.replyTo('What is saved?', store);

    final context = capturedBody['context'] as Map<String, dynamic>;
    final medications = context['medications'] as List<dynamic>;
    final serialized = medications.cast<Map<String, dynamic>>().singleWhere(
      (item) => item['name'] == 'Combination medicine',
    );
    expect(serialized['activeIngredients'], const [
      'Amoxicillin',
      'Clavulanic acid',
    ]);
  });

  for (final contract in const {
    TargetPlatform.iOS: 'ios',
    TargetPlatform.macOS: 'macos',
  }.entries) {
    test(
      'assistant request uses ${contract.value} platform contract',
      () async {
        debugDefaultTargetPlatformOverride = contract.key;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final store = AppStore.demo(clock: DateTime(2026, 7, 20, 9));
        addTearDown(store.dispose);

        late Map<String, dynamic> capturedBody;
        final gateway = HttpAssistantGateway(
          baseUri: Uri.parse('https://api.example.test'),
          client: MockClient((request) async {
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(jsonEncode(_validResponse()), 200);
          }),
          clientIdProvider: () async => 'install_test_client',
        );

        await gateway.replyTo('Question', store);

        final client = capturedBody['client'] as Map<String, dynamic>;
        expect(client['platform'], contract.value);
      },
    );
  }
}

Map<String, Object?> _validResponse() {
  return {
    'reply': {
      'title': 'General information',
      'message': 'Saved context received.',
      'level': 'general',
      'coverage': 'notChecked',
    },
    'meta': {
      'source': 'model',
      'model': 'gpt-5.6-terra',
      'requestId': 'req_active_ingredients',
      'degraded': false,
      'notice':
          'The model classified intent; wording came from a server-owned template.',
      'fallbackReason': null,
      'safetyGate': null,
    },
  };
}
