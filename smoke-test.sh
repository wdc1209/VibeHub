#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${VIBE_HUB_BRIDGE_URL:-${TOKEN_CARD_BRIDGE_URL:-http://127.0.0.1:4765}}"
SESSION_ID="${VIBE_HUB_SESSION_ID:-${TOKEN_CARD_SESSION_ID:-current-webchat}}"
PROBE_TEXT="${VIBE_HUB_PROBE_TEXT:-${TOKEN_CARD_PROBE_TEXT:-Vibe Hub smoke test → Codex}}"

node - <<'NODE' "$BASE_URL" "$SESSION_ID" "$PROBE_TEXT"
const [baseUrl, sessionId, probeText] = process.argv.slice(2);
const http = require(baseUrl.startsWith('https:') ? 'https' : 'http');

function request(method, url, body) {
  return new Promise((resolve, reject) => {
    const req = http.request(url, {
      method,
      headers: body
        ? {
            'content-type': 'application/json',
            'content-length': Buffer.byteLength(body),
          }
        : undefined,
    }, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, json: JSON.parse(data) });
        } catch (error) {
          reject(new Error(`Invalid JSON from ${url}: ${error.message}\n${data}`));
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

(async () => {
  const status = await request('GET', `${baseUrl}/status`);
  const tokenSession = await request('GET', `${baseUrl}/token-session?sessionId=${encodeURIComponent(sessionId)}`);
  const send = await request('POST', `${baseUrl}/send/codex`, JSON.stringify({ text: probeText }));

  const summary = {
    ok: status.status === 200 && tokenSession.status === 200 && send.status === 200,
    bridge: {
      inputTerminal: status.json.inputTerminal,
      codexConnected: status.json.codex?.connected ?? false,
      discoveredApps: (status.json.apps || []).filter((app) => app.installed).map((app) => app.name),
    },
    tokenSession: {
      exists: !!tokenSession.json.tokenSession,
      updatedAt: tokenSession.json.tokenSession?.updatedAt ?? null,
      mergedTextPreview: (tokenSession.json.tokenSession?.mergedText || '').slice(0, 120),
    },
    send: {
      target: send.json.target ?? null,
      command: send.json.command ?? null,
      outputPreview: (send.json.output || send.json.error || '').slice(0, 160),
    },
  };

  console.log(JSON.stringify(summary, null, 2));

  if (!summary.ok || !summary.bridge.codexConnected) {
    process.exit(1);
  }
})();
NODE
