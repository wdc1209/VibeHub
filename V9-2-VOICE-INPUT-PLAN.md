# V9-2 Voice Press Input Plan

## Goal

Add a press-to-talk path inside Vibe Hub so spoken input can enter the same draft lifecycle as typed input.

Phase 1 is not a full voice product. It is a stable MVP loop:

1. hold to talk in the mac app
2. speech becomes transcript text
3. transcript is stored as raw Vibe Hub input through bridge
4. main editor is nudged back into a `整理后再发送` state

## Why this scope first

The current product risk is not "speech model quality" first. It is whether Vibe Hub can become a reliable foreground controller.

So the first implementation should lock down:

- UI location
- recording state machine
- transcript ingestion contract
- lifecycle semantics after voice append

before trying to optimize:

- long-running streaming ASR
- direct LLM rewrite inside Vibe Hub
- mobile parity

## Product behavior

### Entry

- user presses and holds the voice surface
- Vibe Hub requests microphone + speech permissions when needed
- partial transcript can appear while recording

### Release

- when the user releases, recording stops
- transcript is posted to bridge `/voice/input`
- bridge appends it to the current token session as raw input
- Vibe Hub moves the main draft into a "needs rewrite" state

### User-visible rule

Voice transcript is treated as raw input, not as already polished output.

That means after successful voice capture the UI should bias toward:

- `已收到语音`
- `建议整理后再发送`

instead of pretending the transcript is already final.

## Bridge contract

### `POST /voice/input`

Request:

```json
{
  "sessionId": "current-webchat",
  "text": "用户语音转写结果",
  "source": "press-to-talk"
}
```

Response:

```json
{
  "ok": true,
  "message": "语音已转写并并入 Vibe Hub 原始输入，建议整理后再发送。",
  "suggestedAction": "rewrite",
  "voiceInput": {
    "text": "用户语音转写结果",
    "source": "press-to-talk",
    "recordedAt": "2026-03-26T08:00:00.000Z"
  },
  "tokenSession": {
    "id": "...",
    "sessionId": "current-webchat",
    "mergedText": "..."
  }
}
```

Phase 1 intentionally does not make bridge itself rewrite the transcript.

## Native app state machine

### Voice states

- `idle`
- `requestingPermission`
- `recording`
- `processing`
- `failed`

### Transitions

- `idle -> requestingPermission -> recording`
- `recording -> processing -> idle`
- any failure -> `failed`

### Recovery

- next press should always be able to start a fresh attempt
- failed state must not poison later attempts

## Implementation choices for Phase 1

- use macOS `Speech` + `AVFoundation` locally for transcription
- keep Vibe Hub as the recording owner
- keep bridge as the raw-input persistence owner
- do not depend on OpenClaw for the speech-to-text step
- keep later "rewrite by LLM" as a separate layer

## Deferred to later

- server-side ASR
- direct Vibe Hub -> LLM rewrite after transcript lands
- audio file persistence / replay
- per-session waveform history
- mobile / Windows parity

## Acceptance for this phase

1. Pressing and holding shows a clear recording state.
2. Releasing sends transcript to bridge successfully.
3. Raw input panel shows the merged transcript.
4. Main editor enters a rewrite-recommended state.
5. Packaging includes microphone and speech-recognition usage descriptions.
