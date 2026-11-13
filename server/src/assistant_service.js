import { DEFAULT_MODEL } from './contract.js';
import {
  emptyAssistantEffects,
  sanitizeAssistantTurn,
} from './assistant_plan.js';
import {
  hasStrongSafetySecret,
  OpenAIServiceError,
  requestOpenAIPlan,
  resolveModel,
} from './openai_client.js';
import {
  containsDoseChangingAdvice,
  demoReplyFor,
  emergencyReplyFor,
  guardedModelReply,
  modelPossibleEmergencyReply,
} from './safety.js';

function envelope({
  reply,
  source,
  requestId,
  model,
  degraded,
  notice,
  fallbackReason = null,
  safetyGate = null,
  effects = emptyAssistantEffects(),
}) {
  return {
    reply,
    ...effects,
    meta: {
      source,
      requestId,
      model,
      degraded,
      notice,
      fallbackReason,
      safetyGate,
    },
  };
}

export function createAssistantService({
  env = process.env,
  fetchImpl = globalThis.fetch,
  endpoint,
} = {}) {
  const model = resolveModel(env.PILLAI_OPENAI_MODEL ?? DEFAULT_MODEL);
  // Off for an organizer-only launch: the model is told not to propose
  // reminder moves and any proposal that still arrives is dropped here.
  const scheduleProposalsEnabled = env.PILLAI_SCHEDULE_PROPOSALS !== 'false';
  const apiKey =
    typeof env.OPENAI_API_KEY === 'string' ? env.OPENAI_API_KEY.trim() : '';
  if (apiKey && !hasStrongSafetySecret(env.PILLAI_SAFETY_ID_SECRET)) {
    throw new Error(
      'PILLAI_SAFETY_ID_SECRET must contain at least 32 characters when OPENAI_API_KEY is configured.',
    );
  }

  return {
    mode: apiKey ? 'model' : 'demo',
    model,
    scheduleProposalsEnabled,

    async replyTo(request, requestId) {
      // This check is intentionally first and cannot be bypassed by the model,
      // an unavailable API, or a missing API key.
      const emergencyReply = emergencyReplyFor(request.message);
      if (emergencyReply) {
        return envelope({
          reply: emergencyReply,
          source: 'safety_gate',
          requestId,
          model,
          degraded: false,
          safetyGate: 'emergency_phrase',
          notice:
            'Deterministic emergency wording was detected before any model call.',
        });
      }

      if (!apiKey) {
        return envelope({
          reply: demoReplyFor(request.message, request.context),
          source: 'demo',
          requestId,
          model,
          degraded: false,
          fallbackReason: 'no_key',
          notice:
            'Demo mode is active because OPENAI_API_KEY is not configured.',
        });
      }

      try {
        const result = await requestOpenAIPlan({
          request,
          requestId,
          apiKey,
          model,
          safetySecret: env.PILLAI_SAFETY_ID_SECRET,
          requestTimeoutMs: env.PILLAI_OPENAI_TIMEOUT_MS,
          webSearchEnabled: env.PILLAI_WEB_SEARCH_ENABLED !== 'false',
          scheduleProposalsEnabled,
          fetchImpl,
          endpoint,
        });
        if (result.turn.emergency || result.turn.reply.level === 'urgent') {
          return envelope({
            reply: modelPossibleEmergencyReply(request.message),
            source: 'safety_gate',
            requestId,
            model: result.model,
            degraded: false,
            safetyGate: 'model_possible_emergency',
            notice:
              'The model escalated a possible emergency to deterministic server guidance.',
          });
        }
        const turn = sanitizeAssistantTurn(
          result.turn,
          request,
          result.retrievedUrls,
        );
        const reply = turn.reply;

        // Structured effects are validated separately below. Retain the text
        // guard as defense in depth against direct dose/prescription changes.
        if (containsDoseChangingAdvice(reply)) {
          return envelope({
            reply: guardedModelReply('unsafe_output'),
            source: 'safety_gate',
            requestId,
            model: result.model,
            degraded: false,
            safetyGate: 'composed_output_guard',
            notice:
              'A deterministic defense-in-depth guard replaced generated medication guidance.',
          });
        }

        return envelope({
          reply,
          source: 'model',
          requestId,
          model: result.model,
          degraded: false,
          effects: {
            memoryUpdates: turn.memoryUpdates,
            doseEvent: turn.doseEvent,
            scheduleProposal: scheduleProposalsEnabled
              ? turn.scheduleProposal
              : emptyAssistantEffects().scheduleProposal,
            sources: turn.sources,
          },
          notice:
            turn.sources.length > 0
              ? 'The answer used retrieved authoritative sources; state changes were server-validated and still require in-app confirmation where applicable.'
              : 'The answer used the saved record. No product-specific source was verified for this turn.',
        });
      } catch (error) {
        // Do not leak upstream error bodies, credentials, internal stack traces,
        // or patient context. The deterministic fallback keeps the demo usable.
        const invalidOutputKinds = new Set([
          'invalid_json',
          'invalid_output',
          'empty_output',
          'refused',
        ]);
        const fallbackReason =
          error instanceof OpenAIServiceError && invalidOutputKinds.has(error.kind)
            ? 'invalid_output'
            : 'upstream_unavailable';
        return envelope({
          reply: demoReplyFor(request.message, request.context, {
            degraded: true,
          }),
          source: 'demo',
          requestId,
          model,
          degraded: true,
          fallbackReason,
          notice:
            fallbackReason === 'invalid_output'
              ? 'The assistant output was invalid; deterministic demo guidance is shown.'
              : 'The AI service is temporarily unavailable; deterministic demo guidance is shown.',
        });
      }
    },
  };
}
