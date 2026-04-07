# Whisper 集成评估

更新时间：2026-04-04

## 目标

评估是否将 OpenAI Whisper 开源语音模型作为 Vibe Hub 的本地语音识别替代方案，用于改善中英混合输入下苹果默认语音识别表现不稳定的问题。

## 结论

结论：可行，但不建议在 1.0 发布前直接切换为默认方案。

更合理的推进方式是：

1. 先保留 Apple Speech 作为 1.0 默认方案
2. 并行做 Whisper 本地原型
3. 原型稳定后，再在状态面板里增加“语音识别引擎”切换

## 为什么可行

OpenAI 官方已经开源 Whisper：

- 官方仓库：<https://github.com/openai/whisper>

Whisper 的优势：

- 多语言识别能力更强
- 中英混合句子的鲁棒性通常优于系统默认识别
- 本地运行可控
- 生态成熟，已有大量封装和推理实现

## 推荐实现路径

最适合 Vibe Hub 的并不是直接嵌入 Python 版 Whisper，而是走本地推理后端：

### 推荐方案 A：whisper.cpp

- 仓库：<https://github.com/ggml-org/whisper.cpp>

优势：

- 原生 C/C++，适合本地打包
- macOS 适配成熟
- 无需依赖 Python 运行时
- 可通过命令行或轻量本地服务与 SwiftUI / bridge 对接

### 备选方案 B：外部 Python 服务

- 例如 faster-whisper / transformers 封装

问题：

- 依赖更重
- 打包和分发复杂
- 对普通用户安装体验不友好

## 为什么不适合 1.0 直接替换

1. 模型体积问题
- Whisper 本地模型需要额外下载或打包

2. 性能问题
- 不同 Mac 性能差异大
- 若选模型过大，识别时延会明显增加

3. 分发复杂度
- 应用打包体积、模型缓存、首次启动下载逻辑都要额外处理

4. 权限和链路仍然要保留
- 即便换成 Whisper，录音权限、音频采集、状态机、写回整理链路仍需完整维护

## 对 Vibe Hub 的建议

### 1.0 阶段

- 保持 Apple Speech 为默认识别
- 发布说明里明确：中英混合识别后续会升级

### 1.1 / 1.2 阶段

- 做 Whisper 本地原型
- 先实现为可选实验功能
- 通过状态面板切换：
  - Apple Speech
  - Whisper (Local)

## 原型验证建议

原型阶段建议先验证：

1. 10 秒中文输入
2. 10 秒英文输入
3. 10 秒中英混合输入
4. 结束录音后的识别耗时
5. 识别结果写回原始输入的稳定性
6. 与现有自动整理链路的兼容性

## 集成方式建议

推荐架构：

```text
Vibe Hub App
  -> VoiceInputService
  -> local whisper.cpp runner / local speech bridge
  -> transcript
  -> Vibe Hub raw input
  -> LLM rewrite/compress
```

不建议直接把 Whisper 推理硬塞进主 UI 线程。

更稳的方式是：

- 本地子进程
- 或轻量 bridge 子服务

## 当前建议

Whisper 值得做，但不应阻塞 1.0。

推荐动作：

1. 先完成 1.0 支持终端测试
2. 发布后单独开 Whisper 实验分支
3. 用 whisper.cpp 做第一版本地原型
