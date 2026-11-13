import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { extname, join, normalize, resolve, sep } from 'node:path';

const root = resolve('build/web');
const port = Number(process.env.PILLAI_WEB_PORT ?? 8765);
const mimeTypes = {
  '.css': 'text/css',
  '.html': 'text/html',
  '.ico': 'image/x-icon',
  '.js': 'text/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.wasm': 'application/wasm',
};

createServer(async (request, response) => {
  try {
    const requestPath = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    const relative = normalize(requestPath).replace(/^[/\\]+/, '');
    let filePath = join(root, relative || 'index.html');
    if (filePath !== root && !filePath.startsWith(root + sep)) throw new Error('Invalid path');
    const fileStat = await stat(filePath).catch(() => null);
    if (!fileStat || fileStat.isDirectory()) filePath = join(root, 'index.html');
    const body = await readFile(filePath);
    response.writeHead(200, {
      'Content-Type': mimeTypes[extname(filePath)] ?? 'application/octet-stream',
      'Cache-Control': 'no-store',
    });
    response.end(body);
  } catch {
    response.writeHead(404, { 'Content-Type': 'text/plain' });
    response.end('Not found');
  }
}).listen(port, '127.0.0.1');
