# VibeHub Launch Notes

## Current situation
- Latest native build compiles successfully.
- Running via exec/background session can still be terminated with session SIGTERM.
- App bundle launcher path bug has been fixed.
- `.app` launch now works again via `open -na dist/VibeHub.app` after re-signing the bundle.
- Current packaging fix applied: normalize bundle permissions, then `codesign --force --deep --sign - dist/VibeHub.app`.
- Next launch work should preserve this in a repeatable packaging script and continue end-to-end bridge verification.

## Verification checklist
- confirm latest build timestamp in UI header
- confirm target picker is visible
- confirm status panel button is visible
- confirm history panel button is visible
- confirm rewrite / compress / cancel buttons are visible
- confirm bridge status reads `inputTerminal` and `codex.connected`
