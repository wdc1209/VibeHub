#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { getResolvedLlmSettings, writeDefaultLlmSettingsIfNeeded, LLM_CONFIG_PATH } from './llmSettings.js';

const execFileAsync = promisify(execFile);
const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..', '..');
const BRIDGE_DIR = path.join(ROOT, 'bridge');
const CONFIG_DIR = path.join(ROOT, '.vibe-hub');
const CONFIG_PATH = path.join(CONFIG_DIR, 'bridge.json');
const PORT = Number(process.env.VIBE_HUB_PORT || process.env.TOKEN_CARD_PORT || 4765);

const command = process.argv[2] || 'help';

function print(obj) {
  process.stdout.write(`${typeof obj === 'string' ? obj : JSON.stringify(obj, null, 2)}\n`);
}

async function doctor() {
  const checks = [];
  checks.push({ check: 'node', ok: true, value: process.version });
  checks.push({ check: 'bridgeDir', ok: fs.existsSync(BRIDGE_DIR), value: BRIDGE_DIR });
  checks.push({ check: 'v6Page', ok: fs.existsSync(path.join(ROOT, 'versions', '2026-03-24-v6-vibe-hub-status-split', 'index.html')) });
  try {
    const { stdout } = await execFileAsync('sh', ['-lc', 'command -v opencli || true']);
    checks.push({ check: 'opencli', ok: !!stdout.trim(), value: stdout.trim() || null });
  } catch {
    checks.push({ check: 'opencli', ok: false, value: null });
  }
  print({ ok: checks.every((item) => item.ok), checks });
}

async function install() {
  fs.mkdirSync(CONFIG_DIR, { recursive: true });
  const config = {
    installedAt: new Date().toISOString(),
    port: PORT,
    bridgeUrl: `http://127.0.0.1:${PORT}`,
    inputTerminal: '微信',
    firstOutputTarget: 'Codex',
    packageMode: 'local-dev',
    nextStep: 'Run `npm run bridge:start` inside vibe-hub/',
    futureInstall: 'npx @openclaw/vibe-hub install',
  };
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
  const llm = writeDefaultLlmSettingsIfNeeded();
  print({ ok: true, installed: true, configPath: CONFIG_PATH, llmConfigPath: LLM_CONFIG_PATH, config, llm });
}

async function status() {
  const exists = fs.existsSync(CONFIG_PATH);
  const config = exists ? JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8')) : null;
  print({ ok: true, installed: exists, config, llm: getResolvedLlmSettings(), host: os.hostname() });
}

async function llmStatus() {
  print({ ok: true, llm: getResolvedLlmSettings() });
}

switch (command) {
  case 'doctor':
    await doctor();
    break;
  case 'install':
    await install();
    break;
  case 'status':
    await status();
    break;
  case 'llm-status':
    await llmStatus();
    break;
  default:
    print([
      'vibe-hub bridge commands:',
      '  vibe-hub doctor',
      '  vibe-hub install',
      '  vibe-hub status',
      '  vibe-hub llm-status',
      '',
      'Current goal: local bridge first, then package as npx installer.',
    ].join('\n'));
}
