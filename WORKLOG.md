# Vibe Hub Worklog

## Current mode
- Product direction: SwiftUI / AppKit native macOS utility window
- Not using Electron anymore
- Input: OpenClaw + bridge
- Output: bridge + opencli / Codex

## Current status
- bridge process is running
- Codex 9333 process is running
- native `VibeHub` binary exists and has run before
- SwiftUI/AppKit native scaffold exists under `vibe-hub/vibe-hub-mac/VibeHubApp/`
- bridge client / view model / history store have been added

## Last completed
- Added native files:
  - `VibeHubApp/main.swift`
  - `VibeHubApp/Views/VibeHubRootView.swift`
  - `VibeHubApp/Services/BridgeClient.swift`
  - `VibeHubApp/Models/VibeHubModels.swift`
  - `VibeHubApp/Models/VibeHubViewModel.swift`
  - `VibeHubApp/Models/SendHistoryStore.swift`
- Rebuilt native app successfully after fixing Swift concurrency / state wiring issues
- Added local history-store path (`Application Support/VibeHub/send-history.json`)

## Current focus
1. Verify native UI reads bridge status + token session correctly
2. Verify native send action truly reaches Codex
3. Preserve the fixed `.app` launch path in a repeatable packaging/install script
4. Then add native history UI / status panel UI
5. Then logo / install path

## Newly completed
- Rebuilt `VibeHub` successfully again on 2026-03-25 morning.
- Refreshed `dist/VibeHub.app/Contents/MacOS/VibeHub` with the latest native binary.
- Found that `.app` launch failure was in bundle launch/packaging rather than SwiftUI compilation.
- Fixed `.app` launch path enough for Finder/LaunchServices launch again by normalizing permissions and re-signing the bundle with ad-hoc deep codesign.
- Confirmed `open -na dist/VibeHub.app` no longer errors and `VibeHub` shows up as a normal app process.
- Added `vibe-hub/vibe-hub-mac/package-app.sh` so the working packaging fix is now repeatable in one command.
- Updated local install docs to use `./package-app.sh` instead of manual copy/sign steps.
- Aligned native Swift models with bridge JSON (`apps[].installed`, `send/codex -> output/error`) so status and send feedback can render correctly in the native UI.
- Rebuilt and re-packaged successfully after fixing a temporary model-edit regression.
- Added `vibe-hub/smoke-test.sh` to exercise `/status`, `/token-session`, and `/send/codex` in one repeatable command.
- Updated native install docs so bridge/Codex validation can happen before opening the app.
- Added a visible Help panel toggle in the native window with step-by-step acceptance instructions for smoke test, app launch, status verification, and Codex send verification.
- Rebuilt and re-packaged the app so the new acceptance guidance ships inside the native UI.
- Added `vibe-hub/install-local.sh` as a one-command local installer flow: smoke test -> package app -> open app.
- Ran the new fast local install flow end-to-end successfully.
- Updated native install docs so the fastest path is now `cd vibe-hub && ./install-local.sh`.
- Adjusted native floating behavior so the card is composited and moved as one unit instead of separately animating shadow/material perception against the text layer.
- Then reduced the motion further into a very light whole-card breathing effect (tiny scale + small vertical offset) so the utility window feels calmer and less theatrically floating.
- After direct user feedback, removed the current in-card floating motion entirely to eliminate perceived text/frame desync, and shifted the visual direction toward a steadier utility card.
- Hid the native traffic-light buttons/titlebar chrome and increased the glass-card transparency so the outer macOS window frame recedes much more.
- Reworked status/help/history into overlay-style floating panels so they no longer squeeze the main card layout.
- Restored only a very light whole-shell drift so the main card and overlay panel move together as one composed layer.
- Tightened the overlay behavior further toward popover semantics: closer anchoring near the top-right controls and tap-outside-to-dismiss.
- Restored the raw-input section to be collapsed by default via a DisclosureGroup-style interaction.
- Removed in-card overlay panels and switched status / history / help triggers over to separate NSWindow pop-outs.
- Reworked native status and history panels toward the V6 split layout so they more closely match the earlier web prototype.
- Removed the remaining content-layer float from `VibeHubRootView`; next motion work should happen at the NSWindow level so the frame and text truly drift together.
- Started a new native revision after the previous app version: moved floating from content-layer animation toward NSWindow-level drift, restored full-row raw-input expand behavior, brought back top-right icon buttons, widened/scroll-enabled status + history pop-out windows, and reintroduced expandable history rows plus richer search/filter controls.
- Added a native Edit menu so copy / paste / select-all / cut work properly in the main text editor.
- After user feedback that the first NSWindow drift felt like the window was "drowning", reduced it to a much smaller slow hover (sub-pixel-ish amplitude, slower cadence, guarded frame updates).
- Then reduced the hover amplitude again after feedback that the vertical travel was still too large; target now is only a barely-there lift, not visible bobbing.
- Fixed the hover anchor logic so the motion stays symmetric around a stable base point instead of gradually drifting downward over time.
- After continued user feedback about the window sinking, temporarily disabled NSWindow-level drift entirely so testing can continue from a stable baseline.
- Removed the leftover NSWindow drift scaffolding from `main.swift` entirely so future revisions cannot accidentally revive sinking behavior.
- Began v8 implementation: restored prototype-like whole-card float in `VibeHubRootView` (instead of window movement), removed the sync button, and changed body editing flow so incoming raw input merges onto the current edited body context rather than overwriting it.
- Extended bridge `/status` toward v8 needs: added real input source rows, connected agent rows, output terminal rows, and a local tutorial URL, plus a first `/connect/codex` action endpoint for output-terminal connect semantics.
- Updated native status panel to consume real bridge rows instead of placeholder counts, and added the fourth history filter (date) to the native send-history window.
- Completed the missing native ViewModel wiring for v8 status semantics: added published `inputSources` / `agentConnections` / `outputTerminals` / `localTutorialUrl`, so the new bridge `/status` shape now actually reaches the native status panel.
- Tightened the v8 raw-input merge path so incoming content appends into the current edited body context with an explicit `--- 新输入 ---` boundary, instead of silently overwriting the edited draft.
- Moved output-terminal connect behavior behind `BridgeClient.connectTerminal(action:)`, and wired the native status panel's `连接` button through that path followed by a refresh.
- Rebuilt successfully after the above v8 changes, so the current native branch compiles again with the real status-panel model.
- Hit a real integration blocker during v8 verification: the bridge was down and Codex was running without the required `--remote-debugging-port=9333` path, so native status/send verification could not complete until the runtime chain was restored.
- Restarted the bridge on `127.0.0.1:4765`, relaunched Codex with `--remote-debugging-port=9333`, verified `curl http://127.0.0.1:9333/json/version`, and confirmed `OPENCLI_CDP_ENDPOINT=http://127.0.0.1:9333 opencli codex status` is connected again.
- Re-ran `vibe-hub/smoke-test.sh` successfully: `/status` ok, Codex connected, and `/send/codex` now injects text successfully again. This clears the runtime chain blocker and returns v8 to real UI/interaction verification mode.
- Tightened v8 input-terminal semantics on the bridge side: `/status` now always reports both real intake channels (`微信` and `OpenClaw Web Chat`) instead of hiding webchat until a token session exists.
- Switched the native status-panel input badges toward the intended wording (`当前` / `已接入` / `未接入`) so the UI reads like real channel state rather than a generic placeholder connection list.
- Corrected the local tutorial path in bridge `/status` so the native panel now points to `opencli-supported-targets.html` instead of the generic prototype page.
- Rebuilt successfully after the above v8 status-semantics refinements.
- Added a first visible v8 editing-lifecycle layer in the native app: `lifecycleHint` now explains whether the card is waiting for input, being edited, has merged fresh raw input, should be rewritten, or has already been sent.
- Added `needsRewriteAfterMerge` so when new raw input lands on top of the current edited body, the UI can explicitly surface a `建议整理` cue instead of silently leaving the merged draft looking final.
- Wired rewrite / compress / cancel / send paths to update lifecycle messaging, so A/B/C is no longer just background merge logic — the user can now see the current draft state in the main editor area.
- Rebuilt successfully after the above v8 editing-lifecycle visibility pass.
- Pushed the v8 lifecycle semantics one step further in the main action row: when fresh raw input has been merged into the current edited draft, the old generic `重写` button now upgrades into an orange primary `整理` action so the product nudges the user toward the correct next step.
- Tightened the in-editor lifecycle cue from `建议整理` to `建议整理后再发送`, making the post-merge state less ambiguous.
- Fixed a SwiftUI button-style implementation issue during this pass and rebuilt successfully after switching to a branch-based button rendering path.
- Synced the first user-led acceptance results into the tracker: marked 1 / 4 / 7 / 10 as accepted, parked 11 for later dedicated testing, and kept 2 / 3 / 5 / 6 / 8 / 9 active.
- Updated the acceptance tracker after the latest user review: item 6 (`窗体四周玻璃留白统一`) is now accepted; item 11 (`A/B/C 编辑生命周期正确`) remains intentionally unaccepted and will be tested in one focused pass after the first 10 items are fully closed.
- Tightened the status panel back toward the requested four-block structure by removing the extra agent block, simplifying the top summary to `Codex 已连接 / 待连接`, and changing the aggregate output summary to `x / total 已连接`.
- Changed the history button icon again from `clock.arrow.circlepath` to the simpler `clock` so it reads more like plain history/time.
- Reduced the remaining visual float impression further by lowering outer padding/inner padding uniformly and toning down the background + shadow strength, aiming for a steadier glass card.
- Rebuilt and re-packaged successfully after the above acceptance-driven fixes.
- Started v9-1 as an actual implementation instead of a note: added `skills/vibe-hub-router/SKILL.md` plus a route matrix reference so the "must enter Vibe Hub / may stay direct / should clarify" policy now exists as a reusable skill artifact.
- Replaced the bridge's old length-based `/route` classifier with a rule-based evaluator in `bridge/src/routingRules.js`; routing now distinguishes explicit outbound handoff, active Vibe Hub continuation, direct explanation/control requests, and outbound intent that still needs clarification.
- Extended `/route` responses with `policyVersion`, `decision`, `triggers`, and optional `clarificationPrompt`, and updated the V6 prototype status copy so `clarify` can surface as `需要澄清`.
- Added a Chinese real-phrase route library in `skills/vibe-hub-router/references/real-phrases.md` and mirrored those examples into `bridge/src/routeCases.js` plus `bridge/src/route-check.js`, so routing policy can now be regression-checked with realistic daily wording instead of only hand-picked one-offs.
- Tuned the v9-1 evaluator for more natural Chinese phrasing during that pass, including "能发的版本", "出一版", active-session edit phrases like "把语气再收一点", and the special case where the user is only asking how to phrase something to an external person rather than asking for a sendable draft yet.
- Began v9-2 as a concrete scaffold instead of only a tracker note: added `V9-2-VOICE-INPUT-PLAN.md` to lock the first-phase architecture around press-to-talk UI, local speech recognition, bridge persistence, and post-voice rewrite semantics.
- Added a first bridge-side voice contract at `/voice/input`, which appends transcript text into the current token session and returns `suggestedAction: rewrite` plus voice metadata for the native client.
- Added a native `VoiceInputService` using macOS `Speech` + `AVFoundation`, along with new view-model voice states (`idle / requestingPermission / recording / processing / failed`) and a first hold-to-talk surface in the main Vibe Hub window.
- Wired successful voice transcript submission back into the existing raw-input merge lifecycle so the editor now explicitly re-enters a `建议整理后再发送` state after voice append.
- Updated `vibe-hub-mac/package-app.sh` to emit an app `Info.plist` with microphone and speech-recognition usage descriptions so packaged builds have the required privacy keys for the new voice path.
- Added a first bridge-side LLM settings layer in `bridge/src/llmSettings.js`, using `.vibe-hub/llm.json` for provider/baseURL/model config and an environment variable (`TOKEN_CARD_LLM_API_KEY` by default) for the real secret.
- Exposed that settings layer through `GET /llm/settings`, `POST /llm/settings`, and `vibe-hub llm-status`, so Vibe Hub now has an explicit engineering path for API/model configuration without putting keys into the native app bundle.
- Extended native bridge/status models and the Status panel so the current provider, base URL, rewrite/compress/route models, and key-source status are visible inside the app.
- Paused DeerFlow exploration and formalized the next floating-work priority: added `FLOATING-WEB-PLAN-2026-03-30.md` to define the web-side floating parameter model, default values, editor-pause rule, phased rollout, and acceptance criteria before resuming any new target integrations.
- Added two new first-class text delivery targets to Vibe Hub: `微信` and `剪贴板`. The bridge now exposes both in `outputTerminals`, `clipboard` send is verified end-to-end via system clipboard, and `wechat` uses the macOS AppleScript + clipboard draft path (activate WeChat + paste into the current chat input without auto-send). Live validation showed clipboard success and WeChat currently blocked only by missing System Events keystroke permission (`1002`), so the remaining step is macOS automation/accessibility authorization rather than bridge wiring.

## Known blockers
- Cron delivery back to chat is unreliable (`sendWeixinOutbound: contextToken is required`)
- Native app staying alive independently from exec/session needs more validation

## Rule for updates
This file should be updated whenever a concrete implementation step lands, not for empty status chatter.
