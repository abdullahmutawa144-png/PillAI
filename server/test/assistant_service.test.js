import assert from 'node:assert/strict';
import test from 'node:test';

import { createAssistantService } from '../src/assistant_service.js';
import { validateAssistantPlan } from '../src/assistant_plan.js';
import { createSafetyIdentifier } from '../src/openai_client.js';
import { validateAssistantRequest } from '../src/validation.js';

const TEST_SECRET = 'test-safety-secret-value-at-least-32-characters';

const baseRequest = {
  clientId: 'install_12345678',
  message: 'Can these medicines be taken together?',
  context: {
    locale: 'en-SA',
    timeZone: 'Asia/Riyadh',
    now: '2026-07-20T09:41:00+03:00',
    profile: {
      ageRange: '25-34',
      sexForMedicationSafety: 'Female',
      reproductiveStatus: 'pregnant',
      kidneyStatus: 'no',
      liverStatus: 'unsure',
      conditions: ['Colitis'],
      allergies: ['Penicillin'],
      wakeTimeLabel: '7:00 AM',
      sleepTimeLabel: '11:00 PM',
      weightLabel: 'Prefer not to share',
      preferredLanguage: 'English',
    },
    safetyContext: {
      foodAndDrink: {
        reviewed: true,
        factors: ['Tea', 'Milk'],
      },
      supplementsAndOtc: { reviewed: true, items: ['Iron'] },
      lifestyle: { reviewed: true, factors: ['Shift work'] },
    },
    medications: [
      {
        id: 'medicine-1',
        name: 'Example medicine',
        activeIngredients: ['Example ingredient'],
        strength: '100 mg',
        form: 'tablet',
        doseLabel: '1 tablet',
        instructions: 'Use exactly as prescribed',
        isPrescription: true,
      },
    ],
    todayDoses: [
      {
        id: 'dose-1',
        medicationId: 'medicine-1',
        medicationName: 'Example medicine',
        scheduledAt: '2026-07-20T10:00:00+03:00',
        status: 'scheduled',
      },
    ],
  },
  history: [
    { role: 'user', content: 'I usually drink tea at breakfast.' },
    { role: 'assistant', content: 'Which exact products are involved?' },
  ],
  client: {
    app: 'PillAI',
    version: '1.0.0',
    platform: 'android',
    displayMode: 'simple',
    locale: 'English',
    timezoneOffsetMinutes: 180,
  },
};

const safeModelPlan = {
  reply: {
    title: 'I need the exact product details',
    message:
      'I can compare the saved medicines after you confirm every active ingredient and strength.',
    level: 'caution',
    actionLabel: 'Review medication list',
    suggestedPrompt: 'What is printed under active ingredients?',
    coverage: 'insufficientInformation',
    contextNote: 'I used the saved medication list and safety profile.',
  },
  emergency: false,
  memoryUpdates: [],
  doseEvent: {
    action: 'none',
    doseId: null,
    occurredAt: null,
    note: null,
    confidence: 'low',
  },
  scheduleProposal: { summary: null, changes: [] },
  sources: [],
};

function openAIResponse(
  plan,
  {
    status = 200,
    requestId = 'req_upstream',
    model = 'gpt-5.6-terra-actual',
    sources = [],
  } = {},
) {
  const output = {
    model,
    output: [
      ...(sources.length > 0
        ? [{ type: 'web_search_call', action: { sources } }]
        : []),
      {
        type: 'message',
        content: [{ type: 'output_text', text: JSON.stringify(plan) }],
      },
    ],
  };
  return new Response(JSON.stringify(output), {
    status,
    headers: {
      'content-type': 'application/json',
      'x-request-id': requestId,
    },
  });
}

test('validates and preserves all clinically relevant structured context', () => {
  const result = validateAssistantRequest(baseRequest);
  assert.equal(result.context.profile.reproductiveStatus, 'pregnant');
  assert.deepEqual(result.context.safetyContext.foodAndDrink.factors, [
    'Tea',
    'Milk',
  ]);
  assert.equal(result.context.medications[0].activeIngredients[0], 'Example ingredient');
  assert.equal(result.context.todayDoses[0].status, 'scheduled');
  assert.equal(result.history.length, 2);
  assert.equal(result.client.displayMode, 'simple');
});

test('rejects names or emails as client identifiers and unknown profile fields', () => {
  assert.throws(
    () => validateAssistantRequest({ ...baseRequest, clientId: 'person@example.com' }),
    /opaque installation ID/,
  );
  assert.throws(
    () =>
      validateAssistantRequest({
        ...baseRequest,
        context: {
          ...baseRequest.context,
          profile: { ...baseRequest.context.profile, name: 'Private Name' },
        },
      }),
    /context\.profile\.name is not supported/,
  );
});

test('uses a stable privacy-preserving safety identifier', () => {
  const first = createSafetyIdentifier('install_12345678', TEST_SECRET);
  const second = createSafetyIdentifier('install_12345678', TEST_SECRET);
  const other = createSafetyIdentifier('install_87654321', TEST_SECRET);
  assert.equal(first, second);
  assert.notEqual(first, other);
  assert.match(first, /^pillai_[a-f0-9]{48}$/);
  assert.ok(!first.includes('install_12345678'));
});

test('validates a closed structured assistant turn and rejects additions', () => {
  assert.deepEqual(validateAssistantPlan(safeModelPlan), safeModelPlan);
  assert.throws(
    () =>
      validateAssistantPlan({
        ...safeModelPlan,
        unexpected: 'Hold the next dose.',
      }),
    /closed contract/,
  );
  assert.throws(
    () =>
      validateAssistantPlan({
        ...safeModelPlan,
        doseEvent: { ...safeModelPlan.doseEvent, action: 'delay' },
      }),
    /doseEvent\.action/,
  );
});

test('fails fast when a live API key lacks a strong safety-ID secret', () => {
  assert.throws(
    () => createAssistantService({ env: { OPENAI_API_KEY: 'test-key' } }),
    /PILLAI_SAFETY_ID_SECRET must contain at least 32 characters/,
  );
});

test('returns a clearly labeled deterministic demo when there is no API key', async () => {
  const service = createAssistantService({ env: {} });
  const result = await service.replyTo(baseRequest, 'request-demo');
  assert.equal(result.meta.source, 'demo');
  assert.equal(result.meta.requestId, 'request-demo');
  assert.equal(result.meta.fallbackReason, 'no_key');
  assert.equal(result.meta.safetyGate, null);
  assert.match(result.reply.title, /^Demo mode:/);
  assert.match(result.reply.contextNote, /^Demo mode:/);
  assert.equal(result.reply.coverage, 'notChecked');
});

test('emergency pre-check runs first and cannot be de-escalated by the model', async () => {
  let calls = 0;
  const service = createAssistantService({
    env: {
      OPENAI_API_KEY: 'server-only-test-key',
      PILLAI_SAFETY_ID_SECRET: TEST_SECRET,
    },
    fetchImpl: async () => {
      calls += 1;
      throw new Error('must not be called');
    },
  });
  const result = await service.replyTo(
    { ...baseRequest, message: 'I took an extra dose and cannot breathe' },
    'request-emergency',
  );
  assert.equal(calls, 0);
  assert.equal(result.meta.source, 'safety_gate');
  assert.equal(result.meta.safetyGate, 'emergency_phrase');
  assert.equal(result.meta.fallbackReason, null);
  assert.equal(result.reply.level, 'urgent');
  assert.match(result.reply.message, /emergency service or poison center/i);

  const wholeBottle = await service.replyTo(
    { ...baseRequest, message: 'I took the entire bottle' },
    'request-whole-bottle-emergency',
  );
  assert.equal(calls, 0);
  assert.equal(wholeBottle.meta.source, 'safety_gate');
  assert.equal(wholeBottle.meta.safetyGate, 'emergency_phrase');
});

test('a model emergency flag can only escalate to fixed urgent guidance', async () => {
  let calls = 0;
  const possibleEmergencyPlan = {
    ...safeModelPlan,
    emergency: true,
    reply: { ...safeModelPlan.reply, level: 'urgent' },
  };
  const service = createAssistantService({
    env: {
      OPENAI_API_KEY: 'server-only-test-key',
      PILLAI_SAFETY_ID_SECRET: TEST_SECRET,
    },
    fetchImpl: async () => {
      calls += 1;
      return openAIResponse(possibleEmergencyPlan);
    },
  });
  const result = await service.replyTo(
    { ...baseRequest, message: 'I swallowed the whole bottle' },
    'request-model-emergency',
  );
  assert.equal(calls, 1);
  assert.equal(result.meta.source, 'safety_gate');
  assert.equal(result.meta.safetyGate, 'model_possible_emergency');
  assert.equal(result.meta.fallbackReason, null);
  assert.equal(result.meta.model, 'gpt-5.6-terra-actual');
  assert.equal(result.reply.level, 'urgent');
  assert.match(result.reply.message, /emergency service or poison center/i);
  assert.match(result.reply.contextNote, /AI flagged/i);
  assert.ok(!JSON.stringify(result.reply).includes('swallowed the whole bottle'));
});

test('finite high-signal Arabic emergency phrases bypass the model', async () => {
  let calls = 0;
  const service = createAssistantService({
    env: {
      OPENAI_API_KEY: 'server-only-test-key',
      PILLAI_SAFETY_ID_SECRET: TEST_SECRET,
    },
    fetchImpl: async () => {
      calls += 1;
      throw new Error('must not be called');
    },
  });
  const phrases = [
    'تناولت جرعة زائدة',
    'أخذت جرعة إضافية',
    'لا أستطيع التنفس',
    'تورم الوجه',
    'تورم اللسان',
    'تورم الحلق',
    'أنا فاقد الوعي',
    'لديه نوبة صرع',
    'أشعر بألم في الصدر',
    'هناك نزيف شديد',
    'أريد إيذاء نفسي',
  ];
  for (const [index, message] of phrases.entries()) {
    const result = await service.replyTo(
      { ...baseRequest, message },
      `request-arabic-emergency-${index}`,
    );
    assert.equal(result.meta.source, 'safety_gate', message);
    assert.equal(result.meta.safetyGate, 'emergency_phrase', message);
    assert.equal(result.reply.level, 'urgent', message);
    // Arabic messages get Arabic guidance with the Saudi numbers.
    assert.match(result.reply.message, /997/);
    assert.match(result.reply.title, /اطلب المساعدة/);
    assert.match(result.reply.contextNote, /قائمة محدودة/);
  }
  assert.equal(calls, 0);
});

test('Saudi dialect emergency wording with Arabic prefixes bypasses the model', async () => {
  let calls = 0;
  const service = createAssistantService({
    env: {
      OPENAI_API_KEY: 'server-only-test-key',
      PILLAI_SAFETY_ID_SECRET: TEST_SECRET,
    },
    fetchImpl: async () => {
      calls += 1;
      throw new Error('must not be called');
    },
  });
  for (const [index, message] of [
    'ولدي بلع حبوب كثيرة',
    'أبوي ما يستجيب بعد الدواء',
    'ما أقدر أتنفس من بعد الحبة',
  ].entries()) {
    const result = await service.replyTo(
      { ...baseRequest, message },
      `request-saudi-emergency-${index}`,
    );
    assert.equal(result.meta.safetyGate, 'emergency_phrase', message);
    assert.match(result.reply.message, /997/, message);
  }
  assert.equal(calls, 0);
});

test('English emergency guidance names the Saudi numbers first', async () => {
  const service = createAssistantService({ env: {} });
  const result = await service.replyTo(
    { ...baseRequest, message: 'My child swallowed my pills' },
    'request-english-emergency',
  );
  assert.equal(result.meta.safetyGate, 'emergency_phrase');
  assert.match(result.reply.message, /997 \(ambulance\) or 911/);
});

test('organizer mode tells the model not to move reminders and drops any proposal', async () => {
  const sourceUrl =
    'https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=example';
  const turn = {
    ...safeModelPlan,
    scheduleProposal: {
      summary: 'Move the reminder.',
      changes: [
        {
          doseId: 'dose-1',
          from: '2026-07-20T10:00:00+03:00',
          to: '2026-07-20T12:00:00+03:00',
          reason: 'The retrieved product label supports this timing constraint.',
          sourceUrl,
        },
      ],
    },
    sources: [
      {
        title: 'Official product label',
        url: sourceUrl,
        support: 'The label contains the product-specific timing instruction.',
      },
    ],
  };
  const bodies = [];
  const service = createAssistantService({
    env: {
      OPENAI_API_KEY: 'server-only-test-key',
      PILLAI_SAFETY_ID_SECRET: TEST_SECRET,
      PILLAI_SCHEDULE_PROPOSALS: 'false',
    },
    fetchImpl: async (url, options) => {
      bodies.push(JSON.parse(options.body));
      return openAIResponse(turn, {
        sources: [{ title: 'Official product label', url: sourceUrl }],
      });
    },
  });

  assert.equal(service.scheduleProposalsEnabled, false);
  const result = await service.replyTo(baseRequest, 'request-organizer');

  assert.match(bodies[0].instructions, /Organizer mode/);
  assert.equal(result.meta.source, 'model');
  assert.deepEqual(result.scheduleProposal, { summary: null, changes: [] });
  assert.equal(result.sources.length, 1);
});

test('instructions ask for short replies in the user language with Saudi context', async () => {
  const bodies = [];
  const service = createAssistantService({
    env: {
      OPENAI_API_KEY: 'server-only-test-key',
      PILLAI_SAFETY_ID_SECRET: TEST_SECRET,
    },
    fetchImpl: async (url, options) => {
      bodies.push(JSON.parse(options.body));
      return openAIResponse(safeModelPlan);
    },
  });
  assert.equal(service.scheduleProposalsEnabled, true);
  await service.replyTo(baseRequest, 'request-language');
  assert.match(bodies[0].instructions, /language of the user's latest message/);
  assert.match(bodies[0].instructions, /at most three short sentences/);
  assert.match(bodies[0].instructions, /997/);
  assert.doesNotMatch(bodies[0].instructions, /Organizer mode/);
});

test('calls Responses API with required privacy and structured-output controls', async () => {
  const calls = [];
  const service = createAssistantService({
    env: {
      OPENAI_API_KEY: 'server-only-test-key',
      PILLAI_OPENAI_MODEL: 'gpt-5.6-terra',
      PILLAI_SAFETY_ID_SECRET: TEST_SECRET,
    },
    fetchImpl: async (url, options) => {
      calls.push({ url, options, body: JSON.parse(options.body) });
      return openAIResponse(safeModelPlan);
    },
  });

  const first = await service.replyTo(baseRequest, 'request-model-1');
  const second = await service.replyTo(baseRequest, 'request-model-2');

  assert.equal(first.meta.source, 'model');
  assert.equal(first.meta.model, 'gpt-5.6-terra-actual');
  assert.equal(first.meta.fallbackReason, null);
  assert.equal(first.meta.safetyGate, null);
  assert.equal(first.reply.title, 'I need the exact product details');
  assert.equal(first.reply.actionLabel, 'Review medication list');
  assert.equal(calls.length, 2);
  assert.equal(calls[0].url, 'https://api.openai.com/v1/responses');
  assert.equal(calls[0].body.model, 'gpt-5.6-terra');
  assert.deepEqual(calls[0].body.reasoning, { effort: 'low' });
  assert.equal(calls[0].body.text.verbosity, 'low');
  assert.equal(calls[0].body.text.format.type, 'json_schema');
  assert.equal(calls[0].body.text.format.strict, true);
  assert.deepEqual(calls[0].body.text.format.schema.required, [
    'reply',
    'emergency',
    'memoryUpdates',
    'doseEvent',
    'scheduleProposal',
    'sources',
  ]);
  assert.equal(calls[0].body.text.format.name, 'pillai_assistant_turn');
  assert.equal(calls[0].body.text.format.schema.additionalProperties, false);
  assert.equal(calls[0].body.tools[0].type, 'web_search');
  assert.ok(
    calls[0].body.tools[0].filters.allowed_domains.includes(
      'dailymed.nlm.nih.gov',
    ),
  );
  assert.deepEqual(calls[0].body.include, [
    'web_search_call.action.sources',
  ]);
  assert.equal(calls[0].body.store, false);
  assert.equal(calls[0].body.safety_identifier, calls[1].body.safety_identifier);
  assert.equal(calls[0].options.headers.authorization, 'Bearer server-only-test-key');
  assert.equal(
    calls[0].options.headers['x-client-request-id'],
    'request-model-1',
  );
  assert.ok(!calls[0].options.body.includes('install_12345678'));
  assert.ok(!calls[0].options.body.includes('server-only-test-key'));
  assert.equal(calls[0].body.input[0].role, 'user');
  assert.equal(
    calls[0].body.input[0].content,
    'I usually drink tea at breakfast.',
  );
  assert.equal(calls[0].body.input[1].role, 'assistant');
  const currentInput = calls[0].body.input.at(-1);
  const modelInput = JSON.parse(currentInput.content[0].text);
  assert.equal(modelInput.context.profile.reproductiveStatus, 'pregnant');
  assert.deepEqual(modelInput.regionalContext, {
    locale: 'English',
    timezoneOffsetMinutes: 180,
  });
  assert.ok(!currentInput.content[0].text.includes('displayMode'));
  assert.ok(!currentInput.content[0].text.includes('platform'));
  assert.equal(second.meta.requestId, 'request-model-2');
});

test('model answer still reports model source while unrelated unsafe user text cannot enter the reply', async () => {
  const service = createAssistantService({
    env: {
      OPENAI_API_KEY: 'server-only-test-key',
      PILLAI_SAFETY_ID_SECRET: TEST_SECRET,
    },
    fetchImpl: async () => openAIResponse(safeModelPlan),
  });
  const unsafePhrases = [
    'hold the next dose',
    "avoid tonight's tablet",
    'delay by six hours',
    'اوقف الجرعة القادمة',
  ];
  const result = await service.replyTo(
    { ...baseRequest, message: unsafePhrases.join(' / ') },
    'request-structural-guard',
  );
  const serializedReply = JSON.stringify(result.reply).toLocaleLowerCase('en-US');
  assert.equal(result.meta.source, 'model');
  assert.equal(result.meta.model, 'gpt-5.6-terra-actual');
  for (const phrase of unsafePhrases) {
    assert.ok(!serializedReply.includes(phrase.toLocaleLowerCase('en-US')));
  }
  assert.match(result.meta.notice, /saved record/i);
});

test('accepts general memory and source-backed schedule effects without scenario rules', async () => {
  const sourceUrl =
    'https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=example';
  const turn = {
    ...safeModelPlan,
    reply: {
      ...safeModelPlan.reply,
      title: 'I prepared a reminder update',
      coverage: 'verifiedIssue',
    },
    memoryUpdates: [
      {
        kind: 'routine',
        value: 'Usually drinks a hot beverage at 9:30 AM',
        status: 'reported',
        occurredAt: '2026-07-20T09:30:00+03:00',
        medicationIds: ['medicine-1'],
      },
    ],
    scheduleProposal: {
      summary: 'Move the reminder while preserving the prescribed dose.',
      changes: [
        {
          doseId: 'dose-1',
          from: '2026-07-20T10:00:00+03:00',
          to: '2026-07-20T12:00:00+03:00',
          reason: 'The retrieved product label supports this timing constraint.',
          sourceUrl,
        },
      ],
    },
    sources: [
      {
        title: 'Official product label',
        url: sourceUrl,
        support: 'The label contains the product-specific timing instruction.',
      },
    ],
  };
  const service = createAssistantService({
    env: {
      OPENAI_API_KEY: 'server-only-test-key',
      PILLAI_SAFETY_ID_SECRET: TEST_SECRET,
    },
    fetchImpl: async () =>
      openAIResponse(turn, {
        sources: [{ title: 'Official product label', url: sourceUrl }],
      }),
  });

  const result = await service.replyTo(baseRequest, 'request-effects');

  assert.equal(result.meta.source, 'model');
  assert.equal(result.memoryUpdates[0].kind, 'routine');
  assert.equal(result.scheduleProposal.changes.length, 1);
  assert.equal(result.scheduleProposal.changes[0].doseId, 'dose-1');
  assert.equal(result.sources[0].url, sourceUrl);
  assert.equal(result.reply.coverage, 'verifiedIssue');
});

test('drops invented or unapproved source links and their schedule changes', async () => {
  const turn = {
    ...safeModelPlan,
    reply: { ...safeModelPlan.reply, coverage: 'verifiedIssue' },
    scheduleProposal: {
      summary: 'Unsafe proposed change',
      changes: [
        {
          doseId: 'dose-1',
          from: '2026-07-20T10:00:00+03:00',
          to: '2026-07-20T12:00:00+03:00',
          reason: 'Unsupported',
          sourceUrl: 'https://untrusted.example/claim',
        },
      ],
    },
    sources: [
      {
        title: 'Invented source',
        url: 'https://untrusted.example/claim',
        support: 'Unsupported',
      },
    ],
  };
  const service = createAssistantService({
    env: {
      OPENAI_API_KEY: 'server-only-test-key',
      PILLAI_SAFETY_ID_SECRET: TEST_SECRET,
    },
    fetchImpl: async () => openAIResponse(turn),
  });

  const result = await service.replyTo(baseRequest, 'request-invented-source');

  assert.equal(result.sources.length, 0);
  assert.equal(result.scheduleProposal.changes.length, 0);
  assert.equal(result.reply.coverage, 'notChecked');
});

test('rejects model output containing any free-form clinical field', async () => {
  const invalidPlan = {
    ...safeModelPlan,
    unexpected: 'Hold the next dose and delay it by six hours.',
  };
  const service = createAssistantService({
    env: {
      OPENAI_API_KEY: 'server-only-test-key',
      PILLAI_SAFETY_ID_SECRET: TEST_SECRET,
    },
    fetchImpl: async () => openAIResponse(invalidPlan),
  });
  const result = await service.replyTo(baseRequest, 'request-invalid-plan');
  assert.equal(result.meta.source, 'demo');
  assert.equal(result.meta.degraded, true);
  assert.equal(result.meta.fallbackReason, 'invalid_output');
  assert.ok(!JSON.stringify(result.reply).includes('Hold the next dose'));
});

test('uses a safe degraded demo without leaking upstream errors', async () => {
  const service = createAssistantService({
    env: {
      OPENAI_API_KEY: 'server-only-test-key',
      PILLAI_SAFETY_ID_SECRET: TEST_SECRET,
    },
    fetchImpl: async () =>
      new Response(
        JSON.stringify({
          error: { message: 'secret upstream detail server-only-test-key' },
        }),
        { status: 429, headers: { 'x-request-id': 'req_rate_limited' } },
      ),
  });
  const result = await service.replyTo(baseRequest, 'request-degraded');
  const serialized = JSON.stringify(result);
  assert.equal(result.meta.source, 'demo');
  assert.equal(result.meta.degraded, true);
  assert.equal(result.meta.fallbackReason, 'upstream_unavailable');
  assert.equal(result.meta.safetyGate, null);
  assert.match(result.reply.message, /temporarily unavailable/i);
  assert.ok(!serialized.includes('server-only-test-key'));
  assert.ok(!serialized.includes('secret upstream detail'));
});
