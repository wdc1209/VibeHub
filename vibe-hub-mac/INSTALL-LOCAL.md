# VibeHub Local Install

## Current local run path
### Fastest path
- `cd vibe-hub && ./install-local.sh`

This now:
- runs the bridge smoke test
- packages the native app bundle
- opens `VibeHub.app`

### Manual path
1. Package native app bundle
   - `cd vibe-hub/vibe-hub-mac && ./package-app.sh`
2. Launch app bundle
   - `open vibe-hub/vibe-hub-mac/dist/VibeHub.app`

## GitHub release package
- `cd vibe-hub/vibe-hub-mac && ./package-release.sh 1.0.0`
- output:
  - `dist/VibeHub.app`
  - `dist/VibeHub-macOS-1.0.0.zip`

The `.zip` file is the one to upload to GitHub Releases for direct download.

## What `package-app.sh` now does
- runs `swift build`
- copies the latest binary into `dist/VibeHub.app/Contents/MacOS/VibeHub`
- normalizes bundle permissions
- re-signs the bundle with ad-hoc deep codesign so `open` / Finder launch keeps working

## Current prerequisites
- bridge running on `http://127.0.0.1:4765`
- Codex dedicated instance running with `--remote-debugging-port=9333`
- optional for future native rewrite/compress path:
  - set `VIBE_HUB_LLM_API_KEY=...`
  - edit `.vibe-hub/llm.json` for provider / base URL / models

## Current expected visible UI
- target picker
- status panel button
- history panel button
- rewrite / compress / cancel / refresh / send buttons
- build label in header

## Optional bridge smoke test
Before opening the native app, you can verify the bridge/session/Codex path with:
- `cd vibe-hub && ./smoke-test.sh`

This checks:
- `/status`
- `/token-session?sessionId=current-webchat`
- `/send/codex`

## LLM settings skeleton

Vibe Hub now exposes a first bridge-side settings layer for future native rewrite/compress:

- config file: `.vibe-hub/llm.json`
- read status: `curl http://127.0.0.1:4765/llm/settings`
- local CLI: `vibe-hub llm-status`

Recommended key path:

- keep the real key in env: `export VIBE_HUB_LLM_API_KEY=...`
- keep provider / base URL / model names in `.vibe-hub/llm.json`
- do not commit `.vibe-hub/llm.json`
- if needed, use another AI tool locally to help you write the config file, but keep the real key only on your own machine
