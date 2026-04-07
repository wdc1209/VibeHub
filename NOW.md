# NOW

## Actively doing
Design the first native LLM-settings path for Vibe Hub independence:
1. add a bridge-side local config file for provider / base URL / models
2. keep the API key out of git and read it from an environment variable
3. expose `GET /llm/settings` and `POST /llm/settings`
4. surface current LLM settings in the native status panel
5. keep actual rewrite/compress provider calls as the next implementation layer

## Next concrete action
Validate the new settings endpoint and native status rendering, then decide whether the next pass should add a real provider adapter for `/llm/rewrite` and `/llm/compress`.
