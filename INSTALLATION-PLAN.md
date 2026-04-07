# Vibe Hub · Installation Plan

## 目标体验

用户最终只需要：

```bash
npx @openclaw/vibe-hub install
```

然后完成：
- 安装 Vibe Hub bridge
- 写入本地配置
- 注册 OpenClaw 可见入口
- 启动本地状态 / 发送服务
- 打开 Vibe Hub V6 页面

## 分阶段实施

### Phase 1 · Local bridge
- 本地 HTTP bridge
- 第一条真实输出：Codex App
- 最小状态发现：输入终端 / 输出终端 / Codex 连接状态

### Phase 2 · UI 接 bridge
- V6 页面读取 `/status`
- 发送按钮调用 `/send/codex`
- 输入内容先调用 `/route`

### Phase 3 · Desktop shell
- 使用真正独立的 macOS 窗口承载 Vibe Hub（不是网页里再模拟桌面）
- Vibe Hub 本体就是窗口主内容，不再保留网页里的假桌面截图作为主视觉
- 先做可拖动、独立存在的本地窗口版 Vibe Hub
- 再把 bridge / Codex 链路接入窗口内容

### Phase 4 · Installer
- package bin
- install / doctor / status 子命令
- 未来发布到 npm

## GitHub 同步

用户已明确要求：后续后端 / bridge / 安装链路推进后，记得同步到 GitHub。
