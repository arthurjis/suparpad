# suparpad — scope

A from-scratch Launchpad replacement for macOS Tahoe (26+). Personal tool, not a product.

Target machine: Apple Silicon (arm64), macOS 26.6.2.

## Product decisions

- Full-screen app grid over a blurred wallpaper, like classic Launchpad.
- **No search bar.** Deliberate omission — Spotlight (⌘Space) already does search.
- Fixed grid, 7 columns × 5 rows per page (classic Launchpad density; make it a config constant).
- Click an app to launch it and dismiss. Esc or click-on-empty dismisses.
- Layout (ordering + page assignment) persists to a JSON file in `~/Library/Application Support/suparpad/`.
- New/removed apps: appended to the dump / pruned automatically — but only on
  app relaunch (scan runs once at startup), not on every panel open.
- Pinch-open while the panel is hidden toggles Show Desktop — restores the
  pre-Tahoe spread gesture, which macOS 26 dropped (Mission Control's toggle
  still exists; we invoke it via `open -a "Mission Control" --args 1`).

## Milestones

### M1 — Grid that launches apps
- Enumerate apps from `/Applications`, `~/Applications`, `/System/Applications` (top level + one folder depth, `.app` bundles only).
- Icons via NSWorkspace. Launch via NSWorkspace.
- Borderless full-screen NSPanel with blur (NSVisualEffectView), shows over current Space without creating a new one.
- Trigger: run the binary (dev mode). Esc closes.
- **Done when:** it opens instantly, shows all apps in a stable (alphabetical) grid, launches on click.

### M2 — Pages — CUT (2026-09-02)
- Dropped after M1: the vertical scroll grid turned out nicer than paging.
- Consequence for M3: layout is one continuous ordered sequence, no page assignment.

### M3 — Custom ordering
- Drag-and-drop to reorder within a page and across pages (drag to edge flips page).
- Persisted layout JSON; survives restart; new apps don't disturb existing order.
- **Done when:** an arrangement made by hand is still exactly there a week later.

### M4 — Always-on triggers — DONE 2026-09-02 (F4 deferred)
- Menu bar item (LSUIElement app, no Dock icon) with Show/Quit. ✓
- Launch-at-login via LaunchAgent; .app bundle built by scripts/make-app.sh,
  installed to /Applications, logs to ~/Library/Logs/suparpad.log. ✓
- Global hotkey (F4) deferred — pinch covers summoning; add on request.

### M5 — Pinch to open (stretch goal)
- Global 3/4-finger pinch detection via the private MultitouchSupport framework (raw touch data → own pinch detector with tunable thresholds).
- Needs Input Monitoring/Accessibility permission; user disables the system Apps-view gesture in System Settings → Trackpad.
- Known risk: private API, threshold tuning is trial-and-error, could break on a macOS update. If it fights us too long, hot corner + F4 is the fallback and M5 is dropped without regret.
- **Done when:** pinch-close opens suparpad reliably without false triggers while scrolling/zooming.

## Out of scope (v1)

- Search bar (permanent), pages (cut after M1 — scroll won), folders (maybe later), app deletion/uninstall, Liquid Glass styling, Intel support, App Store distribution, auto-update, importing the old Launchpad database.

## Tech choices

- Swift + SwiftUI for the grid, AppKit for the window/panel plumbing.
- Swift Package Manager executable + a small `make app` script that wraps it into a `.app` bundle with Info.plist (no Xcode project; buildable entirely from the terminal with `swift build`).
- Ad-hoc codesigned locally. No sandbox (M5 needs raw input access anyway).
