import { createHmac } from 'node:crypto';

import {
  ASSISTANT_TURN_SCHEMA,
  DEFAULT_MODEL,
  OPENAI_RESPONSES_URL,
  ORGANIZER_MODE_INSTRUCTIONS,
  SYSTEM_INSTRUCTIONS,
  VERIFIED_SOURCE_DOMAINS,
} from './contract.js';
import { validateAssistantTurn } from './assistant_plan.js';

export class OpenAIServiceError extends Error {
  constructor(kind, { status, upstreamRequestId, cause } = {}) {
    super(`OpenAI request failed: ${kind}`, { cause });
    this.name = 'OpenAIServiceError';
    this.kind = kind;
    this.status = status;
    this.upstreamRequestId = upstreamRequestId;
  }
}

export function resolveModel(value) {
  if (typeof value !== 'string' || !value.trim()) return DEFAULT_MODEL;
  const model = value.trim();
  return /^[A-Za-z0-9._:-]{1,100}$/.test(model) ? model : DEFAULT_MODEL;
}

export function createSafetyIdentifier(clientId, secret) {
  if (!hasStrongSafetySecret(secret)) {
    throw new Error('PILLAI_SAFETY_ID_SECRET must contain at least 32 characters.');
  }
  const digest = createHmac('sha256', secret).update(clientId).digest('hex');
  return `pillai_${digest.slice(0, 48)}`;
}

export function hasStrongSafetySecret(value) {
  return typeof value === 'string' && value.length >= 32;
}

function timeoutMs(value) {
  const parsed = Number.parseInt(value ?? '', 10);
  if (!Number.isFinite(parsed)) return 35_000;
  return Math.min(90_000, Math.max(3_000, parsed));
}

function extractOutputText(response) {
  if (typeof response?.output_text === 'string' && response.output_text.trim()) {
    return response.output_text;
  }
  if (!Array.isArray(response?.output)) return null;
  for (const item of response.output) {
    if (!Array.isArray(item?.content)) continue;
    for (const content of item.content) {
      if (content?.type === 'output_text' && typeof content.text === 'string') {
        return content.text;
      }
      if (content?.type === 'refusal') {
        throw new OpenAIServiceError('refused');
      }
    }
  }
  return null;
}

function collectSourceUrls(value, urls = new Set()) {
  if (Array.isArray(value)) {
    for (const item of value) collectSourceUrls(item, urls);
    return urls;
  }
  if (value === null || typeof value !== 'object') return urls;
  if (typeof value.url === 'string') {
    try {
      const url = new URL(value.url);
      if (url.protocol === 'https:') {
        url.hash = '';
        urls.add(url.toString());
      }
    } catch {
      // Ignore malformed URLs in upstream metadata.
    }
  }
  for (const entry of Object.values(value)) collectSourceUrls(entry, urls);
  return urls;
}

export function createOpenAIRequest({
  request,
  requestId,
  model,
  safetyIdentifier,
  webSearchEnabled = true,
  scheduleProposalsEnabled = true,
}) {
  // clientId is intentionally omitted. OpenAI receives only its HMAC plus the
  // clinically relevant, already-bounded context.
  const regionalContext = {
    ...(request.client.locale ? { locale: request.client.locale } : {}),
    ...(request.client.timezoneOffsetMinutes !== undefined
      ? { timezoneOffsetMinutes: request.client.timezoneOffsetMinutes }
      : {}),
  };
  const userInput = JSON.stringify({
    userMessage: request.message,
    context: request.context,
    ...(Object.keys(regionalContext).length > 0 ? { regionalContext } : {}),
  });

  const payload = {
    model,
    instructions: scheduleProposalsEnabled
      ? SYSTEM_INSTRUCTIONS
      : [SYSTEM_INSTRUCTIONS, ORGANIZER_MODE_INSTRUCTIONS].join('\n\n'),
    input: [
      ...request.history.map((message) => ({
        role: message.role,
        content: message.content,
      })),
      {
        role: 'user',
        content: [{ type: 'input_text', text: userInput }],
      },
    ],
    reasoning: { effort: 'low' },
    text: {
      verbosity: 'low',
      format: {
        type: 'json_schema',
        name: 'pillai_assistant_turn',
        schema: ASSISTANT_TURN_SCHEMA,
        strict: true,
      },
    },
    max_output_tokens: 2400,
    safety_identifier: safetyIdentifier,
    store: false,
    metadata: {
      app: 'pillai',
      request_id: requestId,
    },
  };
  if (webSearchEnabled) {
    payload.tools = [
      {
        type: 'web_search',
        filters: { allowed_domains: VERIFIED_SOURCE_DOMAINS },
      },
    ];
    payload.tool_choice = 'auto';
    payload.include = ['web_search_call.action.sources'];
  }
  return payload;
}

export async function requestOpenAIPlan({
  request,
  requestId,
  apiKey,
  model = DEFAULT_MODEL,
  safetySecret,
  webSearchEnabled = true,
  scheduleProposalsEnabled = true,
  requestTimeoutMs,
  fetchImpl = globalThis.fetch,
  endpoint = OPENAI_RESPONSES_URL,
}) {
  if (typeof fetchImpl !== 'function') {
    throw new OpenAIServiceError('fetch_unavailable');
  }

  const controller = new AbortController();
  const timer = setTimeout(
    () => controller.abort(new Error('OpenAI request timed out.')),
    timeoutMs(requestTimeoutMs),
  );
  const safetyIdentifier = createSafetyIdentifier(
    request.clientId,
    safetySecret,
  );
  const payload = createOpenAIRequest({
    request,
    requestId,
    model,
    safetyIdentifier,
    webSearchEnabled,
    scheduleProposalsEnabled,
  });

  let response;
  try {
    response = await fetchImpl(endpoint, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${apiKey}`,
        'content-type': 'application/json',
        'x-client-request-id': requestId,
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
  } catch (error) {
    const kind = controller.signal.aborted ? 'timeout' : 'network';
    throw new OpenAIServiceError(kind, { cause: error });
  } finally {
    clearTimeout(timer);
  }

  const upstreamRequestId = response.headers?.get?.('x-request-id') ?? undefined;
  if (!response.ok) {
    // Do not parse or forward the upstream body; it may contain sensitive
    // request details. The caller returns a safe deterministic fallback.
    try {
      await response.body?.cancel?.();
    } catch {
      // A failed cleanup is non-fatal and is intentionally not surfaced.
    }
    throw new OpenAIServiceError('http', {
      status: response.status,
      upstreamRequestId,
    });
  }

  let json;
  try {
    json = await response.json();
  } catch (error) {
    throw new OpenAIServiceError('invalid_json', {
      upstreamRequestId,
      cause: error,
    });
  }

  let outputText;
  try {
    outputText = extractOutputText(json);
  } catch (error) {
    if (error instanceof OpenAIServiceError) throw error;
    throw new OpenAIServiceError('invalid_output', {
      upstreamRequestId,
      cause: error,
    });
  }
  if (!outputText) {
    throw new OpenAIServiceError('empty_output', { upstreamRequestId });
  }

  try {
    const actualModel =
      typeof json.model === 'string' &&
      /^[A-Za-z0-9._:-]{1,100}$/.test(json.model.trim())
        ? json.model.trim()
        : model;
    return {
      turn: validateAssistantTurn(JSON.parse(outputText)),
      model: actualModel,
      upstreamRequestId,
      retrievedUrls: collectSourceUrls(json),
    };
  } catch (error) {
    throw new OpenAIServiceError('invalid_output', {
      upstreamRequestId,
      cause: error,
    });
  }
}
