import { getResolvedLlmSettings, getRuntimeLlmSettings } from './llmSettings.js';

function buildHeaders(settings, apiKey) {
  const headers = {
    'content-type': 'application/json',
  };

  if (apiKey) {
    headers.authorization = `Bearer ${apiKey}`;
  }

  return headers;
}

function extractTextFromResponse(payload) {
  if (typeof payload?.output_text === 'string' && payload.output_text.trim()) {
    return payload.output_text.trim();
  }

  const chatText = payload?.choices?.[0]?.message?.content;
  if (typeof chatText === 'string' && chatText.trim()) {
    return chatText.trim();
  }

  if (Array.isArray(chatText)) {
    const combined = chatText
      .map((item) => item?.text || item?.content || '')
      .join('\n')
      .trim();
    if (combined) return combined;
  }

  const text = payload?.choices?.[0]?.text;
  if (typeof text === 'string' && text.trim()) {
    return text.trim();
  }

  throw new Error('llm response did not include text');
}

function stripReasoningArtifacts(text) {
  return String(text || '')
    .replace(/<think>[\s\S]*?<\/think>/gi, '')
    .trim();
}

async function callOpenAICompatible({ model, system, user, temperature, maxOutputTokens }) {
  const settings = getRuntimeLlmSettings();
  const apiKey = String(settings.apiKey || '').trim();
  if (!apiKey) {
    throw new Error(`llm api key missing (${settings.apiKeyEnvVar || 'VIBE_HUB_LLM_API_KEY'})`);
  }

  const endpoint = new URL('chat/completions', settings.baseURL.endsWith('/') ? settings.baseURL : `${settings.baseURL}/`).toString();
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: buildHeaders(settings, apiKey),
    body: JSON.stringify({
      model,
      temperature,
      max_tokens: maxOutputTokens,
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: user },
      ],
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`llm http ${response.status}: ${errorText.slice(0, 400)}`);
  }

  const payload = await response.json();
  return {
    text: stripReasoningArtifacts(extractTextFromResponse(payload)),
    raw: payload,
    settings,
  };
}

function buildRewritePrompt({ rawInput, draftText, target }) {
  const safeRawInput = String(rawInput || '').trim();
  const safeDraftText = String(draftText || '').trim();
  const safeTarget = String(target || '外部 agent').trim();
  const hasDraft = Boolean(safeDraftText);
  const isWeChatTarget = /^(wechat|weixin|微信)$/i.test(safeTarget);

  return {
    system: [
      '你是 Vibe Hub 的整理引擎。',
      '你的任务是把用户的原始输入和当前整理稿，整理成一版可直接发送给目标对象的清晰内容。',
      '保留关键信息、约束、目标、上下文。',
      hasDraft
        ? '当“当前整理稿”不为空时，它是当前最权威的工作版本，可能已经包含用户手工修改。你必须在保留其结构、措辞和新增要求的前提下，只把本次新增原始输入并入，不要回退成只按历史原始输入重写。'
        : '当“当前整理稿”为空时，请根据原始输入直接生成第一版可发送整理稿。',
      isWeChatTarget
        ? '当前目标是微信。默认请整理成轻松、自然、口语化的聊天表达，不要过度书面化，不要像正式邮件或公文。除非用户明确要求，否则不要拔高语气。'
        : '默认按清晰、直接、可发送的工作沟通风格整理。',
      '不要解释你做了什么，不要加前言，不要加“当然可以”。',
      '直接输出整理后的正文。',
    ].join('\n'),
    user: [
      `目标对象：${safeTarget}`,
      '',
      hasDraft ? '本次新增原始输入：' : '原始输入：',
      safeRawInput || '(空)',
      '',
      '当前整理稿：',
      safeDraftText || '(空)',
      '',
      '请产出一版更清晰、更适合直接发送的整理稿。',
      hasDraft
        ? '请把这次新增原始输入合理并入当前整理稿，优先保留当前整理稿里的用户手工修改。'
        : '请直接生成第一版整理稿。',
    ].join('\n'),
  };
}

function buildCompressPrompt({ draftText, target }) {
  const safeDraftText = String(draftText || '').trim();
  const safeTarget = String(target || '外部 agent').trim();
  const isWeChatTarget = /^(wechat|weixin|微信)$/i.test(safeTarget);

  return {
    system: [
      '你是 Vibe Hub 的压缩引擎。',
      '你的任务是把当前整理稿压缩得更短，但不能丢掉关键约束、目标和行动要求。',
      isWeChatTarget
        ? '当前目标是微信。压缩后也要保持自然口语，不要压成生硬提纲。'
        : '压缩后保持清晰、直接、可发送。',
      '不要解释，不要加标题，直接输出压缩后的正文。',
    ].join('\n'),
    user: [
      `目标对象：${safeTarget}`,
      '',
      '当前整理稿：',
      safeDraftText || '(空)',
      '',
      '请输出一版更短、更紧凑、但仍可直接发送的内容。',
    ].join('\n'),
  };
}

export async function rewriteDraft(params) {
  const settings = getResolvedLlmSettings();
  const prompt = buildRewritePrompt(params);
  const result = await callOpenAICompatible({
    model: settings.modelRewrite,
    system: prompt.system,
    user: prompt.user,
    temperature: settings.temperature,
    maxOutputTokens: settings.maxOutputTokens,
  });

  return {
    ok: true,
    action: 'rewrite',
    output: result.text,
    model: settings.modelRewrite,
    provider: settings.provider,
    baseURL: settings.baseURL,
  };
}

export async function compressDraft(params) {
  const settings = getResolvedLlmSettings();
  const prompt = buildCompressPrompt(params);
  const result = await callOpenAICompatible({
    model: settings.modelCompress,
    system: prompt.system,
    user: prompt.user,
    temperature: settings.temperature,
    maxOutputTokens: settings.maxOutputTokens,
  });

  return {
    ok: true,
    action: 'compress',
    output: result.text,
    model: settings.modelCompress,
    provider: settings.provider,
    baseURL: settings.baseURL,
  };
}
