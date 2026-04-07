#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "[Vibe Hub] Running bridge smoke test..."
./smoke-test.sh

echo "[Vibe Hub] Packaging native macOS app..."
(
  cd vibe-hub-mac
  ./package-app.sh
)

echo "[Vibe Hub] Opening VibeHub.app..."
open "vibe-hub-mac/dist/VibeHub.app"

echo

echo "Done. Suggested checks:"
echo "  1. Open the 状态面板 and confirm 微信 / Codex / app list look correct."
echo "  2. Confirm 原始输入 shows current token session text."
echo "  3. Hold the 语音按压输入 area, speak a short line, and confirm it appears in 原始输入."
echo "  4. Send a short test line and verify Codex receives it."
