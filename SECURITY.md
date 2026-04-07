# Security

## Secrets and private data

Do not commit or publish any of the following:

- `.vibe-hub/`
- `.env` or `.env.*`
- API keys
- local memory files
- crash logs or personal runtime logs

Recommended local env var for cloud LLM access:

- `VIBE_HUB_LLM_API_KEY`

## Local-only configuration

If a user wants cloud speech or LLM features, the key should be configured locally on their own machine.

It is acceptable to use another AI tool locally to help generate a config file or shell command, but the real key must remain local and must never be committed to git.

## Release packaging

Before creating a public release, verify that the packaged app and repository do not include:

- personal file-system paths
- local model caches
- local bridge state
- memory files
- API keys
- development crash logs
