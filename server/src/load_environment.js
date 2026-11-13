import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import dotenv from 'dotenv';

const defaultServerDirectory = resolve(
  dirname(fileURLToPath(import.meta.url)),
  '..',
);

export function loadServerEnvironment({
  env = process.env,
  serverDirectory = defaultServerDirectory,
} = {}) {
  const candidates = [
    resolve(serverDirectory, '.env'),
    resolve(serverDirectory, '..', '.env'),
  ];
  const loaded = [];

  for (const path of candidates) {
    const result = dotenv.config({
      path,
      processEnv: env,
      override: false,
      quiet: true,
    });
    if (!result.error) {
      loaded.push(path);
      continue;
    }
    if (result.error.code !== 'ENOENT') {
      throw result.error;
    }
  }

  return loaded;
}
