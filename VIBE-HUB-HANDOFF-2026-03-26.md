# Vibe Hub Handoff — 2026-03-26

## 1. 项目是什么

Vibe Hub 是一个正在从网页原型转向 **原生跨平台前台控制器** 的产品雏形。

当前已经落地的实现主线是：
- 原生 macOS App：**SwiftUI / AppKit**
- bridge：本地中间层，负责状态、路由、发送动作
- 输出链路：**bridge → opencli → Codex**
- 当前主要目标：把长文本 / 复杂意图从普通聊天流中抽离出来，进入一个可编辑、可确认、可追踪的“卡片式工作台”中，再决定是否发送给外部 agent / 软件

一句话定义：

> Vibe Hub 不是普通输入框，而是“外发前的整理、确认、修改、回看工作台”。

---

## 2. 当前已经明确的产品定位

### Vibe Hub 的核心价值
不是“帮用户自动写 prompt”这么简单，而是：

1. 把将要发出去的内容从聊天流中抽离出来
2. 让用户在发送前看见、修改、确认
3. 保留原始输入、整理稿、用户手改稿、发送历史
4. 支持多轮追加输入后的再整理（A/B/C 生命周期）

### 当前明确的职责边界

#### Vibe Hub 负责
- 窗口 UI
- 内容编辑
- 原始输入展示
- 整理后内容展示
- 历史记录
- 发送入口
- 后续可扩展到语音输入

#### bridge 负责
- 状态聚合
- 输入路由
- token session
- 输出目标探测
- 调用 opencli / Codex

#### opencli 负责
- 真正把消息投递给 Codex / 目标终端

#### OpenClaw 当前仍承担
- 某些输入终端接入
- 某些复杂研究 / 解释 / skill 路由
- 暂时部分整理逻辑

---

## 3. 当前阶段成果（已完成）

### 技术路线
- 已明确放弃 Electron
- 已转向 **SwiftUI / AppKit 原生 macOS app**

### 原生工程已存在
目录：
- `vibe-hub/vibe-hub-mac/`

主要已有：
- `VibeHubApp/main.swift`
- `Views/VibeHubRootView.swift`
- `Services/BridgeClient.swift`
- `Models/VibeHubViewModel.swift`
- `Models/SendHistoryStore.swift`
- 状态面板 / 历史面板 / 教程面板

### bridge 侧已有能力
- `/status`
- `/token-session`
- `/route`
- `/connect/codex`
- `/send/codex`

### 发送链路已验证
当前真实链路已跑通：

> bridge → opencli → Codex

其中 bridge 会实际执行类似：

```bash
OPENCLI_CDP_ENDPOINT=http://127.0.0.1:9333 opencli codex send "..."
```

### 安装 / 打包链路已有
已有脚本：
- `vibe-hub/vibe-hub-mac/package-app.sh`
- `vibe-hub/install-local.sh`
- `vibe-hub/smoke-test.sh`

### 项目看板已有
- `vibe-hub/project-tracker.html`

当前这页已经更新为：
- v8 前 10 条收口
- 第 11 条待集中测试
- v9 两个方向已确认可行

---

## 4. v8 当前状态

### 已明确验收通过
以下 v8 项已经通过：

1. 右上角 Codex 连接状态正确
2. 历史按钮改回时钟 / 历史语义图标
3. 状态面板恢复详细内容
4. 左下角不再错误提示“无法连接到服务器”
5. 漂浮效果取消
6. 窗体四周玻璃留白统一
7. 输入终端只显示真实接入渠道
8. 输出终端分成已连接 / 可连接
9. 本地教程入口正确
10. 发送历史支持日期筛选

### 尚未验收
11. **A/B/C 编辑生命周期正确**

当前状态不是“没做”，而是：
- 已有第一版实现
- 但还没做最终集中测试与口头验收

---

## 5. 第 11 条到底是什么（很关键）

第 11 条不是一个小 UI 文案问题，而是 Vibe Hub 的核心体验。

### A/B/C 编辑生命周期定义

#### A
用户输入原始内容 → 生成整理后内容 → 用户可直接发送

#### B
用户手动修改“整理后的内容”

#### C
在 B 的基础上，再来一条新的原始输入时：
系统不能把用户手改过的整理稿粗暴覆盖掉，
而必须使用：

> 当前整理后内容（含用户手改） + 新原始输入

重新进入下一轮整理。

### 当前已经做了哪些
- 新原始输入不会再直接覆盖当前 body
- 会以 `--- 新输入 ---` 的方式合并到当前编辑内容上下文中
- UI 已加入 `lifecycleHint`
- UI 已加入 `needsRewriteAfterMerge`
- 合并后主操作会从普通 `重写` 升级为橙色的 `整理`

### 仍需验证的点
- 这个状态机是否完全符合用户心智
- 是否真的能在连续多轮输入里保持稳定
- 是否存在某些路径又把用户编辑稿覆盖回去了

---

## 6. 当前暴露出的关键产品问题

在测试中已经发现一个核心问题：

用户给出较长、较完整、明显是任务描述的内容时，
OpenClaw 仍有可能直接调用：

> bridge → opencli → Codex

而绕开：

> bridge → Vibe Hub → opencli → Codex

这是不对的。

### 目标链路应为

```text
bridge → Vibe Hub → opencli → Codex
```

### 这引出了一个必须被工程化的问题

> 如何区分：
> - 这是 OpenClaw 自己应该回答/研究/解释的问题
> - 还是必须先进 Vibe Hub 的“待外发任务”

结论已经明确：
这个判断不能只靠临场经验，
必须写成 **可触发、可复用、可安装的 skill / 规则**。

---

## 7. 已确认的 v9 方向

当前已经明确、并且产品上判断为可行的 v9 内容有两条：

### v9-1 · 触发式 Vibe Hub skill

目标：
把“什么情况必须先进 Vibe Hub、什么情况允许 OpenClaw 直发”固化成一个 skill。

要求：
- 这个 skill 可以装在 OpenClaw / IDE 上
- 命中后，消息不再由 OpenClaw 自己直接处理
- 而是转发给 Vibe Hub 进入整理流程

本质作用：
- 解决路由漂移
- 解决长期记忆不稳定
- 让 Vibe Hub 成为稳定的外发前台

### v9-2 · Vibe Hub 内语音按压输入

目标：
在 Vibe Hub 内增加一个语音按压按钮。

期望行为：
1. 用户按住说话
2. 语音输入进入 Vibe Hub
3. 先记录为“原始输入”
4. 语音经 bridge 转到处理层
5. 处理结果显示在“整理后的内容”

这条当前讨论版本是：
- 先通过 bridge 回到 OpenClaw 处理
- 但更长期可能改为 Vibe Hub 自己直连 LLM API 处理

---

## 8. 更长期的架构判断（非常重要）

讨论已经明确出一个更大的方向：

### Vibe Hub 可以逐步独立

也就是说，Vibe Hub 不一定必须永久依赖 OpenClaw 来完成：

> 原始输入 → 整理后内容

这一步。

### 一条可行的新架构是

Vibe Hub 自己接 LLM API，自己完成：
- 原始输入摘要
- 整理
- 改写
- 压缩
- 生命周期内的再整理

而 OpenClaw 退到：
- 某些输入终端上的 skill / 入口增强器
- 某些复杂研究 / 深度代理能力
- 某些需要长期上下文的任务

### 这意味着什么

如果 Vibe Hub 独立，就可以走向：
- mac app
- 手机 app
- Windows app
- 多端同步
- 统一语音入口
- 在任何终端上，用语音控制软件

当前结论：

> 一个触发式 skill + 一个独立 Vibe Hub app
> 已经足够构成“语音控制电脑”的核心 MVP 架构。

---

## 9. 推荐给下一位 AI 的实施优先级

### 第一优先级
完成第 11 条集中测试与修正：
- 验证 A/B/C 生命周期是否真的符合用户定义
- 找出当前所有可能绕开 Vibe Hub 的路径
- 确保长任务描述不会被 OpenClaw 直接发给 Codex

### 第二优先级
开始 v9-1：触发式 Vibe Hub skill

建议产出：
- skill 目录
- SKILL.md
- 明确触发规则
- 路由表：什么情况进 Vibe Hub / 什么情况允许直发 / 什么情况需要澄清

### 第三优先级
开始 v9-2：Vibe Hub 语音按压输入

建议拆分：
1. UI 按钮与录音状态
2. 音频采集
3. 转写
4. 原始输入回填
5. 整理后内容回填

### 第四优先级（架构探索）
验证 Vibe Hub 自己直连 LLM API 是否更优于“回发 OpenClaw”。

建议回答的问题：
- 整理逻辑是否应该留在 Vibe Hub 本地
- 是否允许 Vibe Hub 成为独立产品
- OpenClaw 与 Vibe Hub 的长期边界如何划分

---

## 10. 给开发者的关键原则

1. **不要再把 Vibe Hub 当成 prompt 美化器**
   - 它是外发前的工作台

2. **不要默认 OpenClaw 可以直接替代 Vibe Hub**
   - 一旦绕开 Vibe Hub，用户就失去可见、可改、可确认层

3. **不要只靠文本长度判断是否进 Vibe Hub**
   - 关键应是“是否存在明确外发意图 / 任务交付意图”

4. **第 11 条是核心，不是附属功能**
   - 做不对，Vibe Hub 的产品价值会塌

5. **v9 的两条不是边角料，而是方向性升级**
   - skill 决定路由控制权
   - 语音输入决定 Vibe Hub 能不能变成前台控制器

---

## 11. 关键文件

- `vibe-hub/project-tracker.html`
- `vibe-hub/WORKLOG.md`
- `vibe-hub/NOW.md`
- `vibe-hub/SWIFTUI-APPKIT-PLAN.md`
- `vibe-hub/vibe-hub-mac/VibeHubApp/Views/VibeHubRootView.swift`
- `vibe-hub/vibe-hub-mac/VibeHubApp/Models/VibeHubViewModel.swift`
- `vibe-hub/vibe-hub-mac/VibeHubApp/Services/BridgeClient.swift`
- `vibe-hub/bridge/src/server.js`

---

## 12. 当前一句话状态

> v8 前 10 条已收口，第 11 条待集中测试；v9 已确认两条可行新方向：触发式 Vibe Hub skill + Vibe Hub 内语音按压输入；更长期可将 Vibe Hub 推进为独立跨平台前台控制器。
