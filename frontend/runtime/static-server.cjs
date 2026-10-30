const http = require('http');
const fs = require('fs');
const path = require('path');

const root = path.resolve(process.env.AFA_FRONTEND_DIST || 'D:/AFA-Frontend/app/dist');
const port = Number(process.env.AFA_FRONTEND_PORT || 5173);
const host = process.env.AFA_FRONTEND_HOST || '127.0.0.1';

const mime = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.cjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.txt': 'text/plain; charset=utf-8',
  '.map': 'application/json; charset=utf-8',
  '.zip': 'application/zip',
};

function safePath(urlPath) {
  const raw = decodeURIComponent((urlPath || '/').split('?')[0]);
  const normalized = path.posix.normalize('/' + raw).replace(/^\/+/, '');
  const candidate = path.resolve(root, normalized);
  return candidate.startsWith(root) ? candidate : null;
}

function send(res, filePath) {
  fs.stat(filePath, (statErr, stat) => {
    if (statErr || !stat.isFile()) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('Not found');
      return;
    }

    const ext = path.extname(filePath).toLowerCase();
    const headers = {
      'Content-Type': mime[ext] || 'application/octet-stream',
      'Cache-Control': ext === '.html' ? 'no-cache' : 'public, max-age=3600',
      'X-Content-Type-Options': 'nosniff',
      'Referrer-Policy': 'same-origin',
    };

    res.writeHead(200, headers);
    fs.createReadStream(filePath).pipe(res);
  });
}

const server = http.createServer((req, res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.writeHead(405, { Allow: 'GET, HEAD' });
    res.end();
    return;
  }

  let candidate = safePath(req.url);
  if (!candidate) {
    res.writeHead(400, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Bad request');
    return;
  }

  if (req.url === '/' || req.url.startsWith('/?')) {
    candidate = path.join(root, 'index.html');
    send(res, candidate);
    return;
  }

  fs.stat(candidate, (err, stat) => {
    if (!err && stat.isDirectory()) {
      const indexFile = path.join(candidate, 'index.html');
      if (fs.existsSync(indexFile)) {
        send(res, indexFile);
        return;
      }
    }

    if (!err && stat.isFile()) {
      send(res, candidate);
      return;
    }

    // SPA fallback for route-like paths without a file extension.
    if (!path.extname(candidate)) {
      send(res, path.join(root, 'index.html'));
      return;
    }

    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Not found');
  });
});

server.on('error', (err) => {
  console.error(`[AFA] frontend server error: ${err.stack || err.message}`);
  process.exitCode = 1;
});

server.listen(port, host, () => {
  console.log(`[AFA] frontend root: ${root}`);
  console.log(`[AFA] frontend URL: http://${host}:${port}`);
});
