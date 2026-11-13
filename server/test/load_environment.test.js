import assert from 'node:assert/strict';
import { mkdir, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import { loadServerEnvironment } from '../src/load_environment.js';

test('loads server/.env independently of the current working directory', async () => {
  const projectDirectory = join(
    tmpdir(),
    `pillai-env-${process.pid}-${Date.now()}`,
  );
  const serverDirectory = join(projectDirectory, 'server');
  await mkdir(serverDirectory, { recursive: true });
  await writeFile(
    join(serverDirectory, '.env'),
    'OPENAI_API_KEY=local-test-key\nPILLAI_OPENAI_MODEL=gpt-test\n',
  );

  try {
    const env = {};
    const loaded = loadServerEnvironment({ env, serverDirectory });

    assert.deepEqual(loaded, [join(serverDirectory, '.env')]);
    assert.equal(env.OPENAI_API_KEY, 'local-test-key');
    assert.equal(env.PILLAI_OPENAI_MODEL, 'gpt-test');
  } finally {
    await rm(projectDirectory, { recursive: true, force: true });
  }
});

test('keeps deployment variables ahead of local files', async () => {
  const projectDirectory = join(
    tmpdir(),
    `pillai-env-priority-${process.pid}-${Date.now()}`,
  );
  const serverDirectory = join(projectDirectory, 'server');
  await mkdir(serverDirectory, { recursive: true });
  await writeFile(
    join(serverDirectory, '.env'),
    'OPENAI_API_KEY=file-key\nPILLAI_OPENAI_MODEL=file-model\n',
  );

  try {
    const env = {
      OPENAI_API_KEY: 'deployment-key',
    };
    loadServerEnvironment({ env, serverDirectory });

    assert.equal(env.OPENAI_API_KEY, 'deployment-key');
    assert.equal(env.PILLAI_OPENAI_MODEL, 'file-model');
  } finally {
    await rm(projectDirectory, { recursive: true, force: true });
  }
});
