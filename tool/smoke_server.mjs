import { once } from 'node:events';

import { createPillAIServer } from '../server/src/http_server.js';

const server = createPillAIServer({ env: {} });
server.listen(0, '127.0.0.1');
await once(server, 'listening');

const address = server.address();
const baseUrl = `http://127.0.0.1:${address.port}`;

async function post(message) {
  const response = await fetch(`${baseUrl}/v1/assistant/messages`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      clientId: 'install_smoke_1234',
      message,
      context: {},
    }),
  });
  return { status: response.status, body: await response.json() };
}

try {
  const healthResponse = await fetch(`${baseUrl}/health`);
  const health = await healthResponse.json();
  const demo = await post('Can I take this with milk?');
  const emergency = await post('I took the whole bottle');

  if (
    healthResponse.status !== 200 ||
    health.mode !== 'demo' ||
    demo.status !== 200 ||
    demo.body.meta?.source !== 'demo' ||
    demo.body.meta?.fallbackReason !== 'no_key' ||
    emergency.status !== 200 ||
    emergency.body.meta?.source !== 'safety_gate' ||
    emergency.body.meta?.safetyGate !== 'emergency_phrase'
  ) {
    throw new Error('PillAI server smoke contract failed.');
  }

  console.log(
    JSON.stringify(
      {
        health: { status: health.status, mode: health.mode, model: health.model },
        demo: {
          source: demo.body.meta.source,
          fallbackReason: demo.body.meta.fallbackReason,
        },
        emergency: {
          source: emergency.body.meta.source,
          safetyGate: emergency.body.meta.safetyGate,
        },
      },
      null,
      2,
    ),
  );
} finally {
  server.closeIdleConnections?.();
  server.closeAllConnections?.();
  await new Promise((resolve) => server.close(resolve));
}
