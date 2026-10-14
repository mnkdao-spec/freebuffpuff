#!/usr/bin/env node
/**
 * local-readonly MCP server — a deliberately narrow, READ-ONLY bridge to a self-hosted
 * music stack. Every exposed tool performs a single HTTP GET against an allowlisted host.
 *
 * Design rules (do not "improve" these away):
 *   - GET only. There is no code path that issues POST/PUT/PATCH/DELETE.
 *   - Host allowlist from env; anything else is refused before a request is made.
 *   - At most MAX_BYTES of any response is read, and the socket is cancelled at the cap, so a
 *     huge body can neither flood the model context nor be buffered into memory.
 *   - A non-2xx upstream response is a tool ERROR (isError: true), not a successful result with
 *     odd content — otherwise a 404 from Lidarr reads to the model as good news.
 *   - An argument that violates its declared `enum` is rejected locally, before any request.
 *   - No filesystem access, no shell, no subprocess.
 *   - MusicBrainz requests are serialised to <= 1 request/second (their documented limit).
 *
 * Configure with environment variables (set them in `.agents/mcp.json` env, or your shell):
 *   ND_URL, ND_USER, ND_TOKEN, ND_SALT      (Navidrome, Subsonic auth)
 *   LIDARR_URL, LIDARR_API_KEY
 *   SLSKD_URL, SLSKD_API_KEY                (use a READ-ONLY slskd key)
 *   MB_URL                                  (default https://musicbrainz.org; a mirror also works)
 *   MB_USER_AGENT                           (must identify you: app/version (contact))
 *   MCP_ALLOWED_HOSTS                       (optional) comma-separated override of the host
 *                                           allowlist; replaces the derived list entirely.
 *                                           Unset — the normal case — the allowlist is the host
 *                                           of each *_URL above plus the MusicBrainz host.
 *
 * A missing $VAR makes the CLI skip the whole mcp.json, so set them in your shell, not here.
 */
const readline = require('readline');

const ENV = {
  nd: { url: process.env.ND_URL || 'http://localhost:4533', user: process.env.ND_USER, token: process.env.ND_TOKEN, salt: process.env.ND_SALT },
  lidarr: { url: process.env.LIDARR_URL || 'http://localhost:8686', key: process.env.LIDARR_API_KEY },
  slskd: { url: process.env.SLSKD_URL || 'http://localhost:5030', key: process.env.SLSKD_API_KEY },
  mb: { url: process.env.MB_URL || 'https://musicbrainz.org', ua: process.env.MB_USER_AGENT || 'freebuff-homelab-pack/1.0 ( set MB_USER_AGENT )' },
};

// The allowlist is derived from the configured service URLs, so in normal operation every call
// site is trivially allowed and the refusal is unreachable code. MCP_ALLOWED_HOSTS overrides the
// list outright: that makes the refusal path testable — `MCP_ALLOWED_HOSTS=example.invalid` must
// refuse every tool — and lets a user tighten the list (e.g. after moving a service behind a
// proxy) without editing this file. Bare hostnames are accepted as well as full URLs.
const ALLOWED_HOSTS = new Set(
  (process.env.MCP_ALLOWED_HOSTS
    ? process.env.MCP_ALLOWED_HOSTS.split(',')
    : [ENV.nd.url, ENV.lidarr.url, ENV.slskd.url, ENV.mb.url])
    .map((h) => { const s = String(h).trim(); try { return new URL(s.includes('://') ? s : `http://${s}`).host; } catch { return null; } })
    .filter(Boolean)
);

const MAX_BYTES = 6000;
let lastMbRequest = 0;

function assertAllowed(urlStr) {
  const u = new URL(urlStr);
  if (!ALLOWED_HOSTS.has(u.host)) throw new Error(`refusing ${u.host}: not in the configured allowlist (${[...ALLOWED_HOSTS].join(', ') || 'empty'})`);
  return u;
}

// Read at most `limit` bytes and then CANCEL the body, which closes the upstream socket early.
// `res.text()` buffers the entire response into memory before anything can truncate it, so a
// multi-gigabyte body (or a hostile one) would be read in full first.
async function readCapped(res, limit) {
  if (!res.body) return { text: '', truncated: false };
  const reader = res.body.getReader();
  const chunks = [];
  let size = 0, truncated = false;
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      const room = limit - size;
      if (value.byteLength >= room) { chunks.push(value.subarray(0, room)); truncated = true; break; }
      chunks.push(value); size += value.byteLength;
    }
  } finally {
    await reader.cancel().catch(() => {});
  }
  return { text: Buffer.concat(chunks).toString('utf8'), truncated };
}

async function httpGet(urlStr, headers = {}, opts = {}) {
  const u = assertAllowed(urlStr);
  const res = await fetch(u, { method: 'GET', headers, redirect: 'error', signal: AbortSignal.timeout(opts.timeoutMs || 15000) });
  const { text, truncated } = await readCapped(res, MAX_BYTES);
  // Surface the status instead of handing the model an error page labelled as a result.
  if (!res.ok) {
    const detail = text.replace(/\s+/g, ' ').trim().slice(0, 300);
    throw new Error(`HTTP ${res.status}${res.statusText ? ' ' + res.statusText : ''} from ${u.host}${detail ? ': ' + detail : ''}`);
  }
  return truncated ? `${text}\n...[truncated at ${MAX_BYTES} bytes; connection closed]` : text;
}

function subsonic(path, params) {
  const p = new URLSearchParams({ u: ENV.nd.user || '', t: ENV.nd.token || '', s: ENV.nd.salt || '', v: '1.16.1', c: 'freebuff-pack', f: 'json', ...params });
  return `${ENV.nd.url.replace(/\/$/, '')}/rest/${path}?${p.toString()}`;
}

async function mbGet(path) {
  const now = Date.now();
  const wait = lastMbRequest + 1100 - now;
  if (wait > 0) await new Promise((r) => setTimeout(r, wait));
  lastMbRequest = Date.now();
  return httpGet(`${ENV.mb.url.replace(/\/$/, '')}/ws/2/${path}`, { 'User-Agent': ENV.mb.ua, Accept: 'application/json' });
}

// MusicBrainz search terms are Lucene queries. An unescaped `"` or `\` does not raise an error,
// it silently rewrites the query: measured, artist: 'Radio"head' returned 6806 hits — an operator
// injection that looks like a normal success. Escape the two characters that matter inside a
// quoted phrase so the term stays a phrase.
const lucenePhrase = (s) => `"${String(s).replace(/([\\"])/g, '\\$1')}"`;

const TOOLS = [
  { name: 'navidrome_ping', description: 'Read-only. Confirm the Navidrome/Subsonic API answers and report the server version.', inputSchema: { type: 'object', properties: {} },
    run: async () => httpGet(subsonic('ping', {})) },
  { name: 'navidrome_search', description: 'Read-only. Search the Navidrome library for artists, albums and songs by free text.', inputSchema: { type: 'object', properties: { query: { type: 'string' } }, required: ['query'] },
    run: async ({ query }) => httpGet(subsonic('search3', { query: String(query), songCount: '20', albumCount: '20', artistCount: '10' })) },
  { name: 'navidrome_album', description: 'Read-only. Fetch one album (with its songs) from Navidrome by album id.', inputSchema: { type: 'object', properties: { id: { type: 'string' } }, required: ['id'] },
    run: async ({ id }) => httpGet(subsonic('getAlbum', { id: String(id) })) },
  { name: 'lidarr_health', description: 'Read-only. Lidarr health checks — the fastest way to see indexer, download-client, path and disk warnings.', inputSchema: { type: 'object', properties: {} },
    run: async () => httpGet(`${ENV.lidarr.url.replace(/\/$/, '')}/api/v1/health`, { 'X-Api-Key': ENV.lidarr.key || '' }) },
  { name: 'lidarr_queue', description: 'Read-only. Lidarr download queue, including why items are stuck.', inputSchema: { type: 'object', properties: {} },
    run: async () => httpGet(`${ENV.lidarr.url.replace(/\/$/, '')}/api/v1/queue?includeUnknownArtistItems=true&pageSize=25`, { 'X-Api-Key': ENV.lidarr.key || '' }) },
  { name: 'lidarr_wanted_missing', description: 'Read-only. Lidarr wanted/missing albums — what Lidarr wants but has not got.', inputSchema: { type: 'object', properties: {} },
    run: async () => httpGet(`${ENV.lidarr.url.replace(/\/$/, '')}/api/v1/wanted/missing?pageSize=25`, { 'X-Api-Key': ENV.lidarr.key || '' }) },
  { name: 'slskd_session', description: 'Read-only. slskd session/user state. Use a READ-ONLY API key.', inputSchema: { type: 'object', properties: {} },
    run: async () => httpGet(`${ENV.slskd.url.replace(/\/$/, '')}/api/v0/session`, { 'X-API-Key': ENV.slskd.key || '' }) },
  { name: 'slskd_server', description: 'Read-only. slskd Soulseek server connection state.', inputSchema: { type: 'object', properties: {} },
    run: async () => httpGet(`${ENV.slskd.url.replace(/\/$/, '')}/api/v0/server`, { 'X-API-Key': ENV.slskd.key || '' }) },
  { name: 'musicbrainz_search_release_group', description: 'Read-only, rate-limited to 1 request/second. Search MusicBrainz release groups (albums) by artist and/or album title.', inputSchema: { type: 'object', properties: { artist: { type: 'string' }, album: { type: 'string' } }, required: ['artist'] },
    run: async ({ artist, album }) => {
      let q = `artist:${lucenePhrase(artist)}`; if (album) q += ` AND releasegroup:${lucenePhrase(album)}`;
      return mbGet(`release-group/?query=${encodeURIComponent(q)}&fmt=json&limit=8`);
    } },
  { name: 'musicbrainz_lookup', description: 'Read-only, rate-limited. Look up a MusicBrainz entity by MBID. Use release-group for the album "as a work", release for one edition, recording for a track.', inputSchema: { type: 'object', properties: { kind: { type: 'string', enum: ['release-group', 'release', 'recording', 'artist'] }, mbid: { type: 'string' } }, required: ['kind', 'mbid'] },
    run: async ({ kind, mbid }) => mbGet(`${kind}/${encodeURIComponent(mbid)}?fmt=json&inc=artist-credits`) },
];

const send = (o) => process.stdout.write(JSON.stringify(o) + '\n');
const rl = readline.createInterface({ input: process.stdin });

rl.on('line', async (line) => {
  let m; try { m = JSON.parse(line); } catch { return; }
  const { id, method, params } = m;
  const fail = (text) => send({ jsonrpc: '2.0', id, result: { isError: true, content: [{ type: 'text', text }] } });
  try {
    if (method === 'initialize') {
      return send({ jsonrpc: '2.0', id, result: { protocolVersion: '2025-06-18', capabilities: { tools: {} },
        serverInfo: { name: 'local-readonly', version: '1.0.0' },
        instructions: 'Read-only tools for a self-hosted music stack. Nothing here can change state.' } });
    }
    if (method === 'notifications/initialized' || method === 'notifications/cancelled') return;
    if (method === 'ping') return send({ jsonrpc: '2.0', id, result: {} });
    if (method === 'tools/list') {
      return send({ jsonrpc: '2.0', id, result: { tools: TOOLS.map(({ name, description, inputSchema }) => ({ name, description, inputSchema })) } });
    }
    if (method === 'tools/call') {
      const tool = TOOLS.find((t) => t.name === params?.name);
      if (!tool) return send({ jsonrpc: '2.0', id, error: { code: -32602, message: `unknown tool: ${params?.name}` } });
      const args = params?.arguments || {};
      const missing = (tool.inputSchema.required || []).filter((k) => args[k] === undefined);
      if (missing.length) return fail(`missing required argument(s): ${missing.join(', ')}`);
      // An `enum` nobody checks is decoration: kind: "not-a-kind" used to reach
      // https://musicbrainz.org/ws/2/not-a-kind/... verbatim. Validate every enum we publish.
      const invalid = Object.entries(tool.inputSchema.properties || {})
        .filter(([k, spec]) => spec.enum && args[k] !== undefined && !spec.enum.includes(args[k]))
        .map(([k, spec]) => `${k} must be one of: ${spec.enum.join(', ')} (got ${JSON.stringify(args[k])})`);
      if (invalid.length) return fail(invalid.join('; '));
      try {
        const out = await tool.run(args);
        return send({ jsonrpc: '2.0', id, result: { content: [{ type: 'text', text: String(out) }] } });
      } catch (err) {
        return fail(`request failed: ${err.message}`);
      }
    }
    if (id !== undefined) send({ jsonrpc: '2.0', id, error: { code: -32601, message: `Method not found: ${method}` } });
  } catch (err) {
    if (id !== undefined) send({ jsonrpc: '2.0', id, error: { code: -32603, message: String(err && err.message) } });
  }
});
