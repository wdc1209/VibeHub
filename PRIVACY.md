# Privacy

## What Vibe Hub accesses

Vibe Hub is a local macOS app. It may access:

- Microphone, when you use voice input
- Speech recognition, when converting held voice input into draft text
- Clipboard, when you choose clipboard as the send target
- Local bridge services running on your own machine

## What Vibe Hub does not do by default

Vibe Hub does not require a cloud account just to open the app UI.

It does not upload your content anywhere unless you explicitly use:

- an LLM provider
- an external send target
- a local integration that forwards content outside the app

## LLM providers

When rewrite/compress/routing features are enabled, Vibe Hub may send content to the configured LLM provider.

The current provider is determined by your local configuration.

## Local storage

Vibe Hub stores local app state, release assets, and local configuration on your machine. It may also keep transient logs during local development and packaging.

Local configuration such as `.vibe-hub/llm.json`, `.env` files, model assets, and any API keys should remain on the user's machine and should not be uploaded to public repositories.

## Distribution note

Public builds may still require Apple Developer ID signing and notarization for the smoothest installation experience on other Macs.
