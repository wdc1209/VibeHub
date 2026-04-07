# Vibe Hub · OpenCLI 支持对象与能力

这份说明用于回答两个问题：

1. **Vibe Hub 在 OpenClaw 内部可以发给谁**
2. **Vibe Hub 当前能操控哪些程序 / 页面，以及支持哪些能力**

> 当前阶段仍是前端原型，因此这里既包含**已经验证**的能力，也包含**UI 预留 / 后续接入**的能力。

---

## 1. 已验证的 OpenCLI 路径

当前本地文档里，已经有一条被验证过的稳定链路：

- **程序**：`Codex.app`
- **调度方式**：`opencli codex`
- **连接方式**：通过 `--remote-debugging-port=9333` 启动 Codex，再由 `opencli` 连接

参考本地文档：
- `docs/codex-opencli-dispatch-template-v1.md`

### 标准启动方式
```bash
nohup /Applications/Codex.app/Contents/MacOS/Codex --remote-debugging-port=9333 >/tmp/codex-opencli.log 2>&1 &
```

### 连通性验证
```bash
curl http://127.0.0.1:9333/json/version
OPENCLI_CDP_ENDPOINT=http://127.0.0.1:9333 opencli codex status
```

### 已验证支持的能力
- 查询 Codex 当前连接状态
- 向当前活动 Codex 会话发送消息
- 读取当前活动 Codex 会话内容

对应命令：
```bash
OPENCLI_CDP_ENDPOINT=http://127.0.0.1:9333 opencli codex status
OPENCLI_CDP_ENDPOINT=http://127.0.0.1:9333 opencli codex send "你的消息"
OPENCLI_CDP_ENDPOINT=http://127.0.0.1:9333 opencli codex read
```

---

## 2. Vibe Hub 在 OpenClaw 内部的可用对象

当前原型里，Vibe Hub 的“输入端”主要表示：

- 哪些 **agent** 支持接收 Vibe Hub
- 哪些 **session / thread** 已挂载 Vibe Hub
- 哪些对象目前是摘要 / 审阅型，而不是直接执行型

### 当前 UI 中展示的对象
- `Codex`
- `财神`
- `Echo 审阅`
- `当前 Thread / Session`

### 当前建议的状态语义
- **可用**：可以直接接收 Vibe Hub
- **已挂载**：当前 session / thread 已启用 Vibe Hub
- **可审阅**：支持摘要 / 审阅，但未必是直接执行端
- **未连接 / 待接入**：前端先展示，等待后端能力补齐

---

## 3. Vibe Hub 在系统侧的可连接对象

当前原型里，“输出端”表示 Vibe Hub 最终可以落到哪些本地程序 / 网页环境。

### 当前 UI 预留的对象
- `微信`
- `Safari 当前页`
- `Chrome 当前页`
- `VS Code`

### 推荐展示的能力字段
对每个对象，建议至少说明：

- **类型**：App / Web
- **状态**：已连接 / 可连接 / 待接入 / 未连接
- **支持能力**：
  - 可投递
  - 可注入
  - 可读取
  - 可作为活动终端

### 当前前端原型里的能力解释
- **微信**：当前会话可投递
- **Safari 当前页**：可连接 / 可注入（UI 预留）
- **Chrome 当前页**：等待 bridge 接入
- **VS Code**：预留目标，尚未完成真实接入

---

## 4. 为什么设置里要放这份教程

因为对用户来说，最关键的不是“有几个设置项”，而是：

- **这个 Vibe Hub 到底能发给谁**
- **它能接到哪些程序 / 网页**
- **每个目标支持什么能力**

所以设置弹窗更适合做成一个：

- **连接与可用性面板**
- 再附带一个**本地教程入口**

这样用户能在本地直接查看，不依赖外网，也更适合后面继续扩展。

---

## 5. 当前已确认的产品方向

- 右上角不再是传统“设置页”，而是 **连接与可用性面板**
- 面板需要同时展示：
  - **输入端**：OpenClaw 内部哪些 agent / session 可用
  - **输出端**：系统中哪些程序 / 网页已连接或可连接
- 教程内容最好提供 **本地链接**，方便直接查看支持对象与能力说明

---

## Source
- `docs/codex-opencli-dispatch-template-v1.md`
