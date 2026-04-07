# Vibe Hub

<p align="center">
  <img src="vibe-hub-mac/VibeHubApp/Assets/vibe-hub-logo.png" alt="Vibe Hub logo" width="180">
</p>

<p align="center">
  <a href="./README.zh-CN.md">简体中文</a>
</p>

With voice input alone, Vibe Hub automatically turns what the user says into a structured prompt and routes it across local AI tools on the same machine, including OpenClaw, Codex, AntiGravity, Claude, Cline, and VS Code. It serves as the voice hub for Vibe Coding on macOS, giving users a single place to manage and dispatch work across their local development tools.

## Overview

Vibe Hub sits between input and delivery.

You can first capture voice, text, pasted content, or external input, then use the app to:

- rewrite it
- compress it
- preserve manual edits during iteration
- send it to different targets

It is designed as a preparation layer rather than a normal chat box.

## Core Workflow

1. Capture raw input  
2. Refine it into structured output  
3. Review or edit if needed  
4. Send it to the selected target

## Current Features

- Native macOS app
- Full mode and compact mode
- Voice input
- Rewrite / compress actions
- Clipboard output
- Multiple target routing
- Local packaging for GitHub Releases

## Release

Current macOS packaging is available under `vibe-hub-mac/`.

- local app bundle: `vibe-hub-mac/dist/VibeHub.app`
- GitHub release zip: `vibe-hub-mac/dist/VibeHub-macOS-<version>.zip`

See [RELEASE.md](/Users/nethon/.openclaw/workspace-main/vibe-hub/RELEASE.md) for release steps.  
See [RELEASE-NOTES-1.0.0.md](/Users/nethon/.openclaw/workspace-main/vibe-hub/RELEASE-NOTES-1.0.0.md) for the current release notes.  
See [PRIVACY.md](/Users/nethon/.openclaw/workspace-main/vibe-hub/PRIVACY.md) for the privacy note.  
See [SECURITY.md](/Users/nethon/.openclaw/workspace-main/vibe-hub/SECURITY.md) for secret-handling guidance.

## Installation

1. Download the latest release zip
2. Unzip it
3. Drag `VibeHub.app` into `Applications`
4. Open it from Applications or Launchpad

## Local Configuration

Users may need to configure a few local-only items:

- `Microphone` permission
- `Speech Recognition` permission
- optional `.env` file for local bridge settings and cloud LLM keys
- optional local `.vibe-hub/llm.json` for provider / model selection

Templates:

- [.env.example](/Users/nethon/.openclaw/workspace-main/vibe-hub/.env.example)
- [examples/llm.example.json](/Users/nethon/.openclaw/workspace-main/vibe-hub/examples/llm.example.json)

Recommended flow:

1. Copy `.env.example` to `.env` for local use only
2. Copy `examples/llm.example.json` to `.vibe-hub/llm.json`
3. Fill in your own local API key if you want cloud LLM features

If needed, you may use another AI tool locally to help generate the config, but keep the real key only on your own machine.

## Notes

- Voice input requires Microphone and Speech Recognition permissions
- Apple Speech may perform poorly on mixed Chinese-English dictation. If you need better mixed-language recognition, prefer `SenseVoice ONNX` as the secondary voice option.
- `SenseVoice ONNX` requires a local model download before it can run.
- Some targets require local integrations or app permissions
- Public builds are currently intended for direct distribution and testing
- Keep secrets local. Do not commit `.vibe-hub/`, `.env`, API keys, memory files, or personal runtime logs.
- If you use a cloud speech or LLM provider, set the key locally with `VIBE_HUB_LLM_API_KEY` or your own local config flow.
- If needed, you can use another AI tool locally to help write your API-key config, but keep the real key only on your own machine.

## License

MIT
