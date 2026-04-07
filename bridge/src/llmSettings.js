import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..', '..');
const CONFIG_DIR = path.join(ROOT, '.vibe-hub');
const LLM_CONFIG_PATH = path.join(CONFIG_DIR, 'llm.json');

const DEFAULT_LLM_SETTINGS = {
  provider: 'openai',
  baseURL: 'https://api.openai.com/v1',
  apiKeyEnvVar: 'VIBE_HUB_LLM_API_KEY',
  apiKey: '',
  modelRewrite: 'gpt-5.4',
  modelCompress: 'gpt-5.4-mini',
  modelRoute: 'gpt-5.4-mini',
  temperature: 0.2,
  maxOutputTokens: 4000,
};

const WRITEABLE_KEYS = new Set([
  'provider',
  'baseURL',
  'apiKeyEnvVar',
  'apiKey',
  'modelRewrite',
  'modelCompress',
  'modelRoute',
  'temperature',
  'maxOutputTokens',
]);

function ensureConfigDir() {
  fs.mkdirSync(CONFIG_DIR, { recursive: true });
}

function readStoredSettings() {
  if (!fs.existsSync(LLM_CONFIG_PATH)) {
    return { ...DEFAULT_LLM_SETTINGS };
  }

  try {
    const parsed = JSON.parse(fs.readFileSync(LLM_CONFIG_PATH, 'utf8'));
    return {
      ...DEFAULT_LLM_SETTINGS,
      ...parsed,
    };
  } catch {
    return { ...DEFAULT_LLM_SETTINGS };
  }
}

function resolveSecret(stored) {
  const apiKeyEnvVar = String(stored.apiKeyEnvVar || DEFAULT_LLM_SETTINGS.apiKeyEnvVar);
  const envApiKey = process.env[apiKeyEnvVar] || '';
  const configApiKey = String(stored.apiKey || '');
  const resolvedApiKey = envApiKey || configApiKey;

  return {
    apiKeyEnvVar,
    envApiKey,
    configApiKey,
    resolvedApiKey,
  };
}

export function getResolvedLlmSettings() {
  const stored = readStoredSettings();
  const { apiKeyEnvVar, envApiKey, configApiKey, resolvedApiKey } = resolveSecret(stored);

  return {
    ...stored,
    apiKey: undefined,
    configPath: LLM_CONFIG_PATH,
    apiKeyEnvVar,
    apiKeyConfigured: Boolean(resolvedApiKey.trim()),
    apiKeySource: envApiKey.trim()
      ? `env:${apiKeyEnvVar}`
      : configApiKey.trim()
        ? `config:${LLM_CONFIG_PATH}`
        : 'missing',
  };
}

export function getRuntimeLlmSettings() {
  const stored = readStoredSettings();
  const { apiKeyEnvVar, resolvedApiKey } = resolveSecret(stored);

  return {
    ...stored,
    apiKeyEnvVar,
    apiKey: resolvedApiKey,
  };
}

export function writeDefaultLlmSettingsIfNeeded() {
  ensureConfigDir();
  if (!fs.existsSync(LLM_CONFIG_PATH)) {
    fs.writeFileSync(LLM_CONFIG_PATH, JSON.stringify(DEFAULT_LLM_SETTINGS, null, 2));
  }
  return getResolvedLlmSettings();
}

export function saveLlmSettings(patch) {
  ensureConfigDir();
  const current = readStoredSettings();
  const next = { ...current };

  for (const [key, value] of Object.entries(patch || {})) {
    if (!WRITEABLE_KEYS.has(key)) continue;
    next[key] = value;
  }

  fs.writeFileSync(LLM_CONFIG_PATH, JSON.stringify(next, null, 2));
  return getResolvedLlmSettings();
}

export { LLM_CONFIG_PATH, DEFAULT_LLM_SETTINGS };
