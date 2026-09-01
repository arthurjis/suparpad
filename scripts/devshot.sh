#!/bin/zsh
# Build, launch suparpad, screenshot the screen, kill the app, print the PNG path.
# Usage: scripts/devshot.sh [seconds-before-shot]
set -e
cd "$(dirname "$0")/.."

DELAY="${1:-2}"
OUT_DIR=".dev/shots"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/shot-$(date +%H%M%S).png"

swift build 2>&1 | tail -5
.build/debug/suparpad &
APP_PID=$!
sleep "$DELAY"
screencapture -x "$OUT"
kill "$APP_PID" 2>/dev/null || true

if [ -s "$OUT" ]; then
  echo "SCREENSHOT: $PWD/$OUT"
else
  echo "FAIL: screenshot empty — grant Screen Recording permission to the terminal app" >&2
  exit 1
fi
