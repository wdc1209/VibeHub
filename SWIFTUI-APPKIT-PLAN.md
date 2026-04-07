# Vibe Hub · SwiftUI / AppKit Plan

## Goal
Build Vibe Hub as a real macOS utility window using SwiftUI + AppKit.

It should:
- be a standalone draggable macOS window
- visually inherit the final V6 structure
- read input from OpenClaw + bridge
- send output through bridge + opencli
- keep local history
- include basic logo / app icon direction
- be installable by other users with minimal setup friction

## Product boundaries
Vibe Hub app itself is responsible for:
- window UI
- content editing
- status display
- local history display
- send entrypoint

Vibe Hub app is NOT responsible for:
- capturing input from the user’s chat surfaces directly
- executing target delivery directly

Those remain in:
- OpenClaw + bridge for input aggregation/routing
- opencli / target adapters for delivery

## Architecture

### App layer
- SwiftUI for main UI
- AppKit for window styling / dragging / vibrancy / traffic-light placement / utility-window behavior

### Integration layer
- local HTTP to bridge (`127.0.0.1`)
- endpoints reused from current prototype:
  - `GET /status`
  - `POST /route`
  - `GET /token-session?sessionId=current-webchat`
  - `POST /send/codex`

### Persistence layer
- local history storage in app container
- first version acceptable: JSON
- preferred next step: SwiftData or SQLite

## Milestones

### M1 · Native window shell
- create mac app project
- create standalone Vibe Hub window
- draggable custom top region
- transparent / vibrancy-backed utility-window feel
- no fake desktop screenshot, no web-shell semantics

### M2 · V6 structure migration
Translate V6 into native views:
- header row
- target selector
- card status pill
- main editor
- raw input disclosure section
- send progress / feedback
- status panel
- history panel

### M3 · Bridge input integration
- fetch `GET /status`
- fetch `GET /token-session?sessionId=current-webchat`
- hydrate current card from merged long-form input
- mark card state as pending when new input arrives

### M4 · Output integration
- send via `POST /send/codex`
- preserve current Codex requirement:
  - dedicated Codex instance started with `--remote-debugging-port=9333`
- show success / failure feedback
- append send result into local history

### M5 · Logo / icon
- create initial app icon direction
- lightweight in-window mark for Vibe Hub
- keep style aligned with glass / token / card metaphor
- deliver at least:
  - app icon
  - small inline logo mark
  - exportable assets for README / installer

### M6 · Installation / distribution
Short-term:
- local buildable `.app`
- README with bridge + Codex setup

Medium-term:
- signed `.dmg`
- onboarding checks for:
  - bridge installed/running
  - opencli available
  - Codex 9333 instance reachable

Long-term:
- GitHub Releases
- auto-update path
- `npx @openclaw/vibe-hub install` for bridge/doctor/environment setup

## Logo direction
- avoid over-designed illustration in v1
- small floating card + token core motif
- mac-friendly, clean, recognizable in Dock/Finder
- colors: fog blue / silver white / subtle glow

## Fast-install strategy for other users
1. download `Vibe Hub.app`
2. move to Applications
3. run installer / doctor for bridge setup
4. verify Codex connectivity and targets from app onboarding

## First release definition
Release is good enough when:
- real native macOS window exists
- V6 structure is recognizably migrated
- app reads current token session from bridge
- app can send to Codex through bridge
- send history is stored locally
- app icon/logo exists in usable form
- another user can install using documented steps

## Immediate next build steps
1. scaffold native macOS app project
2. build window shell
3. migrate V6 layout into SwiftUI views
4. add bridge client
5. connect send flow
6. add local history
7. add icon + install notes
