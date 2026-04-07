# Vibe Hub

<p align="center">
  <img src="vibe-hub-mac/VibeHubApp/Assets/vibe-hub-logo.png" alt="Vibe Hub logo" width="180">
</p>

<p align="center">
  <a href="./README.md">English</a>
</p>

用户仅需语音输入，模型自动将其整理为结构化 Prompt，自主分发至本机内所有 AI 软件（包括 OpenClaw、Codex、AntiGravity、Claude、Cline、VS Code 等），该软件作为 Mac 上 Vibe Coding 的语音中枢，实现本地所有开发工具的一站式处理。

## 项目简介

Vibe Hub 位于“输入”和“发送”之间。

你可以先把语音、文字、剪贴内容或外部输入收进来，再用它完成：

- 重写
- 压缩
- 在迭代中保留手工修改
- 发送到不同目标

它不是普通聊天框，而是一层“发送前整理工作台”。

## 核心工作流

1. 接收原始输入  
2. 整理成结构化内容  
3. 按需手动检查和修改  
4. 发送到所选目标

## 当前功能

- 原生 macOS 应用
- 完整模式与微缩模式
- 语音输入
- 重写 / 压缩
- 剪贴板输出
- 多目标分发
- 可直接打包为 GitHub Releases 发布产物

## 发布

当前 macOS 打包目录位于 `vibe-hub-mac/`。

- 本地 app 包：`vibe-hub-mac/dist/VibeHub.app`
- GitHub 发布压缩包：`vibe-hub-mac/dist/VibeHub-macOS-<version>.zip`

发布流程见 [RELEASE.md](/Users/nethon/.openclaw/workspace-main/vibe-hub/RELEASE.md)。  
当前版本发布说明见 [RELEASE-NOTES-1.0.0.md](/Users/nethon/.openclaw/workspace-main/vibe-hub/RELEASE-NOTES-1.0.0.md)。  
隐私说明见 [PRIVACY.md](/Users/nethon/.openclaw/workspace-main/vibe-hub/PRIVACY.md)。  
密钥与安全说明见 [SECURITY.md](/Users/nethon/.openclaw/workspace-main/vibe-hub/SECURITY.md)。

## 安装

1. 下载最新的 release 压缩包
2. 解压
3. 将 `VibeHub.app` 拖入 `Applications`
4. 从“应用程序”或启动台打开

## 本地配置

用户可能需要自行配置以下本地项：

- `麦克风` 权限
- `语音识别` 权限
- 可选的 `.env` 文件，用于本地 bridge 设置和云端 LLM key
- 可选的本地 `.vibe-hub/llm.json`，用于 provider / model 配置

模板文件：

- [.env.example](/Users/nethon/.openclaw/workspace-main/vibe-hub/.env.example)
- [examples/llm.example.json](/Users/nethon/.openclaw/workspace-main/vibe-hub/examples/llm.example.json)

推荐流程：

1. 将 `.env.example` 复制为 `.env`，仅供本地使用
2. 将 `examples/llm.example.json` 复制为 `.vibe-hub/llm.json`
3. 如果需要云端 LLM 功能，再填入你自己的本地 API key

如有需要，也可以让其他 AI 工具在本地帮你生成配置，但真实 key 只应保留在你自己的机器上。

## 说明

- 语音输入需要麦克风和语音识别权限
- 苹果自带语音识别在中英文混合识别上存在问题。如果你需要更好的中英混合识别，建议优先使用第二个语音方案：`SenseVoice ONNX`。
- `SenseVoice ONNX` 需要用户先在本地下载模型后才能运行。
- 某些发送目标需要本地集成或系统权限
- 当前公开构建更适合直接分发和测试使用
- 所有密钥都应只保留在本地。不要提交 `.vibe-hub/`、`.env`、API key、记忆文件或个人运行日志。
- 如果你使用云端语音识别或 LLM，请在本地通过 `VIBE_HUB_LLM_API_KEY` 或你自己的本地配置方式写入。
- 如有需要，也可以让其他 AI 工具在本地帮你生成配置文件，但真实 key 只应保留在你自己的机器上。

## 许可证

MIT
