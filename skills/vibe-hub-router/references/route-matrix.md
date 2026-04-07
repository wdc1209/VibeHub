# Vibe Hub Router Matrix

## Priority order

Evaluate in this order:

1. Explicit outbound handoff
2. Active Vibe Hub continuation
3. Direct question or terse control command
4. Ambiguous outbound intent
5. Default direct

## Trigger groups

### `direct`

- Terse control commands:
  - `继续`
  - `暂停`
  - `停止`
  - `取消`
  - `重试`
  - `打开`
  - `关闭`
- Questions seeking explanation or analysis:
  - `解释一下`
  - `为什么`
  - `如何`
  - `这是什么`
  - `帮我分析`
  - `review 一下`

### `vibe-hub`

- Explicit outbound verbs:
  - `发给`
  - `发送给`
  - `交给`
  - `转给`
  - `提交给`
  - `同步到`
  - `整理后发`
  - `代我发`
- External targets or recipients:
  - `Codex`
  - `OpenClaw`
  - `当前应用`
  - `客户`
  - `老板`
  - `同事`
  - `群里`
  - `邮件`
- Structured brief signals:
  - multiple paragraphs
  - bullet lists
  - numbered lists
  - code block
  - URL
  - explicit sections such as `背景` `目标` `要求` `约束`
- Active-session continuation cues:
  - `补充一下`
  - `补充一点`
  - `再加一条`
  - `另外`
  - `新增`
  - `续上`
  - `新输入`
  - `把预算风险也写进去`

### `clarify`

- Outbound language without a clear target:
  - `发出去`
  - `发一版`
  - `交出去`
  - `拿去用`
- Ask:
  - `这是要我现在直接处理，还是先进入 Vibe Hub 整理后再发送？`

## Non-goals

- Do not use character length as the only rule.
- Do not force Vibe Hub for pure explanation or research requests.
- Do not let active Vibe Hub sessions swallow obvious local control commands.
