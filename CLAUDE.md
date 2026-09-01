# suparpad — agent guide

From-scratch Launchpad replacement for macOS Tahoe. Read `SCOPE.md` first — it defines milestones and what is deliberately out of scope (e.g. NO search bar).

## Build & run

- `swift build` — builds both targets. No Xcode project; SPM only.
- `.build/debug/suparpad` — runs the app directly (full-screen panel, Esc quits).
- `.build/debug/pinchprobe [seconds]` — raw trackpad touch logger (M5 spike). Prints finger count + spread per frame. Needs a human touching the trackpad; ask the user to pinch while it runs (suggest they run `! .build/debug/pinchprobe 15` themselves so timing lines up). Exit code 2 = no devices (missing Input Monitoring permission or no trackpad).

Verified working on this machine (2026-09-01, macOS 26.6.2, arm64): device enumerates, ~125Hz frames, MTTouch layout correct (normalized coords track smoothly in 0–1). The pinch detector in pinchprobe is validated with real gestures: ≥3-finger stable run, 12-frame (~90ms) sliding window, |Δspread| ≥ 0.05, centroid drift ≤ 0.10, one event per touch session (re-arm on all-fingers-up). 18/18 pinches detected, 0 false positives from scrolls/swipes, ~100–140ms latency. Reuse these exact thresholds when porting the detector into the app (M5).

## Seeing the UI (yes, you can)

Run `scripts/devshot.sh [delay-seconds]` — it builds, launches the app, takes a full-screen `screencapture`, kills the app, and prints the PNG path. Then use the Read tool on that PNG to actually look at the rendered UI. Shots land in `.dev/shots/` (gitignored).

If the screenshot comes out empty/black, the terminal app needs Screen Recording permission (System Settings → Privacy & Security) — ask the user, don't retry in a loop.

For interaction testing later: `cliclick` (brew) can synthesize clicks/keys, but it needs Accessibility permission. Real pinches cannot be synthesized — pinch testing always needs the user's fingers on the trackpad.

## Conventions

- The app must stay runnable as a bare SPM executable (`swift build` + run) — don't introduce an Xcode-project-only workflow.
- Layout persistence goes to `~/Library/Application Support/suparpad/` as JSON.
- Private API (MultitouchSupport) is confined to the pinch code path; everything else public API only.
