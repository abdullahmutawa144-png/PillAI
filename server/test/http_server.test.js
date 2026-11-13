import assert from 'node:assert/strict';
import { once } from 'node:events';
import test from 'node:test';

import { MAX_REQUEST_BYTES } from '../src/contract.js';
import { createPillAIServer } from '../src/http_server.js';

async function withServer(env, callback, options = {}) {
  const server = createPillAIServer({ env, ...options });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const address = server.address();
  const baseUrl = `http://127.0.0.1:${address.port}`;
  try {
    await callback(baseUrl);
  } finally {
    server.closeIdleConnections?.();
    server.closeAllConnections?.();
    await new Promise((resolve) => server.close(resolve));
  }
}

test('GET /health reports demo mode without exposing secrets', async () => {
  await withServer({}, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/health`, {
      headers: { origin: 'http://localhost:54321' },
    });
    const body = await response.json();
    assert.equal(response.status, 200);
    assert.equal(body.status, 'ok');
    assert.equal(body.mode, 'demo');
    assert.equal(body.model, 'gpt-5.6-terra');
    assert.equal(response.headers.get('access-control-allow-origin'), 'http://localhost:54321');
    assert.equal(response.headers.get('x-request-id'), body.requestId);
  });
});

test('reuses one valid client UUIDv4 throughout request correlation', async () => {
  const suppliedRequestId = '550e8400-e29b-41d4-a716-446655440000';
  let internalRequestId;
  const assistantService = {
    mode: 'model',
    model: 'gpt-5.6-terra',
    async replyTo(_request, requestId) {
      internalRequestId = requestId;
      return {
        reply: {
          title: 'Server template',
          message: 'Fixed server response.',
          level: 'general',
          actionLabel: null,
          suggestedPrompt: null,
          coverage: 'generalGuidance',
          contextNote: 'No clinical rule was verified.',
        },
        meta: {
          source: 'model',
          model: 'gpt-5.6-terra',
          requestId,
          degraded: false,
          notice: 'Test response.',
          fallbackReason: null,
          safetyGate: null,
        },
      };
    },
  };

  await withServer(
    {},
    async (baseUrl) => {
      const response = await fetch(`${baseUrl}/v1/assistant/messages`, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-request-id': suppliedRequestId,
        },
        body: JSON.stringify({
          clientId: 'install_http_1234',
          message: 'Show my saved schedule',
          context: {},
        }),
      });
      const body = await response.json();
      assert.equal(response.status, 200);
      assert.equal(internalRequestId, suppliedRequestId);
      assert.equal(response.headers.get('x-request-id'), suppliedRequestId);
      assert.equal(body.meta.requestId, suppliedRequestId);
    },
    { assistantService },
  );
});

test('replaces an invalid client request ID with a fresh UUIDv4', async () => {
  await withServer({}, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/health`, {
      headers: { 'x-request-id': 'not-a-valid-request-id' },
    });
    const body = await response.json();
    const generated = response.headers.get('x-request-id');
    assert.notEqual(generated, 'not-a-valid-request-id');
    assert.match(
      generated,
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
    );
    assert.equal(body.requestId, generated);
  });
});

test('supports Flutter web preflight from local origins', async () => {
  await withServer({}, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/v1/assistant/messages`, {
      method: 'OPTIONS',
      headers: {
        origin: 'http://127.0.0.1:61234',
        'access-control-request-method': 'POST',
      },
    });
    assert.equal(response.status, 204);
    assert.equal(
      response.headers.get('access-control-allow-origin'),
      'http://127.0.0.1:61234',
    );
    assert.match(response.headers.get('access-control-allow-methods'), /POST/);
  });
});

test('rejects unconfigured remote browser origins', async () => {
  await withServer({}, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/health`, {
      headers: { origin: 'https://untrusted.example' },
    });
    const body = await response.json();
    assert.equal(response.status, 403);
    assert.equal(body.error.code, 'origin_not_allowed');
  });
});

test('POST /v1/assistant/messages validates JSON and returns trace meta', async () => {
  await withServer({}, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/v1/assistant/messages`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        clientId: 'install_http_1234',
        message: 'I forgot my medicine',
        context: {},
      }),
    });
    const body = await response.json();
    assert.equal(response.status, 200);
    assert.equal(body.meta.source, 'demo');
    assert.equal(body.meta.requestId, response.headers.get('x-request-id'));
    assert.deepEqual(Object.keys(body.reply), [
      'title',
      'message',
      'level',
      'actionLabel',
      'suggestedPrompt',
      'coverage',
      'contextNote',
    ]);
  });
});

test('returns useful 400 and 415 errors without stack traces', async () => {
  await withServer({}, async (baseUrl) => {
    const malformed = await fetch(`${baseUrl}/v1/assistant/messages`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: '{not-json',
    });
    const malformedBody = await malformed.json();
    assert.equal(malformed.status, 400);
    assert.equal(malformedBody.error.code, 'invalid_json');

    const wrongType = await fetch(`${baseUrl}/v1/assistant/messages`, {
      method: 'POST',
      headers: { 'content-type': 'text/plain' },
      body: 'hello',
    });
    const wrongTypeBody = await wrongType.json();
    assert.equal(wrongType.status, 415);
    assert.equal(wrongTypeBody.error.code, 'unsupported_media_type');
    assert.ok(!JSON.stringify(wrongTypeBody).includes('at '));
  });
});

test('enforces the request size limit before validation', async () => {
  await withServer({}, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/v1/assistant/messages`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ padding: 'x'.repeat(MAX_REQUEST_BYTES + 1) }),
    });
    const body = await response.json();
    assert.equal(response.status, 413);
    assert.equal(body.error.code, 'request_too_large');
  });
});
