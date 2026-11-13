import { DEFAULT_PORT } from './contract.js';
import { createPillAIServer } from './http_server.js';
import { loadServerEnvironment } from './load_environment.js';

// Load secrets before any service reads process.env. Shell/deployment variables
// keep priority; server/.env is used locally, with the project-root .env as a
// compatibility fallback.
loadServerEnvironment();

function portFrom(value) {
  const parsed = Number.parseInt(value ?? '', 10);
  return Number.isInteger(parsed) && parsed > 0 && parsed <= 65_535
    ? parsed
    : DEFAULT_PORT;
}

const port = portFrom(process.env.PORT);
const host = process.env.HOST?.trim() || '127.0.0.1';
const server = createPillAIServer();

server.listen(port, host, () => {
  const address = server.address();
  const boundPort = typeof address === 'object' && address ? address.port : port;
  console.log(`PillAI assistant server listening on http://${host}:${boundPort}`);
});

function shutDown() {
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 5_000).unref();
}

process.on('SIGINT', shutDown);
process.on('SIGTERM', shutDown);
