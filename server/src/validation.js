const REPRODUCTIVE_STATUSES = new Set([
  'notAnswered',
  'notApplicable',
  'pregnant',
  'breastfeeding',
  'tryingToConceive',
  'postpartum',
  'none',
  'preferNotToAnswer',
]);

const PROFILE_ANSWERS = new Set(['notAnswered', 'no', 'yes', 'unsure']);
const MEDICATION_FORMS = new Set([
  'tablet',
  'capsule',
  'liquid',
  'injection',
  'other',
]);
const DOSE_STATUSES = new Set([
  'scheduled',
  'due',
  'taken',
  'missed',
  'snoozed',
  'adjusted',
]);

export class ValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = 'ValidationError';
  }
}

function fail(path, message) {
  throw new ValidationError(`${path} ${message}`);
}

function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function object(value, path) {
  if (!isRecord(value)) fail(path, 'must be an object.');
  return value;
}

function allowedKeys(value, keys, path) {
  for (const key of Object.keys(value)) {
    if (!keys.has(key)) fail(`${path}.${key}`, 'is not supported.');
  }
}

function string(value, path, { min = 1, max = 200, optional = false } = {}) {
  if (value === undefined || value === null) {
    if (optional) return undefined;
    fail(path, 'is required.');
  }
  if (typeof value !== 'string') fail(path, 'must be a string.');
  const cleaned = value.trim();
  if (cleaned.length < min) fail(path, `must contain at least ${min} character(s).`);
  if (cleaned.length > max) fail(path, `must contain at most ${max} characters.`);
  return cleaned;
}

function boolean(value, path, { optional = false } = {}) {
  if (value === undefined || value === null) {
    if (optional) return undefined;
    fail(path, 'is required.');
  }
  if (typeof value !== 'boolean') fail(path, 'must be a boolean.');
  return value;
}

function integer(
  value,
  path,
  { min = Number.MIN_SAFE_INTEGER, max = Number.MAX_SAFE_INTEGER, optional = false } = {},
) {
  if (value === undefined || value === null) {
    if (optional) return undefined;
    fail(path, 'is required.');
  }
  if (!Number.isInteger(value) || value < min || value > max) {
    fail(path, `must be an integer from ${min} to ${max}.`);
  }
  return value;
}

function enumeration(value, values, path, { optional = false } = {}) {
  const cleaned = string(value, path, { optional, max: 64 });
  if (cleaned === undefined) return undefined;
  if (!values.has(cleaned)) fail(path, 'has an unsupported value.');
  return cleaned;
}

function dateTime(value, path, { optional = false } = {}) {
  const cleaned = string(value, path, { optional, max: 64 });
  if (cleaned === undefined) return undefined;
  if (
    !/^\d{4}-\d{2}-\d{2}T/.test(cleaned) ||
    Number.isNaN(Date.parse(cleaned))
  ) {
    fail(path, 'must be an ISO-8601 date-time.');
  }
  return cleaned;
}

function stringList(value, path, { maxItems = 20, maxLength = 100 } = {}) {
  if (value === undefined || value === null) return undefined;
  if (!Array.isArray(value)) fail(path, 'must be an array.');
  if (value.length > maxItems) fail(path, `must contain at most ${maxItems} items.`);
  const result = [];
  const seen = new Set();
  for (let index = 0; index < value.length; index += 1) {
    const item = string(value[index], `${path}[${index}]`, { max: maxLength });
    const key = item.toLocaleLowerCase('en-US');
    if (!seen.has(key)) {
      seen.add(key);
      result.push(item);
    }
  }
  return result;
}

function compact(value) {
  return Object.fromEntries(
    Object.entries(value).filter(([, entry]) => entry !== undefined),
  );
}

function validateProfile(value) {
  const profile = object(value, 'context.profile');
  allowedKeys(
    profile,
    new Set([
      'conditions',
      'allergies',
      'ageRange',
      'sexForMedicationSafety',
      'reproductiveStatus',
      'kidneyStatus',
      'liverStatus',
      'wakeTimeLabel',
      'sleepTimeLabel',
      'weightLabel',
      'preferredLanguage',
    ]),
    'context.profile',
  );
  return compact({
    ageRange: string(profile.ageRange, 'context.profile.ageRange', {
      optional: true,
      max: 40,
    }),
    sexForMedicationSafety: string(
      profile.sexForMedicationSafety,
      'context.profile.sexForMedicationSafety',
      { optional: true, max: 40 },
    ),
    reproductiveStatus: enumeration(
      profile.reproductiveStatus,
      REPRODUCTIVE_STATUSES,
      'context.profile.reproductiveStatus',
      { optional: true },
    ),
    kidneyStatus: enumeration(
      profile.kidneyStatus,
      PROFILE_ANSWERS,
      'context.profile.kidneyStatus',
      { optional: true },
    ),
    liverStatus: enumeration(
      profile.liverStatus,
      PROFILE_ANSWERS,
      'context.profile.liverStatus',
      { optional: true },
    ),
    conditions: stringList(profile.conditions, 'context.profile.conditions', {
      maxItems: 25,
      maxLength: 100,
    }),
    allergies: stringList(profile.allergies, 'context.profile.allergies', {
      maxItems: 25,
      maxLength: 100,
    }),
    wakeTimeLabel: string(profile.wakeTimeLabel, 'context.profile.wakeTimeLabel', {
      optional: true,
      max: 40,
    }),
    sleepTimeLabel: string(
      profile.sleepTimeLabel,
      'context.profile.sleepTimeLabel',
      { optional: true, max: 40 },
    ),
    weightLabel: string(profile.weightLabel, 'context.profile.weightLabel', {
      optional: true,
      max: 40,
    }),
    preferredLanguage: string(
      profile.preferredLanguage,
      'context.profile.preferredLanguage',
      { optional: true, max: 50 },
    ),
  });
}

function validateReviewGroup(value, path, listKey, maxItems = 20) {
  const group = object(value, path);
  allowedKeys(group, new Set(['reviewed', listKey]), path);
  return compact({
    reviewed: boolean(group.reviewed, `${path}.reviewed`, { optional: true }),
    [listKey]: stringList(group[listKey], `${path}.${listKey}`, { maxItems }),
  });
}

function validateSafetyContext(value) {
  const safety = object(value, 'context.safetyContext');
  allowedKeys(
    safety,
    new Set([
      'foodAndDrink',
      'supplementsAndOtc',
      'lifestyle',
    ]),
    'context.safetyContext',
  );
  return compact({
    foodAndDrink:
      safety.foodAndDrink === undefined
        ? undefined
        : validateReviewGroup(
            safety.foodAndDrink,
            'context.safetyContext.foodAndDrink',
            'factors',
          ),
    supplementsAndOtc:
      safety.supplementsAndOtc === undefined
        ? undefined
        : validateReviewGroup(
            safety.supplementsAndOtc,
            'context.safetyContext.supplementsAndOtc',
            'items',
          ),
    lifestyle:
      safety.lifestyle === undefined
        ? undefined
        : validateReviewGroup(
            safety.lifestyle,
            'context.safetyContext.lifestyle',
            'factors',
          ),
  });
}

function validateMedication(value, index) {
  const path = `context.medications[${index}]`;
  const medication = object(value, path);
  allowedKeys(
    medication,
    new Set([
      'id',
      'name',
      'activeIngredients',
      'strength',
      'form',
      'doseLabel',
      'instructions',
      'isPrescription',
    ]),
    path,
  );
  return compact({
    id: string(medication.id, `${path}.id`, { max: 64 }),
    name: string(medication.name, `${path}.name`, { max: 120 }),
    activeIngredients: stringList(
      medication.activeIngredients,
      `${path}.activeIngredients`,
      { maxItems: 12, maxLength: 120 },
    ),
    strength: string(medication.strength, `${path}.strength`, {
      optional: true,
      max: 80,
    }),
    form: enumeration(medication.form, MEDICATION_FORMS, `${path}.form`, {
      optional: true,
    }),
    doseLabel: string(medication.doseLabel, `${path}.doseLabel`, {
      optional: true,
      max: 80,
    }),
    instructions: string(medication.instructions, `${path}.instructions`, {
      optional: true,
      max: 500,
    }),
    isPrescription: boolean(
      medication.isPrescription,
      `${path}.isPrescription`,
      { optional: true },
    ),
  });
}

function validateDose(value, index) {
  const path = `context.todayDoses[${index}]`;
  const dose = object(value, path);
  allowedKeys(
    dose,
    new Set([
      'id',
      'medicationId',
      'medicationName',
      'scheduledAt',
      'status',
      'actualAt',
      'missedReason',
      'originalScheduledAt',
    ]),
    path,
  );
  return compact({
    id: string(dose.id, `${path}.id`, { max: 64 }),
    medicationId: string(dose.medicationId, `${path}.medicationId`, {
      max: 64,
    }),
    medicationName: string(dose.medicationName, `${path}.medicationName`, {
      optional: true,
      max: 120,
    }),
    scheduledAt: dateTime(dose.scheduledAt, `${path}.scheduledAt`),
    status: enumeration(dose.status, DOSE_STATUSES, `${path}.status`),
    actualAt: dateTime(dose.actualAt, `${path}.actualAt`, { optional: true }),
    missedReason: string(dose.missedReason, `${path}.missedReason`, {
      optional: true,
      max: 240,
    }),
    originalScheduledAt: dateTime(
      dose.originalScheduledAt,
      `${path}.originalScheduledAt`,
      { optional: true },
    ),
  });
}

function validateMemoryFact(value, index) {
  const path = `context.memoryFacts[${index}]`;
  const fact = object(value, path);
  allowedKeys(
    fact,
    new Set(['id', 'kind', 'value', 'status', 'occurredAt', 'medicationIds']),
    path,
  );
  return compact({
    id: string(fact.id, `${path}.id`, { max: 96 }),
    kind: enumeration(
      fact.kind,
      new Set(MEMORY_KINDS),
      `${path}.kind`,
    ),
    value: string(fact.value, `${path}.value`, { max: 300 }),
    status: enumeration(
      fact.status,
      new Set(['reported', 'confirmed', 'uncertain']),
      `${path}.status`,
    ),
    occurredAt: dateTime(fact.occurredAt, `${path}.occurredAt`, {
      optional: true,
    }),
    medicationIds: stringList(
      fact.medicationIds,
      `${path}.medicationIds`,
      { maxItems: 8, maxLength: 64 },
    ),
  });
}

function validateHistoryMessage(value, index) {
  const path = `history[${index}]`;
  const message = object(value, path);
  allowedKeys(message, new Set(['role', 'content']), path);
  return {
    role: enumeration(message.role, new Set(['user', 'assistant']), `${path}.role`),
    content: string(message.content, `${path}.content`, { max: 1_200 }),
  };
}

function validateClient(value) {
  const client = object(value, 'client');
  allowedKeys(
    client,
    new Set([
      'app',
      'version',
      'platform',
      'displayMode',
      'locale',
      'timezoneOffsetMinutes',
    ]),
    'client',
  );
  return compact({
    app: string(client.app, 'client.app', { optional: true, max: 40 }),
    version: string(client.version, 'client.version', {
      optional: true,
      max: 40,
    }),
    platform: enumeration(
      client.platform,
      new Set(['web', 'android', 'ios', 'macos', 'windows', 'linux', 'fuchsia']),
      'client.platform',
      { optional: true },
    ),
    displayMode: enumeration(
      client.displayMode,
      new Set(['standard', 'simple']),
      'client.displayMode',
      { optional: true },
    ),
    locale: string(client.locale, 'client.locale', {
      optional: true,
      max: 50,
    }),
    timezoneOffsetMinutes: integer(
      client.timezoneOffsetMinutes,
      'client.timezoneOffsetMinutes',
      { optional: true, min: -840, max: 840 },
    ),
  });
}

function arrayOf(value, path, maxItems, validator) {
  if (value === undefined || value === null) return undefined;
  if (!Array.isArray(value)) fail(path, 'must be an array.');
  if (value.length > maxItems) fail(path, `must contain at most ${maxItems} items.`);
  return value.map(validator);
}

function validateContext(value) {
  const context = object(value, 'context');
  allowedKeys(
    context,
    new Set([
      'locale',
      'timeZone',
      'now',
      'profile',
      'safetyContext',
      'medications',
      'todayDoses',
      'memoryFacts',
    ]),
    'context',
  );
  return compact({
    locale: string(context.locale, 'context.locale', {
      optional: true,
      max: 35,
    }),
    timeZone: string(context.timeZone, 'context.timeZone', {
      optional: true,
      max: 64,
    }),
    now: dateTime(context.now, 'context.now', { optional: true }),
    profile:
      context.profile === undefined ? undefined : validateProfile(context.profile),
    safetyContext:
      context.safetyContext === undefined
        ? undefined
        : validateSafetyContext(context.safetyContext),
    medications: arrayOf(
      context.medications,
      'context.medications',
      40,
      validateMedication,
    ),
    todayDoses: arrayOf(
      context.todayDoses,
      'context.todayDoses',
      80,
      validateDose,
    ),
    memoryFacts: arrayOf(
      context.memoryFacts,
      'context.memoryFacts',
      120,
      validateMemoryFact,
    ),
  });
}

export function validateAssistantRequest(value) {
  const request = object(value, 'body');
  allowedKeys(
    request,
    new Set(['clientId', 'message', 'context', 'history', 'client']),
    'body',
  );

  const clientId = string(request.clientId, 'clientId', { min: 8, max: 128 });
  if (!/^[A-Za-z0-9._:-]+$/.test(clientId)) {
    fail(
      'clientId',
      'must be an opaque installation ID, not a name or email address.',
    );
  }

  return {
    clientId,
    message: string(request.message, 'message', { max: 2_000 }),
    context:
      request.context === undefined ? {} : validateContext(request.context),
    // The client already sends only a bounded tail; validate again at the trust
    // boundary before including it in Responses input.
    history:
      request.history === undefined
        ? []
        : arrayOf(request.history, 'history', 8, validateHistoryMessage),
    client:
      request.client === undefined ? {} : validateClient(request.client),
  };
}
import { MEMORY_KINDS } from './contract.js';
