#!/usr/bin/env node
/**
 * tests/mcp-fixture.js — a throwaway HTTP server that mimics the three shapes the read-only MCP
 * bridge talks to, so tests/run.sh can prove the BRIDGE's behaviour without a real
 * Navidrome/Lidarr/slskd and without depending on the network. Used by the MCP section of
 * tests/run.sh only; nothing in the pack loads it.
 *
 *   /big...        streams 20 MiB and records how many bytes it actually wrote, so the test can
 *                  show the client aborted the read at the cap instead of draining the body.
 *   /err500...     answers 500 with a JSON body, to show a non-2xx is surfaced as a tool error.
 *   /ws/2/...      echoes the request path, so the test can inspect the URL the bridge built
 *                  (that is how the Lucene escaping is checked offline).
 *
 * Usage: node mcp-fixture.js <portFile> <bytesFile> <logFile>
 * Binds 127.0.0.1 on port 0 and writes the chosen port to <portFile>, so the caller never has to
 * race for a port. Every request appends "METHOD /path" to <logFile>.
 */
const http = require('http');
const fs = require('fs');

const [portFile, bytesFile, logFile] = process.argv.slice(2);
const BIG = 20 * 1024 * 1024;
const CHUNK = 'x'.repeat(8192);

fs.writeFileSync(logFile, '');

const server = http.createServer((req, res) => {
  fs.appendFileSync(logFile, `${req.method} ${req.url}\n`);
  const { pathname } = new URL(req.url, 'http://127.0.0.1');

  if (pathname.startsWith('/big')) {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    let sent = 0;
    const record = () => { try { fs.writeFileSync(bytesFile, String(res.socket.bytesWritten)); } catch { /* socket gone */ } };
    const pump = () => {
      while (sent < BIG) {
        sent += CHUNK.length;
        record();
        if (!res.write(CHUNK)) return res.once('drain', pump); // kernel buffer full: wait
      }
      res.end();
    };
    res.on('close', record);
    pump();
    return;
  }

  if (pathname.startsWith('/err500')) {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    return res.end('{"error":"fixture says no"}');
  }

  if (pathname.startsWith('/ws/2/')) {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ echo: req.url }));
  }

  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end('{"error":"not found"}');
});

server.listen(0, '127.0.0.1', () => fs.writeFileSync(portFile, String(server.address().port)));
