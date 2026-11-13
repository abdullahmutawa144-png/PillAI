import {
  DOSE_EVENT_ACTIONS,
  MEMORY_KINDS,
  VERIFIED_SOURCE_DOMAINS,
  completeReply,
} from './contract.js';
import { validateAssistantReply } from './safety.js';

function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function exactKeys(value, expected, field) {
  if (!isRecord(value)) throw new Error(`${field} must be an object.`);
  const keys = Object.keys(value);
  if (keys.length !== expected.length || expected.some((key) => !keys.includes(key))) {
    throw new Error(`${field} does not match the closed contract.`);
  }
}

function requiredString(value, field, max) {
  if (typeof value !== 'string' || !value.trim() || value.length > max) {
    throw new Error(`${field} must be a non-empty string of at most ${max} characters.`);
  }
  return value.trim();
}

function nullableString(value, field, max) {
  if (value === null) return null;
  return requiredString(value, field, max);
}

function enumValue(value, values, field) {
  if (typeof value !== 'string' || !values.includes(value)) {
    throw new Error(`${field} has an unsupported value.`);
  }
  return value;
}

function isoDate(value, field, { nullable = false } = {}) {
  if (nullable && value === null) return null;
  const text = requiredString(value, field, 64);
  if (!/^\d{4}-\d{2}-\d{2}T/.test(text) || Number.isNaN(Date.parse(text))) {
    throw new Error(`${field} must be an ISO-8601 date-time.`);
  }
  return text;
}

function array(value, field, max) {
  if (!Array.isArray(value) || value.length > max) {
    throw new Error(`${field} must be an array with at most ${max} items.`);
  }
  return value;
}

function validateMemoryUpdate(value, index) {
  const field = `memoryUpdates[${index}]`;
  exactKeys(value, ['kind', 'value', 'status', 'occurredAt', 'medicationIds'], field);
  return {
    kind: enumValue(value.kind, MEMORY_KINDS, `${field}.kind`),
    value: requiredString(value.value, `${field}.value`, 300),
    status: enumValue(
      value.status,
      ['reported', 'confirmed', 'uncertain'],
      `${field}.status`,
    ),
    occurredAt: isoDate(value.occurredAt, `${field}.occurredAt`, {
      nullable: true,
    }),
    medicationIds: array(value.medicationIds, `${field}.medicationIds`, 8).map(
      (id) => requiredString(id, `${field}.medicationIds`, 64),
    ),
  };
}

function validateDoseEvent(value) {
  exactKeys(value, ['action', 'doseId', 'occurredAt', 'note', 'confidence'], 'doseEvent');
  const action = enumValue(value.action, DOSE_EVENT_ACTIONS, 'doseEvent.action');
  const doseId = nullableString(value.doseId, 'doseEvent.doseId', 64);
  const occurredAt = isoDate(value.occurredAt, 'doseEvent.occurredAt', {
    nullable: true,
  });
  const note = nullableString(value.note, 'doseEvent.note', 300);
  const confidence = enumValue(
    value.confidence,
    ['high', 'medium', 'low'],
    'doseEvent.confidence',
  );
  if (action === 'none' && (doseId !== null || occurredAt !== null)) {
    throw new Error('doseEvent none cannot target a dose or time.');
  }
  if (action !== 'none' && doseId === null) {
    throw new Error('doseEvent action requires an existing doseId.');
  }
  return { action, doseId, occurredAt, note, confidence };
}

function validateScheduleProposal(value) {
  exactKeys(value, ['summary', 'changes'], 'scheduleProposal');
  return {
    summary: nullableString(value.summary, 'scheduleProposal.summary', 500),
    changes: array(value.changes, 'scheduleProposal.changes', 12).map(
      (change, index) => {
        const field = `scheduleProposal.changes[${index}]`;
        exactKeys(change, ['doseId', 'from', 'to', 'reason', 'sourceUrl'], field);
        return {
          doseId: requiredString(change.doseId, `${field}.doseId`, 64),
          from: isoDate(change.from, `${field}.from`),
          to: isoDate(change.to, `${field}.to`),
          reason: requiredString(change.reason, `${field}.reason`, 500),
          sourceUrl: requiredString(change.sourceUrl, `${field}.sourceUrl`, 500),
        };
      },
    ),
  };
}

function validateSource(value, index) {
  const field = `sources[${index}]`;
  exactKeys(value, ['title', 'url', 'support'], field);
  return {
    title: requiredString(value.title, `${field}.title`, 200),
    url: requiredString(value.url, `${field}.url`, 500),
    support: requiredString(value.support, `${field}.support`, 500),
  };
}

export function validateAssistantTurn(value) {
  exactKeys(
    value,
    ['reply', 'emergency', 'memoryUpdates', 'doseEvent', 'scheduleProposal', 'sources'],
    'assistantTurn',
  );
  if (typeof value.emergency !== 'boolean') {
    throw new Error('assistantTurn.emergency must be a boolean.');
  }
  return {
    reply: validateAssistantReply(value.reply),
    emergency: value.emergency,
    memoryUpdates: array(value.memoryUpdates, 'memoryUpdates', 8).map(
      validateMemoryUpdate,
    ),
    doseEvent: validateDoseEvent(value.doseEvent),
    scheduleProposal: validateScheduleProposal(value.scheduleProposal),
    sources: array(value.sources, 'sources', 8).map(validateSource),
  };
}

function canonicalUrl(value) {
  try {
    const url = new URL(value);
    if (url.protocol !== 'https:') return null;
    url.hash = '';
    return url.toString();
  } catch {
    return null;
  }
}

function allowedSource(value) {
  const url = canonicalUrl(value);
  if (!url) return false;
  const host = new URL(url).hostname.toLocaleLowerCase('en-US');
  return VERIFIED_SOURCE_DOMAINS.some(
    (domain) => host === domain || host.endsWith(`.${domain}`),
  );
}

function sameInstant(a, b) {
  return Date.parse(a) === Date.parse(b);
}

function sourceWasRetrieved(url, retrievedUrls) {
  const canonical = canonicalUrl(url);
  return canonical !== null && retrievedUrls.has(canonical);
}

function sanitizeMemory(updates, request) {
  const medicationIds = new Set(
    (request.context?.medications ?? []).map((medication) => medication.id),
  );
  const seen = new Set();
  return updates
    .map((update) => ({
      ...update,
      medicationIds: update.medicationIds.filter((id) => medicationIds.has(id)),
    }))
    .filter((update) => {
      const key = `${update.kind}:${update.value.toLocaleLowerCase('en-US')}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
}

function sanitizeDoseEvent(event, request) {
  if (event.action === 'none' || event.confidence !== 'high') {
    return { action: 'none', doseId: null, occurredAt: null, note: null, confidence: event.confidence };
  }
  const dose = (request.context?.todayDoses ?? []).find(
    (candidate) => candidate.id === event.doseId,
  );
  if (!dose || !['scheduled', 'due', 'snoozed', 'adjusted'].includes(dose.status)) {
    return { action: 'none', doseId: null, occurredAt: null, note: null, confidence: 'low' };
  }
  return event;
}

function sanitizeSchedule(proposal, request, sourceUrls) {
  const now = Date.parse(request.context?.now ?? new Date().toISOString());
  const doses = new Map(
    (request.context?.todayDoses ?? []).map((dose) => [dose.id, dose]),
  );
  const changes = proposal.changes.filter((change) => {
    const dose = doses.get(change.doseId);
    if (!dose || !['scheduled', 'due', 'snoozed', 'adjusted'].includes(dose.status)) {
      return false;
    }
    if (!sameInstant(change.from, dose.scheduledAt)) return false;
    if (!allowedSource(change.sourceUrl) || !sourceWasRetrieved(change.sourceUrl, sourceUrls)) {
      return false;
    }
    const target = Date.parse(change.to);
    if (!Number.isFinite(target) || target < now - 5 * 60 * 1000) return false;
    // A chat turn may reorganize reminders, but never silently create a new
    // treatment day or alter the prescription course.
    if (Math.abs(target - Date.parse(change.from)) > 24 * 60 * 60 * 1000) return false;
    return true;
  });
  return {
    summary: changes.length > 0 ? proposal.summary : null,
    changes,
  };
}

export function sanitizeAssistantTurn(turn, request, retrievedUrls = new Set()) {
  const canonicalRetrieved = new Set(
    [...retrievedUrls].map(canonicalUrl).filter(Boolean),
  );
  const sources = turn.sources.filter(
    (source) => allowedSource(source.url) && sourceWasRetrieved(source.url, canonicalRetrieved),
  );
  const acceptedSourceUrls = new Set(sources.map((source) => canonicalUrl(source.url)));
  const scheduleProposal = sanitizeSchedule(
    turn.scheduleProposal,
    request,
    acceptedSourceUrls,
  );
  const sourceBacked = sources.length > 0;
  const reply = completeReply({
    ...turn.reply,
    coverage:
      turn.reply.coverage === 'verifiedIssue' && !sourceBacked
        ? 'notChecked'
        : turn.reply.coverage,
    contextNote:
      scheduleProposal.changes.length < turn.scheduleProposal.changes.length
        ? 'Some proposed reminder changes were removed because their dose, time, or retrieved source could not be verified. No dose amount, frequency, or treatment course was changed.'
        : turn.reply.contextNote,
  });
  return {
    reply,
    emergency: turn.emergency,
    memoryUpdates: sanitizeMemory(turn.memoryUpdates, request),
    doseEvent: sanitizeDoseEvent(turn.doseEvent, request),
    scheduleProposal,
    sources,
  };
}

// Kept as a named export for older imports/tests while the app moves from the
// previous enum classifier to a full structured assistant turn.
export const validateAssistantPlan = validateAssistantTurn;

export function emptyAssistantEffects() {
  return {
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
}
