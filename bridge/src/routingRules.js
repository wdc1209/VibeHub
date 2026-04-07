const CONTROL_COMMAND_PATTERN = /^(继续|暂停|停止|取消|重试|打开|关闭|切到|切换到|返回|下一步|上一步|刷新|发送|复制|粘贴|选中|展开|收起|查看状态|连接|retry|continue|pause|stop|cancel|send|open|close)$/i;
const QUESTION_PATTERN = /[?？]$|(?:为什么|怎么|如何|是什么|什么意思|区别|是否|能不能|解释一下|说明一下|帮我分析|帮我看看|review|审查|analyze|explain|why|how|what)/i;
const EXTERNAL_TARGET_PATTERN = /(?:codex|openclaw|vibe hub|cursor|claude|gpt|agent|ide|chrome|safari|telegram|wechat|微信|浏览器|当前应用|邮件|mail|notion|飞书|slack|jira|github|客户|老板|同事|群里|对方)/i;
const EXPLICIT_HANDOFF_PATTERN = /(?:发给|发送给|交给|转给|投递给|提交给|同步到|丢给|扔给|整理后发|代我发|替我发|帮我发|帮我交给|交由|让.+(?:处理|执行|完成|推进)|给.+(?:处理|执行|完成|推进))/i;
const OUTBOUND_WITHOUT_TARGET_PATTERN = /(?:发出去|发一版|交出去|拿去用|对外发|发出一版|能发的版本|我要对外|对外用)/i;
const EXTERNAL_AUDIENCE_PATTERN = /(?:给客户|给老板|给同事|给对方|群里|邮件里|对外|公开|发文|回给)/i;
const ARTIFACT_PATTERN = /(?:写一(?:份|封|版)?|起草|整理(?:成|一版|一下)?|改写成|压缩成|压成|总结成|做成|生成|输出|形成|出一版|变成|改成).*(?:任务|计划|方案|邮件|消息|文案|提纲|纪要|prompt|提示词|卡片|指令|需求|todo|清单|issue|回复|报告|总结|口径|版本|内容)?/i;
const TASK_BRIEF_PATTERN = /(?:背景|目标|要求|约束|上下文|先|然后|最后|请|帮我|需要|用于|做一个|做一份|实现|完成|产出|输出|交付|修改|重写|整理)/i;
const SESSION_CONTINUATION_PATTERN = /^(?:再补充|补充(?:一下|一点|一句)?|还有|另外|新增|加一条|再加一条|再来一条|新输入|续上|继续补充|顺便加上|补一句)/i;
const ACTIVE_SESSION_EDIT_PATTERN = /(?:加上|补上|写进去|写上|加入|补充一点|补充一句|顺便写|把语气|把口气|把措辞|把节奏|把时间节点|把.+(?:写进去|写上|加进去|补进去))/i;
const STRUCTURED_PATTERN = /\n|^\s*[-*•]\s+|^\s*\d+\.\s+|```|https?:\/\//m;

function normalizeText(text) {
  return String(text || "").trim();
}

function looksShortControlCommand(text) {
  return text.length <= 20 && !/[\n，,。；;:：]/.test(text) && CONTROL_COMMAND_PATTERN.test(text);
}

function sentenceCount(text) {
  return text
    .split(/[。！？!?]\s*|\n+/)
    .map((part) => part.trim())
    .filter(Boolean).length;
}

export function evaluateRoute(text, context = {}) {
  const normalized = normalizeText(text);
  const hasActiveTokenSession = Boolean(context.hasActiveTokenSession);

  if (!normalized) {
    return {
      mode: "direct",
      decision: "direct",
      reason: "空输入不进入 Vibe Hub",
      triggers: ["empty_input"],
      shouldStoreInTokenSession: false,
    };
  }

  const structured = STRUCTURED_PATTERN.test(normalized);
  const explicitTarget = EXTERNAL_TARGET_PATTERN.test(normalized);
  const explicitHandoff = EXPLICIT_HANDOFF_PATTERN.test(normalized);
  const outboundWithoutTarget = OUTBOUND_WITHOUT_TARGET_PATTERN.test(normalized);
  const externalAudience = EXTERNAL_AUDIENCE_PATTERN.test(normalized);
  const artifactRequest = ARTIFACT_PATTERN.test(normalized);
  const question = QUESTION_PATTERN.test(normalized);
  const continuationCue = SESSION_CONTINUATION_PATTERN.test(normalized);
  const taskBriefCue = TASK_BRIEF_PATTERN.test(normalized);
  const shortControl = looksShortControlCommand(normalized);
  const sentences = sentenceCount(normalized);
  const longStructuredBrief = normalized.length >= 120 || (structured && normalized.length >= 40) || sentences >= 3;

  if (explicitHandoff && (explicitTarget || externalAudience || artifactRequest || longStructuredBrief)) {
    return {
      mode: "vibe-hub",
      decision: "vibe-hub",
      reason: "检测到明确外发/交付意图，必须先进 Vibe Hub",
      triggers: ["explicit_handoff"],
      shouldStoreInTokenSession: true,
    };
  }

  if (hasActiveTokenSession && !shortControl && (continuationCue || artifactRequest || longStructuredBrief || taskBriefCue || ACTIVE_SESSION_EDIT_PATTERN.test(normalized))) {
    return {
      mode: "vibe-hub",
      decision: "vibe-hub",
      reason: "当前 session 已在 Vibe Hub 生命周期内，新内容继续进入卡片",
      triggers: ["active_token_session_continuation"],
      shouldStoreInTokenSession: true,
    };
  }

  if (shortControl) {
    return {
      mode: "direct",
      decision: "direct",
      reason: "短控制指令保留在当前会话直达处理",
      triggers: ["short_control_command"],
      shouldStoreInTokenSession: false,
    };
  }

  if (question && !explicitHandoff && !externalAudience) {
    return {
      mode: "direct",
      decision: "direct",
      reason: "这是当前会话内的解释/分析请求，不需要先进入 Vibe Hub",
      triggers: ["question_or_analysis"],
      shouldStoreInTokenSession: false,
    };
  }

  if (outboundWithoutTarget && !explicitTarget && !explicitHandoff) {
    return {
      mode: "clarify",
      decision: "clarify",
      reason: "存在外发意图，但目标或边界还不明确",
      triggers: ["outbound_without_target"],
      clarificationPrompt: "这是要我现在直接在聊天里处理，还是先放进 Vibe Hub 整理后再发送？",
      shouldStoreInTokenSession: false,
    };
  }

  if (explicitTarget && (artifactRequest || longStructuredBrief || externalAudience)) {
    return {
      mode: "vibe-hub",
      decision: "vibe-hub",
      reason: "检测到外部目标与可交付内容，应先进入 Vibe Hub",
      triggers: ["external_target_deliverable"],
      shouldStoreInTokenSession: true,
    };
  }

  if ((externalAudience && (artifactRequest || taskBriefCue)) || (structured && taskBriefCue && !question && sentences >= 2)) {
    return {
      mode: "vibe-hub",
      decision: "vibe-hub",
      reason: "这是面向外部对象的任务稿或结构化交付稿，先进入 Vibe Hub",
      triggers: ["structured_external_brief"],
      shouldStoreInTokenSession: true,
    };
  }

  if (outboundWithoutTarget) {
    return {
      mode: "clarify",
      decision: "clarify",
      reason: "存在外发意图，但目标或边界还不明确",
      triggers: ["outbound_without_target"],
      clarificationPrompt: "这是要我现在直接在聊天里处理，还是先放进 Vibe Hub 整理后再发送？",
      shouldStoreInTokenSession: false,
    };
  }

  if (!hasActiveTokenSession && /(?:给客户|给老板|给同事|给对方).*(?:怎么说|怎么回复|怎么讲|是否合适|会不会)/i.test(normalized)) {
    return {
      mode: "direct",
      decision: "direct",
      reason: "这是在讨论对外表达策略，还没有进入可交付稿阶段",
      triggers: ["external_wording_discussion"],
      shouldStoreInTokenSession: false,
    };
  }

  return {
    mode: "direct",
    decision: "direct",
    reason: "未命中外发前整理信号，默认保留在当前会话处理",
    triggers: ["default_direct"],
    shouldStoreInTokenSession: false,
  };
}
