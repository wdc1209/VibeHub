---
name: vibe-hub-router
description: Route incoming messages into Vibe Hub when the user is handing off work to an external agent, app, or recipient; keep direct chat for explanations, research, and terse control commands; ask one clarification question when outbound intent exists but the destination is still missing.
---

# Vibe Hub Router

Use this skill when an incoming message may need to leave the current chat and become a Vibe Hub draft.

Vibe Hub is not a prompt beautifier. It is the visible review layer before content is sent outward.

## Decision contract

Return one of:

- `direct`
- `vibe-hub`
- `clarify`

Also return:

- a short `reason`
- matched `triggers`
- `clarificationPrompt` only when the decision is `clarify`

## Core rule

Do not route by length alone.

The primary question is:

`Is the user asking for a direct answer inside the current chat, or are they preparing work that should be reviewed before being sent outward?`

## Route to `direct`

Use `direct` when the input is clearly one of these:

- a short operational command for the current session
- a question asking for explanation, analysis, research, or advice
- a local coding/task request meant to be handled directly in the current conversation

Examples:

- `继续`
- `暂停`
- `解释一下这个报错`
- `帮我分析这段代码`

## Route to `vibe-hub`

Use `vibe-hub` when any of these is true:

- the user explicitly wants to send, hand off, forward, submit, or deliver something outward
- the message names an external target, recipient, app, or agent for execution
- the message is a structured task brief, draft, or multi-part handoff that should be reviewed before send
- there is already an active Vibe Hub session and the user is appending more task content
- the user is preparing content for an external audience such as a customer, boss, teammate, or public channel

Examples:

- `把这段整理后发给 Codex`
- `这是给客户的一版回复，你先整理成可发送版本`
- `补充一点：把预算风险也写进去`

## Route to `clarify`

Use `clarify` only when outbound intent exists, but the destination or workflow boundary is still unclear.

Ask one short question instead of guessing.

Example:

- `把这个整理一下然后发出去`

Suggested clarification:

- `这是要我现在直接在聊天里处理，还是先放进 Vibe Hub 整理后再发送？`

## Session rule

If a Vibe Hub session is already active, bias toward keeping new substantial input in Vibe Hub.

Only break out of the card flow when the new message is obviously a terse control command such as:

- `继续`
- `发送`
- `取消`
- `重试`

## Signal reference

For the current rule matrix and trigger examples, read:

- [references/route-matrix.md](references/route-matrix.md)
- [references/real-phrases.md](references/real-phrases.md)
