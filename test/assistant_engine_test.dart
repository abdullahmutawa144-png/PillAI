import 'package:flutter_test/flutter_test.dart';
import 'package:pill_ai/domain/app_models.dart';
import 'package:pill_ai/domain/app_store.dart';
import 'package:pill_ai/domain/assistant_engine.dart';
// ignore: depend_on_referenced_packages, test-only in-memory plugin backend
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages, test-only in-memory plugin backend
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late AppStore store;
  const DemoAssistantEngine engine = DemoAssistantEngine();

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDownAll(() {
    SharedPreferencesAsyncPlatform.instance = null;
  });

  setUp(() {
    store = AppStore.demo(clock: DateTime(2026, 7, 20, 9));
  });

  tearDown(() {
    store.dispose();
  });

  group('emergency routing', () {
    const emergencyPrompts = <String>[
      'I took an extra dose by mistake',
      'My tongue is swelling',
      'I cannot breathe after the medicine',
      'They passed out after taking pills',
      'I have chest pain after my dose',
      'There is a blistering rash',
      'My speech is slurred and my face is drooping',
      'I took the wrong medicine',
      'I want to hurt myself with these pills',
    ];

    for (final prompt in emergencyPrompts) {
      test('routes "$prompt" to immediate help', () {
        final reply = engine.replyTo(prompt, store);

        expect(reply.level, SafetyLevel.urgent);
        expect(reply.actionLabel, 'View emergency guidance');
        expect(reply.coverage, SafetyCoverage.generalGuidance);
        expect(reply.message, contains('do not wait for this app'));
        expect(reply.contextNote, contains('warning words'));
      });
    }

    test('emergency language takes priority over missed-dose routing', () {
      final reply = engine.replyTo(
        'I missed a dose and now I cannot breathe',
        store,
      );

      expect(reply.level, SafetyLevel.urgent);
      expect(reply.title, 'Get urgent help now');
    });

    const arabicEmergencyPrompts = <String>[
      'أخذت جرعة إضافية ولا أستطيع التنفس',
      'لدي تورم في اللسان',
      'أشعر بألم في الصدر',
      'أريد قتل نفسي',
    ];

    for (final prompt in arabicEmergencyPrompts) {
      test('routes Arabic warning phrase "$prompt" to immediate help', () {
        final reply = engine.replyTo(prompt, store);

        expect(reply.level, SafetyLevel.urgent);
        expect(reply.actionLabel, 'View emergency guidance');
      });
    }
  });

  group('higher-risk context', () {
    test('pregnancy route uses saved context without claiming safety', () {
      store.updateSafetyContext(
        store.safetyContext.copyWith(
          reproductiveStatus: ReproductiveStatus.pregnant,
        ),
      );

      final reply = engine.replyTo(
        'Can I use this medicine while pregnant?',
        store,
      );

      expect(reply.level, SafetyLevel.caution);
      expect(reply.coverage, SafetyCoverage.notChecked);
      expect(reply.message, contains('exact product'));
      expect(reply.message, contains('has not checked'));
      expect(reply.contextNote, contains('Pregnant'));
      expect(reply.contextNote, contains('no product-specific check'));
    });

    test('breastfeeding route discloses missing saved status', () {
      final reply = engine.replyTo('Is this okay while breastfeeding?', store);

      expect(reply.level, SafetyLevel.caution);
      expect(reply.coverage, SafetyCoverage.notChecked);
      expect(reply.contextNote, contains('has not been reviewed'));
    });

    test('kidney and liver route never calculates an adjustment', () {
      store.updateSafetyContext(
        store.safetyContext.copyWith(
          kidneyStatus: ProfileAnswer.yes,
          liverStatus: ProfileAnswer.unsure,
        ),
      );

      final reply = engine.replyTo(
        'I have kidney and liver disease. Should my dose change?',
        store,
      );

      expect(reply.level, SafetyLevel.caution);
      expect(reply.coverage, SafetyCoverage.notChecked);
      expect(
        reply.message,
        contains('does not calculate or verify dose changes'),
      );
      expect(reply.contextNote, contains('Kidney health'));
      expect(reply.contextNote, contains('Liver health'));
      expect(reply.contextNote, contains('no dose adjustment was checked'));
    });

    test('known allergy is surfaced as context but not cross-checked', () {
      store.updateProfile(
        store.profile.copyWith(allergies: const ['Penicillin']),
      );

      final reply = engine.replyTo(
        'Could this be an allergy to my medicine?',
        store,
      );

      expect(reply.level, SafetyLevel.caution);
      expect(reply.coverage, SafetyCoverage.notChecked);
      expect(reply.contextNote, contains('Penicillin'));
      expect(reply.contextNote, contains('not cross-checked'));
    });

    test('no recorded allergy is never treated as proof of safety', () {
      final reply = engine.replyTo('Am I allergic to this tablet?', store);

      expect(reply.coverage, SafetyCoverage.notChecked);
      expect(reply.contextNote, contains('not proof'));
    });

    test('other health conditions route to a condition-specific review', () {
      final reply = engine.replyTo(
        'I have diabetes and high blood pressure. Is this medicine okay?',
        store,
      );

      expect(reply.level, SafetyLevel.caution);
      expect(reply.coverage, SafetyCoverage.notChecked);
      expect(reply.title, contains('Health conditions'));
      expect(reply.message, contains('has not checked'));
      expect(reply.contextNote, contains('No medicine-condition rule'));
    });

    test('a seizure diagnosis is not mistaken for an active emergency', () {
      final reply = engine.replyTo(
        'I have a seizure disorder. Can I take this cold medicine?',
        store,
      );

      expect(reply.level, SafetyLevel.caution);
      expect(reply.title, contains('Health conditions'));
      expect(reply.level, isNot(SafetyLevel.urgent));
    });
  });

  group('interaction categories', () {
    const foodPrompts = <String>[
      'Can I drink tea with my antibiotic?',
      'Should I take it with milk?',
      'Does grapefruit interact with my medicine?',
      'Can I drink alcohol with these tablets?',
      'How should I take it while fasting?',
      'Does tube feeding affect this medicine?',
    ];

    for (final prompt in foodPrompts) {
      test('routes food or drink question: "$prompt"', () {
        final reply = engine.replyTo(prompt, store);

        expect(reply.level, SafetyLevel.caution);
        expect(reply.coverage, SafetyCoverage.notChecked);
        expect(reply.message, contains('medicine-specific'));
        expect(reply.message, contains('cannot verify a safe interval'));
        expect(reply.contextNote, contains('context only'));
      });
    }

    test('uses reviewed supplement status transparently', () {
      store.updateSafetyContext(
        store.safetyContext.copyWith(
          supplementsReviewed: true,
          supplementsAndOtc: const ['Iron', 'Cold or flu remedies'],
        ),
      );

      final reply = engine.replyTo(
        'Can I combine my iron supplement and an antacid?',
        store,
      );

      expect(reply.level, SafetyLevel.caution);
      expect(reply.coverage, SafetyCoverage.notChecked);
      expect(reply.contextNote, contains('Iron'));
      expect(reply.contextNote, contains('not cross-checked'));
      expect(reply.message, isNot(contains('safe to take together')));
    });

    test('warns that combination products may duplicate ingredients', () {
      final reply = engine.replyTo(
        'Do these cold products have duplicate active ingredients?',
        store,
      );

      expect(reply.level, SafetyLevel.caution);
      expect(reply.coverage, SafetyCoverage.notChecked);
      expect(reply.title, contains('active ingredient'));
      expect(reply.message, contains('cannot compare the labels'));
      expect(reply.message, contains('different brand names'));
    });

    test('legacy broad interaction request keeps its safety boundary', () {
      final reply = engine.replyTo(
        'Can I take iron, milk, and an antibiotic together?',
        store,
      );

      expect(reply.level, SafetyLevel.caution);
      expect(reply.coverage, SafetyCoverage.notChecked);
      expect(reply.message, contains('medicine-specific'));
      expect(reply.message, contains('cannot verify a safe interval'));
    });

    test('general pair question does not label a pair safe', () {
      final reply = engine.replyTo(
        'Can I take Vitamin D3 and Omega 3 together?',
        store,
      );

      expect(reply.coverage, SafetyCoverage.notChecked);
      expect(reply.message, contains('exact active ingredients'));
      expect(reply.message, contains('cannot verify'));
      expect(reply.message, isNot(contains('are safe together')));
    });
  });

  group('coverage and missing context', () {
    test('vague safety question requests exact product information', () {
      final reply = engine.replyTo('Is this medicine safe for me?', store);

      expect(reply.level, SafetyLevel.caution);
      expect(reply.coverage, SafetyCoverage.insufficientInformation);
      expect(reply.message, contains('active ingredients'));
      expect(reply.message, contains('strength'));
      expect(reply.contextNote, contains('missing'));
    });

    test('empty input is insufficient information', () {
      final reply = engine.replyTo('   ', store);

      expect(reply.coverage, SafetyCoverage.insufficientInformation);
      expect(reply.title, 'I need the exact product details');
    });

    test('coverage answer names capabilities and exclusions', () {
      final reply = engine.replyTo('What can you check?', store);

      expect(reply.level, SafetyLevel.general);
      expect(reply.coverage, SafetyCoverage.generalGuidance);
      expect(reply.message, contains('deterministic'));
      expect(reply.message, contains('does not yet have'));
      expect(
        reply.message,
        contains('verified ingredient interaction database'),
      );
      expect(reply.contextNote, contains('of 8 safety-profile areas'));
    });

    test('side-effect route asks for missing assessment details', () {
      final reply = engine.replyTo(
        'I feel dizzy and think it is a side effect',
        store,
      );

      expect(reply.level, SafetyLevel.caution);
      expect(reply.coverage, SafetyCoverage.insufficientInformation);
      expect(reply.message, contains('cannot determine'));
      expect(reply.suggestedPrompt, contains('which medicine'));
    });
  });

  group('dose workflow behavior', () {
    test('missed-dose route preserves no-double-dose boundary', () {
      final reply = engine.replyTo('I forgot my afternoon dose', store);

      expect(reply.level, SafetyLevel.caution);
      expect(reply.actionLabel, "Open today's doses");
      expect(reply.coverage, SafetyCoverage.notChecked);
      expect(reply.message, contains('Do not double'));
    });

    test('taken-dose route opens the dose record without claiming safety', () {
      final reply = engine.replyTo('Mark my dose taken', store);

      expect(reply.level, SafetyLevel.general);
      expect(reply.actionLabel, "Open today's doses");
      expect(reply.message, contains('does not confirm'));
      expect(reply.contextNote, contains('dose record only'));
    });

    test('schedule route reports saved counts and invents no interval', () {
      store.markTaken(store.nextDose!.id);

      final reply = engine.replyTo('Organize my schedule today', store);

      expect(reply.level, SafetyLevel.general);
      expect(reply.actionLabel, 'View schedule');
      expect(reply.message, contains('2 of 3 demo doses'));
      expect(reply.message, contains('will not change the prescribed dose'));
      expect(reply.message, contains('not'));
      expect(
        reply.message,
        isNot(matches(RegExp(r'\b\d+\s*(hour|minute)s?\b'))),
      );
    });
  });
}
