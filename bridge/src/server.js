import http from 'node:http';
import os from 'node:os';
import fs from 'node:fs';
import path from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { randomUUID } from 'node:crypto';
import { CDPBridge } from '/opt/homebrew/lib/node_modules/@jackwener/opencli/dist/browser/cdp.js';
import { checkDaemonStatus } from '/opt/homebrew/lib/node_modules/@jackwener/opencli/dist/browser/discover.js';
import { sendCommand as sendBrowserCommand } from '/opt/homebrew/lib/node_modules/@jackwener/opencli/dist/browser/daemon-client.js';
import { evaluateRoute } from './routingRules.js';
import { getResolvedLlmSettings } from './llmSettings.js';
import { rewriteDraft, compressDraft } from './llmAdapter.js';

const execFileAsync = promisify(execFile);
const PORT = Number(process.env.VIBE_HUB_PORT || process.env.TOKEN_CARD_PORT || 4765);
const HOST = process.env.VIBE_HUB_HOST || process.env.TOKEN_CARD_HOST || '127.0.0.1';
const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..', '..');
const V6_DIR = path.join(ROOT, 'versions', '2026-03-24-v6-vibe-hub-status-split');
const CODEX_CDP_ENDPOINT = 'http://127.0.0.1:9333';
const CODEX_CDP_STATUS_COMMAND = `OPENCLI_CDP_ENDPOINT=${CODEX_CDP_ENDPOINT} opencli codex status`;
const CODEX_BINARY = '/Applications/Codex.app/Contents/MacOS/Codex';
const CODEX_CONNECT_LOG = '/tmp/vibe-hub-connect-codex.log';
const ANTIGRAVITY_CDP_ENDPOINT = 'http://127.0.0.1:9224';
const ANTIGRAVITY_CDP_STATUS_COMMAND = `OPENCLI_CDP_ENDPOINT=${ANTIGRAVITY_CDP_ENDPOINT} opencli antigravity status`;
const ANTIGRAVITY_BINARY = '/Applications/Antigravity.app/Contents/MacOS/Electron';
const ANTIGRAVITY_CONNECT_LOG = '/tmp/vibe-hub-connect-antigravity.log';
const OPENCLI_DAEMON_PATH = '/opt/homebrew/lib/node_modules/@jackwener/opencli/dist/daemon.js';
const CHROME_CONNECT_LOG = '/tmp/vibe-hub-connect-chrome.log';
const SEND_AUDIT_LOG = '/tmp/vibe-hub-send-audit.log';
const tokenSessions = new Map();
const lastTargetSends = new Map();
const targetWindowCache = {
  webchat: [],
};
let webchatWindowsInFlight = null;
let webchatWindowsLastLoadedAt = 0;
const WEBCHAT_WINDOWS_TTL_MS = 5000;

function normalizeCodexThreadLabel(text) {
  return String(text || '')
    .replace(/\s*(刚刚|\d+\s*(秒|分|分钟|小?时|天|周|个月|月|年)|Yesterday|Today|\d+\s*(min|mins?|h|hr|hrs?|day|days|week|weeks|month|months|year|years))\s*$/iu, '')
    .replace(/[\s+\-·•]+$/u, '')
    .trim();
}

function decodeCodexThreadWindowTitle(windowTitle) {
  const value = String(windowTitle || '').trim();
  if (!value.startsWith('thread::')) return null;
  return value.slice('thread::'.length).trim() || null;
}

async function withCodexPage(callback) {
  process.env.OPENCLI_CDP_ENDPOINT = CODEX_CDP_ENDPOINT;
  const bridge = new CDPBridge();
  const page = await bridge.connect({ timeout: 5 });
  try {
    return await callback(page);
  } finally {
    try {
      await bridge.close();
    } catch {
      // best-effort close
    }
  }
}

async function listCodexPinnedThreads() {
  try {
    const items = await withCodexPage((page) => page.evaluate(`
      (() => {
        const normalize = (text) => String(text || '')
          .replace(/\\s*(刚刚|\\d+\\s*(秒|分|分钟|小?时|天|周|个月|月|年)|Yesterday|Today|\\d+\\s*(min|mins?|h|hr|hrs?|day|days|week|weeks|month|months|year|years))\\s*$/iu, '')
          .replace(/[\\s+\\-·•]+$/u, '')
          .trim();
        const list = document.querySelector('[role="list"][aria-label="置顶的线程"]');
        if (!(list instanceof HTMLElement)) return [];
        return Array.from(list.querySelectorAll('[role="listitem"]'))
          .map((item) => {
            const rawText = String(item.textContent || '').trim();
            const label = normalize(rawText);
            if (!label) return null;
            return {
              label,
              rawText,
            };
          })
          .filter(Boolean);
      })()
    `));

    if (!Array.isArray(items) || items.length === 0) {
      return [];
    }

    const seenIds = new Set();
    return items
      .map((item, index) => {
        const label = normalizeCodexThreadLabel(item?.label || item?.rawText || '');
        if (!label) return null;
        const baseId = `codex-thread:${label}`;
        const id = seenIds.has(baseId) ? `${baseId}:${index}` : baseId;
        seenIds.add(id);
        return {
          id,
          label,
          title: `thread::${label}`,
          subtitle: String(item?.rawText || '').trim() || null,
          type: 'thread',
        };
      })
      .filter(Boolean);
  } catch {
    return [];
  }
}

async function switchCodexPinnedThread(threadLabel) {
  const normalizedTarget = normalizeCodexThreadLabel(threadLabel);
  if (!normalizedTarget) {
    return { ok: false, error: 'invalid Codex thread label' };
  }

  const result = await withCodexPage((page) => page.evaluate(`
    (() => {
      const normalize = (text) => String(text || '')
        .replace(/\\s*(刚刚|\\d+\\s*(秒|分|分钟|小?时|天|周|个月|月|年)|Yesterday|Today|\\d+\\s*(min|mins?|h|hr|hrs?|day|days|week|weeks|month|months|year|years))\\s*$/iu, '')
        .replace(/[\\s+\\-·•]+$/u, '')
        .trim();
      const targetLabel = ${JSON.stringify(normalizedTarget)};
      const list = document.querySelector('[role="list"][aria-label="置顶的线程"]');
      if (!(list instanceof HTMLElement)) {
        return { ok: false, error: 'Codex 当前没有可见的置顶线程列表' };
      }
      const items = Array.from(list.querySelectorAll('[role="listitem"]'));
      const match = items.find((item) => normalize(item.textContent || '') === targetLabel);
      if (!(match instanceof HTMLElement)) {
        return { ok: false, error: '未找到指定的 Codex 置顶线程' };
      }
      const outer = match.querySelector('[role="button"]');
      const inner = outer?.firstElementChild;
      const clickable = inner instanceof HTMLElement
        ? inner
        : (outer instanceof HTMLElement ? outer : (match.firstElementChild || match));
      if (!(clickable instanceof HTMLElement)) {
        return { ok: false, error: '指定线程没有可点击节点' };
      }
      clickable.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, cancelable: true, view: window }));
      clickable.dispatchEvent(new MouseEvent('mouseup', { bubbles: true, cancelable: true, view: window }));
      clickable.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
      return { ok: true, label: targetLabel };
    })()
  `));

  if (result?.ok) {
    await delay(250);
  }
  return result;
}

const CLIPBOARD_OSASCRIPT = [
  'on run argv',
  'set the clipboard to item 1 of argv',
  'return "已复制到系统剪贴板，可在任意应用中直接粘贴使用。"',
  'end run',
];

function extractJsonPayload(stdout) {
  const text = String(stdout || '').trim();
  if (!text) {
    throw new Error('empty gateway output');
  }
  const objectStart = text.indexOf('{');
  const arrayStart = text.indexOf('[');
  const starts = [objectStart, arrayStart].filter((index) => index >= 0);
  if (starts.length === 0) {
    throw new Error(text);
  }
  const start = Math.min(...starts);
  return JSON.parse(text.slice(start));
}

async function callOpenClawGateway(method, params = {}, timeout = 10000) {
  const { stdout } = await execFileAsync(
    'openclaw',
    ['gateway', 'call', method, '--json', '--timeout', String(timeout), '--params', JSON.stringify(params)],
    { timeout: timeout + 2000 },
  );
  return extractJsonPayload(stdout);
}

function shellQuote(value) {
  return JSON.stringify(String(value ?? ''));
}

function json(res, status, payload) {
  res.writeHead(status, { 'content-type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(payload, null, 2));
}

function appendSendAudit(event, details = {}) {
  const line = JSON.stringify({
    at: new Date().toISOString(),
    event,
    ...details,
  });
  fs.appendFileSync(SEND_AUDIT_LOG, `${line}\n`);
}

function describeCodexBusyState(codexUi) {
  const hasQueue = Boolean(codexUi?.hasQueuedMessages);
  const isRunning = Boolean(codexUi?.hasStopButton || codexUi?.hasRunningTasks);

  if (hasQueue && isRunning) {
    return 'Codex 当前正在运行，且已有排队消息。为避免重复发送，本次发送已拦截，请等当前生成完成并清掉排队消息后再发。';
  }

  if (hasQueue) {
    return 'Codex 当前已有排队消息。为避免重复发送，本次发送已拦截，请先清掉排队消息后再发。';
  }

  if (isRunning) {
    return 'Codex 当前正在运行。为避免重复发送，本次发送已拦截，请等当前生成完成后再发。';
  }

  return 'Codex 当前不可发送，请稍后再试。';
}

const SEND_TARGETS = {
  codex: {
    id: 'codex',
    label: 'Codex',
    sendCommand: (text, options = {}) => {
      const prefix = options.windowTitle
        ? `OPENCLI_CDP_TARGET=${shellQuote(options.windowTitle)} `
        : '';
      return `${prefix}OPENCLI_CDP_ENDPOINT=${CODEX_CDP_ENDPOINT} opencli codex send ${shellQuote(text)}`;
    },
    getBusyState: getCodexUiState,
    describeBusyState: describeCodexBusyState,
  },
  antigravity: {
    id: 'antigravity',
    label: 'AntiGravity',
    sendCommand: (text, options = {}) => {
      const prefix = options.windowTitle
        ? `OPENCLI_CDP_TARGET=${shellQuote(options.windowTitle)} `
        : '';
      return `${prefix}OPENCLI_CDP_ENDPOINT=${ANTIGRAVITY_CDP_ENDPOINT} opencli antigravity send ${shellQuote(text)}`;
    },
  },
  'google-chrome': {
    id: 'google-chrome',
    label: 'Google Chrome',
    sendCommand: () => '',
  },
  clipboard: {
    id: 'clipboard',
    label: '剪贴板',
    sendCommand: () => '',
  },
  webchat: {
    id: 'webchat',
    label: 'OpenClaw Web Chat',
    sendCommand: () => '',
  },
};

function readJsonBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', (chunk) => (body += chunk));
    req.on('end', () => {
      try {
        resolve(JSON.parse(body || '{}'));
      } catch (error) {
        reject(error);
      }
    });
    req.on('error', reject);
  });
}

function ensureTokenSession(sessionId) {
  return tokenSessions.get(sessionId) || {
    id: randomUUID(),
    sessionId,
    chunks: [],
    mergedText: '',
    updatedAt: null,
    lastInputSource: 'text',
  };
}

function appendTokenSessionChunk(sessionId, text, source = 'text') {
  const trimmed = String(text || '').trim();
  const existing = ensureTokenSession(sessionId);
  if (!trimmed) return existing;

  existing.chunks.push(trimmed);
  existing.mergedText = existing.chunks.join('\n\n');
  existing.updatedAt = new Date().toISOString();
  existing.lastInputSource = source;
  tokenSessions.set(sessionId, existing);
  return existing;
}

function clearTokenSession(sessionId) {
  if (!sessionId) return null;
  const existing = tokenSessions.get(sessionId) || null;
  tokenSessions.delete(sessionId);
  return existing;
}

function getMostRecentTokenSession() {
  const sessions = Array.from(tokenSessions.values())
    .filter((session) => session && session.updatedAt)
    .sort((left, right) => String(right.updatedAt).localeCompare(String(left.updatedAt)));
  return sessions[0] || null;
}

async function detectApps() {
  const apps = ['Codex.app', 'Antigravity.app', 'Google Chrome.app', 'Safari.app', 'Telegram.app', 'WeChat.app'];
  const baseDirs = ['/Applications', '/System/Applications'];
  return apps.map((name) => {
    const found = baseDirs.some((base) => fs.existsSync(path.join(base, name)));
    return { name: name.replace(/\.app$/, ''), installed: found };
  });
}

async function getCodexStatus() {
  try {
    const { stdout } = await execFileAsync('sh', ['-lc', CODEX_CDP_STATUS_COMMAND], { timeout: 5000 });
    return { connected: /connected/i.test(stdout), raw: stdout.trim() };
  } catch (error) {
    return { connected: false, raw: error.stderr?.trim() || error.message };
  }
}

async function getAntigravityStatus() {
  try {
    const { stdout } = await execFileAsync('sh', ['-lc', ANTIGRAVITY_CDP_STATUS_COMMAND], { timeout: 5000 });
    return { connected: /connected/i.test(stdout), raw: stdout.trim() };
  } catch (error) {
    return { connected: false, raw: error.stderr?.trim() || error.message };
  }
}

async function getChromeStatus() {
  try {
    const status = await checkDaemonStatus();
    return {
      connected: Boolean(status.running && status.extensionConnected),
      running: Boolean(status.running),
      extensionConnected: Boolean(status.extensionConnected),
      raw: status.running
        ? (status.extensionConnected ? 'opencli browser bridge connected' : 'opencli daemon running, extension not connected')
        : 'opencli daemon not running',
    };
  } catch (error) {
    return {
      connected: false,
      running: false,
      extensionConnected: false,
      raw: error.message,
    };
  }
}

async function listInspectableWindows(endpoint, targetId) {
  try {
    const response = await fetch(`${endpoint}/json`);
    if (!response.ok) {
      return [];
    }
    const payload = await response.json();
    if (!Array.isArray(payload)) {
      return [];
    }

    return payload
      .filter((item) => item && item.webSocketDebuggerUrl)
      .filter((item) => ['page', 'app', 'webview'].includes(String(item.type || '').toLowerCase()))
      .filter((item) => {
        const haystack = `${String(item.title || '').toLowerCase()} ${String(item.url || '').toLowerCase()}`;
        return !haystack.includes('devtools');
      })
      .map((item, index) => {
        const title = String(item.title || '').trim() || `${targetId} window ${index + 1}`;
        const subtitle = String(item.url || '').trim();
        return {
          id: `${targetId}:${index}:${title}`,
          label: title,
          title,
          subtitle: subtitle || null,
          type: String(item.type || ''),
        };
      });
  } catch {
    return [];
  }
}

async function listChromeWindows() {
  const status = await getChromeStatus();
  if (!status.connected) {
    return [];
  }
  try {
    const tabs = await sendBrowserCommand('tabs', {
      op: 'list',
      workspace: 'vibe-hub:chrome',
    });
    if (!Array.isArray(tabs)) {
      return [];
    }
    return tabs.map((tab, index) => {
      const title = String(tab?.title || tab?.identity || `Chrome 标签 ${index + 1}`).trim();
      const url = String(tab?.url || '').trim();
      return {
        id: `chrome:${tab?.id ?? index}`,
        label: title,
        title,
        subtitle: url || null,
        type: 'tab',
      };
    });
  } catch {
    return [];
  }
}

async function listCodexWindows() {
  const threadWindows = await listCodexPinnedThreads();
  if (threadWindows.length > 0) {
    return threadWindows;
  }
  return listInspectableWindows(CODEX_CDP_ENDPOINT, 'codex');
}

function buildWebchatWindowLabel(sessionKey, rawLabel) {
  const normalizedRaw = String(rawLabel || '').trim();
  if (normalizedRaw && !normalizedRaw.toLowerCase().startsWith('webchat:')) {
    return normalizedRaw;
  }

  const parts = String(sessionKey || '').split(':');
  if (parts.length >= 3 && parts[0] === 'agent') {
    const agentId = parts[1] || 'agent';
    const tail = parts.slice(2).join(':');
    if (tail === 'main') return agentId;
    return `${agentId} / ${tail}`;
  }

  return String(sessionKey || '').trim() || 'webchat session';
}

function isPrimaryWebchatSessionKey(sessionKey) {
  return /^agent:[^:]+:main$/.test(String(sessionKey || '').trim());
}

function isMainWechatSession(entry) {
  const sessionKey = String(entry?.key || '').trim();
  const loweredSessionKey = sessionKey.toLowerCase();
  const provider = String(entry?.origin?.provider || '').trim().toLowerCase();
  const deliveryChannel = String(entry?.deliveryContext?.channel || '').trim().toLowerCase();
  const lastChannel = String(entry?.lastChannel || '').trim().toLowerCase();
  const displayName = String(entry?.displayName || '').trim().toLowerCase();
  return (
    sessionKey.startsWith('agent:main:')
    && (
      loweredSessionKey.includes('weixin')
      || provider.includes('weixin')
      || deliveryChannel.includes('weixin')
      || lastChannel.includes('weixin')
      || displayName.includes('weixin')
    )
  );
}

async function listWebchatSessions() {
  const now = Date.now();
  if (
    Array.isArray(targetWindowCache.webchat)
    && targetWindowCache.webchat.length > 0
    && now - webchatWindowsLastLoadedAt < WEBCHAT_WINDOWS_TTL_MS
  ) {
    return targetWindowCache.webchat;
  }

  if (webchatWindowsInFlight) {
    return webchatWindowsInFlight;
  }

  webchatWindowsInFlight = (async () => {
    try {
      const payload = await callOpenClawGateway('sessions.list', {
        includeGlobal: true,
        includeUnknown: true,
        limit: 300,
      }, 15000);
      const sessions = Array.isArray(payload?.sessions) ? payload.sessions : [];
      const mainWindows = sessions
        .map((entry) => {
          const sessionKey = String(entry?.key || '').trim();
          if (!sessionKey) return null;
          if (!isPrimaryWebchatSessionKey(sessionKey)) return null;
          const label = buildWebchatWindowLabel(sessionKey, entry?.displayName || entry?.label);
          const updatedAt = entry?.updatedAt ? new Date(Number(entry.updatedAt)).toISOString() : null;
          return {
            id: `webchat:${sessionKey}`,
            label,
            title: sessionKey,
            subtitle: updatedAt ? `${sessionKey} · ${updatedAt}` : sessionKey,
            type: 'session',
            updatedAtValue: Number(entry?.updatedAt || 0),
          };
        })
        .filter(Boolean)
        .sort((left, right) => Number(right.updatedAtValue || 0) - Number(left.updatedAtValue || 0))
        .slice(0, 6)
        .map(({ updatedAtValue, ...window }) => window);

      const latestWechatWindow = sessions
        .filter((entry) => isMainWechatSession(entry))
        .map((entry) => {
          const sessionKey = String(entry?.key || '').trim();
          if (!sessionKey) return null;
          const rawName = String(entry?.displayName || entry?.origin?.label || entry?.label || '').trim();
          const normalizedRawName = !rawName || rawName.toLowerCase() === 'heartbeat'
            ? '微信'
            : rawName;
          const updatedAt = entry?.updatedAt ? new Date(Number(entry.updatedAt)).toISOString() : null;
          return {
            id: `webchat:${sessionKey}`,
            label: normalizedRawName.startsWith('微信') ? normalizedRawName : `微信 · ${normalizedRawName}`,
            title: sessionKey,
            subtitle: updatedAt ? `${sessionKey} · ${updatedAt}` : sessionKey,
            type: 'session',
            updatedAtValue: Number(entry?.updatedAt || 0),
          };
        })
        .filter(Boolean)
        .sort((left, right) => Number(right.updatedAtValue || 0) - Number(left.updatedAtValue || 0))[0] || null;

      const wechatEntries = latestWechatWindow
        ? [{ ...(() => {
            const { updatedAtValue, ...window } = latestWechatWindow;
            return window;
          })() }]
        : [];

      const windows = [...mainWindows, ...wechatEntries]
        .filter((entry, index, all) => all.findIndex((candidate) => candidate.id === entry.id) === index);
      if (windows.length > 0) {
        targetWindowCache.webchat = windows;
        webchatWindowsLastLoadedAt = Date.now();
      }
      return windows.length > 0 ? windows : (Array.isArray(targetWindowCache.webchat) ? targetWindowCache.webchat : []);
    } catch {
      return Array.isArray(targetWindowCache.webchat) ? targetWindowCache.webchat : [];
    } finally {
      webchatWindowsInFlight = null;
    }
  })();

  return webchatWindowsInFlight;
}

function resolveDefaultWebchatWindow(windows) {
  if (!Array.isArray(windows) || windows.length === 0) return null;
  return (
    windows.find((window) => window.title === 'agent:main:main')
    || windows.find((window) => window.title === 'agent:main:onboarding')
    || windows[0]
    || null
  );
}

async function launchChromeBridge() {
  const initial = await getChromeStatus();
  if (initial.connected) {
    return {
      ok: true,
      target: 'Google Chrome',
      command: `node ${OPENCLI_DAEMON_PATH}`,
      output: initial.raw,
    };
  }

  if (!initial.running) {
    const launchCommand = `nohup node ${shellQuote(OPENCLI_DAEMON_PATH)} >${shellQuote(CHROME_CONNECT_LOG)} 2>&1 < /dev/null &`;
    await execFileAsync('sh', ['-lc', launchCommand], { timeout: 5000 });
  }

  const deadline = Date.now() + 10000;
  let lastStatus = initial;
  while (Date.now() < deadline) {
    lastStatus = await getChromeStatus();
    if (lastStatus.connected) {
      return {
        ok: true,
        target: 'Google Chrome',
        command: `node ${OPENCLI_DAEMON_PATH}`,
        output: lastStatus.raw,
      };
    }
    if (lastStatus.running) {
      break;
    }
    await delay(500);
  }

  return {
    ok: false,
    target: 'Google Chrome',
    command: `node ${OPENCLI_DAEMON_PATH}`,
    error: lastStatus.running
      ? 'opencli daemon 已启动，但 Chrome Browser Bridge extension 尚未连接。请在 Chrome 中安装并启用 opencli Browser Bridge 扩展。'
      : `未能启动 opencli daemon。${lastStatus.raw || ''}`.trim(),
  };
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function isCodexDebugPortReady() {
  try {
    const response = await fetch(`${CODEX_CDP_ENDPOINT}/json/version`);
    if (!response.ok) {
      return { ok: false, error: `HTTP ${response.status}` };
    }
    const payload = await response.json();
    return { ok: true, payload };
  } catch (error) {
    return { ok: false, error: error.message };
  }
}

async function isAntigravityDebugPortReady() {
  try {
    const response = await fetch(`${ANTIGRAVITY_CDP_ENDPOINT}/json/version`);
    if (!response.ok) {
      return { ok: false, error: `HTTP ${response.status}` };
    }
    const payload = await response.json();
    return { ok: true, payload };
  } catch (error) {
    return { ok: false, error: error.message };
  }
}

async function launchControllableCodex() {
  const debugStatus = await isCodexDebugPortReady();
  if (!debugStatus.ok) {
    const launchCommand = `nohup ${JSON.stringify(CODEX_BINARY)} --remote-debugging-port=9333 >${JSON.stringify(CODEX_CONNECT_LOG)} 2>&1 &`;
    await execFileAsync('sh', ['-lc', launchCommand], { timeout: 5000 });
  }

  try {
    await execFileAsync('osascript', ['-e', 'tell application "Codex" to activate'], { timeout: 5000 });
  } catch {
    // The controlled instance may still be starting; activation is best-effort.
  }

  const deadline = Date.now() + 15000;
  let lastError = '';

  while (Date.now() < deadline) {
    const codex = await getCodexStatus();
    if (codex.connected) {
      return {
        ok: true,
        target: 'Codex',
        command: `${CODEX_BINARY} --remote-debugging-port=9333`,
        output: codex.raw,
      };
    }

    const debugPort = await isCodexDebugPortReady();
    lastError = codex.raw || debugPort.error || 'Codex debug port not ready';
    await delay(500);
  }

  return {
    ok: false,
    target: 'Codex',
    command: `${CODEX_BINARY} --remote-debugging-port=9333`,
    error: `未能在 15 秒内拉起可控 Codex。${lastError}`.trim(),
  };
}

async function launchControllableAntigravity() {
  try {
    await execFileAsync('osascript', ['-e', 'tell application "Antigravity" to quit'], { timeout: 5000 });
  } catch {
    // Best-effort only.
  }
  await delay(1500);

  const launchCommand = `nohup ${JSON.stringify(ANTIGRAVITY_BINARY)} --remote-debugging-port=9224 >${JSON.stringify(ANTIGRAVITY_CONNECT_LOG)} 2>&1 &`;
  await execFileAsync('sh', ['-lc', launchCommand], { timeout: 5000 });

  try {
    await execFileAsync('osascript', ['-e', 'tell application "Antigravity" to activate'], { timeout: 5000 });
  } catch {
    // Best-effort only.
  }

  const deadline = Date.now() + 15000;
  let lastError = '';

  while (Date.now() < deadline) {
    const antigravity = await getAntigravityStatus();
    if (antigravity.connected) {
      return {
        ok: true,
        target: 'Antigravity',
        command: `${ANTIGRAVITY_BINARY} --remote-debugging-port=9224`,
        output: antigravity.raw,
      };
    }

    const debugPort = await isAntigravityDebugPortReady();
    lastError = antigravity.raw || debugPort.error || 'Antigravity debug port not ready';
    await delay(500);
  }

  return {
    ok: false,
    target: 'Antigravity',
    command: `${ANTIGRAVITY_BINARY} --remote-debugging-port=9224`,
    error: `未能在 15 秒内拉起可控 AntiGravity。${lastError}`.trim(),
  };
}

async function getCodexUiState() {
  try {
    process.env.OPENCLI_CDP_ENDPOINT = CODEX_CDP_ENDPOINT;
    const bridge = new CDPBridge();
    const page = await bridge.connect({ timeout: 5 });
    const state = await page.evaluate(`
      (() => {
        function isVisible(node) {
          if (!(node instanceof HTMLElement)) return false;
          const rect = node.getBoundingClientRect();
          const style = window.getComputedStyle(node);
          return rect.width > 0 && rect.height > 0 && style.visibility !== 'hidden' && style.display !== 'none';
        }

        const footer = document.querySelector('.composer-footer');
        if (!(footer instanceof HTMLElement) || !isVisible(footer)) {
          return {
            busy: false,
            hasQueuedMessages: false,
            hasStopButton: false,
            hasRunningTasks: false,
            reason: 'composer-footer-not-visible',
          };
        }

        const hasQueuedMessages = Array.from(footer.querySelectorAll('button[aria-label="删除排队的消息"]'))
          .some(isVisible);
        const hasStopButton = Array.from(footer.querySelectorAll('button[aria-label="停止"]'))
          .some(isVisible);
        const footerText = footer.textContent || '';
        const hasRunningTasks = /正在运行\\s*\\d+\\s*个终端/.test(footerText);

        return {
          busy: hasQueuedMessages || hasStopButton || hasRunningTasks,
          hasQueuedMessages,
          hasStopButton,
          hasRunningTasks,
        };
      })()
    `);
    await bridge.close();

    return state;
  } catch (error) {
    return {
      busy: false,
      hasQueuedMessages: false,
      hasStopButton: false,
      hasRunningTasks: false,
      error: error.stderr?.trim() || error.message,
    };
  }
}

function buildInputSources() {
  const sources = [
    { id: 'wechat', label: '微信', connected: true, current: true },
    { id: 'webchat', label: 'OpenClaw Web Chat', connected: true, current: false },
  ];
  if (tokenSessions.has('current-webchat')) {
    return sources.map((source) =>
      source.id === 'webchat'
        ? { ...source, current: true }
        : source
    );
  }
  return sources;
}

function buildAgentConnections(codex) {
  const agents = [];
  if (codex.connected) {
    agents.push({ id: 'codex', label: 'Agent: Codex', connected: true });
  }
  return agents;
}

function buildOutputTerminals(apps, codex, antigravity, targetWindows) {
  const installed = new Map(apps.filter((app) => app.installed).map((app) => [app.name, app]));
  const rows = [];

  rows.push({
    id: 'clipboard',
    label: '剪贴板',
    status: '已连接',
    connectAction: null,
    windows: [],
  });

  // 可连接 = 本机上属于 opencli 支持范围内的程序总数
  if (installed.has('Codex')) {
    rows.push({
      id: 'codex',
      label: 'Codex',
      status: codex.connected ? '已连接' : '可连接',
      connectAction: codex.connected ? null : '/connect/codex',
      windows: targetWindows.codex ?? [],
    });
  }

  if (installed.has('Antigravity')) {
    rows.push({
      id: 'antigravity',
      label: 'AntiGravity',
      status: antigravity.connected ? '已连接' : '可连接',
      connectAction: antigravity.connected ? null : '/connect/antigravity',
      windows: targetWindows.antigravity ?? [],
    });
  }

  const webchatWindows = Array.isArray(targetWindows.webchat) && targetWindows.webchat.length > 0
    ? targetWindows.webchat
    : [
        {
          id: 'webchat:agent:main:main',
          label: 'main',
          title: 'agent:main:main',
          subtitle: 'webchat session',
          type: 'session',
        },
      ];

  rows.push({
    id: 'webchat',
    label: 'OpenClaw Web Chat',
    status: '已连接',
    connectAction: null,
    windows: webchatWindows,
  });
  return rows;
}

function buildOutputWebsites(apps, chrome, targetWindows) {
  const installed = new Map(apps.filter((app) => app.installed).map((app) => [app.name, app]));
  const rows = [];

  if (installed.has('Google Chrome')) {
    rows.push({
      id: 'google-chrome',
      label: 'Google Chrome',
      status: chrome.connected ? '扩展已连接' : '可连接',
      connectAction: chrome.connected ? null : '/connect/chrome',
      windows: targetWindows.chrome ?? [],
    });
  }

  return rows;
}

async function sendToTarget(targetId, payload) {
  const target = SEND_TARGETS[targetId];
  if (!target) {
    return {
      status: 400,
      body: { ok: false, error: `unsupported target: ${targetId}` },
    };
  }

  const text = String(payload.text || '').trim();
  const source = String(payload.source || 'unknown').trim() || 'unknown';
  const windowTitle = String(payload.windowTitle || '').trim();
  if (!text) {
    return {
      status: 400,
      body: { ok: false, error: 'text is required' },
    };
  }

  const now = Date.now();
  const lastSend = lastTargetSends.get(targetId) || null;
  appendSendAudit('request', { target: target.label, text, source });

  if (targetId === 'clipboard') {
    try {
      const { stdout } = await execFileAsync(
        'osascript',
        CLIPBOARD_OSASCRIPT.flatMap((line) => ['-e', line]).concat(['--', text]),
        { timeout: 5000 },
      );
      lastTargetSends.set(targetId, { text, at: now });
      appendSendAudit('success', { target: target.label, text, source });
      return {
        status: 200,
        body: {
          ok: true,
          target: target.label,
          command: 'osascript(set clipboard)',
          output: stdout.trim() || '已复制到系统剪贴板',
        },
      };
    } catch (error) {
      appendSendAudit('error', {
        target: target.label,
        text,
        source,
        error: error.stderr?.trim() || error.message,
      });
      return {
        status: 502,
        body: {
          ok: false,
          target: target.label,
          error: error.stderr?.trim() || error.message,
        },
      };
    }
  }

  if (targetId === 'webchat') {
    try {
      const windows = await listWebchatSessions();
      const fallbackWindow = resolveDefaultWebchatWindow(windows);
      const sessionKey = String(
        payload.windowTitle
          || payload.sessionKey
          || fallbackWindow?.title
          || 'agent:main:main'
      ).trim();
      const idempotencyKey = randomUUID();
      const gatewayResult = await callOpenClawGateway('agent', {
        message: text,
        sessionKey,
        channel: 'webchat',
        deliver: false,
        idempotencyKey,
      }, 10000);
      const tokenSession = appendTokenSessionChunk(sessionKey, text, 'vibe-hub-send');
      lastTargetSends.set(targetId, { text, at: now });
      appendSendAudit('success', {
        target: target.label,
        text,
        source,
        sessionKey,
        runId: gatewayResult?.runId || null,
      });
      return {
        status: 200,
        body: {
          ok: true,
          target: target.label,
          output: '已写入 OpenClaw Web Chat 真实会话',
          sessionId: sessionKey,
          runId: gatewayResult?.runId || null,
          gatewayStatus: gatewayResult?.status || null,
          tokenSession,
        },
      };
    } catch (error) {
      appendSendAudit('error', {
        target: target.label,
        text,
        source,
        error: error.stderr?.trim() || error.message,
      });
      return {
        status: 502,
        body: {
          ok: false,
          target: target.label,
          error: error.stderr?.trim() || error.message,
        },
      };
    }
  }

  if (targetId === 'google-chrome') {
    const chrome = await getChromeStatus();
    const windows = await listChromeWindows();
    return {
      status: 409,
      body: {
        ok: false,
        target: target.label,
        error: chrome.connected
          ? (windows.length > 0
              ? 'Google Chrome 已连接，但 Vibe Hub 的页面级发送链路还未完成。当前不能把内容正式注入选中页面。'
              : 'Google Chrome 扩展已连接，但当前没有可用页面会话。请先建立 Chrome 页面会话后再发送。')
          : 'Google Chrome 尚未连接。请先在状态面板中完成 Chrome 连接。',
      },
    };
  }

  if (lastSend && lastSend.text === text && now - lastSend.at < 3000) {
    appendSendAudit('blocked_duplicate_guard', { target: target.label, text, source, lastSend });
    return {
      status: 409,
      body: {
        ok: false,
        target: target.label,
        error: '检测到 3 秒内同内容重复发送，bridge 已拦截本次请求。',
        duplicateGuard: true,
        lastSend,
      },
    };
  }

  let targetUi = null;
  if (typeof target.getBusyState === 'function') {
    targetUi = await target.getBusyState();
    if (targetUi?.busy) {
      appendSendAudit('blocked_busy', { target: target.label, text, source, targetUi });
      return {
        status: 409,
        body: {
          ok: false,
          target: target.label,
          error: target.describeBusyState ? target.describeBusyState(targetUi) : `${target.label} 当前不可发送`,
          targetUi,
        },
      };
    }
  }

  const command = target.sendCommand(text, {
    windowTitle: windowTitle || undefined,
  });
  try {
    const { stdout } = await execFileAsync('sh', ['-lc', command], { timeout: 10000 });
    lastTargetSends.set(targetId, { text, at: now });
    appendSendAudit('success', { target: target.label, text, source, command, windowTitle });
    return {
      status: 200,
      body: {
        ok: true,
        target: target.label,
        command,
        output: stdout.trim(),
        targetUi,
      },
    };
  } catch (error) {
    appendSendAudit('error', { target: target.label, text, source, command, error: error.stderr?.trim() || error.message });
    return {
      status: 502,
      body: {
        ok: false,
        target: target.label,
        command,
        error: error.stderr?.trim() || error.message,
      },
    };
  }
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);

  if (req.method === 'GET' && url.pathname === '/health') {
    return json(res, 200, { ok: true, service: 'vibe-hub-bridge', host: HOST, port: PORT });
  }

  if (req.method === 'GET' && url.pathname === '/status') {
    const [apps, codex, antigravity, chrome, codexUi, webchatWindows] = await Promise.all([
      detectApps(),
      getCodexStatus(),
      getAntigravityStatus(),
      getChromeStatus(),
      getCodexUiState(),
      listWebchatSessions(),
    ]);
    const targetWindows = {
      codex: codex.connected ? await listCodexWindows() : [],
      antigravity: antigravity.connected ? await listInspectableWindows(ANTIGRAVITY_CDP_ENDPOINT, 'antigravity') : [],
      chrome: chrome.connected ? await listChromeWindows() : [],
      webchat: webchatWindows,
    };
    const inputSources = buildInputSources();
    const agentConnections = buildAgentConnections(codex);
    const outputTerminals = buildOutputTerminals(apps, codex, antigravity, targetWindows);
    const outputWebsites = buildOutputWebsites(apps, chrome, targetWindows);
    const activeTokenSession = getMostRecentTokenSession();
    const llm = getResolvedLlmSettings();
    return json(res, 200, {
      ok: true,
      inputTerminal: '微信',
      currentTarget: 'Codex',
      activeTokenSessionId: activeTokenSession?.sessionId ?? null,
      activeTokenSessionUpdatedAt: activeTokenSession?.updatedAt ?? null,
      v6Page: path.join(V6_DIR, 'index.html'),
      localTutorialUrl: `file://${path.join(V6_DIR, 'opencli-supported-targets.html')}`,
      apps,
      codex,
      antigravity,
      chrome,
      codexUi,
      inputSources,
      agentConnections,
      outputTerminals,
      outputWebsites,
      llm,
      os: { platform: os.platform(), release: os.release(), hostname: os.hostname() },
    });
  }

  if (req.method === 'GET' && url.pathname === '/llm/settings') {
    return json(res, 200, {
      ok: true,
      llm: getResolvedLlmSettings(),
    });
  }

  if (req.method === 'POST' && url.pathname === '/llm/settings') {
    readJsonBody(req)
      .then(async (payload) => {
        const { saveLlmSettings } = await import('./llmSettings.js');
        const llm = saveLlmSettings(payload);
        return json(res, 200, { ok: true, llm });
      })
      .catch((error) => json(res, 400, { ok: false, error: error.message }));
    return;
  }

  if (req.method === 'POST' && url.pathname === '/llm/rewrite') {
    readJsonBody(req)
      .then(async (payload) => {
        const result = await rewriteDraft({
          rawInput: payload.rawInput,
          draftText: payload.draftText,
          target: payload.target,
        });
        return json(res, 200, result);
      })
      .catch((error) => json(res, 400, { ok: false, error: error.message }));
    return;
  }

  if (req.method === 'POST' && url.pathname === '/llm/compress') {
    readJsonBody(req)
      .then(async (payload) => {
        const result = await compressDraft({
          draftText: payload.draftText,
          target: payload.target,
        });
        return json(res, 200, result);
      })
      .catch((error) => json(res, 400, { ok: false, error: error.message }));
    return;
  }

  if (req.method === 'POST' && url.pathname === '/route') {
    readJsonBody(req)
      .then((payload) => {
        const sessionId = String(payload.sessionId || 'current-webchat');
        const route = evaluateRoute(payload.text, {
          hasActiveTokenSession: tokenSessions.has(sessionId),
        });
        const existing = route.shouldStoreInTokenSession
          ? appendTokenSessionChunk(sessionId, payload.text, 'text')
          : null;

        return json(res, 200, {
          ok: true,
          policyVersion: 'v9-1',
          mode: route.mode,
          decision: route.decision,
          reason: route.reason,
          triggers: route.triggers,
          clarificationPrompt: route.clarificationPrompt ?? null,
          tokenSession: existing,
        });
      })
      .catch((error) => json(res, 400, { ok: false, error: error.message }));
    return;
  }

  if (req.method === 'POST' && url.pathname === '/voice/input') {
    readJsonBody(req)
      .then((payload) => {
        const sessionId = String(payload.sessionId || 'current-webchat');
        const text = String(payload.text || payload.transcript || '').trim();
        const source = String(payload.source || 'press-to-talk');
        if (!text) {
          return json(res, 400, { ok: false, error: 'text is required' });
        }

        const tokenSession = appendTokenSessionChunk(sessionId, text, source);
        return json(res, 200, {
          ok: true,
          message: '语音已转写并并入 Vibe Hub 原始输入，建议整理后再发送。',
          suggestedAction: 'rewrite',
          voiceInput: {
            text,
            source,
            recordedAt: new Date().toISOString(),
          },
          tokenSession,
        });
      })
      .catch((error) => json(res, 400, { ok: false, error: error.message }));
    return;
  }

  if (req.method === 'GET' && url.pathname === '/token-session') {
    const requestedSessionId = url.searchParams.get('sessionId');
    const fallbackSession = getMostRecentTokenSession();
    const sessionId = requestedSessionId || fallbackSession?.sessionId || 'current-webchat';
    const tokenSession = tokenSessions.get(sessionId) || fallbackSession || null;
    return json(res, 200, { ok: true, tokenSession });
  }

  if (req.method === 'POST' && url.pathname === '/token-session/clear') {
    readJsonBody(req)
      .then((payload) => {
        const requestedSessionId = String(payload.sessionId || '').trim();
        const fallbackSession = getMostRecentTokenSession();
        const sessionId = requestedSessionId || fallbackSession?.sessionId || '';
        const cleared = clearTokenSession(sessionId);
        return json(res, 200, {
          ok: true,
          clearedSessionId: sessionId || null,
          cleared: Boolean(cleared),
        });
      })
      .catch((error) => json(res, 400, { ok: false, error: error.message }));
    return;
  }

  if (req.method === 'POST' && url.pathname === '/connect/codex') {
    try {
      const result = await launchControllableCodex();
      if (result.ok) {
        return json(res, 200, result);
      }
      return json(res, 502, result);
    } catch (error) {
      return json(res, 502, {
        ok: false,
        target: 'Codex',
        command: `${CODEX_BINARY} --remote-debugging-port=9333`,
        error: error.stderr?.trim() || error.message,
      });
    }
  }

  if (req.method === 'POST' && url.pathname === '/connect/antigravity') {
    try {
      const result = await launchControllableAntigravity();
      if (result.ok) {
        return json(res, 200, result);
      }
      return json(res, 502, result);
    } catch (error) {
      return json(res, 502, {
        ok: false,
        target: 'Antigravity',
        command: `${ANTIGRAVITY_BINARY} --remote-debugging-port=9224`,
        error: error.stderr?.trim() || error.message,
      });
    }
  }

  if (req.method === 'POST' && url.pathname === '/connect/chrome') {
    try {
      const result = await launchChromeBridge();
      if (result.ok) {
        return json(res, 200, result);
      }
      return json(res, 502, result);
    } catch (error) {
      return json(res, 502, {
        ok: false,
        target: 'Google Chrome',
        command: `node ${OPENCLI_DAEMON_PATH}`,
        error: error.stderr?.trim() || error.message,
      });
    }
  }

  if (req.method === 'POST' && url.pathname === '/send/codex') {
    readJsonBody(req)
      .then(async (payload) => {
        try {
          const result = await sendToTarget('codex', payload);
          return json(res, result.status, result.body);
        } catch (error) {
          return json(res, 400, { ok: false, error: error.message });
        }
      })
      .catch((error) => json(res, 400, { ok: false, error: error.message }));
    return;
  }

  if (req.method === 'POST' && url.pathname === '/send/antigravity') {
    readJsonBody(req)
      .then(async (payload) => {
        try {
          const result = await sendToTarget('antigravity', payload);
          return json(res, result.status, result.body);
        } catch (error) {
          return json(res, 400, { ok: false, error: error.message });
        }
      })
      .catch((error) => json(res, 400, { ok: false, error: error.message }));
    return;
  }

  if (req.method === 'POST' && url.pathname === '/target-window/select') {
    readJsonBody(req)
      .then(async (payload) => {
        try {
          const target = String(payload.target || '').trim().toLowerCase();
          const windowTitle = String(payload.windowTitle || '').trim();
          if (target === 'codex') {
            const threadLabel = decodeCodexThreadWindowTitle(windowTitle);
            if (threadLabel) {
              const result = await switchCodexPinnedThread(threadLabel);
              return json(res, result?.ok ? 200 : 502, {
                ok: Boolean(result?.ok),
                target: 'Codex',
                windowTitle,
                error: result?.ok ? null : (result?.error || 'Codex 线程切换失败'),
              });
            }
          }
          return json(res, 200, { ok: true, target, windowTitle });
        } catch (error) {
          return json(res, 400, { ok: false, error: error.message });
        }
      })
      .catch((error) => json(res, 400, { ok: false, error: error.message }));
    return;
  }

  if (req.method === 'POST' && url.pathname === '/send') {
    readJsonBody(req)
      .then(async (payload) => {
        try {
          const requestedTarget = String(payload.target || '').trim().toLowerCase();
          const resolvedTarget = requestedTarget === 'antigravity'
            ? 'antigravity'
            : requestedTarget === 'google-chrome' || requestedTarget === 'chrome'
              ? 'google-chrome'
              : requestedTarget === 'clipboard'
                  ? 'clipboard'
              : requestedTarget === 'webchat' || requestedTarget === 'openclaw-web-chat' || requestedTarget === 'openclaw-webchat'
                ? 'webchat'
              : 'codex';
          const result = await sendToTarget(resolvedTarget, payload);
          return json(res, result.status, result.body);
        } catch (error) {
          return json(res, 400, { ok: false, error: error.message });
        }
      })
      .catch((error) => json(res, 400, { ok: false, error: error.message }));
    return;
  }

  return json(res, 404, { ok: false, error: 'not found' });
});

server.listen(PORT, HOST, () => {
  console.log(`[vibe-hub-bridge] listening on http://${HOST}:${PORT}`);
});
