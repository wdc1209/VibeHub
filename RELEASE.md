# Release Guide

## Current release artifact

The current GitHub-ready build artifact is:

- `vibe-hub-mac/dist/VibeHub-macOS-<version>.zip`

## Local release steps

```bash
cd /Users/nethon/.openclaw/workspace-main/vibe-hub/vibe-hub-mac
./generate-app-icon.sh
./package-release.sh 1.0.0
```

This produces:

- `dist/VibeHub.app`
- `dist/VibeHub-macOS-1.0.0.zip`

Upload the `.zip` file to GitHub Releases.

## Install for local use

```bash
cp -R /Users/nethon/.openclaw/workspace-main/vibe-hub/vibe-hub-mac/dist/VibeHub.app /Applications/
```

## What is already done

- App bundle packaging
- Ad-hoc codesign
- App icon generation via `.icns`
- GitHub release zip packaging
- MIT license
- Privacy note
- Secrets kept out of repo via `.gitignore`
- Local model / speech paths resolved from the current user's home directory
- Notarization script scaffold: `vibe-hub-mac/notarize-app.sh`

## What is still missing for a stricter public release

- Developer ID signing
- Apple notarization
- Optional auto-update feed

Without Developer ID signing and notarization, the app is suitable for direct distribution and testing, but Gatekeeper behavior may be stricter on other machines.

## Product line direction

- The current public release track is macOS-only.
- macOS should keep its own package and installation flow.
- Windows, if added later, should be released as a separate package instead of being bundled into the macOS release.
- The current macOS release should not be destabilized just to pre-optimize for future Windows support.

## Secrets and local config

- Do not publish `.vibe-hub/`, `.env`, API keys, memory files, or personal logs.
- If cloud speech or LLM access is needed, configure keys locally.
- Recommended env var name: `VIBE_HUB_LLM_API_KEY`
- Users may use another AI tool locally to help write config files, but the actual key must stay on their own machine.

## Optional notarized release

If you have Apple credentials configured:

```bash
cd /Users/nethon/.openclaw/workspace-main/vibe-hub/vibe-hub-mac
./generate-app-icon.sh
./package-app.sh
APPLE_SIGNING_IDENTITY="Developer ID Application: YOUR NAME (TEAMID)" \
APPLE_TEAM_ID="TEAMID" \
APPLE_ID="your@apple.id" \
APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
./notarize-app.sh
```
