import {
  ACTION_LABELS,
  SAFETY_COVERAGE,
  SAFETY_LEVELS,
  completeReply,
} from './contract.js';

const EMERGENCY_PHRASES = [
  'overdose',
  'overdosed',
  'too many pills',
  'too much medicine',
  'took the whole bottle',
  'took the entire bottle',
  'drank the entire bottle',
  'double dose',
  'extra dose',
  'took extra',
  'wrong medicine',
  'wrong medication',
  'child swallowed',
  'child took medicine',
  'cannot breathe',
  "can't breathe",
  'cant breathe',
  'difficulty breathing',
  'trouble breathing',
  'shortness of breath',
  'face swelling',
  'facial swelling',
  'tongue swelling',
  'swollen tongue',
  'throat swelling',
  'swollen throat',
  'lip swelling',
  'lips swelling',
  'lips are swelling',
  'anaphylaxis',
  'severe allergic reaction',
  'having a seizure',
  'seizing',
  'unconscious',
  'unresponsive',
  'passed out',
  'collapsed',
  'not waking',
  'chest pain',
  'stroke symptoms',
  'face drooping',
  'slurred speech',
  'one sided weakness',
  'vomiting blood',
  'coughing blood',
  'black stool',
  'severe bleeding',
  'bleeding will not stop',
  'blistering rash',
  'peeling skin',
  'intentional overdose',
  'hurt myself',
  'kill myself',
  'end my life',
  'suicidal',
  "don't want to live",
  'do not want to live',
  // Finite high-signal Arabic coverage. This is deliberately not presented as
  // comprehensive Arabic triage.
  'جرعة زائدة',
  'أخذت جرعة إضافية',
  'تناولت جرعة إضافية',
  'لا أستطيع التنفس',
  'لا أقدر أتنفس',
  'تورم الوجه',
  'وجهي متورم',
  'تورم اللسان',
  'لساني متورم',
  'تورم الحلق',
  'حلقي متورم',
  'فاقد الوعي',
  'فقد الوعي',
  'لا يستجيب',
  'نوبة صرع',
  'تشنجات',
  'ألم في الصدر',
  'بألم في الصدر',
  'أشعر بألم في الصدر',
  'نزيف شديد',
  'النزيف لا يتوقف',
  'أريد إيذاء نفسي',
  'أريد قتل نفسي',
  'أريد الانتحار',
  // Common Saudi wording.
  'ما أقدر أتنفس',
  'جرعة كبيرة',
  'بلع حبوب',
  'بلع الدواء',
  'طفل بلع',
  'اختناق',
  'أغمي عليه',
  'مغمى عليه',
  'ما يستجيب',
  'تشنج',
  'استفرغ دم',
  'أبي أموت',
  'أبغى أموت',
  'أنهي حياتي',
  'انتحار',
];

const ARABIC_LETTER = /[\u0600-\u06FF]/u;

function isArabic(value) {
  return typeof value === 'string' && ARABIC_LETTER.test(value);
}

const MISSED_DOSE_PHRASES = [
  'missed',
  'forgot',
  'slept through',
  'late dose',
  'dose is late',
];

const FOOD_PHRASES = [
  'food',
  'meal',
  'empty stomach',
  'milk',
  'dairy',
  'tea',
  'coffee',
  'caffeine',
  'grapefruit',
  'alcohol',
  'calcium',
  'iron',
];

const INTERACTION_PHRASES = [
  'interaction',
  'interact',
  'together',
  'same time',
  'combine',
  'mix medicines',
  'mix medications',
  'take both',
  'supplement',
  'over the counter',
  'otc',
];

const HEALTH_CONTEXT_PHRASES = [
  'pregnant',
  'pregnancy',
  'breastfeeding',
  'trying to conceive',
  'kidney',
  'renal',
  'liver',
  'allergy',
  'allergic',
  'condition',
];

const SCHEDULE_PHRASES = [
  'schedule',
  'organize',
  'organise',
  'plan today',
  'next dose',
  'what is due',
  'reminder',
];

function normalize(value) {
  return value
    .toLocaleLowerCase('en-US')
    .replaceAll('\u2019', "'")
    .normalize('NFKD')
    .replace(/\p{M}+/gu, '')
    .replace(/[^\p{L}\p{N}']+/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function containsPhrase(text, phrase) {
  // Arabic attaches prefixes such as و and ب to words, so Arabic phrases
  // match anywhere; Latin phrases still need whole-word boundaries.
  if (isArabic(phrase)) return text.includes(phrase);
  return (
    text === phrase ||
    text.startsWith(`${phrase} `) ||
    text.endsWith(` ${phrase}`) ||
    text.includes(` ${phrase} `)
  );
}

function containsAny(text, phrases) {
  return phrases.some((phrase) => containsPhrase(text, normalize(phrase)));
}

export function emergencyReplyFor(message) {
  const text = normalize(message);
  if (!containsAny(text, EMERGENCY_PHRASES)) return null;

  if (isArabic(message)) {
    return completeReply({
      title: 'اطلب المساعدة الآن',
      message:
        'الجرعة الزائدة أو التحسس الشديد أو أعراض الطوارئ قد تحتاج تدخلاً فورياً. اتصل الآن على 997 (الإسعاف) أو 911 ولا تنتظر التطبيق. إن أمكن، احتفظ بعلب الأدوية وأوقات الجرعات.',
      level: 'urgent',
      actionLabel: 'View emergency guidance',
      coverage: 'generalGuidance',
      contextNote:
        'طابق PillAI قائمة محدودة من عبارات الطوارئ الواضحة؛ هذا ليس فرزاً طبياً شاملاً، ولم يشخّص الحالة أو يتحقق مما حدث.',
    });
  }

  return completeReply({
    title: 'Get urgent help now',
    message:
      'An overdose, extra dose, severe reaction, or emergency symptom may need immediate help. In Saudi Arabia call 997 (ambulance) or 911; elsewhere call your local emergency service or poison center now and do not wait for this app. If it is safe, bring the medicine packages and the times each dose was taken.',
    level: 'urgent',
    actionLabel: 'View emergency guidance',
    coverage: 'generalGuidance',
    contextNote:
      'PillAI matched a finite set of high-signal English or Arabic emergency phrases; this is not comprehensive triage and it did not diagnose or verify what happened.',
  });
}

export function modelPossibleEmergencyReply(message) {
  if (isArabic(message)) {
    return completeReply({
      title: 'اطلب المساعدة الآن',
      message:
        'قد تكون هذه حالة طارئة متعلقة بالدواء. اتصل الآن على 997 (الإسعاف) أو 911 ولا تنتظر التطبيق. إن أمكن، احتفظ بعلب الأدوية وأوقات الجرعات.',
      level: 'urgent',
      actionLabel: 'View emergency guidance',
      coverage: 'generalGuidance',
      contextNote:
        'نبّه الذكاء الاصطناعي إلى حالة طارئة محتملة فاستبدل الخادم إجابته بإرشاد ثابت. لم يتم تشخيص الحالة أو التحقق مما حدث.',
    });
  }
  return completeReply({
    title: 'Get urgent help now',
    message:
      'This may be a medication emergency. In Saudi Arabia call 997 (ambulance) or 911; elsewhere call your local emergency service or poison center now and do not wait for this app. If it is safe, bring the medicine packages and any available dose or timing information.',
    level: 'urgent',
    actionLabel: 'View emergency guidance',
    coverage: 'generalGuidance',
    contextNote:
      'The AI flagged a possible emergency and the server replaced its answer with fixed urgent guidance. It did not diagnose or verify what happened.',
  });
}

function demoNote(extra) {
  return `Demo mode: no OpenAI API key is configured, so this is deterministic general guidance only. ${extra}`;
}

export function demoReplyFor(message, context = {}, { degraded = false } = {}) {
  const text = normalize(message);
  const degradedPrefix = degraded ? 'The AI service is temporarily unavailable. ' : '';

  if (containsAny(text, MISSED_DOSE_PHRASES)) {
    return completeReply({
      title: 'Demo mode: handle a missed dose carefully',
      message: `${degradedPrefix}Record which dose was missed and how late it is. Do not make up for it by changing the next dose; medicine-specific missed-dose directions need the package label, pharmacist, or prescriber.`,
      level: 'caution',
      actionLabel: "Open today's doses",
      suggestedPrompt: 'Which medicine was missed, and when was it due?',
      coverage: 'notChecked',
      contextNote: demoNote(
        'No medicine-specific missed-dose instruction was checked.',
      ),
    });
  }

  if (containsAny(text, FOOD_PHRASES) || containsAny(text, INTERACTION_PHRASES)) {
    return completeReply({
      title: 'Demo mode: exact ingredients matter',
      message: `${degradedPrefix}Foods, drinks, supplements, non-prescription products, and other medicines can matter, but the effect is product-specific. Check the exact active ingredients, strengths, and label directions with a pharmacist before changing your plan.`,
      level: 'caution',
      actionLabel: 'Review medication list',
      suggestedPrompt:
        'What exact names, active ingredients, strengths, and label directions are involved?',
      coverage: 'notChecked',
      contextNote: demoNote(
        'The supplied records were not cross-checked against a verified clinical database.',
      ),
    });
  }

  if (containsAny(text, HEALTH_CONTEXT_PHRASES)) {
    return completeReply({
      title: 'Demo mode: this health context needs a specific check',
      message: `${degradedPrefix}Pregnancy or breastfeeding, allergies, kidney or liver health, and other conditions can change medication decisions. A pharmacist or prescriber needs the exact product, active ingredients, strength, directions, and relevant health details.`,
      level: 'caution',
      actionLabel: 'Review safety profile',
      suggestedPrompt: 'What exact product and health factor are you asking about?',
      coverage: 'notChecked',
      contextNote: demoNote(
        'Saved profile answers provide context but are not a product-specific safety check.',
      ),
    });
  }

  if (containsAny(text, SCHEDULE_PHRASES)) {
    const doses = Array.isArray(context.todayDoses) ? context.todayDoses : [];
    const open = doses.filter((dose) => dose.status !== 'taken').length;
    const countText = doses.length
      ? `The saved plan has ${open} of ${doses.length} doses still open today. `
      : '';
    return completeReply({
      title: 'Demo mode: your saved plan at a glance',
      message: `${degradedPrefix}${countText}PillAI can organize reminders around an existing prescribed plan, but medicine-specific timing and spacing must be verified before the plan is changed.`,
      level: 'general',
      actionLabel: 'View schedule',
      suggestedPrompt: 'Which saved routine should the reminders fit around?',
      coverage: 'generalGuidance',
      contextNote: demoNote(
        'Dose counts come from the supplied schedule; no clinical timing rule was checked.',
      ),
    });
  }

  return completeReply({
    title: 'Demo mode: I can organize the next question',
    message: `${degradedPrefix}Ask about a missed dose, possible interaction, food or drink timing, a supplement, health condition, allergy, side effect, or your saved schedule. Product-specific safety decisions still need a verified source and a pharmacist or prescriber.`,
    level: 'general',
    suggestedPrompt: 'Can these exact medicines be taken together?',
    coverage: 'generalGuidance',
    contextNote: demoNote(
      'Add an API key for model-generated guidance; clinical verification is a separate required layer.',
    ),
  });
}

function requiredString(value, key, maxLength) {
  if (typeof value !== 'string' || !value.trim() || value.length > maxLength) {
    throw new Error(`Invalid model reply field: ${key}`);
  }
  return value.trim();
}

function nullableString(value, key, maxLength) {
  if (value === null) return null;
  if (typeof value !== 'string' || !value.trim() || value.length > maxLength) {
    throw new Error(`Invalid model reply field: ${key}`);
  }
  return value.trim();
}

export function validateAssistantReply(value) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('Model reply is not an object.');
  }
  const expected = [
    'title',
    'message',
    'level',
    'actionLabel',
    'suggestedPrompt',
    'coverage',
    'contextNote',
  ];
  const keys = Object.keys(value);
  if (keys.length !== expected.length || expected.some((key) => !keys.includes(key))) {
    throw new Error('Model reply does not match the AssistantReply contract.');
  }

  const reply = {
    title: requiredString(value.title, 'title', 120),
    message: requiredString(value.message, 'message', 2_000),
    level: value.level,
    actionLabel: nullableString(value.actionLabel, 'actionLabel', 80),
    suggestedPrompt: nullableString(
      value.suggestedPrompt,
      'suggestedPrompt',
      300,
    ),
    coverage: value.coverage,
    contextNote: nullableString(value.contextNote, 'contextNote', 800),
  };

  if (!SAFETY_LEVELS.includes(reply.level)) {
    throw new Error('Model reply has an invalid safety level.');
  }
  if (!SAFETY_COVERAGE.includes(reply.coverage)) {
    throw new Error('Model reply has invalid safety coverage.');
  }
  if (reply.actionLabel !== null && !ACTION_LABELS.includes(reply.actionLabel)) {
    throw new Error('Model reply has an unsupported action.');
  }
  return reply;
}

export function containsDoseChangingAdvice(reply) {
  const combined = normalize(
    [
      reply.title,
      reply.message,
      reply.actionLabel,
      reply.suggestedPrompt,
      reply.contextNote,
    ]
      .filter(Boolean)
      .join(' '),
  );

  const patterns = [
    /\b(?:you should|you can|you may|i recommend|i advise|please|go ahead and|consider)\s+(?:now\s+)?(?:take|use|inject|swallow|start|stop|skip|switch|increase|decrease|double|halve|split|change|adjust)\b/,
    /\b(?:it is|it's)\s+safe\s+to\s+(?:take|use|start|stop|skip|switch|increase|decrease|double|halve|split|change|adjust)\b/,
    /\b(?:take|use|inject|swallow)\s+(?:another|an|a|one|two|three|your|the|this|\d+)\s+(?:dose|doses|pill|pills|tablet|tablets|capsule|capsules|medicine|medication)\b/,
    /\b(?:start|stop|skip|double|halve|split|continue)\s+(?:taking|using|with|it|them|the|your)\b/,
    /\b(?:increase|decrease|reduce|raise|lower|adjust|change)\s+(?:it|them)\b/,
    /\b(?:increase|decrease|reduce|raise|lower|double|halve|split|skip|stop|start|switch|replace|change|adjust)\s+(?:(?:your|the|this)\s+)?(?:dose|dosage|frequency|medicine|medication|tablet|capsule|pill)\b/,
    /\b(?:take|use|inject|swallow)\b.{0,50}\b\d+(?:\.\d+)?\s*(?:mg|mcg|g|ml|tablet|tablets|capsule|capsules|pill|pills|dose|doses)\b/,
    /\b(?:correct|recommended|appropriate|usual|safe)\s+(?:dose|dosage|frequency)\b.{0,40}\b\d/,
    /\b(?:every|wait|space|separate)\s+\d+(?:\.\d+)?\s*(?:minute|minutes|hour|hours|day|days)\b/,
    /\b(?:once|twice|three times|four times)\s+(?:a|per)\s+day\b/,
  ];
  return patterns.some((pattern) => pattern.test(combined));
}

export function guardedModelReply(reason = 'unsafe_output') {
  const explanation =
    reason === 'unverified_claim'
      ? 'The generated answer claimed a verification that this service cannot perform.'
      : 'The generated answer could have changed a dose, frequency, or medicine plan.';
  return completeReply({
    title: 'A clinician should confirm this medication decision',
    message:
      'I cannot recommend a dose, frequency, or medication change. Keep the prescribed directions unchanged and confirm the exact medicine, active ingredient, strength, label directions, and timing with a pharmacist or prescriber.',
    level: 'caution',
    actionLabel: 'Review medication list',
    suggestedPrompt:
      'What exact product details should I gather for the pharmacist?',
    coverage: 'notChecked',
    contextNote: `Safety gate: ${explanation}`,
  });
}
