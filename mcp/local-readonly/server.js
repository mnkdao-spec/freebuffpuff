#!/usr/bin/env node
/**
 * local-readonly MCP server — a deliberately narrow, READ-ONLY bridge to a self-hosted
 * music stack. Every exposed tool performs a single HTTP GET against an allowlisted host.
 *
 * Design rules (do not "improve" these away):
 *   - GET only. There is no code path that issues POST/PUT/PATCH/DELETE.
 *   - Host allowlist from env; anything else is refused before a request is made.
 *   - Response bodies are truncated so a huge JSON blob cannot flood the model context.
 *   - No filesystem access, no shell, no subprocess.
 *   - MusicBrainz requests are serialised to <= 1 request/second (their documented limit).
 *
 * Configure with environment variables (set them in `.agents/mcp.json` env, or your shell):
 *   ND_URL, ND_USER, ND_TOKEN, ND_SALT      (Navidrome, Subsonic auth)
 *   LIDARR_URL, LIDARR_API_KEY
 *   SLSKD_URL, SLSKD_API_KEY                (use a READ-ONLY slskd key)
 *   MB_USER_AGENT                           (must identify you: app/version (contact))
 */
const readline = require('readline');

const ENV = {
  nd: { url: process.env.ND_URL || 'http://localhost:4533', user: process.env.ND_USER, token: process.env.ND_TOKEN, salt: process.env.ND_SALT },
  lidarr: { url: process.env.LIDARR_URL || 'http://localhost:8686', key: process.env.LIDARR_API_KEY },
  slskd: { url: process.env.SLSKD_URL || 'http://localhost:5030', key: process.env.SLSKD_API_KEY },
  mb: { ua: process.env.MB_USER_AGENT || 'freebuff-homelab-pack/1.0 ( set MB_USER_AGENT )' },
};

const ALLOWED_HOSTS = new Set(
  [ENV.nd.url, ENV.lidarr.url, ENV.slskd.url, 'https://musicbrainz.org']
    .map((u) => { try { return new URL(u).host; } catch { return null; } })
    .filter(Boolean)
);

const MAX_BYTES = 6000;
let lastMbRequest = 0;

function assertAllowed(urlStr) {
  const u = new URL(urlStr);
  if (!ALLOWED_HOSTS.has(u.host)) throw new Error(`refusing ${u.host}: not in the configured allowlist (${[...ALLOWED_HOSTS].join(', ')})`);
  return u;
}

async function httpGet(urlStr, headers = {}, opts = {}) {
  const u = assertAllowed(urlStr);
  const res = await fetch(u, { method: 'GET', headers, redirect: 'error', signal: AbortSignal.timeout(opts.timeoutMs || 15000) });
  let text = await res.text();
  if (text.length > MAX_BYTES) text = text.slice(0, MAX_BYTES) + `\n...[truncated ${text.length - MAX_BYTES} bytes]`;
  return { status: res.status, ok: res.ok, body: text };
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
  return httpGet(`https://musicbrainz.org/ws/2/${path}`, { 'User-Agent': ENV.mb.ua, Accept: 'application/json' });
}

const j = (v) => JSON.stringify(v ?? null);

const TOOLS = [
  { name: 'navidrome_ping', description: 'Read-only. Confirm the Navidrome/Subsonic API answers and report the server version.', inputSchema: { type: 'object', properties: {} },
    run: async () => (await httpGet(subsonic('ping', {}))).body },
  { name: 'navidrome_search', description: 'Read-only. Search the Navidrome library for artists, albums and songs by free text.', inputSchema: { type: 'object', properties: { query: { type: 'string' } }, required: ['query'] },
    run: async ({ query }) => (await httpGet(subsonic('search3', { query: String(query), songCount: '20', albumCount: '20', artistCount: '10' }))).body },
  { name: 'navidrome_album', description: 'Read-only. Fetch one album (with its songs) from Navidrome by album id.', inputSchema: { type: 'object', properties: { id: { type: 'string' } }, required: ['id'] },
    run: async ({ id }) => (await httpGet(subsonic('getAlbum', { id: String(id) }))).body },
  { name: 'lidarr_health', description: 'Read-only. Lidarr health checks — the fastest way to see indexer, download-client, path and disk warnings.', inputSchema: { type: 'object', properties: {} },
    run: async () => (await httpGet(`${ENV.lidarr.url.replace(/\/$/, '')}/api/v1/health`, { 'X-Api-Key': ENV.lidarr.key || '' })).body },
  { name: 'lidarr_queue', description: 'Read-only. Lidarr download queue, including why items are stuck.', inputSchema: { type: 'object', properties: {} },
    run: async () => (await httpGet(`${ENV.lidarr.url.replace(/\/$/, '')}/api/v1/queue?includeUnknownArtistItems=true&pageSize=25`, { 'X-Api-Key': ENV.lidarr.key || '' })).body },
  { name: 'lidarr_wanted_missing', description: 'Read-only. Lidarr wanted/missing albums — what Lidarr wants but has not got.', inputSchema: { type: 'object', properties: {} },
    run: async () => (await httpGet(`${ENV.lidarr.url.replace(/\/$/, '')}/api/v1/wanted/missing?pageSize=25`, { 'X-Api-Key': ENV.lidarr.key || '' })).body },
  { name: 'slskd_session', description: 'Read-only. slskd session/user state. Use a READ-ONLY API key.', inputSchema: { type: 'object', properties: {} },
    run: async () => (await httpGet(`${ENV.slskd.url.replace(/\/$/, '')}/api/v0/session`, { 'X-API-Key': ENV.slskd.key || '' })).body },
  { name: 'slskd_server', description: 'Read-only. slskd Soulseek server connection state.', inputSchema: { type: 'object', properties: {} },
    run: async () => (await httpGet(`${ENV.slskd.url.replace(/\/$/, '')}/api/v0/server`, { 'X-API-Key': ENV.slskd.key || '' })).body },
  { name: 'musicbrainz_search_release_group', description: 'Read-only, rate-limited to 1 request/second. Search MusicBrainz release groups (albums) by artist and/or album title.', inputSchema: { type: 'object', properties: { artist: { type: 'string' }, album: { type: 'string' } }, required: ['artist'] },
    run: async ({ artist, album }) => {
      let q = `artist:"${artist}"`; if (album) q += ` AND releasegroup:"${album}"`;
      return (await mbGet(`release-group/?query=${encodeURIComponent(q)}&fmt=json&limit=8`)).body;
    } },
  { name: 'musicbrainz_lookup', description: 'Read-only, rate-limited. Look up a MusicBrainz entity by MBID. Use release-group for the album "as a work", release for one edition, recording for a track.', inputSchema: { type: 'object', properties: { kind: { type: 'string', enum: ['release-group', 'release', 'recording', 'artist'] }, mbid: { type: 'string' } }, required: ['kind', 'mbid'] },
    run: async ({ kind, mbid }) => (await mbGet(`${kind}/${encodeURIComponent(mbid)}?fmt=json&inc=artist-credits`)).body },
];

const send = (o) => process.stdout.write(JSON.stringify(o) + '\n');
const rl = readline.createInterface({ input: process.stdin });

rl.on('line', async (line) => {
  let m; try { m = JSON.parse(line); } catch { return; }
  const { id, method, params } = m;
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
      const missing = (tool.inputSchema.required || []).filter((k) => params?.arguments?.[k] === undefined);
      if (missing.length) return send({ jsonrpc: '2.0', id, result: { isError: true, content: [{ type: 'text', text: `missing required argument(s): ${missing.join(', ')}` }] } });
      try {
        const out = await tool.run(params.arguments || {});
        return send({ jsonrpc: '2.0', id, result: { content: [{ type: 'text', text: out }] } });
      } catch (err) {
        return send({ jsonrpc: '2.0', id, result: { isError: true, content: [{ type: 'text', text: `request failed: ${err.message}` }] } });
      }
    }
    if (id !== undefined) send({ jsonrpc: '2.0', id, error: { code: -32601, message: `Method not found: ${method}` } });
  } catch (err) {
    if (id !== undefined) send({ jsonrpc: '2.0', id, error: { code: -32603, message: String(err && err.message) } });
  }
});
