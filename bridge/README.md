# Vibe Hub Bridge

最小后端骨架，目标是把 Vibe Hub 从纯前端原型推进到真实可连接版本。

## 现在有什么

- `src/server.js`
  - `GET /health`
  - `GET /status`
  - `GET /llm/settings`
  - `POST /llm/settings`
  - `POST /route`：判断 `direct` / `vibe-hub` / `clarify`
  - `POST /send/codex`：第一条真实输出链路，尝试通过 `opencli codex send` 发给 Codex
- `src/cli.js`
  - `vibe-hub doctor`
  - `vibe-hub install`
  - `vibe-hub status`
  - `vibe-hub llm-status`

## 当前目标

第一阶段先把下面几件事跑通：

1. Vibe Hub 前端能拿到真实 `/status`
2. 能判断输入该走 `direct`、`vibe-hub` 还是 `clarify`
3. 能把长内容整理后发送到 `Codex App`
4. 安装路径先模拟成将来可走的 `npx install` 体验

## v9-1 当前规则

`/route` 不再只按长度判断。

当前优先级是：

1. 明确外发/交付意图 -> `vibe-hub`
2. 已有 Vibe Hub session 的追加输入 -> `vibe-hub`
3. 短控制指令或解释/分析问题 -> `direct`
4. 有外发意图但目标不明确 -> `clarify`

## LLM 设置骨架

Vibe Hub 现在已经有第一版本地 LLM 配置骨架：

- 配置文件：`.vibe-hub/llm.json`
- 默认密钥入口：环境变量 `VIBE_HUB_LLM_API_KEY`
- 当前 bridge 会暴露：
  - `GET /llm/settings`
  - `POST /llm/settings`

推荐做法：

1. 把 provider / base URL / models 写进 `.vibe-hub/llm.json`
2. 把真正的 API key 放进环境变量，而不是写进 repo
3. 不要提交 `.vibe-hub/` 目录或任何本地记忆 / 密钥文件
4. 如果需要，也可以让别的 AI 工具在本地帮你写配置文件，但不要把密钥提交到仓库
3. 以后再把 `rewrite / compress / polish` 真正接到 provider adapter

## 本地试运行

```bash
cd /Users/nethon/.openclaw/workspace-main/vibe-hub
npm run bridge:doctor
npm run bridge:install
npm run bridge:start
npm run bridge:route-check
VIBE_HUB_LLM_API_KEY=... vibe-hub llm-status
```

然后访问：

- `http://127.0.0.1:4765/health`
- `http://127.0.0.1:4765/status`

`bridge:route-check` 会跑一组固定中文话术，验证 `/route` 的当前规则是否还符合 Vibe Hub 的产品口径。

## 未来安装目标

最终希望收敛到：

```bash
npx @openclaw/vibe-hub install
```

这一步后续再把本地桥接、OpenClaw 注册、前端页面入口统一收进 installer。
