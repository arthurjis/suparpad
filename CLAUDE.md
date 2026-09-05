# suparpad — agent guide

From-scratch Launchpad replacement for macOS Tahoe. Read `SCOPE.md` first — it defines milestones and what is deliberately out of scope (e.g. NO search bar).

## Build & run

- `swift build` — builds all targets. No Xcode project; SPM only.
- `.build/debug/suparpad` — runs the app directly (dev loop).
- `scripts/make-app.sh --install` — release build → suparpad.app →
  /Applications, plus a launch-at-login LaunchAgent (com.arthur.suparpad).
  The installed app logs to `~/Library/Logs/suparpad.log` — read that file
  to debug the production instance.
- The user runs the installed app permanently. Before dev-running a debug
  binary, `pkill -x suparpad` (kills the installed instance too — two
  instances fight over the gesture); afterwards restore with
  `launchctl kickstart gui/$UID/com.arthur.suparpad`.
- `.build/debug/pinchprobe [seconds]` — raw trackpad touch logger (M5 spike). Prints finger count + spread per frame. Needs a human touching the trackpad; ask the user to pinch while it runs (suggest they run `! .build/debug/pinchprobe 15` themselves so timing lines up). Exit code 2 = no devices (missing Input Monitoring permission or no trackpad).

Verified working on this machine (2026-09-01, macOS 26.6.2, arm64): device enumerates, ~125Hz frames, MTTouch layout correct (normalized coords track smoothly in 0–1). The pinch detector is validated with real gestures: ≥4-finger stable run (raised from 3 — three contacts matches a 2-finger scroll with a resting thumb and false-triggered), 12-frame (~90ms) sliding window, |Δspread| ≥ 0.035 fast path, cumulative ≥ 0.06 slow path, centroid drift caps, 0.5s refractory, one event per touch session (re-arm on all-fingers-up). 18/18 pinches detected, ~100–140ms latency. pinchkit.c is the source of truth for current thresholds; keep pinchprobe in parity.

## Seeing the UI (yes, you can)

Run `scripts/devshot.sh [delay-seconds]` — it builds, launches the app, takes a full-screen `screencapture`, kills the app, and prints the PNG path. Then use the Read tool on that PNG to actually look at the rendered UI. Shots land in `.dev/shots/` (gitignored).

If the screenshot comes out empty/black, the terminal app needs Screen Recording permission (System Settings → Privacy & Security) — ask the user, don't retry in a loop.

For interaction testing later: `cliclick` (brew) can synthesize clicks/keys, but it needs Accessibility permission. Real pinches cannot be synthesized — pinch testing always needs the user's fingers on the trackpad.

## Conventions

- The app must stay runnable as a bare SPM executable (`swift build` + run) — don't introduce an Xcode-project-only workflow.
- Layout persistence goes to `~/Library/Application Support/suparpad/` as JSON.
- Private API (MultitouchSupport) is confined to the pinch code path; everything else public API only.
