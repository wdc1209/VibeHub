#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
swift build >/tmp/vibe-hub-mac-build.log 2>&1
exec ./.build/debug/VibeHub
