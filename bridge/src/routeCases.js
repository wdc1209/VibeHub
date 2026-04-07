export const routeCases = [
  {
    text: "解释一下这个报错",
    expected: "direct",
    note: "解释请求",
  },
  {
    text: "帮我分析这段代码为什么慢",
    expected: "direct",
    note: "分析请求",
  },
  {
    text: "这个架构合理吗",
    expected: "direct",
    note: "讨论与判断",
  },
  {
    text: "你觉得这段话会不会太强硬",
    expected: "direct",
    note: "判断，不是交付",
  },
  {
    text: "review 一下这个 PR 风险",
    expected: "direct",
    note: "代码审查",
  },
  {
    text: "继续",
    expected: "direct",
    note: "短控制指令",
  },
  {
    text: "发送",
    expected: "direct",
    note: "控制动作",
  },
  {
    text: "把这段整理后发给 Codex",
    expected: "vibe-hub",
    note: "明确外发到 agent",
  },
  {
    text: "给客户写一版回复",
    expected: "vibe-hub",
    note: "面向外部对象的交付稿",
  },
  {
    text: "帮我整理成发给老板的周报口径",
    expected: "vibe-hub",
    note: "对外发送前整理",
  },
  {
    text: "下面这段需求你整理成可以交给 Cursor 的执行任务",
    expected: "vibe-hub",
    note: "交付给外部执行者",
  },
  {
    text: "这是我要发在群里的说明，你先整理一下",
    expected: "vibe-hub",
    note: "群消息草稿",
  },
  {
    text: "把这三点压成一版可以直接发邮件的内容",
    expected: "vibe-hub",
    note: "明确交付形态",
  },
  {
    text: "请把下面内容变成可发送的 Codex 指令卡",
    expected: "vibe-hub",
    note: "外发前指令卡",
  },
  {
    text: "给同事起草一条同步消息",
    expected: "vibe-hub",
    note: "对外对象 + 消息草稿",
  },
  {
    text: "把这个整理一下然后发出去",
    expected: "clarify",
    note: "有外发意图但目标缺失",
  },
  {
    text: "你帮我整理一版，我等下拿去用",
    expected: "clarify",
    note: "用途不清晰",
  },
  {
    text: "做个能发的版本",
    expected: "clarify",
    note: "交付语气但缺目标",
  },
  {
    text: "帮我出一版，我要对外",
    expected: "clarify",
    note: "边界不够具体",
  },
  {
    text: "补充一点：把预算风险也写进去",
    expected: "vibe-hub",
    context: { hasActiveTokenSession: true },
    note: "卡片生命周期内的追加输入",
  },
  {
    text: "再加一条，强调这周必须上线",
    expected: "vibe-hub",
    context: { hasActiveTokenSession: true },
    note: "卡片生命周期内的追加输入",
  },
  {
    text: "把语气再收一点",
    expected: "vibe-hub",
    context: { hasActiveTokenSession: true },
    note: "当前卡片编辑要求",
  },
  {
    text: "顺便写上时间节点",
    expected: "vibe-hub",
    context: { hasActiveTokenSession: true },
    note: "当前卡片编辑要求",
  },
  {
    text: "另外补一句：先不要承诺交期",
    expected: "vibe-hub",
    context: { hasActiveTokenSession: true },
    note: "生命周期内补充",
  },
  {
    text: "取消",
    expected: "direct",
    context: { hasActiveTokenSession: true },
    note: "控制动作不应吞进 session",
  },
  {
    text: "发送",
    expected: "direct",
    context: { hasActiveTokenSession: true },
    note: "控制动作不应吞进 session",
  },
];
