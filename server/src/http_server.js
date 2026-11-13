import { randomUUID } from 'node:crypto';
import { createServer } from 'node:http';

import { createAssistantService } from './assistant_service.js';
import { MAX_REQUEST_BYTES } from './contract.js';
import { validateAssistantRequest, ValidationError } from './validation.js';

class HttpError extends Error {
  constructor(status, code, message) {
    super(message);
    this.name = 'HttpError';
    this.status = status;
    this.code = code;
  }
}

function localOrigin(origin) {
  try {
    const parsed = new URL(origin);
    return (
      (parsed.protocol === 'http:' || parsed.protocol === 'https:') &&
      ['localhost', '127.0.0.1', '[::1]'].includes(parsed.hostname)
    );
  } catch {
    return false;
  }
}

function configuredOrigins(value) {
  if (typeof value !== 'string') return new Set();
  return new Set(
    value
      .split(',')
      .map((entry) => entry.trim())
      .filter(Boolean),
  );
}

function correlationRequestId(request) {
  const occurrences = [];
  for (let index = 0; index < request.rawHeaders.length; index += 2) {
    if (request.rawHeaders[index].toLowerCase() === 'x-request-id') {
      occurrences.push(request.rawHeaders[index + 1]);
    }
  }
  if (occurrences.length === 1) {
    const candidate = occurrences[0].trim();
    if (
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
        candidate,
      )
    ) {
      return candidate;
    }
  }
  return randomUUID();
}

function corsHeaders(origin, allowedOrigins) {
  if (!origin || (!localOrigin(origin) && !allowedOrigins.has(origin))) return {};
  return {
    'access-control-allow-origin': origin,
    'access-control-allow-methods': 'GET, POST, OPTIONS',
    'access-control-allow-headers': 'Content-Type, X-Request-ID',
    'access-control-expose-headers': 'X-Request-ID',
    'access-control-max-age': '600',
    vary: 'Origin',
  };
}

function sendJson(response, status, body, requestId, headers = {}) {
  const payload = JSON.stringify(body);
  response.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(payload),
    'cache-control': 'no-store',
    'x-content-type-options': 'nosniff',
    'x-request-id': requestId,
    ...headers,
  });
  response.end(payload);
}

function readJson(request) {
  const contentType = request.headers['content-type'] ?? '';
  if (!/^application\/json(?:\s*;|$)/i.test(contentType)) {
    request.resume();
    throw new HttpError(
      415,
      'unsupported_media_type',
      'Content-Type must be application/json.',
    );
  }
  const contentEncoding = request.headers['content-encoding'];
  if (contentEncoding && contentEncoding.toLowerCase() !== 'identity') {
    request.resume();
    throw new HttpError(
      415,
      'unsupported_content_encoding',
      'Compressed request bodies are not supported.',
    );
  }

  const declaredLength = Number.parseInt(request.headers['content-length'] ?? '', 10);
  if (Number.isFinite(declaredLength) && declaredLength > MAX_REQUEST_BYTES) {
    request.resume();
    throw new HttpError(
      413,
      'request_too_large',
      `Request body must not exceed ${MAX_REQUEST_BYTES} bytes.`,
    );
  }

  return new Promise((resolve, reject) => {
    let size = 0;
    let settled = false;
    const chunks = [];

    request.on('data', (chunk) => {
      if (settled) return;
      size += chunk.length;
      if (size > MAX_REQUEST_BYTES) {
        settled = true;
        chunks.length = 0;
        reject(
          new HttpError(
            413,
            'request_too_large',
            `Request body must not exceed ${MAX_REQUEST_BYTES} bytes.`,
          ),
        );
        return;
      }
      chunks.push(chunk);
    });

    request.on('end', () => {
      if (settled) return;
      settled = true;
      if (size === 0) {
        reject(new HttpError(400, 'invalid_json', 'Request body is required.'));
        return;
      }
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
      } catch {
        reject(new HttpError(400, 'invalid_json', 'Request body is not valid JSON.'));
      }
    });

    request.on('error', () => {
      if (settled) return;
      settled = true;
      reject(new HttpError(400, 'request_error', 'Could not read the request body.'));
    });
  });
}

export function createPillAIServer({
  env = process.env,
  fetchImpl = globalThis.fetch,
  assistantService,
} = {}) {
  const service =
    assistantService ?? createAssistantService({ env, fetchImpl });
  const allowedOrigins = configuredOrigins(env.PILLAI_ALLOWED_ORIGINS);

  return createServer(async (request, response) => {
    // Correlation only: this ID does not enable caching, replay, or
    // idempotency. Invalid, non-v4, or repeated values are replaced.
    const requestId = correlationRequestId(request);
    const origin = request.headers.origin;
    const cors = corsHeaders(origin, allowedOrigins);

    if (origin && Object.keys(cors).length === 0) {
      sendJson(
        response,
        403,
        {
          error: {
            code: 'origin_not_allowed',
            message: 'This browser origin is not allowed.',
            requestId,
          },
        },
        requestId,
      );
      return;
    }

    let url;
    try {
      url = new URL(request.url ?? '/', 'http://pillai.local');
    } catch {
      sendJson(
        response,
        400,
        {
          error: {
            code: 'invalid_url',
            message: 'The request URL is invalid.',
            requestId,
          },
        },
        requestId,
        cors,
      );
      return;
    }

    if (request.method === 'OPTIONS') {
      response.writeHead(204, {
        'cache-control': 'no-store',
        'x-request-id': requestId,
        ...cors,
      });
      response.end();
      return;
    }

    if (request.method === 'GET' && url.pathname === '/health') {
      sendJson(
        response,
        200,
        {
          status: 'ok',
          service: 'pillai-assistant',
          mode: service.mode,
          model: service.model,
          requestId,
        },
        requestId,
        cors,
      );
      return;
    }

    if (
      url.pathname === '/v1/assistant/messages' &&
      request.method !== 'POST'
    ) {
      sendJson(
        response,
        405,
        {
          error: {
            code: 'method_not_allowed',
            message: 'Use POST for this endpoint.',
            requestId,
          },
        },
        requestId,
        { allow: 'POST, OPTIONS', ...cors },
      );
      return;
    }

    if (request.method !== 'POST' || url.pathname !== '/v1/assistant/messages') {
      sendJson(
        response,
        404,
        {
          error: {
            code: 'not_found',
            message: 'Route not found.',
            requestId,
          },
        },
        requestId,
        cors,
      );
      return;
    }

    try {
      const body = await readJson(request);
      const validated = validateAssistantRequest(body);
      const result = await service.replyTo(validated, requestId);
      sendJson(response, 200, result, requestId, cors);
    } catch (error) {
      const known = error instanceof HttpError || error instanceof ValidationError;
      const status = error instanceof HttpError ? error.status : known ? 400 : 500;
      const code =
        error instanceof HttpError
          ? error.code
          : error instanceof ValidationError
            ? 'validation_error'
            : 'internal_error';
      const message = known
        ? error.message
        : 'The request could not be completed.';
      sendJson(
        response,
        status,
        { error: { code, message, requestId } },
        requestId,
        cors,
      );
    }
  });
}
